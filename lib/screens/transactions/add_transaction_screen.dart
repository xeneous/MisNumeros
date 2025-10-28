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
  const AddTransactionScreen({super.key});

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
  tx.TransactionType _transactionType = tx.TransactionType.expense;
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
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Transacción'),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveTransaction,
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar'),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Transaction type selector (Income/Expense)
                Row(
                  children: [
                    Expanded(
                      child: _buildTypeButton(
                        'Gasto',
                        tx.TransactionType.expense,
                        Icons.remove,
                        Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTypeButton(
                        'Ingreso',
                        tx.TransactionType.income,
                        Icons.add,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Row for Amount and Account
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
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
                        keyboardType: TextInputType.numberWithOptions(
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
                        validator: (value) =>
                            value == null ? 'Selecciona' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Description field
                TextFormField(
                  controller: _descriptionController,
                  focusNode: _descriptionFocus,
                  decoration: InputDecoration(
                    labelText: 'Descripción (opcional)',
                    hintText: '¿En qué gastaste?',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.description),
                  ),
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  onFieldSubmitted: (_) => _categoryFocus.requestFocus(),
                ),
                const SizedBox(height: 16),

                // Category field
                TextFormField(
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
                          _selectedDate.isAtSameMomentAs(DateTime.now())
                              ? 'Hoy'
                              : '',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
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
      ),
    );
  }

  Widget _buildTypeButton(
    String label,
    tx.TransactionType type,
    IconData icon,
    Color color,
  ) {
    final isSelected = _transactionType == type;

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
    if (!_formKey.currentState!.validate()) return;

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
        userId: currentUser.id,
        type: _transactionType,
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
        Navigator.of(context).pop(); // Go back
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transacción guardada correctamente'),
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
