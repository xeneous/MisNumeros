import 'package:shared_preferences/shared_preferences.dart';

class MercadoPagoService {
  // Credenciales de prueba para el flujo de autorización de usuarios (OAuth)
  // DEBES REEMPLAZAR ESTOS VALORES con los que te dio Mercado Pago
  final String _clientId = 'TU_CLIENT_ID'; // <-- Pega aquí tu Client ID
  final String _clientSecret =
      'TU_CLIENT_SECRET'; // <-- Pega aquí tu Client Secret

  // Esta es la URL a la que Mercado Pago redirigirá al usuario. Debe coincidir con la que configuraste en el panel de MP.
  final String _redirectUri = 'https://daybyday.app/mp-callback';

  String getAuthorizationUrl() {
    final url =
        'https://auth.mercadopago.com.ar/authorization'
        '?client_id=$_clientId'
        '&response_type=code'
        '&platform_id=mp'
        '&redirect_uri=$_redirectUri';
    print('Generated MP Auth URL: $url'); // Línea añadida para depuración
    return url;
  }

  // TODO: Implementar el intercambio de código por token
  Future<void> exchangeCodeForToken(String code) async {
    // Aquí irá la llamada HTTP POST para obtener el access_token
    // y guardarlo en SharedPreferences.
    print('Código de autorización recibido: $code');
    // Ejemplo de guardado:
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.setString('mp_access_token', 'EL_TOKEN_RECIBIDO');
    // await prefs.setString('mp_refresh_token', 'EL_REFRESH_TOKEN');
  }

  // TODO: Implementar la función para obtener los pagos
  Future<void> fetchPayments() async {}
}
