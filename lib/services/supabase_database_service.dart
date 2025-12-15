import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account.dart';
import '../models/credit_card.dart';
import '../models/categoria.dart';
import '../models/fixed_expense.dart';
import '../models/skipped_payment.dart';
import '../models/transaction.dart' as new_tx;

/// Service for managing database operations with Supabase
/// Replaces the SQLite database_service.dart
class SupabaseDatabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get current user ID
  String? get currentUserId => _client.auth.currentUser?.id;

  // ============================================
  // ACCOUNTS (Cuentas/Billeteras)
  // ============================================

  /// Get all accounts for the current user
  /// [userId] parameter is optional for backward compatibility (ignored)
  Future<List<Account>> getAccounts([String? userId]) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      final response = await _client
          .from('accounts')
          .select()
          .eq('user_id', currentUserId!);

      return (response as List)
          .map((json) => Account.fromSupabase(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get a single account by ID
  Future<Account?> getAccount(String id) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      final response = await _client
          .from('accounts')
          .select()
          .eq('id', id)
          .eq('user_id', currentUserId!)
          .single();

      return Account.fromSupabase(response);
    } catch (e) {
      return null;
    }
  }

  /// Insert a new account
  Future<Account> insertAccount(Account account) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      final response = await _client
          .from('accounts')
          .insert({
            'user_id': currentUserId!,
            'name': account.name,
            'alias': account.alias,
            'account_type': account.type.name,
            'account_purpose': account.accountPurpose.name,
            'currency': account.currency,
            'initial_balance': account.initialBalance,
            'current_balance': account.currentBalance,
            'is_default': account.isDefault,
            'is_deletable': account.isDeletable,
          })
          .select()
          .single();

      return Account.fromSupabase(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing account
  Future<void> updateAccount(Account account) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      await _client
          .from('accounts')
          .update({
            'name': account.name,
            'alias': account.alias,
            'account_type': account.type.name,
            'account_purpose': account.accountPurpose.name,
            'currency': account.currency,
            'initial_balance': account.initialBalance,
            'current_balance': account.currentBalance,
            'is_default': account.isDefault,
            'is_deletable': account.isDeletable,
          })
          .eq('id', account.id)
          .eq('user_id', currentUserId!);
    } catch (e) {
      rethrow;
    }
  }

  /// Delete an account
  Future<void> deleteAccount(String id) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      await _client
          .from('accounts')
          .delete()
          .eq('id', id)
          .eq('user_id', currentUserId!);
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // BALANCE CALCULATIONS (using SQL functions)
  // ============================================

  /// Get calculated balance for a specific account using SQL function
  Future<double> getAccountBalance(String accountId) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      final response = await _client
          .rpc('get_account_balance', params: {'p_account_id': accountId});

      return (response as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// Get total available balance (only accounts with purpose='available')
  Future<double> getAvailableBalance(String? userId, [String? currency]) async {
    final uid = userId ?? currentUserId;
    if (uid == null) throw Exception('User not authenticated');

    try {
      final response = await _client.rpc('get_available_balance', params: {
        'p_user_id': uid,
        'p_currency': currency,
      });

      return (response as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// Get total savings balance (only accounts with purpose='savings')
  Future<double> getSavingsBalance(String? userId, [String? currency]) async {
    final uid = userId ?? currentUserId;
    if (uid == null) throw Exception('User not authenticated');

    try {
      final response = await _client.rpc('get_savings_balance', params: {
        'p_user_id': uid,
        'p_currency': currency,
      });

      return (response as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// Get accounts with calculated balances from view
  Future<List<Account>> getAccountsWithCalculatedBalances([String? userId]) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      final response = await _client
          .from('account_balances')
          .select()
          .eq('user_id', currentUserId!);

      return (response as List)
          .map((json) => Account.fromSupabase(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // CREDIT CARDS
  // ============================================

  /// Get all credit cards for the current user
  /// [userId] parameter is optional for backward compatibility (ignored)
  Future<List<CreditCard>> getCreditCards([String? userId]) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      final response = await _client
          .from('credit_cards')
          .select()
          .eq('user_id', currentUserId!);

      return (response as List)
          .map((json) => CreditCard.fromSupabase(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Insert a new credit card
  Future<CreditCard> insertCreditCard(CreditCard card) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      final response = await _client
          .from('credit_cards')
          .insert({
            'user_id': currentUserId!,
            'name': card.name,
            'alias': card.alias,
            'credit_limit': card.creditLimit,
            'closing_day': card.closingDay,
            'current_balance': card.currentBalance,
          })
          .select()
          .single();

      return CreditCard.fromSupabase(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing credit card
  Future<void> updateCreditCard(CreditCard card) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      await _client
          .from('credit_cards')
          .update({
            'name': card.name,
            'alias': card.alias,
            'credit_limit': card.creditLimit,
            'closing_day': card.closingDay,
            'current_balance': card.currentBalance,
          })
          .eq('id', card.id)
          .eq('user_id', currentUserId!);
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a credit card
  Future<void> deleteCreditCard(String id) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      await _client
          .from('credit_cards')
          .delete()
          .eq('id', id)
          .eq('user_id', currentUserId!);
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // LEGACY/COMPATIBILITY METHODS
  // ============================================

  /// Legacy method - not needed in Supabase (auth handles user creation)
  Future<int> getOrCreateOldUserId(String firebaseUid) async {
    return 0; // Not used in Supabase
  }

  /// Legacy method - clears other default accounts
  Future<void> clearOtherDefaultAccounts(String excludeAccountId) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      final accounts = await getAccounts();
      for (var account in accounts) {
        if (account.id != excludeAccountId && account.isDefault) {
          await updateAccount(account.copyWith(isDefault: false));
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Legacy method - finds old account by name (SQLite compatibility)
  Future<dynamic> findOldAccountByName(String name, String userId) async {
    return null; // Not used in Supabase
  }

  /// Legacy method - update cuenta (old model)
  Future<void> updateCuenta(dynamic cuenta) async {
    // Not implemented - use updateAccount instead
    throw UnimplementedError('Use updateAccount instead');
  }

  /// Legacy method - insert cuenta (old model)
  Future<void> insertCuenta(dynamic cuenta) async {
    // Not implemented - use insertAccount instead
    throw UnimplementedError('Use insertAccount instead');
  }

  /// Insert transaction (backward compatible name)
  Future<void> insertNewTransaction(new_tx.Transaction transaction) async {
    await insertTransaction(transaction);
  }

  /// Update fixed expense (backward compatible name)
  Future<void> updateFixedExpenseNew(FixedExpense expense) async {
    await updateFixedExpense(expense);
  }

  /// Insert fixed expense (backward compatible name)
  Future<void> insertFixedExpenseNew(FixedExpense expense) async {
    await insertFixedExpense(expense);
  }

  /// Get gastos fijos (legacy Spanish name)
  Future<List<FixedExpense>> getGastosFijos(String userId) async {
    return await getFixedExpenses();
  }

  /// Update gasto fijo (legacy Spanish name)
  Future<void> updateGastoFijo(FixedExpense expense) async {
    await updateFixedExpense(expense);
  }

  /// Delete gasto fijo (legacy Spanish name)
  Future<void> deleteGastoFijo(String id) async {
    await deleteFixedExpense(id);
  }

  /// Legacy methods - not implemented in Supabase version
  Future<List<dynamic>> getMovimientos(String userId) async {
    return []; // Not implemented
  }

  Future<List<dynamic>> getGastos(String userId) async {
    return []; // Not implemented
  }

  Future<List<dynamic>> getContactos(String userId) async {
    return []; // Not implemented
  }

  Future<void> exportAllTablesToCsv(String userId) async {
    throw UnimplementedError('CSV export not yet implemented for Supabase');
  }

  Future<void> insertContacto(dynamic contact) async {
    throw UnimplementedError('Contactos not yet implemented for Supabase');
  }

  Future<List<dynamic>> getAllUsuarios() async {
    return []; // Not implemented - user management handled by Supabase Auth
  }

  Future<List<dynamic>> getConceptos([String? userId]) async {
    return []; // Not implemented
  }

  Future<dynamic> getUsuarioByEmail(String email) async {
    return null; // Not implemented - user management handled by Supabase Auth
  }

  Future<void> updateUsuario(dynamic user) async {
    throw UnimplementedError('Not implemented - user management handled by Supabase Auth');
  }

  Future<void> createInitialUser(String email, String name) async {
    // Not needed - Supabase Auth handles user creation
  }

  Future<List<dynamic>> getCuentas(String userId) async {
    return await getAccounts();
  }

  Future<List<dynamic>> getCategorias(String userId) async {
    return await getCategories();
  }

  Future<void> insertCategoria(dynamic categoria) async {
    throw UnimplementedError('Use insertCategory instead');
  }

  Future<void> insertGastoFijo(dynamic gastoFijo) async {
    throw UnimplementedError('Use insertFixedExpense instead');
  }

  Future<void> insertTransaccion(dynamic transaccion) async {
    throw UnimplementedError('Use insertTransaction instead');
  }

  Future<List<dynamic>> getTiposMovimiento() async {
    return []; // Not implemented
  }

  Future<List<dynamic>> getPeriodicidades() async {
    return []; // Not implemented
  }

  Future<List<dynamic>> getOperaciones() async {
    return []; // Not implemented
  }

  // ============================================
  // CATEGORIES
  // ============================================

  /// Get all categories for the current user
  Future<List<Categoria>> getCategories() async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      final response = await _client
          .from('categories')
          .select()
          .eq('user_id', currentUserId!);

      return (response as List)
          .map((json) => Categoria.fromSupabase(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get categories by type (income/expense)
  Future<List<Categoria>> getCategoriesByType(String type) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      // Convert Spanish to English type names
      final categoryType = type == 'ingreso' ? 'income' : 'expense';

      final response = await _client
          .from('categories')
          .select()
          .eq('user_id', currentUserId!)
          .eq('category_type', categoryType);

      return (response as List)
          .map((json) => Categoria.fromSupabase(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Insert a new category
  Future<Categoria> insertCategory(Categoria category) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      final response = await _client
          .from('categories')
          .insert({
            'user_id': currentUserId!,
            'name': category.nombre,
            'category_type': category.tipo.name == 'ingreso' ? 'income' : 'expense',
            'icon': category.icono,
            'color': category.colorHex,
            'parent_id': category.padreId,
          })
          .select()
          .single();

      return Categoria.fromSupabase(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing category
  Future<void> updateCategory(Categoria category) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      await _client
          .from('categories')
          .update({
            'name': category.nombre,
            'category_type': category.tipo.name == 'ingreso' ? 'income' : 'expense',
            'icon': category.icono,
            'color': category.colorHex,
            'parent_id': category.padreId,
          })
          .eq('id', category.idCategoria.toString())
          .eq('user_id', currentUserId!);
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a category
  Future<void> deleteCategory(String id) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      await _client
          .from('categories')
          .delete()
          .eq('id', id)
          .eq('user_id', currentUserId!);
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // TRANSACTIONS
  // ============================================

  /// Get all transactions for the current user (backward compatible signature)
  Future<List<new_tx.Transaction>> getTransactions({
    String? userId,
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      var query = _client
          .from('transactions')
          .select()
          .eq('user_id', currentUserId!)
          .order('transaction_date', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;
      var transactions = (response as List)
          .map((json) => new_tx.Transaction.fromSupabase(json))
          .toList();

      // Apply date filters in-memory if needed
      final effectiveStartDate = startDate ?? fromDate;
      final effectiveEndDate = endDate ?? toDate;

      if (effectiveStartDate != null) {
        transactions = transactions.where((t) => t.date.isAfter(effectiveStartDate) || t.date.isAtSameMomentAs(effectiveStartDate)).toList();
      }
      if (effectiveEndDate != null) {
        transactions = transactions.where((t) => t.date.isBefore(effectiveEndDate) || t.date.isAtSameMomentAs(effectiveEndDate)).toList();
      }

      return transactions;
    } catch (e) {
      rethrow;
    }
  }

  /// Get transactions by account
  Future<List<new_tx.Transaction>> getTransactionsByAccount(String accountId) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('user_id', currentUserId!)
          .eq('account_id', accountId)
          .order('transaction_date', ascending: false);

      return (response as List)
          .map((json) => new_tx.Transaction.fromSupabase(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get transactions for a specific account (backward compatible signature)
  Future<List<new_tx.Transaction>> getTransactionsForAccount({
    required String userId,
    required String accountId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      var transactions = await getTransactionsByAccount(accountId);

      // Filter by date if needed
      if (fromDate != null) {
        transactions = transactions.where((t) => t.date.isAfter(fromDate) || t.date.isAtSameMomentAs(fromDate)).toList();
      }
      if (toDate != null) {
        transactions = transactions.where((t) => t.date.isBefore(toDate) || t.date.isAtSameMomentAs(toDate)).toList();
      }

      return transactions;
    } catch (e) {
      rethrow;
    }
  }

  /// Get top transaction descriptions by frequency
  /// Used for autocomplete suggestions
  Future<List<String>> getTopTransactionDescriptions(
    String userId,
    dynamic tipo, {
    int limit = 5,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      // Get all transactions
      final allTransactions = await getTransactions();

      // Filter by type (supports both TipoTransaccion enum and TransactionType)
      String typeFilter;
      if (tipo.toString().contains('ingreso') || tipo.toString().contains('income')) {
        typeFilter = 'income';
      } else {
        typeFilter = 'expense';
      }

      final filtered = allTransactions.where((t) {
        final matchesType = (typeFilter == 'income' && t.type == new_tx.TransactionType.income) ||
                           (typeFilter == 'expense' && t.type == new_tx.TransactionType.expense);
        final hasDescription = t.description != null && t.description!.isNotEmpty;
        return matchesType && hasDescription;
      }).toList();

      // Count frequency of each description
      final Map<String, int> descriptionFrequency = {};
      for (var tx in filtered) {
        final desc = tx.description!;
        descriptionFrequency[desc] = (descriptionFrequency[desc] ?? 0) + 1;
      }

      // Sort by frequency and get top N
      final sorted = descriptionFrequency.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sorted.take(limit).map((e) => e.key).toList();
    } catch (e) {
      return [];
    }
  }

  /// Insert a new transaction
  Future<new_tx.Transaction> insertTransaction(new_tx.Transaction transaction) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      // Insert the transaction with transaction_type_id
      final response = await _client
          .from('transactions')
          .insert({
            'user_id': currentUserId!,
            'account_id': transaction.accountId,
            'category_id': transaction.category,
            'transaction_type_id': transaction.transactionTypeId,
            'amount': transaction.amount,
            'description': transaction.description,
            'transaction_date': transaction.date.toIso8601String(),
            'notes': transaction.description,
            'destination_account_id': transaction.destinationAccountId,
          })
          .select()
          .single();

      // Balance is automatically calculated by SQL functions - no manual update needed

      return new_tx.Transaction.fromSupabase(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing transaction
  Future<void> updateTransaction(new_tx.Transaction transaction) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      // Update the transaction with transaction_type_id
      await _client
          .from('transactions')
          .update({
            'account_id': transaction.accountId,
            'category_id': transaction.category,
            'transaction_type_id': transaction.transactionTypeId,
            'amount': transaction.amount,
            'description': transaction.description,
            'transaction_date': transaction.date.toIso8601String(),
            'notes': transaction.description,
            'destination_account_id': transaction.destinationAccountId,
          })
          .eq('id', transaction.id)
          .eq('user_id', currentUserId!);

      // Balance is automatically recalculated by SQL functions - no manual update needed
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a transaction
  Future<void> deleteTransaction(String id) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      // Simply delete the transaction
      await _client
          .from('transactions')
          .delete()
          .eq('id', id)
          .eq('user_id', currentUserId!);

      // Balance is automatically recalculated by SQL functions - no manual update needed
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // FIXED EXPENSES
  // ============================================

  /// Get all fixed expenses for the current user
  Future<List<FixedExpense>> getFixedExpenses({bool? activeOnly}) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      var query = _client
          .from('fixed_expenses')
          .select()
          .eq('user_id', currentUserId!);

      if (activeOnly == true) {
        query = query.eq('is_active', true);
      }

      final response = await query;

      return (response as List)
          .map((json) => FixedExpense.fromSupabase(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Insert a new fixed expense
  Future<FixedExpense> insertFixedExpense(FixedExpense expense) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      // Check if category is a valid UUID, otherwise send null
      String? categoryId;
      if (expense.category.isNotEmpty) {
        // Simple UUID regex check
        final uuidPattern = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
          caseSensitive: false,
        );
        if (uuidPattern.hasMatch(expense.category)) {
          categoryId = expense.category;
        }
      }

      final response = await _client
          .from('fixed_expenses')
          .insert({
            'user_id': currentUserId!,
            'account_id': expense.accountId,
            'category_id': categoryId, // null if not a valid UUID
            'name': expense.name,
            'amount': expense.amount,
            'frequency': expense.frequency.name,
            'start_date': expense.createdAt.toIso8601String().split('T')[0],
            'end_date': null,
            // Only set day_of_week for weekly expenses
            'day_of_week': expense.frequency == ExpenseFrequency.weekly
                ? expense.dayOfWeek
                : null,
            // Only set day_of_month for monthly/bimonthly expenses
            'day_of_month': (expense.frequency == ExpenseFrequency.monthly ||
                    expense.frequency == ExpenseFrequency.bimonthly)
                ? expense.dayOfMonth
                : null,
            // Only set due_date for one-time expenses
            'due_date': expense.frequency == ExpenseFrequency.oneTime
                ? expense.dueDate?.toIso8601String().split('T')[0]
                : null,
            'is_active': expense.isActive,
          })
          .select()
          .single();

      return FixedExpense.fromSupabase(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing fixed expense
  Future<void> updateFixedExpense(FixedExpense expense) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      // Check if category is a valid UUID, otherwise send null
      String? categoryId;
      if (expense.category.isNotEmpty) {
        final uuidPattern = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
          caseSensitive: false,
        );
        if (uuidPattern.hasMatch(expense.category)) {
          categoryId = expense.category;
        }
      }

      await _client
          .from('fixed_expenses')
          .update({
            'account_id': expense.accountId,
            'category_id': categoryId, // null if not a valid UUID
            'name': expense.name,
            'amount': expense.amount,
            'frequency': expense.frequency.name,
            'start_date': expense.createdAt.toIso8601String().split('T')[0],
            'end_date': null,
            // Only set day_of_week for weekly expenses
            'day_of_week': expense.frequency == ExpenseFrequency.weekly
                ? expense.dayOfWeek
                : null,
            // Only set day_of_month for monthly/bimonthly expenses
            'day_of_month': (expense.frequency == ExpenseFrequency.monthly ||
                    expense.frequency == ExpenseFrequency.bimonthly)
                ? expense.dayOfMonth
                : null,
            // Only set due_date for one-time expenses
            'due_date': expense.frequency == ExpenseFrequency.oneTime
                ? expense.dueDate?.toIso8601String().split('T')[0]
                : null,
            'is_active': expense.isActive,
          })
          .eq('id', expense.id)
          .eq('user_id', currentUserId!);
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a fixed expense
  Future<void> deleteFixedExpense(String id) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      await _client
          .from('fixed_expenses')
          .delete()
          .eq('id', id)
          .eq('user_id', currentUserId!);
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Calculate total balance across all accounts
  Future<double> getTotalBalance() async {
    final accounts = await getAccounts();
    return accounts.fold<double>(0.0, (sum, account) => sum + account.currentBalance);
  }

  /// Get monthly income total
  Future<double> getMonthlyIncome(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final transactions = await getTransactions(
      startDate: startOfMonth,
      endDate: endOfMonth,
    );

    return transactions
        .where((t) => t.type == new_tx.TransactionType.income)
        .fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  /// Get monthly expenses total
  Future<double> getMonthlyExpenses(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final transactions = await getTransactions(
      startDate: startOfMonth,
      endDate: endOfMonth,
    );

    return transactions
        .where((t) => t.type == new_tx.TransactionType.expense)
        .fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  // ============================================================================
  // SKIPPED PAYMENTS METHODS
  // ============================================================================

  /// Skip a fixed expense payment for a specific date
  Future<SkippedPayment> skipPayment({
    required String fixedExpenseId,
    required DateTime date,
    String? reason,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      final response = await _client
          .from('skipped_payments')
          .insert({
            'user_id': currentUserId!,
            'fixed_expense_id': fixedExpenseId,
            'skipped_date': date.toIso8601String().split('T')[0],
            'reason': reason,
          })
          .select()
          .single();

      return SkippedPayment.fromSupabase(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Unskip a payment (remove from skipped list)
  Future<void> unskipPayment({
    required String fixedExpenseId,
    required DateTime date,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      await _client
          .from('skipped_payments')
          .delete()
          .eq('fixed_expense_id', fixedExpenseId)
          .eq('skipped_date', date.toIso8601String().split('T')[0])
          .eq('user_id', currentUserId!);
    } catch (e) {
      rethrow;
    }
  }

  /// Check if a payment is skipped for a specific date
  Future<bool> isPaymentSkipped({
    required String fixedExpenseId,
    required DateTime date,
  }) async {
    if (currentUserId == null) return false;

    try {
      final response = await _client
          .from('skipped_payments')
          .select('id')
          .eq('fixed_expense_id', fixedExpenseId)
          .eq('skipped_date', date.toIso8601String().split('T')[0])
          .eq('user_id', currentUserId!)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Get all skipped payments for a fixed expense
  Future<List<SkippedPayment>> getSkippedPayments({
    String? fixedExpenseId,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      dynamic query = _client
          .from('skipped_payments')
          .select()
          .eq('user_id', currentUserId!);

      if (fixedExpenseId != null) {
        query = query.eq('fixed_expense_id', fixedExpenseId);
      }

      final response = await query.order('skipped_date', ascending: false);

      return (response as List)
          .map((json) => SkippedPayment.fromSupabase(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}
