enum EstadoProximoGasto {
  pendiente('Pendiente'),
  pagado('Pagado'),
  cancelado('Cancelado');

  const EstadoProximoGasto(this.displayName);
  final String displayName;
}

enum PrioridadProximoGasto {
  baja('Baja'),
  media('Media'),
  alta('Alta');

  const PrioridadProximoGasto(this.displayName);
  final String displayName;
}

class ProximoGasto {
  final int idObligacion;
  final int idGasto;
  final double montoEstimado;
  final double? montoReal;
  final DateTime fechaVencimiento;
  final DateTime? fechaPago;
  final EstadoProximoGasto estado;
  final PrioridadProximoGasto prioridad;
  final bool recordatorio;
  final int? idTransaccion;

  ProximoGasto({
    required this.idObligacion,
    required this.idGasto,
    required this.montoEstimado,
    this.montoReal,
    required this.fechaVencimiento,
    this.fechaPago,
    this.estado = EstadoProximoGasto.pendiente,
    this.prioridad = PrioridadProximoGasto.media,
    this.recordatorio = true,
    this.idTransaccion,
  });

  ProximoGasto copyWith({
    int? idObligacion,
    int? idGasto,
    double? montoEstimado,
    double? montoReal,
    DateTime? fechaVencimiento,
    DateTime? fechaPago,
    EstadoProximoGasto? estado,
    PrioridadProximoGasto? prioridad,
    bool? recordatorio,
    int? idTransaccion,
  }) {
    return ProximoGasto(
      idObligacion: idObligacion ?? this.idObligacion,
      idGasto: idGasto ?? this.idGasto,
      montoEstimado: montoEstimado ?? this.montoEstimado,
      montoReal: montoReal ?? this.montoReal,
      fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
      fechaPago: fechaPago ?? this.fechaPago,
      estado: estado ?? this.estado,
      prioridad: prioridad ?? this.prioridad,
      recordatorio: recordatorio ?? this.recordatorio,
      idTransaccion: idTransaccion ?? this.idTransaccion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_obligacion': idObligacion,
      'id_gasto': idGasto,
      'monto_estimado': montoEstimado,
      'monto_real': montoReal,
      'fecha_vencimiento': fechaVencimiento.toIso8601String(),
      'fecha_pago': fechaPago?.toIso8601String(),
      'estado': estado.name,
      'prioridad': prioridad.name,
      'recordatorio': recordatorio ? 1 : 0,
      'id_transaccion': idTransaccion,
    };
  }

  factory ProximoGasto.fromMap(Map<String, dynamic> map) {
    return ProximoGasto(
      idObligacion: map['id_obligacion'],
      idGasto: map['id_gasto'],
      montoEstimado: map['monto_estimado']?.toDouble() ?? 0.0,
      montoReal: map['monto_real']?.toDouble(),
      fechaVencimiento: DateTime.parse(map['fecha_vencimiento']),
      fechaPago: map['fecha_pago'] != null
          ? DateTime.parse(map['fecha_pago'])
          : null,
      estado: EstadoProximoGasto.values.firstWhere(
        (estado) => estado.name == map['estado'],
        orElse: () => EstadoProximoGasto.pendiente,
      ),
      prioridad: PrioridadProximoGasto.values.firstWhere(
        (prioridad) => prioridad.name == map['prioridad'],
        orElse: () => PrioridadProximoGasto.media,
      ),
      recordatorio: map['recordatorio'] == 1,
      idTransaccion: map['id_transaccion'],
    );
  }

  // Convenience getters for UI compatibility
  String get detalle =>
      'Gasto $idObligacion'; // This would need to be fetched from GastoFijo
  String? get accountName =>
      null; // This would need to be fetched from related tables
  double get importe => montoEstimado;
  bool get pagado => estado == EstadoProximoGasto.pagado;
}
