import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../../models/cuenta.dart' as old_account;

import '../../models/account.dart';
import '../../services/database_service.dart';
import '../../providers/auth_provider.dart';

class AddEditAccountScreen extends StatefulWidget {
  final AccountType accountType;
  final Account? account; // For editing existing account

  const AddEditAccountScreen({
    super.key,
    required this.accountType,
    this.account,
  });

  @override
  State<AddEditAccountScreen> createState() => _AddEditAccountScreenState();
}

class _AddEditAccountScreenState extends State<AddEditAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _aliasController = TextEditingController();

  bool _isLoading = false;
  bool _isDefault = false;
  String _selectedCurrency = 'ARS';

  @override
  void initState() {
    super.initState();
    if (widget.account != null) {
      // Editing existing account
      _nameController.text = widget.account!.name;
      _aliasController.text = widget.account!.alias ?? '';
      _isDefault = widget.account!.isDefault;
      _selectedCurrency = widget.account!.moneda;
    } else {
      _isDefault = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aliasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account != null ? 'Editar Cuenta' : 'Nueva Cuenta'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Account type header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getAccountTypeColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getAccountTypeIcon(),
                          color: _getAccountTypeColor(),
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.accountType.displayName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _getAccountTypeColor(),
                                ),
                              ),
                              Text(
                                _getAccountTypeDescription(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Name field
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Nombre de la cuenta',
                      hintText: 'Ej: Cuenta Sueldo, Billetera Personal',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.account_balance),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'El nombre es obligatorio';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Alias field (optional)
                  TextFormField(
                    controller: _aliasController,
                    decoration: InputDecoration(
                      labelText: 'Alias (opcional)',
                      hintText: 'Ej: Principal, Ahorros',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.tag),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Currency field
                  DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    items: ['ARS', 'USD', 'EUR', 'BRL'].map((String currency) {
                      return DropdownMenuItem<String>(
                        value: currency,
                        child: Text('Moneda: $currency'),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedCurrency = newValue;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Moneda de la cuenta',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.currency_exchange),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Default account toggle
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: SwitchListTile(
                      title: const Text(
                        'Cuenta predeterminada',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Se sugerirá automáticamente al agregar gastos',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _isDefault,
                      onChanged: (value) {
                        setState(() {
                          _isDefault = value;
                        });
                      },
                      activeThumbColor: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Save button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            widget.account != null
                                ? 'Guardar Cambios'
                                : 'Crear Cuenta',
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.user;

      if (currentUser == null) {
        throw Exception('Usuario no autenticado');
      }

      final dbService = DatabaseService();
      const balance = 0.0;

      if (widget.account != null) {
        // Update existing account
        final updatedAccount = widget.account!.copyWith(
          name: _nameController.text.trim(),
          alias: _aliasController.text.trim().isEmpty
              ? null
              : _aliasController.text.trim(),
          moneda: _selectedCurrency,
          initialBalance: balance,
          currentBalance: balance, // For now, current balance = initial balance
          isDefault: _isDefault,
          updatedAt: DateTime.now(),
        );

        await dbService.updateAccount(updatedAccount);

        // --- TEMPORARY BRIDGE ---
        // Also update the corresponding "old" Cuenta.
        // This should be removed after the transactions table migration.
        final oldAccounts = await dbService.findOldAccountByName(
          updatedAccount.name,
          int.tryParse(updatedAccount.userId) ?? 0,
        );
        if (oldAccounts.isNotEmpty) {
          final oldAccountToUpdate = oldAccounts.first.copyWith(
            moneda: updatedAccount.moneda,
            esPrincipal: updatedAccount.isDefault,
          );
          await dbService.updateCuenta(oldAccountToUpdate);
        }
        // --- END OF BRIDGE ---

        // If this account is set as default, remove default flag from other accounts
        if (_isDefault) {
          await dbService.clearOtherDefaultAccounts(
            updatedAccount.userId,
            updatedAccount.id,
          );
        }
      } else {
        // Create new account
        final newAccount = Account(
          id: const Uuid().v4(),
          userId: currentUser.id,
          name: _nameController.text.trim(),
          alias: _aliasController.text.trim().isEmpty
              ? null
              : _aliasController.text.trim(),
          moneda: _selectedCurrency,
          type: widget.accountType,
          initialBalance: balance,
          currentBalance: balance,
          isDefault: _isDefault,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await dbService.insertAccount(newAccount);

        // --- TEMPORARY BRIDGE ---
        // Also create a corresponding "old" Cuenta to allow transactions to be saved.
        // This should be removed after the transactions table migration.
        final oldAccount = old_account.Cuenta(
          idCuenta: 0, // autoincremento
          idUsuario:
              (await dbService.getUsuarioByEmail(
                currentUser.email,
              ))?.idUsuario ??
              0, // Asegúrate de que el usuario exista en la tabla 'usuarios'
          nombre: newAccount.name,
          // Mapeo manual para corregir la discrepancia de enums
          moneda: newAccount.moneda,
          tipo: _mapAccountTypeToOldTipoCuenta(newAccount.type),
          fechaCreacion: newAccount.createdAt,
          esPrincipal: newAccount.isDefault,
        );
        await dbService.insertCuenta(oldAccount);
        // --- END OF BRIDGE ---

        // If this account is set as default, remove default flag from other accounts
        if (_isDefault) {
          await dbService.clearOtherDefaultAccounts(
            newAccount.userId,
            newAccount.id,
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop(); // Go back to accounts list
        // Se elimina el SnackBar para una transición más rápida.
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar cuenta: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getAccountTypeColor() {
    switch (widget.accountType) {
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

  IconData _getAccountTypeIcon() {
    switch (widget.accountType) {
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

  String _getAccountTypeDescription() {
    switch (widget.accountType) {
      case AccountType.cash:
        return 'Dinero en efectivo o billetera física';
      case AccountType.debit:
        return 'Cuenta bancaria o tarjeta de débito';
      case AccountType.digital:
        return 'Billeteras digitales como PayPal, Mercado Pago, etc.';
      case AccountType.credit:
        return 'Para compras en cuotas o en otra moneda';
    }
  }

  // Helper para mapear el nuevo AccountType al antiguo TipoCuenta
  old_account.TipoCuenta _mapAccountTypeToOldTipoCuenta(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return old_account.TipoCuenta.efectivo;
      case AccountType.debit:
        return old_account.TipoCuenta.bancaria;
      case AccountType.digital:
        return old_account.TipoCuenta.digital;
      case AccountType.credit:
        return old_account.TipoCuenta.bancaria; // Map to a similar old type
    }
  }
}
