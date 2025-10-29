/*
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../services/mercado_pago_service.dart';

class MercadoPagoAuthScreen extends StatefulWidget {
  const MercadoPagoAuthScreen({super.key});

  @override
  State<MercadoPagoAuthScreen> createState() => _MercadoPagoAuthScreenState();
}

class _MercadoPagoAuthScreenState extends State<MercadoPagoAuthScreen> {
  late final WebViewController _controller;
  final _mpService = MercadoPagoService();

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            // Escuchamos la URL de redirección
            if (request.url.startsWith('https://daybyday.app/mp-callback')) {
              final uri = Uri.parse(request.url);
              final code = uri.queryParameters['code'];
              if (code != null) {
                // Tenemos el código, ahora lo intercambiamos por un token
                _mpService.exchangeCodeForToken(code).then((_) {
                  // Una vez completado, volvemos a la pantalla anterior
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('¡Conexión con Mercado Pago exitosa!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                });
              }
              return NavigationDecision.prevent; // Detenemos la navegación
            }
            return NavigationDecision.navigate; // Permitimos otras navegaciones
          },
        ),
      )
      ..loadRequest(Uri.parse(_mpService.getAuthorizationUrl()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conectar con Mercado Pago')),
      body: WebViewWidget(controller: _controller),
    );
  }
}
*/
