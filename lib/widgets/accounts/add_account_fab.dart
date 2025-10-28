import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../screens/accounts/add_edit_account_screen.dart';

class AddAccountFab extends StatelessWidget {
  const AddAccountFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        _showAddAccountDialog(context);
      },
      icon: const Icon(Icons.add),
      label: const Text('Agregar Cuenta'),
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
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

    // Navigate to add account screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddEditAccountScreen(accountType: type),
      ),
    );
  }
}
