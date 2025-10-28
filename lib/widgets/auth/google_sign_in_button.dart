import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return ElevatedButton.icon(
      onPressed: authProvider.isLoading
          ? null
          : () async {
              await authProvider.signInWithGoogle();
              // Show popup for demo
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Google Sign-In'),
                    content: const Text(
                      'Funcionalidad no implementada en modo demo.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            },
      icon: Image.asset(
        'assets/images/google_logo.png',
        height: 20,
        width: 20,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.login),
      ),
      label: const Text('Continuar con Google'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey[300]!),
        ),
      ),
    );
  }
}
