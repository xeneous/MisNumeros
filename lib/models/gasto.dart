class Gasto {
  final String id;
  final DateTime fecha;
  final String concepto;
  final String periodicidad;
  final double importe;
  final String billetera;
  final DateTime createdAt;
  final DateTime updatedAt;

  Gasto({
    required this.id,
    required this.fecha,
    required this.concepto,
    required this.periodicidad,
    required this.importe,
    required this.billetera,
    required this.createdAt,
    required this.updatedAt,
  });

  Gasto copyWith({
    String? id,
    DateTime? fecha,
    String? concepto,
    String? periodicidad,
    double? importe,
    String? billetera,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Gasto(
      id: id ?? this.id,
      fecha: fecha ?? this.fecha,
      concepto: concepto ?? this.concepto,
      periodicidad: periodicidad ?? this.periodicidad,
      importe: importe ?? this.importe,
      billetera: billetera ?? this.billetera,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fecha': fecha.toIso8601String(),
      'concepto': concepto,
      'periodicidad': periodicidad,
      'importe': importe,
      'billetera': billetera,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Gasto.fromMap(Map<String, dynamic> map) {
    return Gasto(
      id: map['id'],
      fecha: DateTime.parse(map['fecha']),
      concepto: map['concepto'],
      periodicidad: map['periodicidad'],
      importe: map['importe']?.toDouble() ?? 0.0,
      billetera: map['billetera'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }
}
