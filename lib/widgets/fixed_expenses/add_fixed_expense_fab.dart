import 'package:flutter/material.dart';

import '../../models/fixed_expense.dart';
import '../../screens/fixed_expenses/add_edit_fixed_expense_screen.dart';

class AddFixedExpenseFab extends StatelessWidget {
  const AddFixedExpenseFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        _showAddExpenseDialog(context);
      },
      icon: const Icon(Icons.add),
      label: const Text('Agregar Gasto Fijo'),
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
    );
  }

  void _showAddExpenseDialog(BuildContext context) {
    showDialog(
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
                onTap: () => _addExpense(context, ExpenseFrequency.monthly),
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
                onTap: () => _addExpense(context, ExpenseFrequency.weekly),
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
                onTap: () => _addExpense(context, ExpenseFrequency.bimonthly),
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
                onTap: () => _addExpense(context, ExpenseFrequency.oneTime),
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
  }

  void _addExpense(BuildContext context, ExpenseFrequency frequency) {
    Navigator.of(context).pop(); // Close the dialog

    // Navigate to add expense screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddEditFixedExpenseScreen(frequency: frequency),
      ),
    );
  }
}
