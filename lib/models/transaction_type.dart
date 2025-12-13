/// Transaction Type model
/// Represents the type of transaction (income, expense, transfer)
///
/// Rule: ODD ids = income (suma), EVEN ids = expense (resta)
class TransactionType {
  final int id;
  final String name;
  final String? description;

  const TransactionType({
    required this.id,
    required this.name,
    this.description,
  });

  /// Check if this transaction type is an income (odd id)
  bool get isIncome => id % 2 == 1;

  /// Check if this transaction type is an expense (even id)
  bool get isExpense => id % 2 == 0;

  /// Check if this is a transfer type
  bool get isTransfer => id >= 11;

  /// Get the display name based on the type
  String get displayName {
    switch (id) {
      case 1:
        return 'Ingreso';
      case 2:
        return 'Gasto';
      case 11:
        return 'Transferencia Entrada';
      case 12:
        return 'Transferencia Salida';
      default:
        return name;
    }
  }

  factory TransactionType.fromMap(Map<String, dynamic> map) {
    return TransactionType(
      id: map['id'] as int,
      name: map['name'] as String,
      description: map['description'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
  }

  // Pre-defined transaction types
  static const TransactionType income = TransactionType(
    id: 1,
    name: 'income',
    description: 'Ingreso regular',
  );

  static const TransactionType expense = TransactionType(
    id: 2,
    name: 'expense',
    description: 'Gasto regular',
  );

  static const TransactionType transferIn = TransactionType(
    id: 11,
    name: 'transfer_in',
    description: 'Transferencia entrada',
  );

  static const TransactionType transferOut = TransactionType(
    id: 12,
    name: 'transfer_out',
    description: 'Transferencia salida',
  );

  /// Get transaction type by id
  static TransactionType fromId(int id) {
    switch (id) {
      case 1:
        return income;
      case 2:
        return expense;
      case 11:
        return transferIn;
      case 12:
        return transferOut;
      default:
        throw ArgumentError('Unknown transaction type id: $id');
    }
  }

  /// Get transaction type by name
  static TransactionType fromName(String name) {
    switch (name) {
      case 'income':
        return income;
      case 'expense':
        return expense;
      case 'transfer_in':
        return transferIn;
      case 'transfer_out':
        return transferOut;
      default:
        throw ArgumentError('Unknown transaction type name: $name');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionType &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'TransactionType(id: $id, name: $name)';
}
