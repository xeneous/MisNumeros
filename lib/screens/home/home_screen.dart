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
// import '../../models/fixed_expense.dart'; // FixedExpense is now GastoFijo
import '../../models/proximo_gasto.dart';
import '../../models/account.dart';
import '../../models/user.dart';
import '../../models/gasto_fijo.dart';
import '../../models/transaccion.dart' as tx; // Import old Transaccion model
import '../../models/transaction.dart'
    as new_tx; // Import NEW Transaction model
import '../../services/database_service.dart';
import '../accounts/add_edit_account_screen.dart';
import '../accounts/accounts_screen.dart';
import '../transactions/add_transaction_screen.dart';

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

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService dbService = DatabaseService();
  // Controla si se muestran los valores o asteriscos
  bool _showFinancialValues = true;

  // Datos del home
  List<Account> _accounts = [];
  List<ProximoGasto> _proximosGastos = [];
  Map<String, double> _accountBalances = {};
  List<new_tx.Transaction> _dailyTransactions =
      []; // List for daily transactions
  double _totalAvailableBalance = 0.0; // Sum of all account balances
  bool _isLoading = true;
  double _dailyLimit = 0.0;

  String _displayMode = 'local'; // 'local', 'travel', 'all'
  String _activeCurrency = 'ARS'; // The primary currency for the current mode
  Map<String, double> _totalBalancesByCurrency = {};

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
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
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
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.user;

    return Scaffold(
      drawer: _buildMasterDataDrawer(),
      body: currentUser == null
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(currentUser),
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

      // Fetch all accounts and then filter by the current display mode
      final allAccounts = await dbService.getAccounts(currentUser.id);
      final accounts = _displayMode == 'all'
          ? allAccounts
          : allAccounts.where((acc) => acc.moneda == _activeCurrency).toList();

      final balances = await _calculateBalances(accounts);
      _totalBalancesByCurrency = _calculateTotalBalancesByCurrency(accounts);

      // Fetch daily transactions
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day, 0, 0, 0);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      // Fetch data that depends on localId only if it's valid
      final dailyTransactions = await dbService.getTransactions(
        userId: currentUser.id,
        fromDate: startOfDay,
        toDate: endOfDay,
      );

      List<String> topExpenses = [];
      List<String> topIncomes = [];

      if (currentUser.localId != null && currentUser.localId! > 0) {
        topExpenses = await dbService.getTopTransactionDescriptions(
          currentUser.localId!,
          tx.TipoTransaccion.gasto,
        );
        topIncomes = await dbService.getTopTransactionDescriptions(
          currentUser.localId!,
          tx.TipoTransaccion.ingreso,
        );
      } else {
        // Log a warning if localId is missing after login. This shouldn't happen with the new logic.
        print(
          'ADVERTENCIA: No se pudo obtener el ID de usuario local. Algunas funciones estarán deshabilitadas.',
        );
      }

      // Calculate daily limit
      final dailyLimit = _calculateDailyLimit(
        _totalBalancesByCurrency[_activeCurrency] ?? 0.0,
      );

      // TODO: Implementar getProximosGastos en DatabaseService (still hardcoded for now)
      final proximosGastos = _getHardcodedProximosGastos();

      // No need for Future.wait here as we await individually
      // final results = await Future.wait([accountsFuture, proximosGastosFuture]);

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
          // Set default account for quick add form if not already set, inside setState
          if (accounts.isNotEmpty) {
            _quickAddSelectedAccount =
                accounts.where((acc) => acc.isDefault).firstOrNull ??
                accounts.first;
          }
        });
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
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showOptionsMenu(context),
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

          const SizedBox(height: 24),
          // Acciones rápidas fijas
          _buildQuickTransactionForm(),
          const SizedBox(height: 24),

          // Próximos gastos - recuadro suave con tabla
          _buildProximosGastos(),

          const SizedBox(height: 20),
          const Divider(),
          _buildDailySummarySection(), // New daily summary section

          const SizedBox(height: 20),
          const Divider(),
          // Cuentas/Billeteras - carrusel
          _buildAccountsCarousel(),
          const SizedBox(height: 80), // Espacio para el FloatingActionButton
        ],
      ),
    );
  }

  Widget _buildTitledAmountBox({
    required String title,
    Map<String, double>? balances,
    double? amount,
    required Color color,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 65,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _showFinancialValues
                    ? (balances != null
                          ? _formatMultiCurrency(balances)
                          : _formatFinancialValue(amount ?? 0.0))
                    : '● ● ● ● ●',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        Positioned(
          top: -10,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProximosGastos() {
    // Usar _proximosGastos cargados en _loadData
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Próximos gastos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          // Lista de gastos sin recuadros individuales
          _proximosGastos.isEmpty
              ? const Text(
                  'No tienes gastos próximos.',
                  style: TextStyle(color: Colors.grey),
                )
              : _buildProximosGastosList(),
        ],
      ),
    );
  }

  Widget _buildAccountsCarousel() {
    if (_accounts.isEmpty) {
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
              'No hay cuentas configuradas',
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
          height: 160, // Reduced height for a more compact look
          child: PageView.builder(
            controller: PageController(
              viewportFraction: 0.9,
            ), // Show part of next card
            itemCount: _accounts.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final cuenta = _accounts[index];
              final saldo = _accountBalances[cuenta.id] ?? 0.0;
              return _buildAccountCard(cuenta, saldo);
            },
          ),
        ),
        if (_accounts.length > 1) ...[
          const SizedBox(height: 12),
          _buildPageIndicator(_accounts.length),
        ],
      ],
    );
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
                      gasto.detalle,
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
        margin: const EdgeInsets.symmetric(horizontal: 8),
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    cuenta.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Icon(icono, color: Colors.white, size: 28),
                ],
              ),
              Text(
                cuenta.type.displayName,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const Spacer(),
              const Text(
                'Saldo Actual',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              Text(
                _showFinancialValues
                    ? _formatFinancialValue(saldo)
                    : '● ● ● ● ●',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator(int pageCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (index) {
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: _currentPage == index
                ? const Color(0xFF6B73FF)
                : Colors.grey[300],
          ),
        );
      }),
    );
  }

  Future<void> _showAccountTransactions(Account account) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;
    if (currentUser == null) return;

    try {
      // Fetch transactions directly using the new Firestore-based system
      final List<new_tx.Transaction> transactions = await dbService
          .getTransactionsForAccount(
            userId: currentUser.id,
            accountId: account.id,
            fromDate: DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
            ),
            toDate: DateTime.now(),
          );

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.3,
            builder: (context, scrollController) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Movimientos de ${account.name}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: transactions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No hay movimientos para esta cuenta hoy.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Los movimientos aparecerán aquí cuando realices transacciones.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : _buildTransactionList(transactions, scrollController),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar movimientos: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
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
                  _dailyTransactions as List<new_tx.Transaction>,
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
  ) {
    final Map<String, double> totals = {};
    for (var acc in accounts) {
      totals.update(
        acc.moneda,
        (value) => value + acc.currentBalance,
        ifAbsent: () => acc.currentBalance,
      );
    }
    return totals;
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
                    value: _quickAddSelectedAccount,
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
                labelText: 'Descripción (opcional)',
                prefixIcon: const Icon(Icons.description),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(100)],
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
          onPressed: () => _saveQuickTransactionWithDescription(label),
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
    // Use the correct localId (integer) to query the old transactions table
    if (currentUser.localId == null || currentUser.localId == 0) return;

    final transactions = await dbService.getTransacciones(currentUser.localId!);

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
      final newTransaction = new_tx.Transaction(
        id: const Uuid().v4(),
        userId: currentUser.id, // Use the Firebase UID (String)
        accountId: _quickAddSelectedAccount!.id,
        type:
            _quickAddTransactionType ==
                tx
                    .TipoTransaccion
                    .gasto // Use the old enum for comparison
            ? new_tx.TransactionType.expense
            : new_tx.TransactionType.income,
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
        final oldAccount = _accounts[accountIndex];
        final newBalance = newTransaction.type == new_tx.TransactionType.income
            ? oldAccount.currentBalance + newTransaction.amount
            : oldAccount.currentBalance - newTransaction.amount;

        // Update the specific account in the list
        _accounts[accountIndex] = oldAccount.copyWith(
          currentBalance: newBalance,
        );

        // Recalculate total balances and daily limit
        _totalBalancesByCurrency = _calculateTotalBalancesByCurrency(_accounts);
        _dailyLimit = _calculateDailyLimit(
          _totalBalancesByCurrency[_activeCurrency] ?? 0.0,
        );
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
      print('Error getting location: $e');
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
      _loadData();
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

  void _toggleGastoPagado(int index, bool value) {
    setState(() {
      _proximosGastos[index] = _proximosGastos[index].copyWith(
        estado: (value ?? false)
            ? EstadoProximoGasto.pagado
            : EstadoProximoGasto.pendiente,
      );
      // TODO: Persistir el cambio en la base de datos
    });
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
    final Map<String, double> balances = {};
    for (final account in accounts) {
      // Aquí se podría llamar a un método que calcule el saldo real si es necesario
      balances[account.id] = account.currentBalance;
    }
    return balances;
  }

  // Temporal: Datos hardcodeados hasta que se implemente en el servicio
  List<ProximoGasto> _getHardcodedProximosGastos() {
    return [
      ProximoGasto(
        idObligacion: 1,
        idGasto: 1,
        montoEstimado: 2500.00,
        fechaVencimiento: DateTime.now().add(const Duration(days: 3)),
        estado: EstadoProximoGasto.pendiente,
      ),
      ProximoGasto(
        idObligacion: 2,
        idGasto: 2,
        montoEstimado: 8500.00,
        fechaVencimiento: DateTime.now().add(const Duration(days: 7)),
        estado: EstadoProximoGasto.pendiente,
      ),
      ProximoGasto(
        idObligacion: 3,
        idGasto: 3,
        montoEstimado: 12500.00,
        fechaVencimiento: DateTime.now().add(const Duration(days: 15)),
        estado: EstadoProximoGasto.pagado,
      ),
    ];
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
      // Do not parse the Firebase UID.
      final userIdInt = currentUser.localId;
      if (userIdInt == null || userIdInt == 0) return 0.0;

      final List<GastoFijo> fixedExpenses = await dbService.getGastosFijos(
        userIdInt,
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

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        // Modern look without rounded corners on top
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Opciones',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(
                Icons.account_balance_wallet,
                color: Colors.blue,
              ),
              title: const Text('Cuentas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (context) => const AccountsScreen(),
                      ),
                    )
                    .then((_) => _loadData());
              },
            ),
            ListTile(
              leading: const Icon(Icons.category, color: Colors.green),
              title: const Text('Categorías'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/categories');
              },
            ),
            ListTile(
              leading: const Icon(Icons.contacts, color: Colors.orange),
              title: const Text('Contactos'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/contacts');
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics, color: Colors.purple),
              title: const Text('Análisis Anual'),
              onTap: () {
                Navigator.pop(context);
                _showAnnualizationDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.import_export, color: Colors.teal),
              title: const Text('Exportar Movimientos'),
              onTap: () {
                Navigator.pop(context);
                _exportTransactionsToCsv();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.grey),
              title: const Text('Configuración'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(
                  context,
                ).pushNamed('/settings').then((_) => _loadData());
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Cerrar Sesión',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                Navigator.pop(context); // Close the modal
                await Provider.of<AuthProvider>(
                  context,
                  listen: false,
                ).signOut();
              },
            ),
          ],
        ),
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
