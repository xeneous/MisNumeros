import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../models/fixed_expense.dart';
import '../../widgets/fixed_expenses/fixed_expense_list_item.dart';
import '../../widgets/fixed_expenses/add_fixed_expense_fab.dart';

class FixedExpensesScreen extends StatefulWidget {
  const FixedExpensesScreen({super.key});

  @override
  State<FixedExpensesScreen> createState() => _FixedExpensesScreenState();
}

class _FixedExpensesScreenState extends State<FixedExpensesScreen> {
  List<FixedExpense> _fixedExpenses = [];
  bool _isLoading = true;
  double _totalMonthlyExpenses = 0.0;
  double _totalWeeklyExpenses = 0.0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure context is available and avoid build conflicts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGastosFijos();
    });
  }

  Future<void> _loadGastosFijos() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;

    if (currentUser != null) {
      try {
        final dbService = DatabaseService();
        // Add timeout to prevent infinite loading
        final expenses = await dbService.getGastosFijos(
          currentUser.id, // Use Firebase UID directly as string
        ).timeout(const Duration(seconds: 10)); // Fetch real data with timeout

        // Calcular totales
        double monthlyTotal = 0.0;
        double weeklyTotal = 0.0;

        for (var expense in expenses) {
          if (expense.isActive) {
            // Safety check for infinite values
            final amount = expense.amount.isFinite ? expense.amount : 0.0;

            switch (expense.frequency) {
              case ExpenseFrequency.monthly:
                monthlyTotal += amount;
                break;
              case ExpenseFrequency.weekly:
                weeklyTotal += amount;
                break;
              case ExpenseFrequency.bimonthly:
                // Convert bimonthly to monthly equivalent (divided by 2)
                monthlyTotal += amount / 2;
                break;
              case ExpenseFrequency.oneTime:
                // One-time expenses don't count in recurring totals
                break;
            }
          }
        }

        if (mounted) {
          setState(() {
            _fixedExpenses = expenses;
            _totalMonthlyExpenses = monthlyTotal;
            _totalWeeklyExpenses = weeklyTotal;
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error loading fixed expenses: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Error al cargar datos: $e';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar gastos fijos: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gastos Fijos'), elevation: 0),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadGastosFijos,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Gastos Fijos'), elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // Resumen de gastos fijos
                  _buildSummaryCard(),

                  // Lista de gastos fijos
                  Expanded(
                    child: _fixedExpenses.isEmpty
                        ? _buildEmptyState()
                        : _buildGastosFijosList(),
                  ),
                ],
              ),
            ),
      floatingActionButton: const AddFixedExpenseFab(),
    );
  }

  Widget _buildSummaryCard() {
    // Safety check for totals
    final safeMonthly = _totalMonthlyExpenses.isFinite ? _totalMonthlyExpenses : 0.0;
    final safeWeekly = _totalWeeklyExpenses.isFinite ? _totalWeeklyExpenses : 0.0;
    
    final totalAnnualExpenses =
        (safeMonthly * 12) + (safeWeekly * 52);
    final safeAnnual = totalAnnualExpenses.isFinite ? totalAnnualExpenses : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen de Gastos Fijos',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '\$${safeMonthly.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const Text(
                      'Mensuales',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(height: 30, width: 1, color: Colors.grey[300]),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '\$${safeWeekly.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const Text(
                      'Semanales',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_month, color: Colors.teal, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Anual: \$${safeAnnual.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No tienes gastos fijos aún',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega tus gastos recurrentes para mejor control',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildGastosFijosList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _fixedExpenses.length,
      itemBuilder: (context, index) {
        final expense = _fixedExpenses[index];
        return FixedExpenseListItem(
          expense: expense,
          onExpenseUpdated: _loadGastosFijos,
        );
      },
    );
  }
}
