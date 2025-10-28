// This file is inferred from usage in other files and database schema.
class Transaccion {
  final int idTransaccion;
  final int idUsuario;
  final int idCuenta;
  final int idCategoria;
  final String tipo; // 'ingreso' or 'gasto'
  final double monto;
  final String? descripcion;
  final DateTime fechaTransaccion;
  final DateTime fechaRegistro;
  final String? metodoPago;
  final String? referencia;
  final String? ubicacion;
  final String? imagenUrl;
  final String? notas;

  Transaccion({
    required this.idTransaccion,
    required this.idUsuario,
    required this.idCuenta,
    required this.idCategoria,
    required this.tipo,
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

  Map<String, dynamic> toMap() {
    return {
      'id_transaccion': idTransaccion,
      'id_usuario': idUsuario,
      'id_cuenta': idCuenta,
      'id_categoria': idCategoria,
      'tipo': tipo,
      'monto': monto,
      'descripcion': descripcion,
      'fecha_transaccion': fechaTransaccion.toIso8601String(),
      'fecha_registro': fechaRegistro.toIso8601String(),
      'metodo_pago': metodoPago,
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
      tipo: map['tipo'],
      monto: map['monto']?.toDouble() ?? 0.0,
      descripcion: map['descripcion'],
      fechaTransaccion: DateTime.parse(map['fecha_transaccion']),
      fechaRegistro: DateTime.parse(map['fecha_registro']),
      metodoPago: map['metodo_pago'],
      referencia: map['referencia'],
      ubicacion: map['ubicacion'],
      imagenUrl: map['imagen_url'],
      notas: map['notas'],
    );
  }
}
