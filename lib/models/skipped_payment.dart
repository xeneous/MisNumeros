class SkippedPayment {
  final String id;
  final String userId;
  final String fixedExpenseId;
  final DateTime skippedDate;
  final String? reason;
  final DateTime createdAt;

  const SkippedPayment({
    required this.id,
    required this.userId,
    required this.fixedExpenseId,
    required this.skippedDate,
    this.reason,
    required this.createdAt,
  });

  SkippedPayment copyWith({
    String? id,
    String? userId,
    String? fixedExpenseId,
    DateTime? skippedDate,
    String? reason,
    DateTime? createdAt,
  }) {
    return SkippedPayment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fixedExpenseId: fixedExpenseId ?? this.fixedExpenseId,
      skippedDate: skippedDate ?? this.skippedDate,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'fixed_expense_id': fixedExpenseId,
      'skipped_date': skippedDate.toIso8601String().split('T')[0],
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SkippedPayment.fromSupabase(Map<String, dynamic> map) {
    return SkippedPayment(
      id: map['id'],
      userId: map['user_id'],
      fixedExpenseId: map['fixed_expense_id'],
      skippedDate: DateTime.parse(map['skipped_date']),
      reason: map['reason'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
