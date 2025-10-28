class Concepto {
  final String id;
  final String concepto;
  final String descripcion;
  final DateTime createdAt;
  final DateTime updatedAt;

  Concepto({
    required this.id,
    required this.concepto,
    required this.descripcion,
    required this.createdAt,
    required this.updatedAt,
  });

  Concepto copyWith({
    String? id,
    String? concepto,
    String? descripcion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Concepto(
      id: id ?? this.id,
      concepto: concepto ?? this.concepto,
      descripcion: descripcion ?? this.descripcion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'concepto': concepto,
      'descripcion': descripcion,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Concepto.fromMap(Map<String, dynamic> map) {
    return Concepto(
      id: map['id'],
      concepto: map['concepto'],
      descripcion: map['descripcion'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }
}
