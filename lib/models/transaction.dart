enum TransactionType {
  income('Ingreso'),
  expense('Egreso');

  const TransactionType(this.displayName);
  final String displayName;
}

enum TransactionStatus {
  pending('Pendiente'),
  completed('Completado'),
  cancelled('Cancelado');

  const TransactionStatus(this.displayName);
  final String displayName;
}

class Transaction {
  final String id;
  final String userId;
  final TransactionType type;
  final double amount;
  final String? description;
  final String? category;
  final DateTime date;
  final TransactionStatus status;

  // Source/Destination
  final String? accountId; // For cash/debit accounts
  final String? creditCardId; // For credit card transactions

  // Credit card specific fields
  final int? installments; // Number of installments (cuotas)
  final double? totalAmount; // Total amount including interest
  final double? interestAmount; // Interest amount
  final int? currentInstallment; // Current installment being paid

  // Shared expense fields
  final bool isSharedExpense;
  final List<String>? participants; // User IDs of participants
  final Map<String, double>? participantAmounts; // Amount per participant

  final DateTime createdAt;
  final DateTime updatedAt;

  Transaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    this.description,
    this.category,
    required this.date,
    this.status = TransactionStatus.completed,
    this.accountId,
    this.creditCardId,
    this.installments,
    this.totalAmount,
    this.interestAmount,
    this.currentInstallment,
    this.isSharedExpense = false,
    this.participants,
    this.participantAmounts,
    required this.createdAt,
    required this.updatedAt,
  });

  Transaction copyWith({
    String? id,
    String? userId,
    TransactionType? type,
    double? amount,
    String? description,
    String? category,
    DateTime? date,
    TransactionStatus? status,
    String? accountId,
    String? creditCardId,
    int? installments,
    double? totalAmount,
    double? interestAmount,
    int? currentInstallment,
    bool? isSharedExpense,
    List<String>? participants,
    Map<String, double>? participantAmounts,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      category: category ?? this.category,
      date: date ?? this.date,
      status: status ?? this.status,
      accountId: accountId ?? this.accountId,
      creditCardId: creditCardId ?? this.creditCardId,
      installments: installments ?? this.installments,
      totalAmount: totalAmount ?? this.totalAmount,
      interestAmount: interestAmount ?? this.interestAmount,
      currentInstallment: currentInstallment ?? this.currentInstallment,
      isSharedExpense: isSharedExpense ?? this.isSharedExpense,
      participants: participants ?? this.participants,
      participantAmounts: participantAmounts ?? this.participantAmounts,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type.name,
      'amount': amount,
      'description': description,
      'category': category,
      'date': date.toIso8601String(),
      'status': status.name,
      'accountId': accountId,
      'creditCardId': creditCardId,
      'installments': installments,
      'totalAmount': totalAmount,
      'interestAmount': interestAmount,
      'currentInstallment': currentInstallment,
      'isSharedExpense': isSharedExpense ? 1 : 0,
      'participants': participants?.join(
        ',',
      ), // Store as comma-separated string
      'participantAmounts': participantAmounts?.map(
        (k, v) => MapEntry(k, v.toString()),
      ),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      userId: map['userId'],
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.expense,
      ),
      amount: map['amount']?.toDouble() ?? 0.0,
      description: map['description'],
      category: map['category'],
      date: DateTime.parse(map['date']),
      status: TransactionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TransactionStatus.completed,
      ),
      accountId: map['accountId'],
      creditCardId: map['creditCardId'],
      installments: map['installments']?.toInt(),
      totalAmount: map['totalAmount']?.toDouble(),
      interestAmount: map['interestAmount']?.toDouble(),
      currentInstallment: map['currentInstallment']?.toInt(),
      isSharedExpense: map['isSharedExpense'] == 1,
      participants: map['participants']
          ?.toString()
          .split(',')
          .where((s) => s.isNotEmpty)
          .toList(),
      participantAmounts: map['participantAmounts'] != null
          ? Map<String, double>.from(
              map['participantAmounts'].map(
                (k, v) => MapEntry(k, double.parse(v.toString())),
              ),
            )
          : null,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  // Helper method to calculate installment amount
  double getInstallmentAmount() {
    if (installments == null || installments! <= 1) return amount;
    return (totalAmount ?? amount) / installments!;
  }

  // Helper method to get personal share for shared expenses
  double getPersonalShare(String userId) {
    if (!isSharedExpense || participantAmounts == null) return amount;
    return participantAmounts![userId] ?? amount;
  }
}
