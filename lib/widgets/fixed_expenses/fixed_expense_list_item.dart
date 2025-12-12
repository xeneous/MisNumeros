import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/fixed_expense.dart';
import '../../screens/fixed_expenses/add_edit_fixed_expense_screen.dart';
import '../../services/database_service.dart';

class FixedExpenseListItem extends StatelessWidget {
  final FixedExpense expense;
  final VoidCallback onExpenseUpdated;

  static final _currencyFormat = NumberFormat.currency(
    locale: 'es_AR',
    symbol: '\$',
    decimalDigits: 0,
  );

  const FixedExpenseListItem({
    super.key,
    required this.expense,
    required this.onExpenseUpdated,
  });

  @override
  Widget build(BuildContext context) {
    // Safety check for infinite or NaN amounts which can crash rendering
    final safeAmount = expense.amount.isFinite ? expense.amount : 0.0;
    final formattedAmount = _currencyFormat.format(safeAmount);

    // Calculate annual amount safely
    final annualAmount = expense.frequency == ExpenseFrequency.monthly
        ? safeAmount * 12
        : safeAmount * 52;
    final safeAnnualAmount = annualAmount.isFinite ? annualAmount : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icono de categoría
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.receipt,
                color: Colors.deepPurple,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Información del gasto fijo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre y frecuencia
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          expense.nombre,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: expense.frecuencia == 'MENSUAL'
                              ? Colors.deepPurple.withValues(alpha: 0.1)
                              : Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          expense.frecuencia == 'MENSUAL'
                              ? 'Mensual'
                              : 'Semanal',
                          style: TextStyle(
                            fontSize: 10,
                            color: expense.frecuencia == 'MENSUAL'
                                ? Colors.deepPurple
                                : Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Categoría y día
                  Text(
                    'Categoría • ${expense.frecuencia == 'MENSUAL' ? 'Día ${expense.diaMes ?? 1}' : 'Día semanal'}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),

                  // Monto y tipo de pago
                  Row(
                    children: [
                      Text(
                        formattedAmount,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: expense.isActive
                              ? Colors.green[600]
                              : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'En el día',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Costo anual
                  if (expense.isActive) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Anual: \$${_currencyFormat.format(safeAnnualAmount)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.teal[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],

                  // Próxima fecha de aplicación
                  if (expense.isActive) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Próximo: Próximamente',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            ),

            // Estado activo/inactivo y menú
            Column(
              children: [
                Switch(
                  value: expense.isActive,
                  onChanged: (value) async {
                    try {
                      final dbService = DatabaseService();
                      final updatedExpense = expense.copyWith(isActive: value);
                      await dbService.updateFixedExpense(updatedExpense);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              value
                                  ? '${expense.nombre} activado'
                                  : '${expense.nombre} desactivado',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                        onExpenseUpdated();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al actualizar: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  activeThumbColor: Colors.deepPurple,
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showEditExpenseDialog(context);
                        break;
                      case 'delete':
                        _showDeleteExpenseDialog(context);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Eliminar'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditExpenseDialog(BuildContext context) async {
    // Convert GastoFijo to FixedExpense
    final fixedExpense = FixedExpense(
      id: expense.idGasto.toString(),
      userId: expense.userId,
      name: expense.nombre,
      description: expense.descripcion,
      amount: expense.montoCuotas,
      frequency: expense.frecuencia == 'MENSUAL'
          ? ExpenseFrequency.monthly
          : ExpenseFrequency.weekly,
      paymentType: PaymentType.onDay, // Default, could be stored in DB later
      dayOfMonth: expense.diaMes ?? 1,
      dayOfWeek: expense.diaSemana ?? 1,
      category: 'Otros', // Default category
      accountId: null, // Will be loaded from DB if needed
      isActive: expense.activo,
      createdAt: expense.fechaInicio,
      updatedAt: DateTime.now(),
    );

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddEditFixedExpenseScreen(
          frequency: fixedExpense.frequency,
          expense: fixedExpense,
        ),
      ),
    );

    if (result == true) {
      onExpenseUpdated();
    }
  }

  void _showDeleteExpenseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar gasto fijo'),
        content: Text(
          '¿Estás seguro de que quieres eliminar "${expense.nombre}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              try {
                final dbService = DatabaseService();
                await dbService.deleteFixedExpense(expense.id);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${expense.nombre} eliminado correctamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  onExpenseUpdated();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al eliminar: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
