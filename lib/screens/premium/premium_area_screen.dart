import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../movimientos/movimientos_screen.dart';

class PremiumAreaScreen extends StatefulWidget {
  const PremiumAreaScreen({super.key});

  @override
  State<PremiumAreaScreen> createState() => _PremiumAreaScreenState();
}

class _PremiumAreaScreenState extends State<PremiumAreaScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.user;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Plan ${currentUser.userPlan.displayName}'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.star, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                const Text(
                  'PREMIUM',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome message
            Text(
              '¡Bienvenido, ${currentUser.alias ?? currentUser.displayName ?? 'Usuario'}!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Estás disfrutando del plan ${currentUser.userPlan.displayName}',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),

            const SizedBox(height: 32),

            // Premium features grid
            _buildPremiumFeaturesGrid(),
            const SizedBox(height: 24),

            // Quick actions for premium users
            _buildQuickActions(),
            const SizedBox(height: 24),

            // Usage stats
            _buildUsageStats(),
            const SizedBox(height: 24),

            // Premium benefits
            _buildPremiumBenefits(),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumFeaturesGrid() {
    final features = [
      {
        'icon': Icons.analytics,
        'title': 'Reportes Avanzados',
        'color': Colors.blue,
      },
      {
        'icon': Icons.file_download,
        'title': 'Exportar Datos',
        'color': Colors.green,
      },
      {
        'icon': Icons.category,
        'title': 'Categorías Personalizadas',
        'color': Colors.orange,
      },
      {
        'icon': Icons.account_balance_wallet,
        'title': 'Presupuestos Múltiples',
        'color': Colors.purple,
      },
      {
        'icon': Icons.notifications,
        'title': 'Alertas Inteligentes',
        'color': Colors.red,
      },
      {
        'icon': Icons.support_agent,
        'title': 'Soporte Prioritario',
        'color': Colors.teal,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            // Corrected withOpacity
            color: (feature['color'] as Color).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (feature['color'] as Color).withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                feature['icon'] as IconData,
                size: 32,
                color: feature['color'] as Color,
              ),
              const SizedBox(height: 8),
              Text(
                feature['title'] as String,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: feature['color'] as Color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1), // Corrected withOpacity
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flash_on, color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Acciones Premium',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildActionButton(
                  '📊 Análisis',
                  'Ver reportes detallados',
                  Icons.analytics,
                  Colors.blue,
                  () => _showSnackBar('Análisis detallado - Próximamente'),
                ),
                const SizedBox(width: 12),
                _buildActionButton(
                  '📁 Exportar',
                  'Descargar datos',
                  Icons.file_download,
                  Colors.green,
                  () => _showSnackBar('Exportación de datos - Próximamente'),
                ),
                const SizedBox(width: 12),
                _buildActionButton(
                  '🎯 Metas',
                  'Configurar objetivos',
                  Icons.flag,
                  Colors.orange,
                  () => _showSnackBar('Configuración de metas - Próximamente'),
                ),
                const SizedBox(width: 12),
                _buildActionButton(
                  '📱 Alertas',
                  'Gestionar notificaciones',
                  Icons.notifications,
                  Colors.red,
                  () => _showSnackBar('Sistema de alertas - Próximamente'),
                ),
                const SizedBox(width: 12),
                _buildActionButton(
                  '💼 Movimientos',
                  'Nueva gestión de movimientos',
                  Icons.account_balance_wallet,
                  Colors.deepPurple,
                  () => _navigateToMovimientos(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 8, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.amber),
    );
  }

  Widget _buildUsageStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1), // Corrected withOpacity
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Estadísticas de uso',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Cuentas', '∞', 'Sin límite'),
              _buildStatItem('Gastos Fijos', '∞', 'Sin límite'),
              _buildStatItem('Reportes', '∞', 'Todos disponibles'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String subtitle) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.amber,
          ),
        ),
        Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildPremiumBenefits() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1), // Corrected withOpacity
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Beneficios exclusivos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBenefitItem('Experiencia sin anuncios'),
          _buildBenefitItem('Sincronización prioritaria'),
          _buildBenefitItem('Acceso anticipado a nuevas funciones'),
          _buildBenefitItem('Soporte técnico especializado'),
          _buildBenefitItem('Análisis financieros avanzados'),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String benefit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 20, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              benefit,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToMovimientos() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const MovimientosScreen()));
  }
}
