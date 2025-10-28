import '../models/user.dart';
import '../models/user_plan.dart';

class FeatureLimiter {
  // Flag to enable/disable limitations - set to false for now
  static const bool _enableLimitations = false;

  // Check if user can access a specific feature
  static bool canAccessFeature(User user, String feature) {
    // If limitations are disabled, allow everything
    if (!_enableLimitations) {
      return true;
    }

    switch (feature) {
      case 'multiple_accounts':
        return _canHaveMultipleAccounts(user.userPlan);
      case 'fixed_expenses':
        return _canHaveFixedExpenses(user.userPlan);
      case 'advanced_reports':
        return _canAccessAdvancedReports(user.userPlan);
      case 'export_data':
        return _canExportData(user.userPlan);
      case 'custom_categories':
        return _canUseCustomCategories(user.userPlan);
      case 'multiple_budgets':
        return _canHaveMultipleBudgets(user.userPlan);
      case 'alerts':
        return _canUseAlerts(user.userPlan);
      case 'priority_support':
        return _canAccessPrioritySupport(user.userPlan);
      case 'no_ads':
        return _canHaveNoAds(user.userPlan);
      default:
        return true;
    }
  }

  // Get feature limits for a user plan
  static Map<String, dynamic> getFeatureLimits(UserPlan plan) {
    return {
      'maxAccounts': _getMaxAccounts(plan),
      'maxFixedExpenses': _getMaxFixedExpenses(plan),
      'hasAdvancedReports': _hasAdvancedReports(plan),
      'hasExportFeatures': _hasExportFeatures(plan),
      'hasCustomCategories': _hasCustomCategories(plan),
      'hasMultipleBudgets': _hasMultipleBudgets(plan),
      'hasAlerts': _hasAlerts(plan),
      'hasPrioritySupport': _hasPrioritySupport(plan),
      'hasNoAds': _hasNoAds(plan),
    };
  }

  // Private methods for each feature check
  static bool _canHaveMultipleAccounts(UserPlan plan) {
    switch (plan) {
      case UserPlan.guest:
        return false;
      case UserPlan.free:
        return true; // Limited to 3
      case UserPlan.premium:
        return true; // Unlimited
    }
  }

  static bool _canHaveFixedExpenses(UserPlan plan) {
    switch (plan) {
      case UserPlan.guest:
        return false;
      case UserPlan.free:
        return true; // Limited to 5
      case UserPlan.premium:
        return true; // Unlimited
    }
  }

  static bool _canAccessAdvancedReports(UserPlan plan) {
    return plan == UserPlan.premium;
  }

  static bool _canExportData(UserPlan plan) {
    return plan == UserPlan.premium;
  }

  static bool _canUseCustomCategories(UserPlan plan) {
    return plan == UserPlan.premium;
  }

  static bool _canHaveMultipleBudgets(UserPlan plan) {
    return plan == UserPlan.premium;
  }

  static bool _canUseAlerts(UserPlan plan) {
    return plan == UserPlan.premium;
  }

  static bool _canAccessPrioritySupport(UserPlan plan) {
    return plan == UserPlan.premium;
  }

  static bool _canHaveNoAds(UserPlan plan) {
    return plan == UserPlan.premium;
  }

  // Get numerical limits
  static int _getMaxAccounts(UserPlan plan) {
    switch (plan) {
      case UserPlan.guest:
        return 0;
      case UserPlan.free:
        return 3;
      case UserPlan.premium:
        return -1; // Unlimited
    }
  }

  static int _getMaxFixedExpenses(UserPlan plan) {
    switch (plan) {
      case UserPlan.guest:
        return 0;
      case UserPlan.free:
        return 5;
      case UserPlan.premium:
        return -1; // Unlimited
    }
  }

  static bool _hasAdvancedReports(UserPlan plan) => plan == UserPlan.premium;
  static bool _hasExportFeatures(UserPlan plan) => plan == UserPlan.premium;
  static bool _hasCustomCategories(UserPlan plan) => plan == UserPlan.premium;
  static bool _hasMultipleBudgets(UserPlan plan) => plan == UserPlan.premium;
  static bool _hasAlerts(UserPlan plan) => plan == UserPlan.premium;
  static bool _hasPrioritySupport(UserPlan plan) => plan == UserPlan.premium;
  static bool _hasNoAds(UserPlan plan) => plan == UserPlan.premium;

  // Enable limitations when ready
  static void enableLimitations() {
    // This would be called when you want to start enforcing limits
    print('Feature limitations enabled');
  }

  // Check current limitation status
  static bool get areLimitationsEnabled => _enableLimitations;
}
