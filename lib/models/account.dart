import 'package:equatable/equatable.dart';

enum AccountType {
  cash('Efectivo'),
  debit('Debito'),
  digital('Digital');

  const AccountType(this.displayName);
  final String displayName;

  factory AccountType.fromName(String name) {
    switch (name) {
      case 'cash':
        return AccountType.cash;
      case 'debit':
        return AccountType.debit;
      case 'digital':
        return AccountType.digital;
      default:
        return AccountType.cash; // Default value
    }
  }
}

class Account extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String? alias;
  final AccountType type;
  final String moneda;
  final double initialBalance;
  final double currentBalance;
  final bool isDefault;
  final bool isDeletable;
  final DateTime createdAt;
  final DateTime updatedAt;

  Account({
    required this.id,
    required this.userId,
    required this.name,
    this.alias,
    required this.type,
    this.moneda = 'ARS',
    required this.initialBalance,
    required this.currentBalance,
    this.isDefault = false,
    this.isDeletable = true,
    required this.createdAt,
    required this.updatedAt,
  });

  // Default wallet "Bolsillo" constructor
  factory Account.defaultWallet(String userId) {
    return Account(
      id: 'default_wallet',
      userId: userId,
      name: 'Bolsillo',
      alias: 'Efectivo',
      type: AccountType.cash,
      moneda: 'ARS',
      initialBalance: 0.0,
      currentBalance: 0.0,
      isDefault: true,
      isDeletable: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Account copyWith({
    String? id,
    String? userId,
    String? name,
    String? alias,
    AccountType? type,
    String? moneda,
    double? initialBalance,
    double? currentBalance,
    bool? isDefault,
    bool? isDeletable,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      alias: alias ?? this.alias,
      type: type ?? this.type,
      moneda: moneda ?? this.moneda,
      initialBalance: initialBalance ?? this.initialBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      isDefault: isDefault ?? this.isDefault,
      isDeletable: isDeletable ?? this.isDeletable,
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
      'type': type.name,
      'moneda': moneda,
      'initialBalance': initialBalance,
      'currentBalance': currentBalance,
      'isDefault': isDefault ? 1 : 0,
      'isDeletable': isDeletable ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'],
      userId: map['userId'],
      name: map['name'],
      alias: map['alias'],
      type: AccountType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => AccountType.cash,
      ),
      moneda: map['moneda'] ?? 'ARS',
      initialBalance: map['initialBalance']?.toDouble() ?? 0.0,
      currentBalance: map['currentBalance']?.toDouble() ?? 0.0,
      isDefault: map['isDefault'] == 1,
      isDeletable: map['isDeletable'] == 1,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  @override
  List<Object?> get props => [id];
}
