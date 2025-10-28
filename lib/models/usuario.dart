class Usuario {
  final int idUsuario;
  final String email;
  final String passwordHash;
  final String alias;
  final String? nombre;
  final DateTime? fechaNacimiento;
  final String? telefono;
  final String? fotoUrl;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;
  final bool activo;
  final String monedaPreferencia;

  Usuario({
    required this.idUsuario,
    required this.email,
    required this.passwordHash,
    required this.alias,
    this.nombre,
    this.fechaNacimiento,
    this.telefono,
    this.fotoUrl,
    required this.fechaCreacion,
    required this.fechaActualizacion,
    this.activo = true,
    this.monedaPreferencia = 'ARS',
  });

  Usuario copyWith({
    int? idUsuario,
    String? email,
    String? passwordHash,
    String? alias,
    String? nombre,
    DateTime? fechaNacimiento,
    String? telefono,
    String? fotoUrl,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    bool? activo,
    String? monedaPreferencia,
  }) {
    return Usuario(
      idUsuario: idUsuario ?? this.idUsuario,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      alias: alias ?? this.alias,
      nombre: nombre ?? this.nombre,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      telefono: telefono ?? this.telefono,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      activo: activo ?? this.activo,
      monedaPreferencia: monedaPreferencia ?? this.monedaPreferencia,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_usuario': idUsuario,
      'email': email,
      'password_hash': passwordHash,
      'alias': alias,
      'nombre': nombre,
      'fecha_nacimiento': fechaNacimiento?.toIso8601String(),
      'telefono': telefono,
      'foto_url': fotoUrl,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion.toIso8601String(),
      'activo': activo ? 1 : 0,
      'moneda_preferencia': monedaPreferencia,
    };
  }

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      idUsuario: map['id_usuario'],
      email: map['email'],
      passwordHash: map['password_hash'],
      alias: map['alias'],
      nombre: map['nombre'],
      fechaNacimiento: map['fecha_nacimiento'] != null
          ? DateTime.parse(map['fecha_nacimiento'])
          : null,
      telefono: map['telefono'],
      fotoUrl: map['foto_url'],
      fechaCreacion: DateTime.parse(map['fecha_creacion']),
      fechaActualizacion: DateTime.parse(map['fecha_actualizacion']),
      activo: map['activo'] == 1,
      monedaPreferencia: map['moneda_preferencia'] ?? 'ARS',
    );
  }
}
