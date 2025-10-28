enum LoanType {
  money('Dinero'),
  object('Objeto');

  const LoanType(this.displayName);
  final String displayName;
}

enum LoanDirection {
  lent('Presté'), // I lent money/object
  borrowed('Debo'); // I borrowed money/object

  const LoanDirection(this.displayName);
  final String displayName;
}

enum LoanStatus {
  active('Activo'),
  completed('Completado'),
  overdue('Vencido'),
  cancelled('Cancelado');

  const LoanStatus(this.displayName);
  final String displayName;
}

class Loan {
  final String id;
  final String userId;
  final LoanType type;
  final LoanDirection direction;
  final String thirdParty; // Name of the person
  final String? thirdPartyContact; // Optional contact info

  // Money loan specific fields
  final double? amount;
  final double? interestRate;
  final DateTime? dueDate;

  // Object loan specific fields
  final String? objectName;
  final String? objectDescription;
  final DateTime? returnDate;

  // Payment tracking for money loans
  final List<Payment> payments;
  final double remainingAmount;

  final LoanStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Loan({
    required this.id,
    required this.userId,
    required this.type,
    required this.direction,
    required this.thirdParty,
    this.thirdPartyContact,
    this.amount,
    this.interestRate,
    this.dueDate,
    this.objectName,
    this.objectDescription,
    this.returnDate,
    this.payments = const [],
    this.remainingAmount = 0.0,
    this.status = LoanStatus.active,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Loan copyWith({
    String? id,
    String? userId,
    LoanType? type,
    LoanDirection? direction,
    String? thirdParty,
    String? thirdPartyContact,
    double? amount,
    double? interestRate,
    DateTime? dueDate,
    String? objectName,
    String? objectDescription,
    DateTime? returnDate,
    List<Payment>? payments,
    double? remainingAmount,
    LoanStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Loan(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      direction: direction ?? this.direction,
      thirdParty: thirdParty ?? this.thirdParty,
      thirdPartyContact: thirdPartyContact ?? this.thirdPartyContact,
      amount: amount ?? this.amount,
      interestRate: interestRate ?? this.interestRate,
      dueDate: dueDate ?? this.dueDate,
      objectName: objectName ?? this.objectName,
      objectDescription: objectDescription ?? this.objectDescription,
      returnDate: returnDate ?? this.returnDate,
      payments: payments ?? this.payments,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type.name,
      'direction': direction.name,
      'thirdParty': thirdParty,
      'thirdPartyContact': thirdPartyContact,
      'amount': amount,
      'interestRate': interestRate,
      'dueDate': dueDate?.toIso8601String(),
      'objectName': objectName,
      'objectDescription': objectDescription,
      'returnDate': returnDate?.toIso8601String(),
      'payments': payments.map((p) => p.toMap()).toList(),
      'remainingAmount': remainingAmount,
      'status': status.name,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Loan.fromMap(Map<String, dynamic> map) {
    return Loan(
      id: map['id'],
      userId: map['userId'],
      type: LoanType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => LoanType.money,
      ),
      direction: LoanDirection.values.firstWhere(
        (e) => e.name == map['direction'],
        orElse: () => LoanDirection.lent,
      ),
      thirdParty: map['thirdParty'],
      thirdPartyContact: map['thirdPartyContact'],
      amount: map['amount']?.toDouble(),
      interestRate: map['interestRate']?.toDouble(),
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      objectName: map['objectName'],
      objectDescription: map['objectDescription'],
      returnDate: map['returnDate'] != null
          ? DateTime.parse(map['returnDate'])
          : null,
      payments: map['payments'] != null
          ? (map['payments'] as List<dynamic>)
                .map((p) => Payment.fromMap(p))
                .toList()
          : [],
      remainingAmount: map['remainingAmount']?.toDouble() ?? 0.0,
      status: LoanStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => LoanStatus.active,
      ),
      notes: map['notes'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  // Helper methods
  bool get isOverdue {
    if (status != LoanStatus.active) return false;

    final now = DateTime.now();
    if (type == LoanType.money && dueDate != null) {
      return now.isAfter(dueDate!);
    } else if (type == LoanType.object && returnDate != null) {
      return now.isAfter(returnDate!);
    }
    return false;
  }

  double getTotalPaid() {
    return payments.fold(0.0, (sum, payment) => sum + payment.amount);
  }

  bool get isFullyPaid {
    return type == LoanType.money && remainingAmount <= 0.0;
  }
}

class Payment {
  final String id;
  final double amount;
  final DateTime date;
  final String? notes;

  Payment({
    required this.id,
    required this.amount,
    required this.date,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'date': date.toIso8601String(),
      'notes': notes,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'],
      amount: map['amount']?.toDouble() ?? 0.0,
      date: DateTime.parse(map['date']),
      notes: map['notes'],
    );
  }
}
