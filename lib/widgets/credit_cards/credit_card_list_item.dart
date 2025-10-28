import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/credit_card.dart';

import '../../services/database_service.dart';

class CreditCardListItem extends StatelessWidget {
  final CreditCard creditCard;
  final VoidCallback onCreditCardUpdated;

  const CreditCardListItem({
    super.key,
    required this.creditCard,
    required this.onCreditCardUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'es_AR',
      symbol: '\$',
      decimalDigits: 2,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Credit card icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.credit_card,
                color: Colors.purple,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Credit card info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Credit card name and alias
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          creditCard.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (creditCard.alias != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            creditCard.alias!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Credit limit and closing day
                  Text(
                    'Límite: ${currencyFormat.format(creditCard.creditLimit)} • Cierre: día ${creditCard.closingDay}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),

                  // Current balance and available credit
                  Row(
                    children: [
                      Text(
                        'Usado: ${currencyFormat.format(creditCard.currentBalance)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color:
                              creditCard.currentBalance >
                                  creditCard.creditLimit * 0.8
                              ? Colors.red[600]
                              : Colors.green[600],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Disponible: ${currencyFormat.format(creditCard.availableCredit)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Menu button
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _showEditCreditCardDialog(context);
                    break;
                  case 'delete':
                    if (creditCard.isActive) {
                      _showDeleteCreditCardDialog(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'No se puede eliminar una tarjeta inactiva',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
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
      ),
    );
  }

  void _showEditCreditCardDialog(BuildContext context) {
    // TODO: Implement edit credit card dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Editar tarjeta - Próximamente'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showDeleteCreditCardDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar tarjeta'),
        content: Text(
          '¿Estás seguro de que quieres eliminar la tarjeta "${creditCard.name}"? Esta acción no se puede deshacer.',
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
                await dbService.deleteCreditCard(creditCard.id);
                onCreditCardUpdated(); // Refresh the list
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tarjeta eliminada correctamente'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al eliminar la tarjeta: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
