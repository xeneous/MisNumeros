class Operacion {
  final String id;
  final String operacion;
  final String descripcion;
  final DateTime createdAt;
  final DateTime updatedAt;

  Operacion({
    required this.id,
    required this.operacion,
    required this.descripcion,
    required this.createdAt,
    required this.updatedAt,
  });

  Operacion copyWith({
    String? id,
    String? operacion,
    String? descripcion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Operacion(
      id: id ?? this.id,
      operacion: operacion ?? this.operacion,
      descripcion: descripcion ?? this.descripcion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'operacion': operacion,
      'descripcion': descripcion,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Operacion.fromMap(Map<String, dynamic> map) {
    return Operacion(
      id: map['id'],
      operacion: map['operacion'],
      descripcion: map['descripcion'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }
}
