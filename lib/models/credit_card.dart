class CreditCard {
  final String id;
  final String userId;
  final String name;
  final String? alias;
  final double creditLimit;
  final int closingDay; // Day of month (1-31) for statement closing
  final double currentBalance;
  final double availableCredit;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  CreditCard({
    required this.id,
    required this.userId,
    required this.name,
    this.alias,
    required this.creditLimit,
    required this.closingDay,
    required this.currentBalance,
    required this.availableCredit,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  CreditCard copyWith({
    String? id,
    String? userId,
    String? name,
    String? alias,
    double? creditLimit,
    int? closingDay,
    double? currentBalance,
    double? availableCredit,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CreditCard(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      alias: alias ?? this.alias,
      creditLimit: creditLimit ?? this.creditLimit,
      closingDay: closingDay ?? this.closingDay,
      currentBalance: currentBalance ?? this.currentBalance,
      availableCredit: availableCredit ?? this.availableCredit,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'alias': alias,
      'creditLimit': creditLimit,
      'closingDay': closingDay,
      'currentBalance': currentBalance,
      'availableCredit': availableCredit,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CreditCard.fromMap(Map<String, dynamic> map) {
    return CreditCard(
      id: map['id'],
      userId: map['userId'],
      name: map['name'],
      alias: map['alias'],
      creditLimit: map['creditLimit']?.toDouble() ?? 0.0,
      closingDay: map['closingDay']?.toInt() ?? 1,
      currentBalance: map['currentBalance']?.toDouble() ?? 0.0,
      availableCredit: map['availableCredit']?.toDouble() ?? 0.0,
      isActive: map['isActive'] == 1,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  // Helper method to get next closing date
  DateTime getNextClosingDate() {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    // If closing day has passed this month, get next month
    final closingThisMonth = DateTime(currentYear, currentMonth, closingDay);
    if (now.isAfter(closingThisMonth) ||
        now.isAtSameMomentAs(closingThisMonth)) {
      // Get next month
      final nextMonth = currentMonth == 12 ? 1 : currentMonth + 1;
      final nextYear = currentMonth == 12 ? currentYear + 1 : currentYear;
      return DateTime(nextYear, nextMonth, closingDay);
    } else {
      return closingThisMonth;
    }
  }

  // Helper method to get current billing period
  (DateTime start, DateTime end) getCurrentBillingPeriod() {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    // Previous closing date
    final previousClosing = DateTime(currentYear, currentMonth, closingDay - 1);
    final startDate = DateTime(
      previousClosing.year,
      previousClosing.month,
      closingDay + 1,
    );

    // Current closing date
    final endDate = DateTime(currentYear, currentMonth, closingDay);

    return (startDate, endDate);
  }
}
