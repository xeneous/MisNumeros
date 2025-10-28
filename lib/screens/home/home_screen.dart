import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
// import '../../models/user.dart'; // User model is now Usuario
import '../../models/transaction.dart' as tx;
// import '../../models/fixed_expense.dart'; // FixedExpense is now GastoFijo
import '../../models/proximo_gasto.dart';
import '../../models/account.dart';
import '../../models/user.dart';
import '../../models/gasto_fijo.dart';
import '../../models/transaccion.dart'
    as old_tx; // Import old Transaccion model
import '../../services/database_service.dart';
import '../accounts/add_edit_account_screen.dart';
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
  // Controla si se muestran los valores o asteriscos
  bool _showFinancialValues = true;

  // Datos del home
  List<Account> _accounts = [];
  List<ProximoGasto> _proximosGastos = [];
  Map<String, double> _accountBalances = {};
  List<old_tx.Transaccion> _dailyTransactions =
      []; // List for daily transactions
  double _totalAvailableBalance = 0.0; // Sum of all account balances
  bool _isLoading = true;

  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.user;
      if (currentUser == null) throw Exception("Usuario no encontrado");

      final dbService = DatabaseService();

      // Fetch accounts
      final accounts = await dbService.getAccounts(currentUser.id);

      // Calculate total available balance
      double totalBalance = 0.0;
      final balances = await _calculateBalances(accounts);
      balances.forEach((key, value) => totalBalance += value);

      // Fetch daily transactions
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day, 0, 0, 0);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
      final dailyTransactions = await dbService.getTransacciones(
        (await dbService.getUsuarioByEmail(currentUser.email))?.idUsuario ?? 0,
        fromDate: startOfDay,
        toDate: endOfDay,
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
          _totalAvailableBalance = totalBalance;
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
                  amount: _totalAvailableBalance,
                  color: Colors.blue[800]!,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: _buildTitledAmountBox(
                  title: 'Límite Diario',
                  amount: 0.0, // Placeholder
                  color: Colors.grey[700]!,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          // Acciones rápidas fijas
          _buildFixedQuickActions(),
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
    required double amount,
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
            child: Text(
              _showFinancialValues
                  ? '\$${amount.toStringAsFixed(2)}'
                  : '••••••••',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
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
                        ? '\$${gasto.importe.toStringAsFixed(2)}'
                        : '••••••',
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
                    ? '\$${saldo.toStringAsFixed(2)}'
                    : '••••••••',
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

    final dbService = DatabaseService();

    // --- TEMPORARY BRIDGE ---
    // Find the old account ID to fetch transactions from the old table structure.
    final oldUser = await dbService.getUsuarioByEmail(currentUser.email);
    if (oldUser == null) return;

    final oldAccounts = await dbService.findOldAccountByName(
      account.name,
      oldUser.idUsuario,
    );
    if (oldAccounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontró la cuenta correspondiente.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final oldAccountId = oldAccounts.first.idCuenta;
    // --- END OF BRIDGE ---

    final transactions = await dbService.getTransacciones(
      oldUser.idUsuario,
      accountId: oldAccountId,
      // Por defecto, muestra los de hoy. Se podrá cambiar en el futuro.
      fromDate: DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ),
      toDate: DateTime.now(),
    );

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
                      ? const Center(
                          child: Text('No hay movimientos en esta cuenta.'),
                        )
                      : _buildTransactionList(transactions, scrollController),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDailySummarySection() {
    double totalIngresos = 0;
    double totalEgresos = 0;

    for (var tx in _dailyTransactions) {
      if (tx.tipo == old_tx.TipoTransaccion.ingreso) {
        totalIngresos += tx.monto;
      } else {
        totalEgresos += tx.monto;
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
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Text(
          _showFinancialValues ? '\$${amount.toStringAsFixed(2)}' : '••••••',
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
    for (var tx in _dailyTransactions) {
      subtotals.update(
        tx.moneda,
        (value) => value + (tx.signo * tx.monto),
        ifAbsent: () => tx.signo * tx.monto,
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
    List<old_tx.Transaccion> transactions,
    ScrollController controller,
  ) {
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        // Re-use the same widget as for daily transactions, but now it's in a list
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

  Widget _buildFixedQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildQuickActionIcon(Icons.remove, 'Gasto', Colors.red, () {
          _navigateToAddTransaction(tx.TransactionType.expense);
        }),
        _buildQuickActionIcon(Icons.add, 'Ingreso', Colors.green, () {
          _navigateToAddTransaction(tx.TransactionType.income);
        }),
        _buildQuickActionIcon(
          Icons.receipt_long,
          'Gasto Fijo',
          Colors.orange,
          () {
            Navigator.of(context).pushNamed('/fixed-expenses');
          },
        ),
      ],
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

  Widget _buildDailyTransactionItem(old_tx.Transaccion transaction) {
    final isIncome = transaction.tipo == old_tx.TipoTransaccion.ingreso;
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
                  transaction.descripcion ?? 'Sin descripción',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${transaction.tipo.displayName} - ${DateFormat('dd/MM/yy').format(transaction.fechaTransaccion)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            _showFinancialValues
                ? '\$${transaction.monto.toStringAsFixed(2)}'
                : '••••••',
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

  void _navigateToAddTransaction(tx.TransactionType type) async {
    // Navega a la pantalla de agregar transacción y espera a que se cierre.
    // El `then` se ejecutará cuando se haga `pop` en la pantalla de transacción.
    await Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
        )
        .then((_) => _loadData());
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
  String _formatFinancialValue(double value) {
    if (!_showFinancialValues) {
      return '••••••';
    }
    return '\$${value.toStringAsFixed(0)}';
  }

  // Función auxiliar para calcular gastos fijos del período actual
  Future<double> _calculateCurrentPeriodFixedExpenses() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final User? currentUser = authProvider.user;

      if (currentUser == null) return 0.0;

      final dbService = DatabaseService();
      final userIdInt = int.parse(currentUser.id);
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
                Navigator.of(
                  context,
                ).pushNamed('/accounts').then((_) => _loadData());
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
        .push(
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
