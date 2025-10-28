enum UserPlan {
  guest('Invitado', 'Acceso limitado sin registro', 0, [
    'Ver demostración de la app',
    'Información básica sobre funcionalidades',
  ]),
  free('Gratuito', 'Funcionalidades básicas', 0, [
    'Gestión básica de gastos e ingresos',
    'Hasta 3 cuentas bancarias',
    'Hasta 5 gastos fijos',
    'Reportes mensuales básicos',
    'Sincronización en la nube',
  ]),
  premium('Premium', 'Todas las funcionalidades', 999, [
    'Cuentas bancarias ilimitadas',
    'Gastos fijos ilimitados',
    'Reportes avanzados y análisis',
    'Exportación de datos (PDF/Excel)',
    'Categorías personalizadas',
    'Presupuestos múltiples',
    'Alertas y notificaciones',
    'Soporte prioritario',
    'Sin anuncios',
  ]);

  const UserPlan(
    this.displayName,
    this.description,
    this.monthlyPrice,
    this.features,
  );

  final String displayName;
  final String description;
  final double monthlyPrice;
  final List<String> features;

  String get yearlyPrice =>
      (monthlyPrice * 12 * 0.8).toStringAsFixed(0); // 20% discount for yearly
}
