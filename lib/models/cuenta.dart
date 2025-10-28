enum TipoCuenta {
  bancaria('Bancaria'),
  digital('Digital'),
  efectivo('Efectivo');

  const TipoCuenta(this.displayName);
  final String displayName;
}

class Cuenta {
  final int idCuenta;
  final int idUsuario;
  final String nombre;
  final TipoCuenta tipo;
  final String? numeroCuenta;
  final String? bancoEntidad;
  final String moneda;
  final String colorHex;
  final String icono;
  final DateTime fechaCreacion;
  final bool activa;
  final bool esPrincipal;

  Cuenta({
    required this.idCuenta,
    required this.idUsuario,
    required this.nombre,
    required this.tipo,
    this.numeroCuenta,
    this.bancoEntidad,
    this.moneda = 'ARS',
    this.colorHex = '#2196F3',
    this.icono = 'credit_card',
    required this.fechaCreacion,
    this.activa = true,
    this.esPrincipal = false,
  });

  Cuenta copyWith({
    int? idCuenta,
    int? idUsuario,
    String? nombre,
    TipoCuenta? tipo,
    String? numeroCuenta,
    String? bancoEntidad,
    String? moneda,
    String? colorHex,
    String? icono,
    DateTime? fechaCreacion,
    bool? activa,
    bool? esPrincipal,
  }) {
    return Cuenta(
      idCuenta: idCuenta ?? this.idCuenta,
      idUsuario: idUsuario ?? this.idUsuario,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      numeroCuenta: numeroCuenta ?? this.numeroCuenta,
      bancoEntidad: bancoEntidad ?? this.bancoEntidad,
      moneda: moneda ?? this.moneda,
      colorHex: colorHex ?? this.colorHex,
      icono: icono ?? this.icono,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      activa: activa ?? this.activa,
      esPrincipal: esPrincipal ?? this.esPrincipal,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_cuenta': idCuenta,
      'id_usuario': idUsuario,
      'nombre': nombre,
      'tipo': tipo.name,
      'numero_cuenta': numeroCuenta,
      'banco_entidad': bancoEntidad,
      'moneda': moneda,
      'color_hex': colorHex,
      'icono': icono,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'activa': activa ? 1 : 0,
      'es_principal': esPrincipal ? 1 : 0,
    };
  }

  factory Cuenta.fromMap(Map<String, dynamic> map) {
    return Cuenta(
      idCuenta: map['id_cuenta'],
      idUsuario: map['id_usuario'],
      nombre: map['nombre'],
      tipo: TipoCuenta.values.firstWhere(
        (tipo) => tipo.name == map['tipo'],
        orElse: () => TipoCuenta.efectivo,
      ),
      numeroCuenta: map['numero_cuenta'],
      bancoEntidad: map['banco_entidad'],
      moneda: map['moneda'] ?? 'ARS',
      colorHex: map['color_hex'] ?? '#2196F3',
      icono: map['icono'] ?? 'credit_card',
      fechaCreacion: DateTime.parse(map['fecha_creacion']),
      activa: map['activa'] == 1,
      esPrincipal: map['es_principal'] == 1,
    );
  }
}
