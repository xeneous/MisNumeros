import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../models/gasto_fijo.dart';
// import '../../models/fixed_expense.dart'; // Use GastoFijo model
import '../../widgets/fixed_expenses/fixed_expense_list_item.dart';
import '../../widgets/fixed_expenses/add_fixed_expense_fab.dart';

class FixedExpensesScreen extends StatefulWidget {
  const FixedExpensesScreen({super.key});

  @override
  State<FixedExpensesScreen> createState() => _FixedExpensesScreenState();
}

class _FixedExpensesScreenState extends State<FixedExpensesScreen> {
  List<GastoFijo> _fixedExpenses = [];
  bool _isLoading = true;
  double _totalMonthlyExpenses = 0.0;
  double _totalWeeklyExpenses = 0.0;

  @override
  void initState() {
    super.initState();
    _loadGastosFijos();
  }

  Future<void> _loadGastosFijos() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;

    if (currentUser != null) {
      try {
        final dbService = DatabaseService();
        final expenses = await dbService.getGastosFijos(
          int.parse(currentUser.id),
        ); // Fetch real data

        // Calcular totales
        double monthlyTotal = 0.0;
        double weeklyTotal = 0.0;

        for (var expense in expenses) {
          if (expense.isActive) {
            if (expense.frecuencia == 'MENSUAL') {
              monthlyTotal += expense.amount;
            } else if (expense.frecuencia == 'SEMANAL') {
              weeklyTotal += expense.amount;
            }
          }
        }

        setState(() {
          _fixedExpenses = expenses;
          _totalMonthlyExpenses = monthlyTotal;
          _totalWeeklyExpenses = weeklyTotal;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar gastos fijos: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gastos Fijos'), elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
      floatingActionButton: const AddFixedExpenseFab(),
    );
  }

  Widget _buildSummaryCard() {
    final totalAnnualExpenses =
        (_totalMonthlyExpenses * 12) + (_totalWeeklyExpenses * 52);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            // Corrected withOpacity
            color: Colors.grey.withOpacity(0.1),
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
                      '\$${_totalMonthlyExpenses.toStringAsFixed(0)}',
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
                      '\$${_totalWeeklyExpenses.toStringAsFixed(0)}',
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
              // Corrected withOpacity
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_month, color: Colors.teal, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Anual: \$${totalAnnualExpenses.toStringAsFixed(0)}',
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
