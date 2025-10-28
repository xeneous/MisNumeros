import 'package:flutter/material.dart';

class GuestAreaScreen extends StatelessWidget {
  const GuestAreaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App logo/title
              const Text(
                'DayByDay',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              Text(
                'Gestión financiera inteligente',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Demo features
              _buildDemoCard(
                '💡 Vista previa',
                'Explora las funcionalidades de la aplicación sin necesidad de registrarte',
                Icons.visibility,
                Colors.blue,
              ),
              const SizedBox(height: 16),

              _buildDemoCard(
                '📊 Estadísticas básicas',
                'Visualiza ejemplos de reportes y análisis financieros',
                Icons.analytics,
                Colors.green,
              ),
              const SizedBox(height: 16),

              _buildDemoCard(
                '🎯 Consejos financieros',
                'Recibe recomendaciones para mejorar tus finanzas personales',
                Icons.lightbulb,
                Colors.orange,
              ),
              const SizedBox(height: 16),

              _buildDemoCard(
                '🔒 Seguro y privado',
                'Tus datos están protegidos con encriptación de nivel bancario',
                Icons.security,
                Colors.purple,
              ),
              const SizedBox(height: 48),

              // Action buttons
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/login'),
                icon: const Icon(Icons.login),
                label: const Text('Iniciar Sesión'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/register'),
                icon: const Icon(Icons.person_add),
                label: const Text('Crear Cuenta Gratuita'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Colors.deepPurple),
                ),
              ),
              const SizedBox(height: 32),

              // Feature comparison
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¿Por qué crear una cuenta?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildFeatureItem('Sincronización en la nube'),
                    _buildFeatureItem('Hasta 3 cuentas bancarias'),
                    _buildFeatureItem('Hasta 5 gastos fijos'),
                    _buildFeatureItem('Reportes mensuales'),
                    _buildFeatureItem('Análisis de gastos'),
                    _buildFeatureItem('Soporte técnico'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDemoCard(
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.check, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Text(
            feature,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}
