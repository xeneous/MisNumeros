enum TipoCategoria {
  ingreso('Ingreso'),
  gasto('Gasto');

  const TipoCategoria(this.displayName);
  final String displayName;
}

class Categoria {
  final int idCategoria;
  final String
  userId; // Changed from int idUsuario to String userId (Firebase UID)
  final String nombre;
  final TipoCategoria tipo;
  final String colorHex;
  final String icono;
  final String? descripcion;
  final int? padreId;
  final DateTime fechaCreacion;
  final bool activa;

  Categoria({
    required this.idCategoria,
    required this.userId,
    required this.nombre,
    required this.tipo,
    this.colorHex = '#6B73FF',
    this.icono = 'category',
    this.descripcion,
    this.padreId,
    required this.fechaCreacion,
    this.activa = true,
  });

  Categoria copyWith({
    int? idCategoria,
    String? userId,
    String? nombre,
    TipoCategoria? tipo,
    String? colorHex,
    String? icono,
    String? descripcion,
    int? padreId,
    DateTime? fechaCreacion,
    bool? activa,
  }) {
    return Categoria(
      idCategoria: idCategoria ?? this.idCategoria,
      userId: userId ?? this.userId,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      colorHex: colorHex ?? this.colorHex,
      icono: icono ?? this.icono,
      descripcion: descripcion ?? this.descripcion,
      padreId: padreId ?? this.padreId,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      activa: activa ?? this.activa,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_categoria': idCategoria,
      'user_id': userId, // Changed field name to user_id for consistency
      'nombre': nombre,
      'tipo': tipo.name,
      'color_hex': colorHex,
      'icono': icono,
      'descripcion': descripcion,
      'padre_id': padreId,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'activa': activa ? 1 : 0,
    };
  }

  factory Categoria.fromMap(Map<String, dynamic> map) {
    return Categoria(
      idCategoria: map['id_categoria'],
      userId:
          map['user_id'] ??
          map['id_usuario'], // Support both old and new field names for migration
      nombre: map['nombre'],
      tipo: TipoCategoria.values.firstWhere(
        (tipo) => tipo.name == map['tipo'],
        orElse: () => TipoCategoria.gasto,
      ),
      colorHex: map['color_hex'] ?? '#6B73FF',
      icono: map['icono'] ?? 'category',
      descripcion: map['descripcion'],
      padreId: map['padre_id'],
      fechaCreacion: DateTime.parse(map['fecha_creacion']),
      activa: map['activa'] == 1,
    );
  }
}
