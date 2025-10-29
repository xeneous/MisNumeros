import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/account.dart';
import '../../screens/accounts/add_edit_account_screen.dart';
import '../../services/database_service.dart';

class AccountListItem extends StatelessWidget {
  final Account account;
  final VoidCallback onAccountUpdated;

  const AccountListItem({
    super.key,
    required this.account,
    required this.onAccountUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'es_AR',
      symbol: '\$',
      decimalDigits: 2,
    );

    return InkWell(
      onTap: () => _showEditAccountDialog(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          children: [
            // Account type icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _getAccountTypeColor(account.type).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getAccountTypeIcon(account.type),
                color: _getAccountTypeColor(account.type),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Account info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Account name and alias
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          account.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (account.alias != null) ...[
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
                            account.alias!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                      if (account.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Por defecto',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Account type
                  Text(
                    account.type.displayName,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),

                  // Current balance
                  Text(
                    currencyFormat.format(account.currentBalance),
                    style: TextStyle(
                      // TODO: This needs real balance
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: 0 >= 0 ? Colors.green[600] : Colors.red[600],
                    ),
                  ),
                ],
              ),
            ),

            // Menu button
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _showEditAccountDialog(context);
                    break;
                  case 'delete':
                    if (account.isDeletable) {
                      _showDeleteAccountDialog(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'No se puede eliminar la billetera por defecto',
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
                if (account.isDeletable)
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

  Color _getAccountTypeColor(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return Colors.green;
      case AccountType.debit:
        return Colors.blue;
      case AccountType.digital:
        return Colors.purple;
      case AccountType.credit:
        return Colors.orange;
    }
  }

  IconData _getAccountTypeIcon(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return Icons.money;
      case AccountType.debit:
        return Icons.credit_card;
      case AccountType.digital:
        return Icons.account_balance_wallet;
      case AccountType.credit:
        return Icons.credit_score;
    }
  }

  void _showEditAccountDialog(BuildContext context) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => AddEditAccountScreen(
              accountType: account.type,
              account: account,
            ),
          ),
        )
        .then((_) => onAccountUpdated());
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: Text(
          '¿Estás seguro de que quieres eliminar la cuenta "${account.name}"? Esta acción no se puede deshacer.',
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
                await dbService.deleteAccount(account.id);
                onAccountUpdated(); // Refresh the list
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cuenta eliminada correctamente'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al eliminar la cuenta: $e'),
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
