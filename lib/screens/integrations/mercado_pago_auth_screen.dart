import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../services/mercado_pago_service.dart';

/// Pantalla de autorización OAuth para Mercado Pago
/// Muestra un WebView con el flujo de autorización y captura el código de respuesta
class MercadoPagoAuthScreen extends StatefulWidget {
  const MercadoPagoAuthScreen({super.key});

  @override
  State<MercadoPagoAuthScreen> createState() => _MercadoPagoAuthScreenState();
}

class _MercadoPagoAuthScreenState extends State<MercadoPagoAuthScreen> {
  late final WebViewController _controller;
  final _mpService = MercadoPagoService();
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    // Verificar si las credenciales están configuradas
    if (!_mpService.isConfigured) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Por favor configura las credenciales de Mercado Pago primero',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onNavigationRequest: (NavigationRequest request) {
            // Escuchamos la URL de redirección
            if (request.url.startsWith('https://misnumeros.app/mp-callback')) {
              _handleRedirect(request.url);
              return NavigationDecision.prevent; // Detenemos la navegación
            }
            return NavigationDecision.navigate; // Permitimos otras navegaciones
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error al cargar: ${error.description}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_mpService.getAuthorizationUrl()));
  }

  /// Maneja la URL de redirección y extrae el código de autorización
  Future<void> _handleRedirect(String url) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final uri = Uri.parse(url);
      final code = uri.queryParameters['code'];
      final error = uri.queryParameters['error'];

      if (error != null) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error de autorización: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (code != null) {
        // Mostrar diálogo de carga
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Conectando con Mercado Pago...'),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // Intercambiamos el código por un token
        final success = await _mpService.exchangeCodeForToken(code);

        if (mounted) {
          Navigator.of(context).pop(); // Cerrar diálogo de carga

          if (success) {
            Navigator.of(context).pop(true); // Volver con éxito
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('¡Conexión con Mercado Pago exitosa!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          } else {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error al obtener el token de acceso'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conectar con Mercado Pago'),
        elevation: 0,
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Cargando...'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
