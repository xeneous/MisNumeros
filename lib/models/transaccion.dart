enum TipoTransaccion {
  ingreso('Ingreso'),
  gasto('Gasto'),
  transferencia('Transferencia');

  const TipoTransaccion(this.displayName);
  final String displayName;
}

enum MetodoPago {
  efectivo('Efectivo'),
  tarjeta('Tarjeta'),
  transferencia('Transferencia');

  const MetodoPago(this.displayName);
  final String displayName;
}

class Transaccion {
  final String idTransaccion;
  final int idUsuario;
  final int idCuenta;
  final int idCategoria;
  final int
  tipoMovimiento; // 1: Ingreso, 2: Egreso, 11: Egreso a otra billetera, 12: Ingreso de otra billetera
  final int signo; // 1 para ingresos, -1 para egresos
  final TipoTransaccion tipo;
  final String moneda;
  final double monto;
  final String? descripcion;
  final DateTime fechaTransaccion;
  final DateTime fechaRegistro;
  final MetodoPago? metodoPago;
  final String? referencia;
  final String? ubicacion;
  final String? imagenUrl;
  final String? notas;

  Transaccion({
    required this.idTransaccion,
    required this.idUsuario,
    required this.idCuenta,
    required this.idCategoria,
    required this.tipoMovimiento,
    required this.signo,
    required this.tipo,
    required this.moneda,
    required this.monto,
    this.descripcion,
    required this.fechaTransaccion,
    required this.fechaRegistro,
    this.metodoPago,
    this.referencia,
    this.ubicacion,
    this.imagenUrl,
    this.notas,
  });

  Transaccion copyWith({
    String? idTransaccion,
    int? idUsuario,
    int? idCuenta,
    int? idCategoria,
    int? tipoMovimiento,
    int? signo,
    TipoTransaccion? tipo,
    String? moneda,
    double? monto,
    String? descripcion,
    DateTime? fechaTransaccion,
    DateTime? fechaRegistro,
    MetodoPago? metodoPago,
    String? referencia,
    String? ubicacion,
    String? imagenUrl,
    String? notas,
  }) {
    return Transaccion(
      idTransaccion: idTransaccion ?? this.idTransaccion,
      idUsuario: idUsuario ?? this.idUsuario,
      idCuenta: idCuenta ?? this.idCuenta,
      idCategoria: idCategoria ?? this.idCategoria,
      tipoMovimiento: tipoMovimiento ?? this.tipoMovimiento,
      signo: signo ?? this.signo,
      tipo: tipo ?? this.tipo,
      moneda: moneda ?? this.moneda,
      monto: monto ?? this.monto,
      descripcion: descripcion ?? this.descripcion,
      fechaTransaccion: fechaTransaccion ?? this.fechaTransaccion,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      metodoPago: metodoPago ?? this.metodoPago,
      referencia: referencia ?? this.referencia,
      ubicacion: ubicacion ?? this.ubicacion,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      notas: notas ?? this.notas,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_transaccion': idTransaccion,
      'id_usuario': idUsuario,
      'id_cuenta': idCuenta,
      'id_categoria': idCategoria,
      'tipo_movimiento': tipoMovimiento,
      'signo': signo,
      'moneda': moneda,
      'tipo': tipo.name,
      'monto': monto,
      'descripcion': descripcion,
      'fecha_transaccion': fechaTransaccion.toIso8601String(),
      'fecha_registro': fechaRegistro.toIso8601String(),
      'metodo_pago': metodoPago?.name,
      'referencia': referencia,
      'ubicacion': ubicacion,
      'imagen_url': imagenUrl,
      'notas': notas,
    };
  }

  factory Transaccion.fromMap(Map<String, dynamic> map) {
    return Transaccion(
      idTransaccion: map['id_transaccion'],
      idUsuario: map['id_usuario'],
      idCuenta: map['id_cuenta'],
      idCategoria: map['id_categoria'],
      tipoMovimiento:
          map['tipo_movimiento'] ?? (map['tipo'] == 'ingreso' ? 1 : 2),
      signo: map['signo'] ?? (map['tipo'] == 'ingreso' ? 1 : -1),
      moneda: map['moneda'] ?? 'ARS',
      tipo: TipoTransaccion.values.firstWhere(
        (tipo) => tipo.name == map['tipo'],
        orElse: () => TipoTransaccion.gasto,
      ),
      monto: map['monto']?.toDouble() ?? 0.0,
      descripcion: map['descripcion'],
      fechaTransaccion: DateTime.parse(map['fecha_transaccion']),
      fechaRegistro: DateTime.parse(map['fecha_registro']),
      metodoPago: map['metodo_pago'] != null
          ? MetodoPago.values.firstWhere(
              (metodo) => metodo.name == map['metodo_pago'],
              orElse: () => MetodoPago.efectivo,
            )
          : null,
      referencia: map['referencia'],
      ubicacion: map['ubicacion'],
      imagenUrl: map['imagen_url'],
      notas: map['notas'],
    );
  }
}
