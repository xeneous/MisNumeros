import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/gasto_fijo.dart';

class FixedExpenseListItem extends StatelessWidget {
  final GastoFijo expense;
  final VoidCallback onExpenseUpdated;

  const FixedExpenseListItem({
    super.key,
    required this.expense,
    required this.onExpenseUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'es_AR',
      symbol: '\$',
      decimalDigits: 0,
    );

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
                      Text(
                        expense.nombre,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
                        currencyFormat.format(expense.amount),
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
                        'Anual: \$${currencyFormat.format(expense.frecuencia == 'MENSUAL' ? expense.amount * 12 : expense.amount * 52)}',
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
                  onChanged: (value) {
                    // TODO: Implementar activar/desactivar gasto fijo
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Activar/desactivar - Próximamente'),
                        backgroundColor: Colors.blue,
                      ),
                    );
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

  void _showEditExpenseDialog(BuildContext context) {
    // TODO: Implement edit expense dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Editar gasto fijo - Próximamente'),
        backgroundColor: Colors.blue,
      ),
    );
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
            onPressed: () {
              // TODO: Implement expense deletion
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Eliminar gasto fijo - Próximamente'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
