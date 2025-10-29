import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/auth_provider.dart';
import '../onboarding/profile_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isTravelModeEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isTravelModeEnabled = prefs.getBool('travel_mode_enabled') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración'), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Modo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Modo Viaje'),
            subtitle: Text(
              _isTravelModeEnabled
                  ? 'Activado (Moneda: USD)'
                  : 'Desactivado (Moneda: ARS)',
            ),
            value: _isTravelModeEnabled,
            onChanged: _toggleTravelMode,
            secondary: const Icon(Icons.flight_takeoff),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const Divider(height: 32),
          const Text(
            'Cuenta',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Editar Perfil'),
            subtitle: const Text('Cambia tu alias, fecha de nacimiento, etc.'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (context) => const ProfileSetupScreen(),
                    ),
                  )
                  .then((_) => Navigator.of(context).pop(true));
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Cerrar Sesión',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              await authProvider.signOut();
              if (context.mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTravelMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('travel_mode_enabled', value);
    // For now, travel currency is hardcoded to USD
    if (value) {
      await prefs.setString('travel_currency', 'USD');
    }

    setState(() {
      _isTravelModeEnabled = value;
    });
    // Pop the screen and return true to signal that data should be reloaded
    if (mounted) Navigator.of(context).pop(true);
  }
}
