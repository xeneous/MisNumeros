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
  String? _selectedAccountId;
  DateTime? _selectedDueDate; // For one-time expenses

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

    // Initialize form values first
    if (widget.expense != null) {
      // Editing existing expense
      _nameController.text = widget.expense!.name;
      _descriptionController.text = widget.expense!.description ?? '';
      _amountController.text = widget.expense!.amount.toString();
      _dayOfMonthController.text = widget.expense!.dayOfMonth.toString();
      _dayOfWeekController.text = widget.expense!.dayOfWeek.toString();
      _selectedCategory = widget.expense!.category;
      _selectedPaymentType = widget.expense!.paymentType;
      _selectedAccountId = widget.expense!.accountId;
      _selectedDueDate = widget.expense!.dueDate;
    } else {
      // Adding new expense - set default day
      if (widget.frequency == ExpenseFrequency.monthly ||
          widget.frequency == ExpenseFrequency.bimonthly) {
        _dayOfMonthController.text = '15';
      } else if (widget.frequency == ExpenseFrequency.weekly) {
        _dayOfWeekController.text = '1'; // Lunes
      } else if (widget.frequency == ExpenseFrequency.oneTime) {
        // Set default due date to tomorrow
        _selectedDueDate = DateTime.now().add(const Duration(days: 1));
      }
    }

    // Add listener for annual cost preview
    _amountController.addListener(_updateAnnualCostPreview);
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
      resizeToAvoidBottomInset: true,
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
                          color: _getFrequencyColor().withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getFrequencyIcon(),
                              color: _getFrequencyColor(),
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getFrequencyTitle(),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _getFrequencyColor(),
                                    ),
                                  ),
                                  Text(
                                    _getFrequencySubtitle(),
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
                      if (widget.frequency == ExpenseFrequency.monthly ||
                          widget.frequency == ExpenseFrequency.bimonthly) ...[
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
                      ] else if (widget.frequency == ExpenseFrequency.weekly) ...[
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
                      ] else if (widget.frequency == ExpenseFrequency.oneTime) ...[
                        // Date picker for one-time expenses
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDueDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                            );
                            if (picked != null) {
                              setState(() {
                                _selectedDueDate = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.event, color: Colors.orange),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Fecha de vencimiento',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _selectedDueDate != null
                                            ? '${_selectedDueDate!.day}/${_selectedDueDate!.month}/${_selectedDueDate!.year}'
                                            : 'Seleccionar fecha',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 16),
                              ],
                            ),
                          ),
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

                      // Account selection with FutureBuilder
                      FutureBuilder<List<Account>>(
                        future: DatabaseService().getAccounts(
                          Provider.of<AuthProvider>(context, listen: false).user?.id ?? '',
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Cargando cuentas...'),
                                ],
                              ),
                            );
                          }

                          final accounts = snapshot.data ?? [];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                value: _selectedAccountId,
                                decoration: InputDecoration(
                                  labelText: 'Cuenta de pago sugerida (opcional)',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Icon(Icons.account_balance_wallet),
                                ),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('Sin cuenta asignada'),
                                  ),
                                  ...accounts.map((account) {
                                    return DropdownMenuItem<String>(
                                      value: account.id,
                                      child: Text(
                                        '${account.name}${account.alias != null ? ' (${account.alias})' : ''}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedAccountId = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Esta será la cuenta sugerida al momento de pagar',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
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
                        style: const TextStyle(fontSize: 16),
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
          dayOfMonth: (widget.frequency == ExpenseFrequency.monthly ||
                  widget.frequency == ExpenseFrequency.bimonthly)
              ? int.parse(_dayOfMonthController.text)
              : 0,
          dayOfWeek: widget.frequency == ExpenseFrequency.weekly
              ? int.parse(_dayOfWeekController.text)
              : 0,
          dueDate: widget.frequency == ExpenseFrequency.oneTime
              ? _selectedDueDate
              : null,
          category: _selectedCategory,
          accountId: _selectedAccountId,
          updatedAt: DateTime.now(),
        );

        await dbService.updateFixedExpenseNew(updatedExpense);
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
          dayOfMonth: (widget.frequency == ExpenseFrequency.monthly ||
                  widget.frequency == ExpenseFrequency.bimonthly)
              ? int.parse(_dayOfMonthController.text)
              : 0,
          dayOfWeek: widget.frequency == ExpenseFrequency.weekly
              ? int.parse(_dayOfWeekController.text)
              : 0,
          dueDate: widget.frequency == ExpenseFrequency.oneTime
              ? _selectedDueDate
              : null,
          category: _selectedCategory,
          accountId: _selectedAccountId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await dbService.insertFixedExpenseNew(newExpense);
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to signal success
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text(
        //       widget.expense != null
        //           ? 'Gasto fijo actualizado correctamente'
        //           : 'Gasto fijo creado correctamente',
        //     ),
        //     backgroundColor: Colors.green,
        //   ),
        // );
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
    double newPreview = 0.0;

    if (amountText.isNotEmpty) {
      final amount = double.tryParse(amountText);
      if (amount != null && amount > 0) {
        switch (widget.frequency) {
          case ExpenseFrequency.monthly:
            newPreview = amount * 12;
            break;
          case ExpenseFrequency.weekly:
            newPreview = amount * 52;
            break;
          case ExpenseFrequency.bimonthly:
            newPreview = amount * 6;
            break;
          case ExpenseFrequency.oneTime:
            newPreview = amount;
            break;
        }
      }
    }

    // Only call setState if the value actually changed
    if (_annualCostPreview != newPreview) {
      setState(() {
        _annualCostPreview = newPreview;
      });
    }
  }

  // Helper methods for frequency UI
  Color _getFrequencyColor() {
    switch (widget.frequency) {
      case ExpenseFrequency.monthly:
        return Colors.deepPurple;
      case ExpenseFrequency.weekly:
        return Colors.blue;
      case ExpenseFrequency.bimonthly:
        return Colors.teal;
      case ExpenseFrequency.oneTime:
        return Colors.orange;
    }
  }

  IconData _getFrequencyIcon() {
    switch (widget.frequency) {
      case ExpenseFrequency.monthly:
        return Icons.event_repeat;
      case ExpenseFrequency.weekly:
        return Icons.repeat;
      case ExpenseFrequency.bimonthly:
        return Icons.calendar_month;
      case ExpenseFrequency.oneTime:
        return Icons.event;
    }
  }

  String _getFrequencyTitle() {
    switch (widget.frequency) {
      case ExpenseFrequency.monthly:
        return 'Mensual';
      case ExpenseFrequency.weekly:
        return 'Semanal';
      case ExpenseFrequency.bimonthly:
        return 'Bimestral';
      case ExpenseFrequency.oneTime:
        return 'Única vez';
    }
  }

  String _getFrequencySubtitle() {
    switch (widget.frequency) {
      case ExpenseFrequency.monthly:
        return 'Se repite cada mes';
      case ExpenseFrequency.weekly:
        return 'Se repite cada semana';
      case ExpenseFrequency.bimonthly:
        return 'Se repite cada 2 meses';
      case ExpenseFrequency.oneTime:
        return 'Gasto que ocurre una sola vez';
    }
  }
}
