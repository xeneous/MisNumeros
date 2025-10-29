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
  String _displayMode = 'local'; // 'local', 'travel', 'all'

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _displayMode = prefs.getString('display_mode') ?? 'local';
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
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'local',
                label: Text('Local'),
                icon: Icon(Icons.home),
              ),
              ButtonSegment(
                value: 'travel',
                label: Text('Viaje'),
                icon: Icon(Icons.flight_takeoff),
              ),
              ButtonSegment(
                value: 'all',
                label: Text('Todo'),
                icon: Icon(Icons.public),
              ),
            ],
            selected: <String>{_displayMode},
            onSelectionChanged: (Set<String> newSelection) {
              _changeDisplayMode(newSelection.first);
            },
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: Colors.deepPurple.withOpacity(0.2),
              selectedForegroundColor: Colors.deepPurple,
            ),
          ),
          /* // Inicio del bloque comentado para pausar la integración con Mercado Pago
          const Divider(height: 32),
          const Text(
            'Integraciones',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Image.asset(
              'assets/images/mp_logo.png', // Asegúrate de tener este logo en tu carpeta de assets
              width: 24,
              height: 24,
            ),
            title: const Text('Conectar con Mercado Pago'),
            subtitle: const Text('Sincroniza tus gastos automáticamente'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.of(context).pushNamed('/mercado-pago-auth'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),*/
          // Fin del bloque comentado
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

  Future<void> _changeDisplayMode(String newMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('display_mode', newMode);

    setState(() {
      _displayMode = newMode;
    });
    // Pop the screen and return true to signal that data should be reloaded
    if (mounted) Navigator.of(context).pop(true);
  }
}
