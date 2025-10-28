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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  // Corrected withOpacity
                  color: Colors.deepPurple.withOpacity(0.1),
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
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.repeat, color: Colors.blue),
              ),
              title: const Text('Semanal'),
              subtitle: const Text('Gastos que se repiten cada semana'),
              onTap: () => _addExpense(context, ExpenseFrequency.weekly),
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
