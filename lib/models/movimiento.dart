class Movimiento {
  final String id;
  final String billetera; // wallet/account reference
  final String codigoMovimiento; // movement type code
  final DateTime fecha;
  final String concepto;
  final double importe;
  final String? contacto; // contact reference
  final String? operacion; // operation reference
  final DateTime createdAt;
  final DateTime updatedAt;

  Movimiento({
    required this.id,
    required this.billetera,
    required this.codigoMovimiento,
    required this.fecha,
    required this.concepto,
    required this.importe,
    this.contacto,
    this.operacion,
    required this.createdAt,
    required this.updatedAt,
  });

  Movimiento copyWith({
    String? id,
    String? billetera,
    String? codigoMovimiento,
    DateTime? fecha,
    String? concepto,
    double? importe,
    String? contacto,
    String? operacion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Movimiento(
      id: id ?? this.id,
      billetera: billetera ?? this.billetera,
      codigoMovimiento: codigoMovimiento ?? this.codigoMovimiento,
      fecha: fecha ?? this.fecha,
      concepto: concepto ?? this.concepto,
      importe: importe ?? this.importe,
      contacto: contacto ?? this.contacto,
      operacion: operacion ?? this.operacion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'billetera': billetera,
      'codigoMovimiento': codigoMovimiento,
      'fecha': fecha.toIso8601String(),
      'concepto': concepto,
      'importe': importe,
      'contacto': contacto,
      'operacion': operacion,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Movimiento.fromMap(Map<String, dynamic> map) {
    return Movimiento(
      id: map['id'],
      billetera: map['billetera'],
      codigoMovimiento: map['codigoMovimiento'],
      fecha: DateTime.parse(map['fecha']),
      concepto: map['concepto'],
      importe: map['importe']?.toDouble() ?? 0.0,
      contacto: map['contacto'],
      operacion: map['operacion'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }
}
