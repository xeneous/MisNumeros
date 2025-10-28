import 'package:flutter/material.dart';

import '../../screens/credit_cards/add_edit_credit_card_screen.dart';

class AddCreditCardFab extends StatelessWidget {
  const AddCreditCardFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        _showAddCreditCardDialog(context);
      },
      icon: const Icon(Icons.add),
      label: const Text('Agregar Tarjeta'),
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
    );
  }

  void _showAddCreditCardDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Nueva Tarjeta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.credit_card, color: Colors.purple),
              ),
              title: const Text('Tarjeta Personal'),
              subtitle: const Text('Tarjeta de crédito personalizada'),
              onTap: () => _addCreditCard(context),
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

  void _addCreditCard(BuildContext context) {
    Navigator.of(context).pop(); // Close the dialog

    // Navigate to add credit card screen
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AddEditCreditCardScreen()),
    );
  }
}
