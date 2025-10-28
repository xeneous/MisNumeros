import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';

import '../../models/credit_card.dart';
import '../../services/database_service.dart';
import '../../providers/auth_provider.dart';

class AddEditCreditCardScreen extends StatefulWidget {
  final CreditCard? creditCard; // For editing existing credit card

  const AddEditCreditCardScreen({super.key, this.creditCard});

  @override
  State<AddEditCreditCardScreen> createState() =>
      _AddEditCreditCardScreenState();
}

class _AddEditCreditCardScreenState extends State<AddEditCreditCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _aliasController = TextEditingController();
  final _creditLimitController = TextEditingController();
  final _closingDayController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.creditCard != null) {
      // Editing existing credit card
      _nameController.text = widget.creditCard!.name;
      _aliasController.text = widget.creditCard!.alias ?? '';
      _creditLimitController.text = widget.creditCard!.creditLimit.toString();
      _closingDayController.text = widget.creditCard!.closingDay.toString();
    } else {
      // Adding new credit card - set default closing day to 15
      _closingDayController.text = '15';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aliasController.dispose();
    _creditLimitController.dispose();
    _closingDayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.creditCard != null ? 'Editar Tarjeta' : 'Nueva Tarjeta',
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Credit card type header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.credit_card,
                        color: Colors.purple,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tarjeta de Crédito',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                            Text(
                              'Configura tu tarjeta de crédito personal',
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
                    labelText: 'Nombre de la tarjeta',
                    hintText: 'Ej: Visa Gold, Mastercard Platinum',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.credit_card),
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
                    hintText: 'Ej: Principal, Compras',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.tag),
                  ),
                ),
                const SizedBox(height: 16),

                // Credit limit field
                TextFormField(
                  controller: _creditLimitController,
                  decoration: InputDecoration(
                    labelText: 'Límite de crédito',
                    hintText: '0.00',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'El límite de crédito es obligatorio';
                    }
                    final limit = double.tryParse(value);
                    if (limit == null || limit <= 0) {
                      return 'Ingresa un límite válido mayor a 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Closing day field
                TextFormField(
                  controller: _closingDayController,
                  decoration: InputDecoration(
                    labelText: 'Día de cierre',
                    hintText: '15',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'El día de cierre es obligatorio';
                    }
                    final day = int.tryParse(value);
                    if (day == null || day < 1 || day > 31) {
                      return 'Ingresa un día válido (1-31)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Save button
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveCreditCard,
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
                          widget.creditCard != null
                              ? 'Guardar Cambios'
                              : 'Crear Tarjeta',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveCreditCard() async {
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
      final creditLimit = double.parse(_creditLimitController.text);
      final closingDay = int.parse(_closingDayController.text);

      if (widget.creditCard != null) {
        // Update existing credit card
        final updatedCreditCard = widget.creditCard!.copyWith(
          name: _nameController.text.trim(),
          alias: _aliasController.text.trim().isEmpty
              ? null
              : _aliasController.text.trim(),
          creditLimit: creditLimit,
          closingDay: closingDay,
          updatedAt: DateTime.now(),
        );

        await dbService.updateCreditCard(updatedCreditCard);
      } else {
        // Create new credit card
        final newCreditCard = CreditCard(
          id: const Uuid().v4(),
          userId: currentUser.id,
          name: _nameController.text.trim(),
          alias: _aliasController.text.trim().isEmpty
              ? null
              : _aliasController.text.trim(),
          creditLimit: creditLimit,
          closingDay: closingDay,
          currentBalance: 0.0,
          availableCredit: creditLimit,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await dbService.insertCreditCard(newCreditCard);
      }

      if (mounted) {
        Navigator.of(context).pop(); // Go back to credit cards list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.creditCard != null
                  ? 'Tarjeta actualizada correctamente'
                  : 'Tarjeta creada correctamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar tarjeta: $e'),
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
}
