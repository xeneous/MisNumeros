import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/onboarding/profile_setup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/accounts/accounts_screen.dart';
import 'screens/credit_cards/credit_cards_screen.dart';
import 'screens/fixed_expenses/fixed_expenses_screen.dart';
import 'screens/free/free_area_screen.dart';
import 'screens/premium/premium_area_screen.dart';
import 'screens/movimientos/movimientos_screen.dart';
import 'screens/home/settings_screen.dart';
// import 'screens/integrations/mercado_pago_auth_screen.dart'; // Comentado para pausar la integración con Mercado Pago

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('App starting...');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          // Add keyboard shortcuts to prevent assertion errors
          const SingleActivator(LogicalKeyboardKey.escape): () {},
        },
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            // Global keyboard event handler to prevent assertion errors
            // This ensures proper keyboard state management
            return KeyEventResult.ignored;
          },
          child: MaterialApp(
            title: 'DayByDay',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
              useMaterial3: true,
            ),
            home: const AuthWrapper(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/onboarding': (context) => const ProfileSetupScreen(),
              '/free': (context) => const FreeAreaScreen(),
              '/premium': (context) => const PremiumAreaScreen(),
              '/home': (context) => const HomeScreen(),
              '/accounts': (context) => const AccountsScreen(),
              '/credit-cards': (context) => const CreditCardsScreen(),
              '/fixed-expenses': (context) => const FixedExpensesScreen(),
              '/movimientos': (context) => const MovimientosScreen(),
              '/settings': (context) => const SettingsScreen(),
              // '/mercado-pago-auth': (context) =>
              //     const MercadoPagoAuthScreen(), // Comentado para pausar la integración con Mercado Pago
            },
          ),
        ),
      ),
    );
  }
}

// Widget that handles authentication-based navigation
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // Usamos Consumer solo para reconstruir la UI cuando cambia el estado de autenticación.
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Show loading while checking authentication state or initializing
        if (authProvider.isLoading || !authProvider.isInitialized) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando...'),
                ],
              ),
            ),
          );
        }

        // Si el usuario está autenticado, muestra la pantalla de inicio.
        // Si el usuario está autenticado, muestra la pantalla de inicio.
        if (authProvider.isAuthenticated) {
          return const HomeScreen();
        }
        // Si no, muestra la pantalla de invitado, que permite iniciar sesión/registrarse.
        return const LoginScreen();
      },
    );
  }
}
