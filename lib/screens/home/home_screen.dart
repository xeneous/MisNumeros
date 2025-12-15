import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geolocator/geolocator.dart';

import '../../providers/auth_provider.dart';
// import '../../models/user.dart'; // User model is now Usuario
import '../../models/fixed_expense.dart'; // Needed for ExpenseFrequency enum
import '../../models/proximo_gasto.dart';
import '../../models/account.dart';
import '../../models/user.dart';
import '../../models/skipped_payment.dart';
import '../../models/transaccion.dart' as tx; // Import old Transaccion model
import '../../models/transaction.dart'
    as new_tx; // Import NEW Transaction model
import '../../services/database_service.dart';
import '../../services/mercado_pago_service.dart';
import '../accounts/add_edit_account_screen.dart';
import '../accounts/account_transactions_screen.dart';
import '../transactions/add_transaction_screen.dart';
import '../fixed_expenses/add_edit_fixed_expense_screen.dart';

// Extensiones auxiliares para manejo de fechas
extension DateTimeExtensions on DateTime {
  int get daysInMonth {
    final nextMonth = month == 12
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);
    return nextMonth.subtract(Duration(days: day)).day;
  }

  DateTime get startOfMonth => DateTime(year, month, 1);
  DateTime get endOfMonth => DateTime(year, month + 1, 0, 23, 59, 59);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final DatabaseService dbService = DatabaseService();
  final MercadoPagoService _mpService = MercadoPagoService();
  // Controla si se muestran los valores o asteriscos
  bool _showFinancialValues = true;
  bool _hasLoadedOnce = false;
  bool _isMercadoPagoConnected = false;
  bool _hasAutoSyncedThisSession = false;

  // Datos del home
  List<Account> _accounts = [];
  List<ProximoGasto> _proximosGastos = [];
  Map<String, double> _accountBalances = {};
  Map<int, String> _gastoFijoNames = {}; // Map of gastoFijo ID to name
  Map<int, String> _gastoFijoIds = {}; // Map of gastoFijo hash to real UUID
  Set<String> _skippedPaymentKeys = {}; // Set of "fixedExpenseId_date" for skipped payments
  List<new_tx.Transaction> _dailyTransactions =
      []; // List for daily transactions
  final double _totalAvailableBalance = 0.0; // Sum of all account balances
  bool _isLoading = true;
  double _dailyLimit = 0.0;

  String _displayMode = 'local'; // 'local', 'travel', 'all'
  String _activeCurrency = 'ARS'; // The primary currency for the current mode
  Map<String, double> _totalBalancesByCurrency = {};
  Map<String, double> _reserveBalancesByCurrency = {};
  Map<String, double> _projectedEndOfMonthByCurrency = {};

  // State for quick transaction form
  final _quickAddFormKey = GlobalKey<FormState>();
  final _quickAddAmountController = TextEditingController();
  final _quickAddDescriptionController = TextEditingController();
  final _quickAddCategoryController = TextEditingController();
  tx.TipoTransaccion? _quickAddTransactionType;
  Account? _quickAddSelectedAccount;
  String? _quickAddTransactionCurrency;
  bool _showExtraQuickAddFields = false;
  bool _isSavingQuickTransaction = false;
  final FocusNode _quickAddAmountFocus = FocusNode();

  List<String> _topExpenseDescriptions = [];
  List<String> _topIncomeDescriptions = [];
  bool _showOnlyPending = true; // Filtro para próximos gastos

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _checkMercadoPagoConnection();
  }

  Future<void> _checkMercadoPagoConnection() async {
    final isConnected = await _mpService.isConnected();
    if (mounted) {
      setState(() {
        _isMercadoPagoConnected = isConnected;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload data when returning to this screen, but skip first load
    if (_hasLoadedOnce && mounted) {
      _loadData();
    }
    _hasLoadedOnce = true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // Properly dispose of controllers and focus nodes
    _quickAddAmountController.dispose();
    _quickAddDescriptionController.dispose();
    _quickAddCategoryController.dispose();

    // Ensure focus node is properly disposed
    if (_quickAddAmountFocus.hasFocus) {
      _quickAddAmountFocus.unfocus();
    }
    _quickAddAmountFocus.dispose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Reload data when app returns to foreground/resumed state
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.user;

    return Scaffold(
      drawer: _buildMasterDataDrawer(),
      body: currentUser == null
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(currentUser),
      floatingActionButton: currentUser != null
          ? FloatingActionButton(
              onPressed: _showAddTransactionSheet,
              backgroundColor: Colors.deepPurple,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _displayMode = prefs.getString('display_mode') ?? 'local';

      switch (_displayMode) {
        case 'local':
          _activeCurrency = 'ARS';
          break;
        case 'travel':
          _activeCurrency = 'USD'; // Hardcoded for now
          break;
        case 'all':
          _activeCurrency = 'ARS'; // Default for suggestions
          break;
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.user;
      if (currentUser == null) throw Exception("Usuario no encontrado");

      // Fetch accounts first (needed for filtering)
      final allAccounts = await dbService.getAccounts(currentUser.id);

      final accounts = _displayMode == 'all'
          ? allAccounts
          : allAccounts.where((acc) => acc.moneda == _activeCurrency).toList();

      // Calculate balances and totals synchronously (no await needed)
      final balances = await _calculateBalances(accounts);

      _totalBalancesByCurrency = _calculateTotalBalancesByCurrency(accounts, balances);
      _reserveBalancesByCurrency = _calculateReserveBalancesByCurrency(accounts, balances);

      // Fetch all other data in parallel
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day, 0, 0, 0);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      final results = await Future.wait([
        // Daily transactions
        dbService.getTransactions(
          userId: currentUser.id,
          fromDate: startOfDay,
          toDate: endOfDay,
        ),
        // Top expense descriptions
        dbService.getTopTransactionDescriptions(
          currentUser.id,
          tx.TipoTransaccion.gasto,
        ),
        // Top income descriptions
        dbService.getTopTransactionDescriptions(
          currentUser.id,
          tx.TipoTransaccion.ingreso,
        ),
        // Próximos gastos
        _generateProximosGastosFromFixed(currentUser.id),
        // Skipped payments
        dbService.getSkippedPayments(),
      ]);

      final dailyTransactions = results[0] as List<new_tx.Transaction>;
      final topExpenses = results[1] as List<String>;
      final topIncomes = results[2] as List<String>;
      final proximosGastos = results[3] as List<ProximoGasto>;
      final skippedPayments = results[4] as List<dynamic>;

      // Build set of skipped payment keys for quick lookup
      final skippedKeys = <String>{};
      for (var skip in skippedPayments) {
        final dateStr = (skip.skippedDate as DateTime).toIso8601String().split('T')[0];
        skippedKeys.add('${skip.fixedExpenseId}_$dateStr');
      }

      // Calculate daily limit
      final dailyLimit = _calculateDailyLimit(
        _totalBalancesByCurrency[_activeCurrency] ?? 0.0,
      );

      if (mounted) {
        setState(() {
          _accounts = accounts;
          _proximosGastos = proximosGastos;
          _accountBalances = balances;
          _isLoading = false;
          _dailyTransactions = dailyTransactions;
          _dailyLimit = dailyLimit;
          _topExpenseDescriptions = topExpenses;
          _topIncomeDescriptions = topIncomes;
          _skippedPaymentKeys = skippedKeys;

          // Calculate theoretical end of month after we have all the data
          _projectedEndOfMonthByCurrency = _calculateTheoreticalEndOfMonth();

          // Set default account for quick add form if not already set, inside setState
          if (accounts.isNotEmpty) {
            _quickAddSelectedAccount =
                accounts.where((acc) => acc.isDefault).firstOrNull ??
                accounts.first;
          }
        });
      }

      // Sincronización automática de Mercado Pago (en segundo plano, sin bloquear)
      // Solo sincronizar una vez por sesión para evitar loops
      if (_isMercadoPagoConnected && !_hasAutoSyncedThisSession) {
        _hasAutoSyncedThisSession = true;
        _autoSyncMercadoPago();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar datos: $e')));
      }
    }
  }

  Future<void> _autoSyncMercadoPago() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.id ?? '';

      final syncedCount = await _mpService.syncPaymentsToTransactions(
        appUserId: userId,
      );

      // Solo mostrar notificación si se sincronizaron pagos nuevos
      if (syncedCount > 0 && mounted) {
        // Actualizar solo las transacciones del día sin recargar todo
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day, 0, 0, 0);
        final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

        final dailyTransactions = await dbService.getTransactions(
          userId: userId,
          fromDate: startOfDay,
          toDate: endOfDay,
        );

        if (mounted) {
          setState(() {
            _dailyTransactions = dailyTransactions;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ $syncedCount pago(s) de Mercado Pago sincronizado(s)'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // Fallar silenciosamente para no interrumpir la experiencia del usuario
      print('Error en sincronización automática de MP: $e');
    }
  }

  Widget _buildBody(User currentUser) {
    return SafeArea(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¡Hola, ${currentUser.alias ?? currentUser.displayName ?? 'Usuario'}!',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(
                            0xFF424242,
                          ), // Un gris oscuro y elegante (grey[850])
                        ),
                      ),
                      Text(
                        _formatDate(DateTime.now()),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors
                              .grey[600], // Un gris más suave para la fecha
                        ),
                      ),
                      if (_displayMode != 'local')
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            _getModeLabel(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _displayMode == 'travel'
                                  ? Colors.deepPurple
                                  : Colors.orange[800],
                            ),
                          ),
                        ),
                    ],
                  ),
                  pinned:
                      false, // Permite que el AppBar desaparezca al hacer scroll
                  floating:
                      true, // Hace que el AppBar reaparezca al hacer scroll hacia abajo
                  snap:
                      true, // Asegura que el AppBar se muestre o se oculte completamente
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  foregroundColor: Colors.grey[800],
                  actions: [
                    IconButton(
                      icon: Icon(
                        _showFinancialValues
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() {
                          _showFinancialValues = !_showFinancialValues;
                        });
                      },
                    ),
                  ],
                ),
                SliverToBoxAdapter(child: _buildFinancialContent(currentUser)),
              ],
            ),
    );
  }

  String _getModeLabel() {
    switch (_displayMode) {
      case 'travel':
        return 'Modo Viaje (USD)';
      case 'all':
        return 'Modo Mixto (Todas las monedas)';
      case 'local':
      default:
        return '';
    }
  }

  Widget _buildFinancialContent(User currentUser) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // const Divider(),
          Row(
            children: [
              Expanded(
                flex: 6,
                child: _buildTitledAmountBox(
                  title: 'Disponible',
                  balances: _totalBalancesByCurrency,
                  color: Colors.blue[800]!,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: _buildTitledAmountBox(
                  title: 'Límite Diario',
                  amount: _dailyLimit,
                  color: Colors.grey[700]!,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Saldo teórico a fin de mes (sin recuadro)
          _buildTheoreticalBalance(),

          const SizedBox(height: 16),

          // Cuentas/Billeteras - carrusel
          _buildAccountsCarousel(),

          const SizedBox(height: 16),

          // Acumulado de tarjetas de crédito
          _buildCreditCardsAccumulated(),

          const SizedBox(height: 16),

          // Formulario de carga de ingresos/gastos
          _buildQuickTransactionForm(),

          const SizedBox(height: 16),

          // Próximos gastos
          _buildProximosGastosCompact(),

          const SizedBox(height: 80), // Espacio para el FloatingActionButton
        ],
      ),
    );
  }

  Widget _buildTheoreticalBalance() {
    final theoreticalBalance = _projectedEndOfMonthByCurrency[_activeCurrency] ?? 0.0;
    final isPositive = theoreticalBalance >= 0;
    final color = isPositive ? Colors.green[700]! : Colors.red[700]!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          _showFinancialValues
              ? 'Saldo teórico fin de mes: ${_formatFinancialValue(theoreticalBalance)}'
              : 'Saldo teórico fin de mes: ● ● ● ● ●',
          style: TextStyle(
            fontSize: 17.1, // 5% menos que 18
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildTitledAmountBox({
    required String title,
    Map<String, double>? balances,
    double? amount,
    required Color color,
    bool showTrendIcon = false,
  }) {
    final isDisponible = title == 'Disponible';
    final isProyectado = title == 'Proyectado Fin de Mes';

    // Determine trend icon for projected balance
    IconData? trendIcon;
    if (showTrendIcon && isProyectado) {
      final projectedValue = balances?[_activeCurrency] ?? amount ?? 0.0;
      trendIcon = projectedValue >= 0 ? Icons.trending_up : Icons.trending_down;
    }

    return InkWell(
      onTap: isDisponible ? _showAccountBreakdown : null,
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 55,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (trendIcon != null) ...[
                      Icon(
                        trendIcon,
                        size: 20,
                        color: color,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      _showFinancialValues
                          ? (balances != null
                                ? _formatMultiCurrency(balances)
                                : _formatFinancialValue(amount ?? 0.0))
                          : '● ● ● ● ●',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -8,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
          if (isDisponible)
            Positioned(
              top: -8,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Icon(
                  Icons.info_outline,
                  size: 14,
                  color: color.withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProximosGastosCompact() {
    // Filtrar gastos según el filtro seleccionado
    final filteredGastos = _showOnlyPending
        ? _proximosGastos.where((g) {
            // Exclude paid expenses
            if (g.pagado) return false;

            // Exclude skipped expenses
            final realFixedExpenseId = _gastoFijoIds[g.idGasto];
            if (realFixedExpenseId != null) {
              final dateStr = g.fechaVencimiento.toIso8601String().split('T')[0];
              final skipKey = '${realFixedExpenseId}_$dateStr';
              if (_skippedPaymentKeys.contains(skipKey)) return false;
            }

            return true;
          }).toList()
        : _proximosGastos;

    // Tomar solo los primeros 3 para el scroll
    final displayGastos = filteredGastos.take(3).toList();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con título, filtro y botón agregar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Próximos gastos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Row(
                children: [
                  // Filtro Todos/Pendientes
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFilterButton('Pendientes', true),
                        _buildFilterButton('Todos', false),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _navigateToAddFixedExpense(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B73FF).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 20,
                        color: Color(0xFF6B73FF),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Lista scrolleable de hasta 3 gastos
          displayGastos.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _showOnlyPending
                          ? 'No tienes gastos pendientes.'
                          : 'No tienes gastos próximos.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: displayGastos.length,
                  separatorBuilder: (context, index) => const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final gasto = displayGastos[index];
                      final daysUntilDue = gasto.fechaVencimiento
                          .difference(DateTime.now())
                          .inDays;
                      final isOverdue = daysUntilDue < 0;
                      final isDueToday = daysUntilDue == 0;

                      // Check if this payment is skipped
                      final realFixedExpenseId = _gastoFijoIds[gasto.idGasto];
                      final dateStr = gasto.fechaVencimiento.toIso8601String().split('T')[0];
                      final skipKey = realFixedExpenseId != null ? '${realFixedExpenseId}_$dateStr' : '';
                      final isSkipped = _skippedPaymentKeys.contains(skipKey);

                      return Opacity(
                        opacity: (gasto.pagado || isSkipped) ? 0.5 : 1.0,
                        child: Row(
                          children: [
                            // Indicador de fecha
                            _buildDateIndicator(gasto.fechaVencimiento, isOverdue),
                            const SizedBox(width: 16),
                            // Detalles del gasto
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _gastoFijoNames[gasto.idGasto] ?? gasto.detalle,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: isSkipped ? Colors.grey : null,
                                      decoration: (gasto.pagado || isSkipped)
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isOverdue
                                        ? 'Vencido hace ${-daysUntilDue} día(s)'
                                        : (isDueToday
                                            ? 'Vence hoy'
                                            : 'Vence en ${daysUntilDue + 1} día(s)'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isOverdue ? Colors.red[700] : Colors.grey[600],
                                      fontWeight: isOverdue || isDueToday
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Monto y botones
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _showFinancialValues
                                      ? _formatFinancialValue(gasto.importe)
                                      : '● ● ● ● ●',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Botón Saltear/Restaurar
                                    if (!gasto.pagado) ...[
                                      InkWell(
                                        onTap: () => _skipPayment(gasto),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSkipped
                                                ? Colors.green.withValues(alpha: 0.1)
                                                : Colors.orange.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isSkipped
                                                  ? Colors.green[300]!
                                                  : Colors.orange[300]!,
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isSkipped ? Icons.refresh : Icons.skip_next,
                                                color: isSkipped
                                                    ? Colors.green[700]
                                                    : Colors.orange[700],
                                                size: 14,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isSkipped ? 'Restaurar' : 'Saltear',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isSkipped
                                                      ? Colors.green[700]
                                                      : Colors.orange[700],
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    // Botón marcar como pagado
                                    InkWell(
                                      onTap: () => _toggleGastoPagado(
                                        _proximosGastos.indexOf(gasto),
                                        !gasto.pagado,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: gasto.pagado
                                              ? const Color(0xFF6B73FF)
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: gasto.pagado
                                                ? const Color(0xFF6B73FF)
                                                : Colors.grey[400]!,
                                            width: 2,
                                          ),
                                        ),
                                        child: gasto.pagado
                                            ? const Icon(
                                                Icons.check,
                                                color: Colors.white,
                                                size: 16,
                                              )
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, bool isPending) {
    final isSelected = _showOnlyPending == isPending;
    return InkWell(
      onTap: () {
        setState(() {
          _showOnlyPending = isPending;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6B73FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountsCarousel() {
    // Filter to show only available accounts (not savings)
    final availableAccounts = _accounts
        .where((account) => account.accountPurpose == AccountPurpose.available)
        .toList();

    if (availableAccounts.isEmpty) {
      return Center(
        child: Column(
          children: [
            const Icon(
              Icons.account_balance_wallet,
              color: Colors.grey,
              size: 48,
            ),
            const SizedBox(height: 8),
            Text(
              'No hay cuentas disponibles',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _showAddAccountDialog(context),
              child: const Text('Crear Cuenta'),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tus cuentas',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 89, // Reduced 15% (105 * 0.85)
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: availableAccounts.length,
            itemBuilder: (context, index) {
              final cuenta = availableAccounts[index];
              final saldo = _accountBalances[cuenta.id] ?? 0.0;
              return SizedBox(
                width: MediaQuery.of(context).size.width * 0.49, // Reduced 15% (0.58 * 0.85)
                child: _buildAccountCard(cuenta, saldo),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCreditCardsAccumulated() {
    // Filter credit card accounts
    final creditCards = _accounts
        .where((account) => account.type == AccountType.credit)
        .toList();

    if (creditCards.isEmpty) {
      return const SizedBox.shrink(); // Don't show anything if no credit cards
    }

    // Calculate total accumulated (negative balance means debt)
    double totalAccumulated = 0;
    for (var card in creditCards) {
      final balance = _accountBalances[card.id] ?? 0.0;
      // For credit cards, negative balance is debt
      totalAccumulated += balance.abs();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.credit_card,
                    color: Colors.orange[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Tarjetas de Crédito',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${creditCards.length} ${creditCards.length == 1 ? 'tarjeta' : 'tarjetas'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total acumulado',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  _showFinancialValues
                      ? _formatFinancialValue(totalAccumulated)
                      : '● ● ● ● ●',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyExpensesSummary() {
    final now = DateTime.now();

    // Calculate totals for each week period
    double week1Total = 0.0; // Next 7 days
    double week2Total = 0.0; // Days 8-14
    double week3PlusTotal = 0.0; // Days 15-31

    List<ProximoGasto> week1Expenses = [];
    List<ProximoGasto> week2Expenses = [];
    List<ProximoGasto> week3PlusExpenses = [];

    for (var gasto in _proximosGastos) {
      if (gasto.pagado) continue; // Skip already paid expenses

      final daysUntilDue = gasto.fechaVencimiento.difference(now).inDays;

      if (daysUntilDue >= 0 && daysUntilDue <= 7) {
        week1Total += gasto.importe;
        week1Expenses.add(gasto);
      } else if (daysUntilDue >= 8 && daysUntilDue <= 14) {
        week2Total += gasto.importe;
        week2Expenses.add(gasto);
      } else if (daysUntilDue >= 15 && daysUntilDue <= 31) {
        week3PlusTotal += gasto.importe;
        week3PlusExpenses.add(gasto);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gastos fijos por período',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildWeeklyExpenseBox(
                title: 'Semana 1',
                subtitle: 'Próximos 7 días',
                amount: week1Total,
                color: Colors.red,
                expenses: week1Expenses,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildWeeklyExpenseBox(
                title: 'Semana 2',
                subtitle: 'Días 8-14',
                amount: week2Total,
                color: Colors.orange,
                expenses: week2Expenses,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildWeeklyExpenseBox(
                title: 'Semanas 3-5',
                subtitle: 'Días 15-31',
                amount: week3PlusTotal,
                color: Colors.blue,
                expenses: week3PlusExpenses,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeeklyExpenseBox({
    required String title,
    required String subtitle,
    required double amount,
    required Color color,
    required List<ProximoGasto> expenses,
  }) {
    return InkWell(
      onTap: expenses.isEmpty ? null : () => _showWeeklyExpensesDetail(title, expenses),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _showFinancialValues
                  ? _formatFinancialValue(amount)
                  : '● ● ● ●',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${expenses.length} gasto${expenses.length != 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWeeklyExpensesDetail(String title, List<ProximoGasto> expenses) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Title
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Expense list
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: expenses.length,
                      separatorBuilder: (context, index) => const Divider(height: 24),
                      itemBuilder: (context, index) {
                        final gasto = expenses[index];
                        final daysUntilDue = gasto.fechaVencimiento
                            .difference(DateTime.now())
                            .inDays;
                        final isOverdue = daysUntilDue < 0;
                        final isDueToday = daysUntilDue == 0;

                        return Row(
                          children: [
                            // Date indicator
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: isOverdue
                                    ? Colors.red.withValues(alpha: 0.1)
                                    : Colors.deepPurple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${gasto.fechaVencimiento.day}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isOverdue ? Colors.red : Colors.deepPurple,
                                    ),
                                  ),
                                  Text(
                                    _getMonthAbbreviation(gasto.fechaVencimiento.month),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isOverdue ? Colors.red : Colors.deepPurple,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Expense details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _gastoFijoNames[gasto.idGasto] ?? gasto.detalle,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isOverdue
                                        ? 'Vencido hace ${-daysUntilDue} día(s)'
                                        : (isDueToday
                                            ? 'Vence hoy'
                                            : 'Vence en ${daysUntilDue + 1} día(s)'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isOverdue ? Colors.red[700] : Colors.grey[600],
                                      fontWeight: isOverdue || isDueToday
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Amount and pay button
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _showFinancialValues
                                      ? _formatFinancialValue(gasto.importe)
                                      : '● ● ● ●',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _quickPayExpense(gasto);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                  ),
                                  child: const Text(
                                    'Pagar',
                                    style: TextStyle(fontSize: 12, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getMonthAbbreviation(int month) {
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
                    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return months[month - 1];
  }

  void _quickPayExpense(ProximoGasto gasto) {
    // Find the index in the main list
    final index = _proximosGastos.indexWhere((g) => g.idObligacion == gasto.idObligacion);
    if (index != -1) {
      _toggleGastoPagado(index, true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gasto marcado como pagado'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildProximosGastosList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _proximosGastos.length,
      itemBuilder: (context, index) {
        final gasto = _proximosGastos[index];
        final daysUntilDue = gasto.fechaVencimiento
            .difference(DateTime.now())
            .inDays;
        final isOverdue = daysUntilDue < 0;
        final isDueToday = daysUntilDue == 0;

        return Opacity(
          opacity: gasto.pagado ? 0.5 : 1.0,
          child: Row(
            children: [
              // Indicador de fecha
              _buildDateIndicator(gasto.fechaVencimiento, isOverdue),
              const SizedBox(width: 16),
              // Detalles del gasto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _gastoFijoNames[gasto.idGasto] ?? gasto.detalle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        decoration: gasto.pagado
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOverdue
                          ? 'Vencido hace ${-daysUntilDue} día(s)'
                          : (isDueToday
                                ? 'Vence hoy'
                                : 'Vence en ${daysUntilDue + 1} día(s)'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isOverdue ? Colors.red[700] : Colors.grey[600],
                        fontWeight: isOverdue || isDueToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Monto y botón de pago
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _showFinancialValues
                        ? _formatFinancialValue(gasto.importe)
                        : '● ● ● ● ●',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => _toggleGastoPagado(index, !gasto.pagado),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: gasto.pagado
                            ? const Color(0xFF6B73FF)
                            : Colors.transparent,
                        border: Border.all(
                          color: gasto.pagado
                              ? const Color(0xFF6B73FF)
                              : Colors.grey[400]!,
                          width: 2,
                        ),
                      ),
                      child: gasto.pagado
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      separatorBuilder: (context, index) => const Divider(height: 24),
    );
  }

  Widget _buildAccountCard(Account cuenta, double saldo) {
    final color = _getAccountColor(cuenta.type);
    final icono = _getAccountIcon(cuenta.type);

    return InkWell(
      onTap: () => _showAccountTransactions(cuenta),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.8), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8), // 10 * 0.85 ≈ 8
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      cuenta.name,
                      style: const TextStyle(
                        fontSize: 12, // 14 * 0.85 ≈ 12
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(icono, color: Colors.white, size: 15), // 18 * 0.85 ≈ 15
                ],
              ),
              Text(
                cuenta.type.displayName,
                style: TextStyle(
                  fontSize: 8, // 9 * 0.85 ≈ 8
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const Spacer(),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Saldo Actual',
                  style: TextStyle(fontSize: 8, color: Colors.white70), // 9 * 0.85 ≈ 8
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _showFinancialValues
                      ? _formatFinancialValue(saldo)
                      : '● ● ● ● ●',
                  style: const TextStyle(
                    fontSize: 14, // 16 * 0.85 ≈ 14
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.7, // 0.8 * 0.85 ≈ 0.7
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAccountBreakdown() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Desglose del Disponible',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _showFinancialValues
                              ? _formatMultiCurrency(_totalBalancesByCurrency)
                              : '● ● ● ● ●',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_accounts.length} cuenta${_accounts.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Account list
                  Expanded(
                    child: _accounts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No hay cuentas configuradas',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: _accounts.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final account = _accounts[index];
                              final balance =
                                  _accountBalances[account.id] ?? 0.0;
                              return _buildAccountBreakdownCard(
                                account,
                                balance,
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAccountBreakdownCard(Account account, double balance) {
    final color = _getAccountColor(account.type);
    final icon = _getAccountIcon(account.type);

    return InkWell(
      onTap: () {
        Navigator.pop(context); // Close the breakdown modal
        _showAccountTransactions(account); // Open transactions
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            // Account info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        account.type.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (account.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.3),
                            ),
                          ),
                          child: const Text(
                            'Principal',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Balance
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _showFinancialValues
                      ? _formatFinancialValue(
                          balance,
                          currency: account.moneda,
                        )
                      : '● ● ● ● ●',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  account.moneda,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountTransactions(Account account) {
    final balance = _accountBalances[account.id] ?? 0.0;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AccountTransactionsScreen(
          account: account,
          balance: balance,
        ),
      ),
    );
  }

  Widget _buildDailySummarySection() {
    double totalIngresos = 0;
    double totalEgresos = 0;


    for (var transaction in _dailyTransactions) {

      if (transaction.type == new_tx.TransactionType.income) {
        totalIngresos += transaction.amount;
      } else {
        totalEgresos += transaction.amount;
      }
    }


    return InkWell(
      onTap: () => _showDailyTransactionsDetail(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Resumen del Día',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Row(
              children: [
                _buildSummaryAmount('Ingresos', totalIngresos, Colors.green),
                const SizedBox(width: 16),
                _buildSummaryAmount('Egresos', totalEgresos, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryAmount(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: color)),
        Text(
          _showFinancialValues ? _formatFinancialValue(amount) : '● ● ● ● ●',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showDailyTransactionsDetail() {
    Map<String, double> subtotals = {};
    for (var transaction in _dailyTransactions) {
      final signo = transaction.type == new_tx.TransactionType.income ? 1 : -1;
      subtotals.update(
        transaction.currency ?? 'ARS',
        (value) => value + (signo * transaction.amount),
        ifAbsent: () => signo * transaction.amount,
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Detalle de Movimientos de Hoy',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              // Aquí irían los subtotales por moneda
              Expanded(
                child: _buildTransactionList(
                  _dailyTransactions,
                  scrollController,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTransactionList(
    List<new_tx.Transaction> transactions,
    ScrollController controller,
  ) {
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        // Re-use the same widget as for daily transactions, but now it's in a list.
        return _buildDailyTransactionItem(transaction);
      },
      separatorBuilder: (context, index) => const Divider(height: 1),
    );
  }

  Color _getAccountColor(AccountType tipo) {
    switch (tipo) {
      case AccountType.cash:
        return Colors.green;
      case AccountType.debit:
        return Colors.blue;
      case AccountType.digital:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getAccountIcon(AccountType tipo) {
    switch (tipo) {
      case AccountType.cash:
        return Icons.money;
      case AccountType.debit:
        return Icons.credit_card;
      case AccountType.digital:
        return Icons.account_balance_wallet;
      default:
        return Icons.account_balance;
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${date.day} de ${months[date.month - 1]} de ${date.year}';
  }

  Widget _buildQuickActionIcon(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, size: 30, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatMultiCurrency(Map<String, double> balances) {
    if (balances.isEmpty) {
      return _formatFinancialValue(0.0);
    }
    if (balances.length == 1) {
      return _formatFinancialValue(
        balances.values.first,
        currency: balances.keys.first,
      );
    }
    return balances.entries
        .map(
          (e) =>
              '${e.key} ${_formatFinancialValue(e.value, showSymbol: false)}',
        )
        .join(' / ');
  }

  Map<String, double> _calculateTotalBalancesByCurrency(
    List<Account> accounts,
    Map<String, double> accountBalances,
  ) {
    final Map<String, double> totals = {};
    for (var acc in accounts) {
      // Only include accounts with purpose 'available' in the total
      if (acc.accountPurpose == AccountPurpose.available) {
        // Use calculated balance from accountBalances parameter
        final balance = accountBalances[acc.id] ?? 0.0;
        totals.update(
          acc.moneda,
          (value) => value + balance,
          ifAbsent: () => balance,
        );
      }
    }
    return totals;
  }

  Map<String, double> _calculateReserveBalancesByCurrency(
    List<Account> accounts,
    Map<String, double> accountBalances,
  ) {
    final Map<String, double> totals = {};
    for (var acc in accounts) {
      // Only include accounts with purpose 'savings' in the reserve total
      if (acc.accountPurpose == AccountPurpose.savings) {
        final balance = accountBalances[acc.id] ?? 0.0;
        totals.update(
          acc.moneda,
          (value) => value + balance,
          ifAbsent: () => balance,
        );
      }
    }
    return totals;
  }

  Map<String, double> _calculateTheoreticalEndOfMonth() {
    final Map<String, double> theoretical = {};

    // Start with available balance only (no savings/reserves)
    _totalBalancesByCurrency.forEach((currency, availableBalance) {
      theoretical[currency] = availableBalance;
    });

    // Subtract pending fixed expenses until end of month
    final now = DateTime.now();
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    for (var gasto in _proximosGastos) {
      // Only subtract if:
      // 1. Not already paid
      // 2. Not skipped
      // 3. Due date is before end of month
      if (gasto.pagado) continue;

      final realFixedExpenseId = _gastoFijoIds[gasto.idGasto];
      if (realFixedExpenseId != null) {
        final dateStr = gasto.fechaVencimiento.toIso8601String().split('T')[0];
        final skipKey = '${realFixedExpenseId}_$dateStr';
        if (_skippedPaymentKeys.contains(skipKey)) continue;
      }

      if (gasto.fechaVencimiento.isAfter(endOfMonth)) continue;

      // Determine currency - assume ARS for local mode, USD for travel mode
      final currency = _activeCurrency;

      theoretical.update(
        currency,
        (value) => value - gasto.montoEstimado,
        ifAbsent: () => -gasto.montoEstimado,
      );
    }

    return theoretical;
  }

  Widget _buildQuickTransactionForm() {
    final isTypeSelected = _quickAddTransactionType != null;

    return Form(
      key: _quickAddFormKey,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<tx.TipoTransaccion>(
              segments: const [
                ButtonSegment(
                  value: tx.TipoTransaccion.gasto,
                  label: Text('Gasto'),
                  icon: Icon(Icons.arrow_upward),
                ),
                ButtonSegment(
                  value: tx.TipoTransaccion.ingreso,
                  label: Text('Ingreso'),
                  icon: Icon(Icons.arrow_downward),
                ),
              ],
              emptySelectionAllowed: true,
              selected: _quickAddTransactionType != null
                  ? <tx.TipoTransaccion>{_quickAddTransactionType!}
                  : {},
              onSelectionChanged: (Set<tx.TipoTransaccion> newSelection) {
                setState(() {
                  _quickAddTransactionType = newSelection.isEmpty
                      ? null
                      : newSelection.first;
                  // Clear amount field on type change
                  _quickAddAmountController.clear();
                  if (_quickAddTransactionType != null) {
                    // Auto-focus amount field when a type is selected
                    _quickAddAmountFocus.requestFocus();
                  }
                });
              },
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor:
                    _quickAddTransactionType == tx.TipoTransaccion.ingreso
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                selectedForegroundColor:
                    _quickAddTransactionType == tx.TipoTransaccion.ingreso
                    ? Colors.green[800]
                    : Colors.red[800],
                foregroundColor: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Focus(
                    onKeyEvent: (node, event) {
                      // Handle keyboard events properly to prevent assertion errors
                      if (event is KeyDownEvent || event is KeyRepeatEvent) {
                        // Allow normal key processing
                        return KeyEventResult.ignored;
                      }
                      if (event is KeyUpEvent) {
                        // Ensure we only handle KeyUp events for keys that were actually pressed
                        return KeyEventResult.ignored;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextFormField(
                      controller: _quickAddAmountController,
                      focusNode: _quickAddAmountFocus,
                      enabled: isTypeSelected,
                      decoration: InputDecoration(
                        labelText: 'Monto',
                        prefixIcon:
                            _quickAddSelectedAccount?.type == AccountType.credit
                            ? null
                            : const Icon(Icons.attach_money),
                        prefix:
                            _quickAddSelectedAccount?.type == AccountType.credit
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                ),
                                child: DropdownButton<String>(
                                  value:
                                      _quickAddTransactionCurrency ??
                                      _activeCurrency,
                                  items: ['ARS', 'USD', 'EUR']
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(e),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _quickAddTransactionCurrency = value;
                                    });
                                  },
                                  underline: const SizedBox(),
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                                  ),
                                ),
                              )
                            : null,
                        border: OutlineInputBorder(
                          // Reduced height
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
                      ],
                      validator: (value) {
                        if (!isTypeSelected) return null;
                        if (value == null || value.isEmpty) {
                          return 'Requerido';
                        }
                        if (double.tryParse(value) == null ||
                            double.parse(value) <= 0) {
                          return 'Inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<Account>(
                    initialValue: _quickAddSelectedAccount,
                    items: _accounts.map((cuenta) {
                      return DropdownMenuItem<Account>(
                        value: cuenta,
                        child: Text(
                          cuenta.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: isTypeSelected
                        ? (Account? newValue) {
                            setState(() {
                              _quickAddSelectedAccount = newValue;
                              // Reset currency if it's not a credit card
                              if (newValue?.type != AccountType.credit) {
                                _quickAddTransactionCurrency = null;
                              }
                            });
                          }
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Cuenta',
                      border: OutlineInputBorder(
                        // Reduced height
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) =>
                        isTypeSelected && value == null ? 'Requerida' : null,
                  ),
                ),
              ],
            ),
            if (_quickAddTransactionType != null) ...[
              const SizedBox(height: 16),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _quickAddTransactionType != null
                    ? _buildQuickCategoryButtons()
                    : const SizedBox.shrink(),
              ),
            ],
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _showExtraQuickAddFields
                  ? _buildExtraQuickAddFields()
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: !isTypeSelected
                      ? null
                      : () => setState(
                          () => _showExtraQuickAddFields =
                              !_showExtraQuickAddFields,
                        ),
                  child: Text(
                    _showExtraQuickAddFields
                        ? 'Menos opciones'
                        : 'Más opciones...',
                  ),
                ),
                ElevatedButton(
                  onPressed: !isTypeSelected || _isSavingQuickTransaction
                      ? null
                      : _saveQuickTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSavingQuickTransaction
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Guardar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateIndicator(DateTime date, bool isOverdue) {
    final day = date.day.toString();
    final month = _getShortMonthName(date.month);

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: isOverdue
            ? Colors.red.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue
              ? Colors.red.withOpacity(0.2)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isOverdue ? Colors.red[700] : Colors.black87,
            ),
          ),
          Text(
            month,
            style: TextStyle(
              fontSize: 10,
              color: isOverdue ? Colors.red[700] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTransactionItem(new_tx.Transaction transaction) {
    final isIncome = transaction.type == new_tx.TransactionType.income;
    final icon = isIncome ? Icons.arrow_downward : Icons.arrow_upward;
    final color = isIncome ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description ?? 'Sin descripción',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${isIncome ? "Ingreso" : "Gasto"} - ${DateFormat('dd/MM/yy').format(transaction.date)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            _showFinancialValues
                ? _formatFinancialValue(
                    transaction.amount,
                    currency: transaction.currency,
                  )
                : '● ● ● ● ●',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtraQuickAddFields() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        children: [
          Focus(
            onKeyEvent: (node, event) {
              // Handle keyboard events properly for description field
              return KeyEventResult.ignored;
            },
            child: TextFormField(
              controller: _quickAddDescriptionController,
              decoration: InputDecoration(
                labelText: 'Descripción',
                prefixIcon: const Icon(Icons.description),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(100)],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'La descripción es obligatoria';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 16),
          Focus(
            onKeyEvent: (node, event) {
              // Handle keyboard events properly for category field
              return KeyEventResult.ignored;
            },
            child: TextFormField(
              controller: _quickAddCategoryController,
              decoration: InputDecoration(
                labelText: 'Categoría (opcional)',
                prefixIcon: const Icon(Icons.category),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textCapitalization: TextCapitalization.words,
              inputFormatters: [LengthLimitingTextInputFormatter(50)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCategoryButtons() {
    // Use dynamic lists, with a fallback to hardcoded values for new users
    final List<String> fallbackGastos = [
      'Supermercado',
      'Combustible',
      'Delivery',
      'Farmacia',
      'Café',
    ];
    final List<String> fallbackIngresos = [
      'Sueldo',
      'Venta',
      'Freelance',
      'Regalo',
      'Reintegro',
    ];

    final bool useExpenseButtons =
        _quickAddTransactionType == tx.TipoTransaccion.gasto;
    final List<String> buttons = useExpenseButtons
        ? (_topExpenseDescriptions.isNotEmpty
              ? _topExpenseDescriptions
              : fallbackGastos)
        : (_topIncomeDescriptions.isNotEmpty
              ? _topIncomeDescriptions
              : fallbackIngresos);

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: buttons.map((label) {
        return ActionChip(
          label: Text(label),
          onPressed: _isSavingQuickTransaction
              ? null
              : () => _saveQuickTransactionWithDescription(label),
          backgroundColor: Colors.grey[200],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey[300]!),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _saveQuickTransactionWithDescription(String description) async {
    // Prevent double-clicks
    if (_isSavingQuickTransaction) return;

    // Set the description from the button
    _quickAddDescriptionController.text = description;

    // Validate only amount and account, as description is now set
    if (_quickAddAmountController.text.isEmpty ||
        _quickAddSelectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingresa un monto y selecciona una cuenta.'),
          backgroundColor: Colors.orange,
        ),
      );
      // Request focus on the amount field if it's empty
      if (_quickAddAmountController.text.isEmpty) {
        _quickAddAmountFocus.requestFocus();
      }
      return;
    }

    // Call the main save function
    await _saveQuickTransaction();
  }

  Future<void> _exportTransactionsToCsv() async {
    final dbService = DatabaseService();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;
    if (currentUser == null) return;
    // Use Firebase UID to query transactions
    if (currentUser.id.isEmpty) return;

    // Use the NEW transaction system that reads from Firestore
    final transactions = await dbService.getTransactions(
      userId: currentUser.id,
    );

    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay movimientos para exportar.')),
      );
      return;
    }

    // Generate CSV content
    final header = transactions.first.toMap().keys.join(',');
    final rows = transactions.map((tx) {
      return tx
          .toMap()
          .values
          .map((value) {
            // Escape commas and wrap in quotes
            return '"${value.toString().replaceAll('"', '""')}"';
          })
          .join(',');
    });
    final csvContent = [header, ...rows].join('\n');

    await Share.share(csvContent, subject: 'Exportación de Movimientos');
  }

  Future<void> _saveQuickTransaction() async {
    if (!_quickAddFormKey.currentState!.validate()) return;

    // Prevent double-clicks
    if (_isSavingQuickTransaction) return;

    setState(() => _isSavingQuickTransaction = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.user;
      if (currentUser == null) throw Exception("Usuario no autenticado");

      // Get current location
      final location = await _getCurrentLocation();

      final amount = double.parse(_quickAddAmountController.text);

      // --- NEW MODEL IMPLEMENTATION ---
      // Create a new transaction using the Firestore-compatible model
      final transactionType = _quickAddTransactionType ==
              tx
                  .TipoTransaccion
                  .gasto // Use the old enum for comparison
          ? new_tx.TransactionType.expense
          : new_tx.TransactionType.income;

      final newTransaction = new_tx.Transaction(
        id: const Uuid().v4(),
        userId: currentUser.id, // Use the Firebase UID (String)
        accountId: _quickAddSelectedAccount!.id,
        transactionTypeId: transactionType == new_tx.TransactionType.expense ? 2 : 1,
        type: transactionType,
        amount: amount,
        description: _quickAddDescriptionController.text.trim().isEmpty
            ? null
            : _quickAddDescriptionController.text.trim(),
        category: _quickAddCategoryController.text.trim().isEmpty
            ? null
            : _quickAddCategoryController.text.trim(),
        date: DateTime.now(),
        currency:
            _quickAddTransactionCurrency ?? _quickAddSelectedAccount!.moneda,
        location: location,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 1. Save the new transaction to Firestore
      await dbService.insertNewTransaction(newTransaction);

      // 2. Update local state without a full reload to avoid screen flickering
      final accountIndex = _accounts.indexWhere(
        (acc) => acc.id == newTransaction.accountId,
      );
      if (accountIndex != -1) {
        // Get the updated account from database to ensure we have the latest balance
        final updatedAccount = await dbService.getAccount(
          newTransaction.accountId!,
        );
        if (updatedAccount != null) {

          // Update the specific account in the list with the database value
          _accounts[accountIndex] = updatedAccount;

          // Recalculate balances using the updated accounts
          _accountBalances = await _calculateBalances(_accounts);
          _totalBalancesByCurrency = _calculateTotalBalancesByCurrency(
            _accounts,
            _accountBalances,
          );
          _dailyLimit = _calculateDailyLimit(
            _totalBalancesByCurrency[_activeCurrency] ?? 0.0,
          );

        } else {
        }
      } else {
      }

      // Add the new transaction to the daily list
      _dailyTransactions.insert(0, newTransaction);

      // 3. Reset form and trigger a single UI update
      setState(() {
        _quickAddAmountController.clear();
        _quickAddDescriptionController.clear();
        _quickAddCategoryController.clear();
        _quickAddTransactionType = null; // Deselect transaction type
        _showExtraQuickAddFields = false;

        // Reset account to default
        _quickAddSelectedAccount = _accounts.where((acc) => acc.isDefault).firstOrNull ?? _accounts.firstOrNull;

        // The state variables for balances are already updated above
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingQuickTransaction = false);
    }
  }

  Future<String?> _getCurrentLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Test if location services are enabled.
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permissions are denied forever, handle appropriately.
        return null;
      }

      // When we reach here, permissions are granted and we can
      // continue accessing the position of the device.
      final position = await Geolocator.getCurrentPosition();
      return '${position.latitude},${position.longitude}';
    } catch (e) {
      return null;
    }
  }

  void _showAddTransactionSheet() async {

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true, // Permite que el sheet ocupe más pantalla
      backgroundColor: Colors.transparent, // Para bordes redondeados
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75, // Altura inicial
        maxChildSize: 0.9, // Altura máxima al arrastrar
        minChildSize: 0.5, // Altura mínima
        builder: (_, controller) => const AddTransactionScreen(isSheet: true),
      ),
    );


    // Refresca los datos solo si la transacción fue exitosa
    if (result == true) {
      await _loadData();
    }
  }

  Future<void> _navigateToAddFixedExpense() async {
    // Show dialog to select frequency
    final frequency = await showDialog<ExpenseFrequency>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tipo de Gasto Fijo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.event_repeat, color: Colors.deepPurple),
                ),
                title: const Text('Mensual'),
                subtitle: const Text('Gastos que se repiten cada mes'),
                onTap: () => Navigator.of(context).pop(ExpenseFrequency.monthly),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.repeat, color: Colors.blue),
                ),
                title: const Text('Semanal'),
                subtitle: const Text('Gastos que se repiten cada semana'),
                onTap: () => Navigator.of(context).pop(ExpenseFrequency.weekly),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.calendar_month, color: Colors.teal),
                ),
                title: const Text('Bimestral'),
                subtitle: const Text('Gastos que se repiten cada 2 meses'),
                onTap: () => Navigator.of(context).pop(ExpenseFrequency.bimonthly),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.event, color: Colors.orange),
                ),
                title: const Text('Única vez'),
                subtitle: const Text('Gasto que ocurre una sola vez'),
                onTap: () => Navigator.of(context).pop(ExpenseFrequency.oneTime),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    // Navigate to add screen if frequency was selected
    if (frequency != null && mounted) {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => AddEditFixedExpenseScreen(frequency: frequency),
        ),
      );

      // Reload data if a fixed expense was added
      if (result == true) {
        await _loadData();
      }
    }
  }

  void _selectAccountForExpense(ProximoGasto gasto) {
    // TODO: Implementar lógica para mostrar un diálogo/modal para seleccionar cuenta
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Seleccionar cuenta para ${gasto.detalle}'),
        backgroundColor: const Color(0xFF6B73FF),
      ),
    );
  }

  Future<void> _skipPayment(ProximoGasto gasto) async {
    try {
      // Get the real UUID from the map (gasto.idGasto is the hashed int)
      final realFixedExpenseId = _gastoFijoIds[gasto.idGasto];
      if (realFixedExpenseId == null) {
        throw Exception('No se encontró el ID del gasto fijo');
      }

      // Check if already skipped
      final dateStr = gasto.fechaVencimiento.toIso8601String().split('T')[0];
      final skipKey = '${realFixedExpenseId}_$dateStr';

      if (_skippedPaymentKeys.contains(skipKey)) {
        // Already skipped - unskip it
        await dbService.unskipPayment(
          fixedExpenseId: realFixedExpenseId,
          date: gasto.fechaVencimiento,
        );

        // Reload data to refresh the list
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Pago de ${_gastoFijoNames[gasto.idGasto] ?? gasto.detalle} restaurado',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Not skipped yet - skip it
        await dbService.skipPayment(
          fixedExpenseId: realFixedExpenseId,
          date: gasto.fechaVencimiento,
          reason: 'Salteado manualmente',
        );

        // Reload data to refresh the list
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Pago de ${_gastoFijoNames[gasto.idGasto] ?? gasto.detalle} salteado',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al saltear pago: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleGastoPagado(int index, bool value) async {
    if (value == true) {
      // When marking as paid, show account selection dialog
      await _showAccountSelectionForExpense(index);
    } else {
      // When unmarking, just update the state
      setState(() {
        _proximosGastos[index] = _proximosGastos[index].copyWith(
          estado: EstadoProximoGasto.pendiente,
        );
      });
    }
  }

  Future<void> _showAccountSelectionForExpense(int gastoIndex) async {
    final gasto = _proximosGastos[gastoIndex];
    final gastoName = _gastoFijoNames[gasto.idGasto] ?? gasto.detalle;

    if (_accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay cuentas disponibles. Crea una cuenta primero.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Find default account or use first available
    Account? selectedAccount =
        _accounts.where((acc) => acc.isDefault).firstOrNull ?? _accounts.first;

    final result = await showDialog<Account>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pagar: $gastoName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Monto: ${_formatFinancialValue(gasto.importe)}'),
            const SizedBox(height: 16),
            const Text('Selecciona la cuenta:'),
            const SizedBox(height: 8),
            DropdownButtonFormField<Account>(
              initialValue: selectedAccount,
              items: _accounts.map((account) {
                return DropdownMenuItem<Account>(
                  value: account,
                  child: Text(
                    '${account.name} (${_formatFinancialValue(account.currentBalance)})',
                  ),
                );
              }).toList(),
              onChanged: (Account? newValue) {
                selectedAccount = newValue;
              },
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(selectedAccount),
            child: const Text('Pagar'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _processExpensePayment(gastoIndex, result);
    }
  }

  Future<void> _processExpensePayment(
    int gastoIndex,
    Account selectedAccount,
  ) async {
    final gasto = _proximosGastos[gastoIndex];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;

    if (currentUser == null) return;

    try {
      // Get the actual name of the fixed expense
      final gastoName = _gastoFijoNames[gasto.idGasto] ?? gasto.detalle;

      // Create a transaction for this expense payment
      final newTransaction = new_tx.Transaction(
        id: const Uuid().v4(),
        userId: currentUser.id,
        accountId: selectedAccount.id,
        transactionTypeId: 2, // 2 = expense
        type: new_tx.TransactionType.expense,
        amount: gasto.importe,
        description: 'Pago: $gastoName',
        category: 'Gasto Fijo',
        date: DateTime.now(),
        currency: selectedAccount.moneda,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save the transaction
      await dbService.insertNewTransaction(newTransaction);

      // Reload data to refresh balances and update paid status
      await _loadData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gasto pagado: $gastoName'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar pago: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getShortMonthName(int month) {
    const months = [
      'ENE',
      'FEB',
      'MAR',
      'ABR',
      'MAY',
      'JUN',
      'JUL',
      'AGO',
      'SEP',
      'OCT',
      'NOV',
      'DIC',
    ];
    return months[month - 1];
  }

  Future<Map<String, double>> _calculateBalances(List<Account> accounts) async {
    // Fetch all balances in parallel for better performance
    final balancesFutures = accounts.map((account) async {
      final calculatedBalance = await dbService.getAccountBalance(account.id);
      return MapEntry(account.id, calculatedBalance);
    }).toList();

    final balanceEntries = await Future.wait(balancesFutures);
    return Map.fromEntries(balanceEntries);
  }

  // Generate próximos gastos from fixed expenses
  Future<List<ProximoGasto>> _generateProximosGastosFromFixed(
    String userId,
  ) async {
    final gastosFijos = await dbService.getGastosFijos(userId);
    final List<ProximoGasto> proximosGastos = [];
    final Map<int, String> gastoNames = {};

    // Get today's transactions to check for payments
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final todayTransactions = await dbService.getTransactions(
      userId: userId,
      fromDate: todayStart,
      toDate: todayEnd,
    );

    for (final gastoFijo in gastosFijos) {
      if (!gastoFijo.activo) continue;

      // Store the name and ID for later use (hash String ID to int for legacy model)
      final gastoIdHash = gastoFijo.idGasto.hashCode.abs();
      gastoNames[gastoIdHash] = gastoFijo.nombre;
      _gastoFijoIds[gastoIdHash] = gastoFijo.idGasto; // Store real UUID

      // Calculate next due date based on frequency
      DateTime nextDueDate = _calculateNextDueDate(gastoFijo);

      // Only show if due within next 30 days
      if (nextDueDate.isBefore(DateTime.now().add(const Duration(days: 30)))) {
        // Check if this expense was already paid today
        final isPaidToday = todayTransactions.any((transaction) =>
            transaction.description?.contains('Pago: ${gastoFijo.nombre}') ??
            false);

        proximosGastos.add(
          ProximoGasto(
            idObligacion: gastoIdHash,
            idGasto: gastoIdHash,
            montoEstimado: gastoFijo.montoCuotas,
            fechaVencimiento: nextDueDate,
            estado: isPaidToday
                ? EstadoProximoGasto.pagado
                : EstadoProximoGasto.pendiente,
            fechaPago: isPaidToday ? now : null,
          ),
        );
      }
    }

    // Update the names map in state
    _gastoFijoNames = gastoNames;

    // Sort by due date
    proximosGastos.sort(
      (a, b) => a.fechaVencimiento.compareTo(b.fechaVencimiento),
    );

    return proximosGastos;
  }

  DateTime _calculateNextDueDate(FixedExpense gastoFijo) {
    final now = DateTime.now();

    switch (gastoFijo.frecuencia) {
      case 'MENSUAL':
        final targetDay = gastoFijo.diaMes;
        var nextDate = DateTime(now.year, now.month, targetDay);

        // If the date has passed this month, move to next month
        if (nextDate.isBefore(now)) {
          nextDate = DateTime(now.year, now.month + 1, targetDay);
        }

        return nextDate;

      case 'SEMANAL':
        final targetWeekday = gastoFijo.diaSemana;
        var nextDate = now;

        // Find next occurrence of the target weekday
        while (nextDate.weekday != targetWeekday) {
          nextDate = nextDate.add(const Duration(days: 1));
        }

        return nextDate;

      case 'BIMESTRAL':
        final targetDay = gastoFijo.diaMes;
        var nextDate = DateTime(now.year, now.month, targetDay);

        // If the date has passed this month, move to next bimonth
        if (nextDate.isBefore(now)) {
          nextDate = DateTime(now.year, now.month + 2, targetDay);
        }

        return nextDate;

      case 'UNICA_VEZ':
        // For one-time expenses, return the due date
        return gastoFijo.dueDate ?? now.add(const Duration(days: 7));

      default:
        // Default: next week
        return now.add(const Duration(days: 7));
    }
  }

  // Función para formatear valores financieros con opción de privacidad
  String _formatFinancialValue(
    double value, {
    String? currency,
    bool showSymbol = true,
  }) {
    if (!_showFinancialValues) {
      return '● ● ● ● ●';
    }
    String symbol = '\$';
    if (currency == 'USD') symbol = 'U\$S';
    if (currency == 'EUR') symbol = '€';

    final formatter = NumberFormat.currency(
      locale: 'es_AR',
      symbol: showSymbol ? symbol : '',
      decimalDigits: 2,
    );
    return formatter.format(value);
  }

  double _calculateDailyLimit(double totalBalance) {
    if (totalBalance <= 0) return 0.0;

    final now = DateTime.now();
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    final remainingDays = endOfMonth.day - now.day + 1;

    if (remainingDays <= 0) return totalBalance;

    return totalBalance / remainingDays;
  }

  // Función auxiliar para calcular gastos fijos del período actual
  Future<double> _calculateCurrentPeriodFixedExpenses() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final User? currentUser = authProvider.user;

      if (currentUser == null) return 0.0;

      final dbService = DatabaseService();
      // FIX: Use the local integer ID for the old database schema.
      // Use Firebase UID directly
      final userId = currentUser.id;
      if (userId.isEmpty) return 0.0;

      final List<FixedExpense> fixedExpenses = await dbService.getGastosFijos(
        userId,
      );
      // For now, return 0.0 since we need to fix the user model integration
      double totalFixedExpenses = 0.0;

      return totalFixedExpenses;
    } catch (e) {
      return 0.0;
    }
  }

  // Función para calcular costo anual de un gasto
  double _calculateAnnualCost(double amount, String frequency) {
    if (frequency == 'monthly') {
      // Assuming 'monthly' and 'weekly' strings
      return amount * 12; // 12 meses al año
    } else {
      return amount * 52; // 52 semanas al año (for 'weekly')
    }
  }

  // Función para obtener ejemplos de gastos comunes subestimados
  List<Map<String, dynamic>> _getCommonExpenseExamples() {
    return [
      {
        'name': 'Café diario',
        'amount': 500.0,
        'frequency': 'weekly',
        'icon': Icons.coffee,
        'color': Colors.brown,
      },
      {
        'name': 'Delivery comida',
        'amount': 2500.0,
        'frequency': 'weekly',
        'icon': Icons.delivery_dining,
        'color': Colors.orange,
      },
      {
        'name': 'Suscripción streaming',
        'amount': 1500.0,
        'frequency': 'monthly',
        'icon': Icons.tv,
        'color': Colors.purple,
      },
      {
        'name': 'Taxi/Uber ocasional',
        'amount': 800.0,
        'frequency': 'weekly',
        'icon': Icons.local_taxi,
        'color': Colors.yellow,
      },
      {
        'name': 'Compras impulsivas',
        'amount': 2000.0,
        'frequency': 'weekly',
        'icon': Icons.shopping_bag,
        'color': Colors.pink,
      },
      {
        'name': 'Suscripción gimnasio',
        'amount': 8000.0,
        'frequency': 'monthly',
        'icon': Icons.fitness_center,
        'color': Colors.green,
      },
    ];
  }

  // Diálogo para mostrar análisis de anualización de gastos
  void _showAnnualizationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anualizar Gastos'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '¿Sabías que los pequeños gastos diarios representan grandes cantidades anuales?',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ..._getCommonExpenseExamples().map((example) {
                final annualCost = _calculateAnnualCost(
                  example['amount'],
                  example['frequency'],
                );
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    // Corrected withOpacity
                    color: (example['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (example['color'] as Color).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        example['icon'] as IconData,
                        color: example['color'] as Color,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              example['name'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '\$${(example['amount'] as double).toStringAsFixed(0)}/${example['frequency'] == 'monthly' ? 'mes' : 'semana'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${annualCost.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: example['color'] as Color,
                            ),
                          ),
                          Text(
                            'anual',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  // Corrected withOpacity
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '¡Estos pequeños gastos pueden sumar miles de pesos al año! Controla los gastos diarios para ahorrar significativamente.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Navegar a pantalla completa de análisis anual
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pantalla completa de análisis - Próximamente'),
                  backgroundColor: Colors.teal,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ver Más'),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterDataDrawer() {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6B73FF), Color(0xFF9B59B6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              InkWell(
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  Navigator.of(
                    context,
                  ).pushNamed('/settings').then((_) => _loadData());
                },
                child: const CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: Color(0xFF6B73FF)),
                ),
              ),
              const SizedBox(height: 16),
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  final currentUser = authProvider.user;
                  return Column(
                    children: [
                      Text(
                        currentUser?.alias ??
                            currentUser?.displayName ??
                            'Usuario',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        currentUser?.email ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text(
                        'Datos Maestros',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDrawerItem(
                        icon: Icons.account_balance_wallet,
                        title: 'Cuentas',
                        subtitle: 'Gestionar cuentas bancarias',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(
                            context,
                          ).pushNamed('/accounts').then((_) => _loadData());
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.category,
                        title: 'Categorías',
                        subtitle: 'Organizar ingresos y gastos',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).pushNamed('/categories');
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.receipt_long,
                        title: 'Gastos Fijos',
                        subtitle: 'Administrar gastos recurrentes',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).pushNamed('/fixed-expenses');
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.contacts,
                        title: 'Contactos',
                        subtitle: 'Gestionar contactos frecuentes',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).pushNamed('/contacts');
                        },
                      ),
                      const Divider(height: 32),
                      const Text(
                        'Análisis',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDrawerItem(
                        icon: Icons.analytics,
                        title: 'Análisis Anual',
                        subtitle: 'Ver gastos anualizados',
                        onTap: () {
                          Navigator.pop(context);
                          _showAnnualizationDialog(context);
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.trending_up,
                        title: 'Estadísticas',
                        subtitle: 'Ver tendencias financieras',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).pushNamed('/statistics');
                        },
                      ),
                      const Divider(height: 32),
                      const Text(
                        'Herramientas',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_isMercadoPagoConnected)
                        _buildDrawerItem(
                          icon: Icons.account_balance_wallet,
                          title: 'Mercado Pago',
                          subtitle: 'Ver y sincronizar pagos',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.of(context)
                                .pushNamed('/mercado-pago-payments')
                                .then((_) => _loadData());
                          },
                        ),
                      _buildDrawerItem(
                        icon: Icons.import_export,
                        title: 'Exportar Movimientos',
                        subtitle: 'Descargar transacciones en CSV',
                        onTap: () {
                          Navigator.pop(context);
                          _exportTransactionsToCsv();
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.settings,
                        title: 'Configuración',
                        subtitle: 'Ajustes de la aplicación',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context)
                              .pushNamed('/settings')
                              .then((_) {
                            _loadData();
                            _checkMercadoPagoConnection();
                          });
                        },
                      ),
                      const Divider(height: 32),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.logout, color: Colors.red),
                        ),
                        title: const Text(
                          'Cerrar Sesión',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onTap: () async {
                          Navigator.pop(context); // Cierra el drawer
                          await Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          ).signOut();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Nueva Cuenta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.money, color: Colors.green),
              ),
              title: const Text('Efectivo'),
              subtitle: const Text('Dinero en efectivo o billetera física'),
              onTap: () => _addAccount(context, AccountType.cash),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.credit_card, color: Colors.blue),
              ),
              title: const Text('Cuenta Débito'),
              subtitle: const Text('Cuenta bancaria o tarjeta de débito'),
              onTap: () => _addAccount(context, AccountType.debit),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.purple,
                ),
              ),
              title: const Text('Billetera Digital'),
              subtitle: const Text('PayPal, Mercado Pago, etc.'),
              onTap: () => _addAccount(context, AccountType.digital),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.credit_score, color: Colors.orange),
              ),
              title: const Text('Tarjeta de Crédito'),
              subtitle: const Text('Para compras en cuotas o en otra moneda'),
              onTap: () => _addAccount(context, AccountType.credit),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _addAccount(BuildContext context, AccountType type) {
    Navigator.of(context).pop(); // Close the dialog

    // Navigate to add account screen and reload data on return
    Navigator.of(context)
        .push<bool>(
          MaterialPageRoute<bool>(
            builder: (context) => AddEditAccountScreen(accountType: type),
          ),
        )
        .then((_) => _loadData());
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF6B73FF).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF6B73FF)),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
