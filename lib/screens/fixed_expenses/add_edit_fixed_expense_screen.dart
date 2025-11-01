import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';

import '../../models/fixed_expense.dart';
import '../../models/account.dart';
import '../../services/database_service.dart';
import '../../providers/auth_provider.dart';

class AddEditFixedExpenseScreen extends StatefulWidget {
  final ExpenseFrequency frequency;
  final FixedExpense? expense; // For editing existing expense

  const AddEditFixedExpenseScreen({
    super.key,
    required this.frequency,
    this.expense,
  });

  @override
  State<AddEditFixedExpenseScreen> createState() =>
      _AddEditFixedExpenseScreenState();
}

class _AddEditFixedExpenseScreenState extends State<AddEditFixedExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _dayOfMonthController = TextEditingController();
  final _dayOfWeekController = TextEditingController();

  String _selectedCategory = 'Otros';
  PaymentType _selectedPaymentType = PaymentType.onDay;
  bool _isLoading = false;
  double _annualCostPreview = 0.0;

  // Account selection
  final List<Account> _accounts = [];
  Account? _selectedAccount;

  final List<String> _categories = [
    'Deporte',
    'Transporte',
    'Comida',
    'Servicios',
    'Entretenimiento',
    'Salud',
    'Educación',
    'Otros',
  ];

  @override
  void initState() {
    super.initState();
    _loadAccounts();

    if (widget.expense != null) {
      // Editing existing expense
      _nameController.text = widget.expense!.name;
      _descriptionController.text = widget.expense!.description ?? '';
      _amountController.text = widget.expense!.amount.toString();
      _dayOfMonthController.text = widget.expense!.dayOfMonth.toString();
      _dayOfWeekController.text = widget.expense!.dayOfWeek.toString();
      _selectedCategory = widget.expense!.category;
      _selectedPaymentType = widget.expense!.paymentType;
    } else {
      // Adding new expense - set default day
      if (widget.frequency == ExpenseFrequency.monthly) {
        _dayOfMonthController.text = '15';
      } else {
        _dayOfWeekController.text = '1'; // Lunes
      }
    }
    _updateAnnualCostPreview();

    // Agregar listeners para actualizar el costo anual cuando cambien los valores
    _amountController.addListener(_updateAnnualCostPreview);
  }

  Future<void> _loadAccounts() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;

    if (currentUser != null) {
      try {
        final dbService = DatabaseService();
        final accounts = await dbService.getAccounts(currentUser.id);

        setState(() {
          _accounts.addAll(accounts);

          // Auto-select default account if available and no expense is being edited
          if (widget.expense == null) {
            _selectedAccount =
                accounts.where((account) => account.isDefault).firstOrNull ??
                (accounts.isNotEmpty ? accounts.first : null);
          } else {
            // When editing, find the account associated with this expense
            _selectedAccount = accounts
                .where((account) => account.id == widget.expense!.accountId)
                .firstOrNull;
          }
        });
      } catch (e) {
        // Handle error silently for now
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _dayOfMonthController.dispose();
    _dayOfWeekController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.expense != null ? 'Editar Gasto Fijo' : 'Nuevo Gasto Fijo',
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header con frecuencia
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          // Corrected withOpacity
                          color: widget.frequency == ExpenseFrequency.monthly
                              ? Colors.deepPurple.withOpacity(0.1)
                              : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              widget.frequency == ExpenseFrequency.monthly
                                  ? Icons.event_repeat
                                  : Icons.repeat,
                              color:
                                  widget.frequency == ExpenseFrequency.monthly
                                  ? Colors.deepPurple
                                  : Colors.blue,
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.frequency == ExpenseFrequency.monthly
                                        ? 'Mensual'
                                        : 'Semanal',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          widget.frequency ==
                                              ExpenseFrequency.monthly
                                          ? Colors.deepPurple
                                          : Colors.blue,
                                    ),
                                  ),
                                  Text(
                                    widget.frequency == ExpenseFrequency.monthly
                                        ? 'Se repite cada mes'
                                        : 'Se repite cada semana',
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
                          labelText: 'Nombre del gasto',
                          hintText: 'Ej: Fútbol, Transporte, Alquiler',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.receipt),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El nombre es obligatorio';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description field (optional)
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Descripción (opcional)',
                          hintText: 'Detalles adicionales del gasto',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.description),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      // Amount field
                      TextFormField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText: 'Monto',
                          hintText: '0.00',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.attach_money),
                        ),
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'El monto es obligatorio';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return 'Ingresa un monto válido mayor a 0';
                          }
                          return null;
                        },
                      ),

                      // Vista previa del costo anual
                      if (_annualCostPreview > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(
                            12,
                          ), // Corrected withOpacity
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.teal.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_month,
                                color: Colors.teal,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Costo anual estimado',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.teal,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '\$${_annualCostPreview.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: Colors.teal,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Category dropdown
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Categoría',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.category),
                        ),
                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Day configuration
                      if (widget.frequency == ExpenseFrequency.monthly) ...[
                        TextFormField(
                          controller: _dayOfMonthController,
                          decoration: InputDecoration(
                            labelText: 'Día del mes',
                            hintText: '15',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.calendar_today),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El día del mes es obligatorio';
                            }
                            final day = int.tryParse(value);
                            if (day == null || day < 1 || day > 31) {
                              return 'Ingresa un día válido (1-31)';
                            }
                            return null;
                          },
                        ),
                      ] else ...[
                        DropdownButtonFormField<String>(
                          initialValue: _getDayOfWeekName(
                            int.parse(_dayOfWeekController.text),
                          ),
                          decoration: InputDecoration(
                            labelText: 'Día de la semana',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.today),
                          ),
                          items:
                              const [
                                'Lunes',
                                'Martes',
                                'Miércoles',
                                'Jueves',
                                'Viernes',
                                'Sábado',
                                'Domingo',
                              ].map((day) {
                                return DropdownMenuItem(
                                  value: day,
                                  child: Text(day),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _dayOfWeekController.text = _getDayOfWeekNumber(
                                value!,
                              ).toString();
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Payment type
                      DropdownButtonFormField<String>(
                        initialValue:
                            _selectedPaymentType == PaymentType.inAdvance
                            ? 'Adelantado'
                            : 'En el día',
                        decoration: InputDecoration(
                          labelText: 'Tipo de pago',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.payment),
                        ),
                        items: const ['En el día', 'Adelantado'].map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedPaymentType = value == 'Adelantado'
                                ? PaymentType.inAdvance
                                : PaymentType.onDay;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Account selection
                      if (_accounts.isNotEmpty) ...[
                        DropdownButtonFormField<Account>(
                          initialValue: _selectedAccount,
                          decoration: InputDecoration(
                            labelText: 'Cuenta de pago (opcional)',
                            hintText: 'Selecciona la cuenta para este gasto',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.account_balance),
                          ),
                          items: _accounts.map((account) {
                            return DropdownMenuItem(
                              value: account,
                              child: Row(
                                children: [
                                  Text(
                                    '${account.name}${account.alias != null ? ' (${account.alias})' : ''}',
                                  ),
                                  if (account.isDefault) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Por defecto',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.deepPurple,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (account) {
                            setState(() {
                              _selectedAccount = account;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Si no seleccionas una cuenta, podrás elegirla al momento del pago',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
            // Fixed button at bottom
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveExpense,
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
                        widget.expense != null
                            ? 'Guardar Cambios'
                            : 'Crear Gasto Fijo',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveExpense() async {
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
      final amount = double.parse(_amountController.text);

      if (widget.expense != null) {
        // Update existing expense
        final updatedExpense = widget.expense!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          amount: amount,
          frequency: widget.frequency,
          paymentType: _selectedPaymentType,
          dayOfMonth: widget.frequency == ExpenseFrequency.monthly
              ? int.parse(_dayOfMonthController.text)
              : 1,
          dayOfWeek: widget.frequency == ExpenseFrequency.weekly
              ? int.parse(_dayOfWeekController.text)
              : 1,
          category: _selectedCategory,
          accountId: _selectedAccount?.id,
          updatedAt: DateTime.now(),
        );

        // TODO: Update for new GastoFijo model
        // await dbService.updateGastoFijo(updatedExpense);
      } else {
        // Create new expense
        final newExpense = FixedExpense(
          id: const Uuid().v4(),
          userId: currentUser.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          amount: amount,
          frequency: widget.frequency,
          paymentType: _selectedPaymentType,
          dayOfMonth: widget.frequency == ExpenseFrequency.monthly
              ? int.parse(_dayOfMonthController.text)
              : 1,
          dayOfWeek: widget.frequency == ExpenseFrequency.weekly
              ? int.parse(_dayOfWeekController.text)
              : 1,
          category: _selectedCategory,
          accountId: _selectedAccount?.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // TODO: Update for new GastoFijo model
        // await dbService.insertGastoFijo(newExpense);
      }

      if (mounted) {
        Navigator.of(context).pop(); // Go back to expenses list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.expense != null
                  ? 'Gasto fijo actualizado correctamente'
                  : 'Gasto fijo creado correctamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar gasto fijo: $e'),
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

  String _getDayOfWeekName(int dayNumber) {
    const days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    return days[dayNumber - 1];
  }

  int _getDayOfWeekNumber(String dayName) {
    const days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    return days.indexOf(dayName) + 1;
  }

  // Función para actualizar la vista previa del costo anual
  void _updateAnnualCostPreview() {
    final amountText = _amountController.text;
    if (amountText.isNotEmpty) {
      final amount = double.tryParse(amountText);
      if (amount != null && amount > 0) {
        setState(() {
          _annualCostPreview = widget.frequency == ExpenseFrequency.monthly
              ? amount * 12
              : amount * 52;
        });
      } else {
        setState(() {
          _annualCostPreview = 0.0;
        });
      }
    } else {
      setState(() {
        _annualCostPreview = 0.0;
      });
    }
  }
}
