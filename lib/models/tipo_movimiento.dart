enum SignoMovimiento {
  ingreso(1, 'Ingreso'),
  salida(0, 'Salida');

  const SignoMovimiento(this.value, this.displayName);
  final int value;
  final String displayName;
}

class TipoMovimiento {
  final String id;
  final String codigoMovimiento;
  final String descripcion;
  final SignoMovimiento signo;
  final DateTime createdAt;
  final DateTime updatedAt;

  TipoMovimiento({
    required this.id,
    required this.codigoMovimiento,
    required this.descripcion,
    required this.signo,
    required this.createdAt,
    required this.updatedAt,
  });

  TipoMovimiento copyWith({
    String? id,
    String? codigoMovimiento,
    String? descripcion,
    SignoMovimiento? signo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TipoMovimiento(
      id: id ?? this.id,
      codigoMovimiento: codigoMovimiento ?? this.codigoMovimiento,
      descripcion: descripcion ?? this.descripcion,
      signo: signo ?? this.signo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigoMovimiento': codigoMovimiento,
      'descripcion': descripcion,
      'signo': signo.value,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TipoMovimiento.fromMap(Map<String, dynamic> map) {
    return TipoMovimiento(
      id: map['id'],
      codigoMovimiento: map['codigoMovimiento'],
      descripcion: map['descripcion'],
      signo: SignoMovimiento.values.firstWhere(
        (e) => e.value == map['signo'],
        orElse: () => SignoMovimiento.salida,
      ),
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }
}
