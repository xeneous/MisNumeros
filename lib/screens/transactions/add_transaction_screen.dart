import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../models/transaction.dart' as tx;
import '../../models/account.dart';
import '../../services/database_service.dart';
import '../../providers/auth_provider.dart';

class AddTransactionScreen extends StatefulWidget {
  // Nuevo parámetro para saber si se muestra como una hoja modal
  final bool isSheet;

  const AddTransactionScreen({super.key, this.isSheet = false});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dbService = DatabaseService();

  // Controllers
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();

  // Form state
  tx.TransactionType? _transactionType; // No se preselecciona nada
  DateTime _selectedDate = DateTime.now();
  Account? _selectedAccount;
  // Credit cards removed from new schema
  // CreditCard? _selectedCreditCard;
  // bool _useCreditCard = false;

  // Credit card specific fields (removed)
  // final _installmentsController = TextEditingController();
  // final _interestAmountController = TextEditingController();
  // bool _hasInterest = false;

  // Data
  List<Account> _accounts = [];
  // List<CreditCard> _creditCards = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // Focus nodes for quick navigation
  final _amountFocus = FocusNode();
  final _descriptionFocus = FocusNode();
  final _categoryFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadData();

    // Auto-focus on amount field for speed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _amountFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    // Credit card controllers removed
    // _installmentsController.dispose();
    // _interestAmountController.dispose();

    // Properly dispose focus nodes to prevent keyboard event errors
    if (_amountFocus.hasFocus) {
      _amountFocus.unfocus();
    }
    if (_descriptionFocus.hasFocus) {
      _descriptionFocus.unfocus();
    }
    if (_categoryFocus.hasFocus) {
      _categoryFocus.unfocus();
    }

    _amountFocus.dispose();
    _descriptionFocus.dispose();
    _categoryFocus.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;

    if (currentUser != null) {
      try {
        final dbService = DatabaseService();
        // TODO: Fix user ID conversion when auth system is updated
        final accounts = await dbService.getAccounts(currentUser.id);
        // final creditCards = await dbService.getCreditCards(currentUser.id); // Credit cards removed

        // Sort accounts: default first, then by name
        accounts.sort((a, b) {
          if (a.isDefault) return -1;
          if (b.isDefault) return 1;
          return a.name.compareTo(b.name);
        });

        setState(() {
          _accounts = accounts;
          // _creditCards = creditCards; // Credit cards removed
          _isLoading = false;

          // Auto-select default account if available
          _selectedAccount =
              accounts.where((account) => account.isDefault).firstOrNull ??
              (accounts.isNotEmpty ? accounts.first : null);
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar datos: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formContent = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _buildForm();

    if (widget.isSheet) {
      // Si es una hoja modal, se muestra con un diseño adaptado
      return Container(
        // Padding para que el contenido no se oculte detrás de la barra de estado/notch
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        // Usamos un Scaffold para que el resizeToAvoidBottomInset funcione correctamente
        child: Scaffold(backgroundColor: Colors.transparent, body: formContent),
      );
    }

    // Si es una pantalla completa, se muestra con AppBar
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar Movimiento')),
      body: formContent, // Scaffold aquí ya maneja el teclado
    );
  }

  Widget _buildForm() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Título para la hoja modal
              if (widget.isSheet) ...[
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Nuevo Movimiento',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              // Transaction type selector (Income/Expense)
              SegmentedButton<tx.TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: tx.TransactionType.expense,
                    label: Text('Gasto'),
                    icon: Icon(Icons.arrow_upward),
                  ),
                  ButtonSegment(
                    value: tx.TransactionType.income,
                    label: Text('Ingreso'),
                    icon: Icon(Icons.arrow_downward),
                  ),
                ],
                emptySelectionAllowed:
                    true, // Permite que no haya nada seleccionado
                selected: _transactionType != null
                    ? <tx.TransactionType>{_transactionType!}
                    : {},
                onSelectionChanged: (Set<tx.TransactionType> newSelection) {
                  setState(() {
                    _transactionType = newSelection.first;
                  });
                },
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor:
                      _transactionType == tx.TransactionType.income
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  selectedForegroundColor:
                      _transactionType == tx.TransactionType.income
                      ? Colors.green[800]
                      : Colors.red[800],
                  foregroundColor: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),

              // Row for Amount and Account
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Focus(
                      onKeyEvent: (node, event) {
                        // Handle keyboard events properly to prevent assertion errors
                        return KeyEventResult.ignored;
                      },
                      child: TextFormField(
                        controller: _amountController,
                        focusNode: _amountFocus,
                        decoration: InputDecoration(
                          labelText: 'Monto',
                          hintText: '0.00',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.attach_money),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'),
                          ),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa el monto';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return 'Monto inválido';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) =>
                            _descriptionFocus.requestFocus(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<Account>(
                      initialValue: _selectedAccount,
                      items: _accounts.map((cuenta) {
                        return DropdownMenuItem<Account>(
                          value: cuenta,
                          child: Text(
                            cuenta.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (Account? newValue) {
                        setState(() {
                          _selectedAccount = newValue;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Cuenta',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) => value == null ? 'Selecciona' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Description field
              Focus(
                onKeyEvent: (node, event) {
                  // Handle keyboard events properly for description field
                  return KeyEventResult.ignored;
                },
                child: TextFormField(
                  controller: _descriptionController,
                  focusNode: _descriptionFocus,
                  decoration: InputDecoration(
                    labelText: 'Descripción',
                    hintText: '¿En qué gastaste?',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.description),
                  ),
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [LengthLimitingTextInputFormatter(100)],
                  onFieldSubmitted: (_) => _categoryFocus.requestFocus(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa una descripción';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Category field
              Focus(
                onKeyEvent: (node, event) {
                  // Handle keyboard events properly for category field
                  return KeyEventResult.ignored;
                },
                child: TextFormField(
                  controller: _categoryController,
                  focusNode: _categoryFocus,
                  decoration: InputDecoration(
                    labelText: 'Categoría (opcional)',
                    hintText: 'Ej: Comida, Transporte, Entretenimiento',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.category),
                  ),
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [LengthLimitingTextInputFormatter(50)],
                ),
              ),
              const SizedBox(height: 16),

              // Date selector
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('dd/MM/yyyy').format(_selectedDate),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat.yMMMd().format(_selectedDate) ==
                                DateFormat.yMMMd().format(DateTime.now())
                            ? 'Hoy'
                            : '',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Quick save button
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveTransaction,
                icon: const Icon(Icons.save),
                label: const Text('Guardar Transacción'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(
    String label,
    tx.TransactionType type,
    IconData icon,
    Color color,
  ) {
    final isSelected = _transactionType == type; // Null check not needed here

    return ElevatedButton(
      onPressed: () => setState(() => _transactionType = type),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : Colors.grey[200],
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        elevation: isSelected ? 4 : 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _saveTransaction() async {
    // Validar que se haya seleccionado un tipo de movimiento
    if (_transactionType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona si es un Ingreso o un Gasto.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return; // Null check is correct

    if (_selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una cuenta'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.user;

      if (currentUser == null) {
        throw Exception('Usuario no autenticado');
      }

      final amount = double.parse(_amountController.text);

      // Create new tx.Transaction model instance
      final newTransaction = tx.Transaction(
        id: const Uuid().v4(),
        userId: currentUser.id, // This is the Firebase UID (String)
        type: _transactionType!, // Now safe to use !
        amount: amount,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        date: _selectedDate,
        accountId: _selectedAccount!.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _dbService.insertNewTransaction(newTransaction);

      if (mounted) {
        Navigator.of(
          context,
        ).pop(true); // Go back or close sheet and signal success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Movimiento guardado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      // Print the error to the console for detailed debugging
      debugPrint('--- ERROR AL GUARDAR TRANSACCIÓN ---');
      debugPrint('Error: $e');
      debugPrint('Stack Trace: $stackTrace');
      debugPrint('------------------------------------');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // Show a more generic error to the user, but the details are in the console
            content: Text('Error al guardar transacción: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }
}
