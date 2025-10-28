import 'fixed_expense.dart';

enum FrecuenciaGasto {
  MENSUAL('Mensual'),
  SEMANAL('Semanal');

  const FrecuenciaGasto(this.displayName);
  final String displayName;
}

class GastoFijo {
  final int idGasto;
  final int idUsuario;
  final int idCuenta;
  final int idCategoria;
  final String nombre;
  final String? descripcion;
  final double montoTotal;
  final int? cuotas;
  final double montoCuotas;
  final String frecuencia; // MENSUAL, SEMANAL
  final int? diaSemana; // 1-7 for weekly
  final int? diaMes; // 1-31 for monthly
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final bool activo;
  final int? recordatorioDias;

  GastoFijo({
    required this.idGasto,
    required this.idUsuario,
    required this.idCuenta,
    required this.idCategoria,
    required this.nombre,
    this.descripcion,
    required this.montoTotal,
    this.cuotas,
    required this.montoCuotas,
    required this.frecuencia,
    this.diaSemana,
    this.diaMes,
    required this.fechaInicio,
    this.fechaFin,
    this.activo = true,
    this.recordatorioDias = 3,
  });

  GastoFijo copyWith({
    int? idGasto,
    int? idUsuario,
    int? idCuenta,
    int? idCategoria,
    String? nombre,
    String? descripcion,
    double? montoTotal,
    int? cuotas,
    double? montoCuotas,
    String? frecuencia,
    int? diaSemana,
    int? diaMes,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    bool? activo,
    int? recordatorioDias,
  }) {
    return GastoFijo(
      idGasto: idGasto ?? this.idGasto,
      idUsuario: idUsuario ?? this.idUsuario,
      idCuenta: idCuenta ?? this.idCuenta,
      idCategoria: idCategoria ?? this.idCategoria,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      montoTotal: montoTotal ?? this.montoTotal,
      cuotas: cuotas ?? this.cuotas,
      montoCuotas: montoCuotas ?? this.montoCuotas,
      frecuencia: frecuencia ?? this.frecuencia,
      diaSemana: diaSemana ?? this.diaSemana,
      diaMes: diaMes ?? this.diaMes,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      activo: activo ?? this.activo,
      recordatorioDias: recordatorioDias ?? this.recordatorioDias,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_gasto': idGasto,
      'id_usuario': idUsuario,
      'id_cuenta': idCuenta,
      'id_categoria': idCategoria,
      'nombre': nombre,
      'descripcion': descripcion,
      'monto_total': montoTotal,
      'cuotas': cuotas,
      'monto_cuotas': montoCuotas,
      'frecuencia': frecuencia,
      'dia_semana': diaSemana,
      'dia_mes': diaMes,
      'fecha_inicio': fechaInicio.toIso8601String(),
      'fecha_fin': fechaFin?.toIso8601String(),
      'activo': activo ? 1 : 0,
      'recordatorio_dias': recordatorioDias,
    };
  }

  factory GastoFijo.fromMap(Map<String, dynamic> map) {
    return GastoFijo(
      idGasto: map['id_gasto'],
      idUsuario: map['id_usuario'],
      idCuenta: map['id_cuenta'],
      idCategoria: map['id_categoria'],
      nombre: map['nombre'],
      descripcion: map['descripcion'],
      montoTotal: map['monto_total']?.toDouble() ?? 0.0,
      cuotas: map['cuotas'],
      montoCuotas: map['monto_cuotas']?.toDouble() ?? 0.0,
      frecuencia: map['frecuencia'] ?? 'MENSUAL',
      diaSemana: map['dia_semana'],
      diaMes: map['dia_mes'],
      fechaInicio: DateTime.parse(map['fecha_inicio']),
      fechaFin: map['fecha_fin'] != null
          ? DateTime.parse(map['fecha_fin'])
          : null,
      activo: map['activo'] == 1,
      recordatorioDias: map['recordatorio_dias'] ?? 3,
    );
  }

  // Convenience getters for UI
  bool get isActive => activo;
  double get amount => montoCuotas;
  ExpenseFrequency get frequencyEnum => frecuencia == 'MENSUAL'
      ? ExpenseFrequency.monthly
      : ExpenseFrequency.weekly;
}
