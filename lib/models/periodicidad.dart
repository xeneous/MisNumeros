class Periodicidad {
  final String id;
  final String codigo;
  final String descripcion;
  final DateTime createdAt;
  final DateTime updatedAt;

  Periodicidad({
    required this.id,
    required this.codigo,
    required this.descripcion,
    required this.createdAt,
    required this.updatedAt,
  });

  Periodicidad copyWith({
    String? id,
    String? codigo,
    String? descripcion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Periodicidad(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      descripcion: descripcion ?? this.descripcion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigo': codigo,
      'descripcion': descripcion,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Periodicidad.fromMap(Map<String, dynamic> map) {
    return Periodicidad(
      id: map['id'],
      codigo: map['codigo'],
      descripcion: map['descripcion'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }
}
