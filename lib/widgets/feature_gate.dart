import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/feature_limiter.dart';

class FeatureGate extends StatelessWidget {
  final User user;
  final String feature;
  final Widget child;
  final Widget? blockedWidget;

  const FeatureGate({
    super.key,
    required this.user,
    required this.feature,
    required this.child,
    this.blockedWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (FeatureLimiter.canAccessFeature(user, feature)) {
      return child;
    }

    if (blockedWidget != null) {
      return blockedWidget!;
    }

    // Default blocked widget
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock, color: Colors.grey, size: 48),
          const SizedBox(height: 12),
          Text(
            'Función Premium',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Esta función requiere una cuenta Premium',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('¡Próximamente! Sistema Premium disponible.'),
                  backgroundColor: Colors.amber,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
            child: const Text('Más Información'),
          ),
        ],
      ),
    );
  }
}

// Widget for showing upgrade prompts
class UpgradePrompt extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const UpgradePrompt({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.color = Colors.amber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
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
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Widget for showing feature availability status
class FeatureStatus extends StatelessWidget {
  final User user;
  final String feature;
  final String featureName;

  const FeatureStatus({
    super.key,
    required this.user,
    required this.feature,
    required this.featureName,
  });

  @override
  Widget build(BuildContext context) {
    final canAccess = FeatureLimiter.canAccessFeature(user, feature);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: canAccess
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: canAccess
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            canAccess ? Icons.check_circle : Icons.info,
            size: 16,
            color: canAccess ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            canAccess ? 'Disponible' : 'Premium',
            style: TextStyle(
              fontSize: 12,
              color: canAccess ? Colors.green : Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
