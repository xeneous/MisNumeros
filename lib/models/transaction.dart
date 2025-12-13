import 'transaction_type.dart' as tx_type;

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

  // New field: transaction_type_id (replaces type string)
  final int transactionTypeId;

  // Legacy field for backward compatibility
  final TransactionType type;

  final double amount;
  final String? description;
  final String? category;

  String? get categoryId => category;
  String? get notes => description;
  final DateTime date;
  final TransactionStatus status;

  // Source/Destination
  final String? accountId; // For cash/debit accounts
  final String? creditCardId; // For credit card transactions
  final String? destinationAccountId; // For transfers

  // Credit card specific fields
  final int? installments; // Number of installments (cuotas)
  final double? totalAmount; // Total amount including interest
  final double? interestAmount; // Interest amount
  final int? currentInstallment; // Current installment being paid

  // Shared expense fields
  final bool isSharedExpense;
  final List<String>? participants; // User IDs of participants
  final Map<String, double>? participantAmounts; // Amount per participant

  // Additional fields
  final String? currency;
  final String? location;

  final DateTime createdAt;
  final DateTime updatedAt;

  Transaction({
    required this.id,
    required this.userId,
    required this.transactionTypeId,
    required this.type,
    required this.amount,
    this.description,
    this.category,
    required this.date,
    this.status = TransactionStatus.completed,
    this.accountId,
    this.creditCardId,
    this.destinationAccountId,
    this.installments,
    this.totalAmount,
    this.interestAmount,
    this.currentInstallment,
    this.isSharedExpense = false,
    this.participants,
    this.participantAmounts,
    this.currency,
    this.location,
    required this.createdAt,
    required this.updatedAt,
  });

  Transaction copyWith({
    String? id,
    String? userId,
    int? transactionTypeId,
    TransactionType? type,
    double? amount,
    String? description,
    String? category,
    DateTime? date,
    TransactionStatus? status,
    String? accountId,
    String? creditCardId,
    String? destinationAccountId,
    int? installments,
    double? totalAmount,
    double? interestAmount,
    int? currentInstallment,
    bool? isSharedExpense,
    List<String>? participants,
    Map<String, double>? participantAmounts,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? currency,
    String? location,
  }) {
    return Transaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      transactionTypeId: transactionTypeId ?? this.transactionTypeId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      category: category ?? this.category,
      date: date ?? this.date,
      status: status ?? this.status,
      accountId: accountId ?? this.accountId,
      creditCardId: creditCardId ?? this.creditCardId,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
      installments: installments ?? this.installments,
      totalAmount: totalAmount ?? this.totalAmount,
      interestAmount: interestAmount ?? this.interestAmount,
      currentInstallment: currentInstallment ?? this.currentInstallment,
      isSharedExpense: isSharedExpense ?? this.isSharedExpense,
      participants: participants ?? this.participants,
      participantAmounts: participantAmounts ?? this.participantAmounts,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      currency: currency ?? this.currency,
      location: location ?? this.location,
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
      'currency': currency,
      'location': location,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    final transactionTypeId = map['transactionTypeId'] as int? ?? 2;

    return Transaction(
      id: map['id'],
      userId: map['userId'],
      transactionTypeId: transactionTypeId,
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
      destinationAccountId: map['destinationAccountId'],
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
      currency: map['currency'],
      location: map['location'],
    );
  }

  factory Transaction.fromSupabase(Map<String, dynamic> map) {
    // Read transaction_type_id from database
    final transactionTypeId = map['transaction_type_id'] as int? ?? 2; // Default to expense

    // For backward compatibility: also support old transaction_type string field
    final typeStr = map['transaction_type'] as String?;

    // Determine legacy TransactionType enum based on transactionTypeId
    TransactionType type;
    if (transactionTypeId % 2 == 1) {
      type = TransactionType.income;
    } else {
      type = TransactionType.expense;
    }

    // Override with string if provided (backward compatibility)
    if (typeStr == 'income') {
      type = TransactionType.income;
    } else if (typeStr == 'expense') {
      type = TransactionType.expense;
    }

    return Transaction(
      id: map['id'],
      userId: map['user_id'],
      transactionTypeId: transactionTypeId,
      type: type,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      description: map['description'],
      category: map['category_id'],
      date: DateTime.parse(map['transaction_date']),
      status: TransactionStatus.completed,
      accountId: map['account_id'],
      creditCardId: null,
      destinationAccountId: map['destination_account_id'],
      installments: null,
      totalAmount: null,
      interestAmount: null,
      currentInstallment: null,
      isSharedExpense: false,
      participants: null,
      participantAmounts: null,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      currency: null,
      location: null,
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
