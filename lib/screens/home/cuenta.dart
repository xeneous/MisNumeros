enum TipoCuenta { bancaria, digital, efectivo }

extension TipoCuentaExtension on TipoCuenta {
  String get displayName {
    switch (this) {
      case TipoCuenta.bancaria:
        return 'Bancaria';
      case TipoCuenta.digital:
        return 'Digital';
      case TipoCuenta.efectivo:
        return 'Efectivo';
    }
  }
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
  double
  saldoActual; // This field will be calculated, not stored in DB directly for now.

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
    this.saldoActual = 0.0, // Default value
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
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
    // Do not include id_cuenta if it's a new record (id is 0)
    // to allow autoincrement to work.
    if (idCuenta != 0) {
      map['id_cuenta'] = idCuenta;
    }
    return map;
  }

  factory Cuenta.fromMap(Map<String, dynamic> map) {
    return Cuenta(
      idCuenta: map['id_cuenta'],
      idUsuario: map['id_usuario'],
      nombre: map['nombre'],
      tipo: TipoCuenta.values.firstWhere(
        (e) => e.name == map['tipo'],
        orElse: () => TipoCuenta.bancaria,
      ),
      numeroCuenta: map['numero_cuenta'],
      bancoEntidad: map['banco_entidad'],
      moneda: map['moneda'],
      colorHex: map['color_hex'],
      icono: map['icono'],
      fechaCreacion: DateTime.parse(map['fecha_creacion']),
      activa: map['activa'] == 1,
      esPrincipal: map['es_principal'] == 1,
      saldoActual: 0.0, // Will be calculated after fetching
    );
  }

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
    double? saldoActual,
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
      saldoActual: saldoActual ?? this.saldoActual,
    );
  }
}
