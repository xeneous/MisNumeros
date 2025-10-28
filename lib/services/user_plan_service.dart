import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_plan.dart';

class UserPlanService {
  static const String _userPlanKey = 'user_plan';
  static const String _accountsCountKey = 'accounts_count';
  static const String _fixedExpensesCountKey = 'fixed_expenses_count';

  // Get user's current plan
  Future<UserPlan> getUserPlan(String userId) async {
    // Try to get from Firestore first with timeout
    try {
      final firestore = FirebaseFirestore.instance;
      final userDoc = await firestore
          .collection('users')
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 3));

      if (userDoc.exists) {
        final data = userDoc.data()!;
        final planName = data['userPlan'] ?? 'free';
        return UserPlan.values.firstWhere(
          (plan) => plan.name == planName,
          orElse: () => UserPlan.free,
        );
      }
    } catch (e) {
      print('Firestore not available for plan check: $e');
    }

    // Fallback to local storage
    final prefs = await SharedPreferences.getInstance();
    final planName = prefs.getString('${userId}_$_userPlanKey');

    if (planName != null) {
      try {
        return UserPlan.values.firstWhere(
          (plan) => plan.name == planName,
          orElse: () => UserPlan.free,
        );
      } catch (e) {
        return UserPlan.free;
      }
    }

    return UserPlan.free; // Default to free plan
  }

  // Update user's plan
  Future<void> updateUserPlan(String userId, UserPlan newPlan) async {
    // Always save locally first
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${userId}_$_userPlanKey', newPlan.name);

    // Try to update in Firestore with timeout
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('users')
          .doc(userId)
          .update({
            'userPlan': newPlan.name,
            'updatedAt': DateTime.now().toIso8601String(),
          })
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      print('Could not update plan in Firestore: $e');
      // Continue silently - local storage is updated
    }
  }

  // Check if user can add more accounts
  Future<bool> canAddAccount(String userId) async {
    final plan = await getUserPlan(userId);
    final currentCount = await getAccountsCount(userId);

    switch (plan) {
      case UserPlan.guest:
        return false; // Guests can't add accounts
      case UserPlan.free:
        return currentCount < 3; // Max 3 accounts for free users
      case UserPlan.premium:
        return true; // Unlimited accounts for premium users
    }
  }

  // Check if user can add more fixed expenses
  Future<bool> canAddFixedExpense(String userId) async {
    final plan = await getUserPlan(userId);
    final currentCount = await getFixedExpensesCount(userId);

    switch (plan) {
      case UserPlan.guest:
        return false; // Guests can't add fixed expenses
      case UserPlan.free:
        return currentCount < 5; // Max 5 fixed expenses for free users
      case UserPlan.premium:
        return true; // Unlimited fixed expenses for premium users
    }
  }

  // Increment accounts count
  Future<void> incrementAccountsCount(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = await getAccountsCount(userId);
    await prefs.setInt('${userId}_$_accountsCountKey', currentCount + 1);
  }

  // Decrement accounts count
  Future<void> decrementAccountsCount(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = await getAccountsCount(userId);
    if (currentCount > 0) {
      await prefs.setInt('${userId}_$_accountsCountKey', currentCount - 1);
    }
  }

  // Increment fixed expenses count
  Future<void> incrementFixedExpensesCount(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = await getFixedExpensesCount(userId);
    await prefs.setInt('${userId}_$_fixedExpensesCountKey', currentCount + 1);
  }

  // Decrement fixed expenses count
  Future<void> decrementFixedExpensesCount(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = await getFixedExpensesCount(userId);
    if (currentCount > 0) {
      await prefs.setInt('${userId}_$_fixedExpensesCountKey', currentCount - 1);
    }
  }

  // Get current accounts count
  Future<int> getAccountsCount(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('${userId}_$_accountsCountKey') ?? 0;
  }

  // Get current fixed expenses count
  Future<int> getFixedExpensesCount(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('${userId}_$_fixedExpensesCountKey') ?? 0;
  }

  // Reset counts (useful when upgrading/downgrading plans)
  Future<void> resetCounts(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${userId}_$_accountsCountKey');
    await prefs.remove('${userId}_$_fixedExpensesCountKey');
  }

  // Get plan limits info
  Map<String, dynamic> getPlanLimits(UserPlan plan) {
    return {
      'maxAccounts': plan == UserPlan.premium
          ? -1
          : (plan == UserPlan.free ? 3 : 0),
      'maxFixedExpenses': plan == UserPlan.premium
          ? -1
          : (plan == UserPlan.free ? 5 : 0),
      'hasAdvancedReports': plan == UserPlan.premium,
      'hasExportFeatures': plan == UserPlan.premium,
      'hasCustomCategories': plan == UserPlan.premium,
      'hasMultipleBudgets': plan == UserPlan.premium,
      'hasAlerts': plan == UserPlan.premium,
      'hasPrioritySupport': plan == UserPlan.premium,
      'hasNoAds': plan == UserPlan.premium,
    };
  }

  // Check if user has access to a specific feature
  Future<bool> hasFeatureAccess(String userId, String feature) async {
    final plan = await getUserPlan(userId);

    switch (feature) {
      case 'accounts':
        return plan != UserPlan.guest;
      case 'fixed_expenses':
        return plan != UserPlan.guest;
      case 'advanced_reports':
        return plan == UserPlan.premium;
      case 'export_data':
        return plan == UserPlan.premium;
      case 'custom_categories':
        return plan == UserPlan.premium;
      case 'multiple_budgets':
        return plan == UserPlan.premium;
      case 'alerts':
        return plan == UserPlan.premium;
      case 'priority_support':
        return plan == UserPlan.premium;
      case 'no_ads':
        return plan == UserPlan.premium;
      default:
        return false;
    }
  }
}
