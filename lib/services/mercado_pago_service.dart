import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction.dart';
import '../models/account.dart';
import 'database_service.dart';

/// Servicio completo para integración con Mercado Pago
/// Permite autorización OAuth, sincronización de pagos y gestión de tokens
class MercadoPagoService {
  // Almacenamiento seguro para tokens sensibles
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // Keys para almacenamiento
  static const String _accessTokenKey = 'mp_access_token';
  static const String _refreshTokenKey = 'mp_refresh_token';
  static const String _tokenExpiryKey = 'mp_token_expiry';
  static const String _userIdKey = 'mp_user_id';
  static const String _lastSyncKey = 'mp_last_sync';

  // Credenciales de la app (DEBEN SER CONFIGURADAS)
  final String clientId;
  final String clientSecret;
  final String redirectUri;

  // URLs de Mercado Pago API
  static const String _authBaseUrl = 'https://auth.mercadopago.com.ar';
  static const String _apiBaseUrl = 'https://api.mercadopago.com';
  static const String _oauthBaseUrl = 'https://api.mercadopago.com';

  final DatabaseService _dbService = DatabaseService();

  MercadoPagoService({
    this.clientId = '554098150836586',
    this.clientSecret = '8KjjudfLi5EIwwok7vIZJ5DguOyXwHtN',
    this.redirectUri = 'https://misnumeros.app/mp-callback',
  });

  /// Verifica si las credenciales están configuradas
  bool get isConfigured =>
      clientId != 'TU_CLIENT_ID' &&
      clientSecret != 'TU_CLIENT_SECRET';

  /// Genera la URL de autorización OAuth para Mercado Pago
  String getAuthorizationUrl() {
    return '$_authBaseUrl/authorization'
        '?client_id=$clientId'
        '&response_type=code'
        '&platform_id=mp'
        '&redirect_uri=$redirectUri';
  }

  /// Intercambia el código de autorización por tokens de acceso
  Future<bool> exchangeCodeForToken(String code) async {
    try {
      final response = await http.post(
        Uri.parse('$_oauthBaseUrl/oauth/token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'client_id': clientId,
          'client_secret': clientSecret,
          'code': code,
          'grant_type': 'authorization_code',
          'redirect_uri': redirectUri,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Guardar tokens de forma segura
        await _saveTokens(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
          expiresIn: data['expires_in'],
          userId: data['user_id']?.toString(),
        );

        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Guarda los tokens de forma segura
  Future<void> _saveTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
    String? userId,
  }) async {
    try {
      final expiryDate = DateTime.now().add(Duration(seconds: expiresIn));

      print('💾 Guardando tokens...');
      await _secureStorage.write(key: _accessTokenKey, value: accessToken);
      await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenExpiryKey, expiryDate.toIso8601String());

      if (userId != null) {
        await prefs.setString(_userIdKey, userId);
      }

      print('✅ Tokens guardados correctamente');
      print('📅 Expira: ${expiryDate.toString()}');
    } catch (e) {
      print('❌ Error al guardar tokens: $e');
      rethrow;
    }
  }

  /// Obtiene el access token, refrescándolo si es necesario
  Future<String?> getAccessToken() async {
    // Verificar si el token está expirado
    final prefs = await SharedPreferences.getInstance();
    final expiryString = prefs.getString(_tokenExpiryKey);

    if (expiryString != null) {
      final expiryDate = DateTime.parse(expiryString);

      // Si expira en menos de 5 minutos, refrescar
      if (DateTime.now().add(const Duration(minutes: 5)).isAfter(expiryDate)) {
        await _refreshAccessToken();
      }
    }

    return await _secureStorage.read(key: _accessTokenKey);
  }

  /// Refresca el access token usando el refresh token
  Future<bool> _refreshAccessToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      if (refreshToken == null) return false;

      final response = await http.post(
        Uri.parse('$_oauthBaseUrl/oauth/token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'client_id': clientId,
          'client_secret': clientSecret,
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        await _saveTokens(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
          expiresIn: data['expires_in'],
        );

        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Verifica si el usuario está conectado a Mercado Pago
  Future<bool> isConnected() async {
    try {
      final token = await _secureStorage.read(key: _accessTokenKey);

      if (token == null || token.isEmpty) {
        print('🔍 No hay token guardado');
        return false;
      }

      print('✅ Token encontrado en almacenamiento');

      // Verificar si el token está expirado
      final prefs = await SharedPreferences.getInstance();
      final expiryString = prefs.getString(_tokenExpiryKey);

      if (expiryString != null) {
        final expiryDate = DateTime.parse(expiryString);

        // Si el token está a punto de expirar (menos de 5 minutos), intentar refrescarlo
        if (DateTime.now().isAfter(expiryDate.subtract(const Duration(minutes: 5)))) {
          print('⚠️ Token próximo a expirar, refrescando...');
          final refreshed = await _refreshAccessToken();
          return refreshed;
        }
      }

      return true;
    } catch (e) {
      print('❌ Error al verificar conexión: $e');
      return false;
    }
  }

  /// Desconecta la cuenta de Mercado Pago
  Future<void> disconnect() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenExpiryKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_lastSyncKey);
  }

  /// Obtiene los pagos del día actual desde Mercado Pago
  Future<List<Map<String, dynamic>>> fetchTodayPayments() async {
    final accessToken = await getAccessToken();
    if (accessToken == null) {
      print('❌ No hay access token para buscar pagos');
      return [];
    }

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Convertir a formato ISO 8601 con zona horaria
      final startDateStr = '${startOfDay.toIso8601String()}Z';
      final endDateStr = '${endOfDay.toIso8601String()}Z';

      final url = '$_apiBaseUrl/v1/payments/search'
          '?begin_date=${Uri.encodeComponent(startDateStr)}'
          '&end_date=${Uri.encodeComponent(endDateStr)}'
          '&sort=date_created'
          '&criteria=desc';

      print('🔍 Buscando pagos...');
      print('📍 URL: $url');
      print('📅 Desde: $startDateStr');
      print('📅 Hasta: $endDateStr');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      print('📊 Status Code: ${response.statusCode}');
      print('📄 Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = List<Map<String, dynamic>>.from(data['results'] ?? []);
        print('✅ Pagos encontrados: ${results.length}');
        return results;
      } else {
        print('❌ Error ${response.statusCode}: ${response.body}');
      }

      return [];
    } catch (e) {
      print('❌ Excepción al buscar pagos: $e');
      return [];
    }
  }

  /// Obtiene pagos en un rango de fechas específico
  Future<List<Map<String, dynamic>>> fetchPaymentsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final accessToken = await getAccessToken();
    if (accessToken == null) {
      print('❌ No hay access token para buscar pagos por rango');
      return [];
    }

    try {
      // Convertir a formato ISO 8601 con zona horaria
      final startDateStr = '${startDate.toIso8601String()}Z';
      final endDateStr = '${endDate.toIso8601String()}Z';

      final url = '$_apiBaseUrl/v1/payments/search'
          '?begin_date=${Uri.encodeComponent(startDateStr)}'
          '&end_date=${Uri.encodeComponent(endDateStr)}'
          '&sort=date_created'
          '&criteria=desc';

      print('🔍 Buscando pagos por rango...');
      print('📍 URL: $url');
      print('📅 Desde: $startDateStr');
      print('📅 Hasta: $endDateStr');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      print('📊 Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = List<Map<String, dynamic>>.from(data['results'] ?? []);
        print('✅ Pagos encontrados en rango: ${results.length}');
        if (results.isNotEmpty) {
          print('📋 Primer pago: ${results.first['description'] ?? 'Sin descripción'}');
        }
        return results;
      } else {
        print('❌ Error ${response.statusCode}: ${response.body}');
      }

      return [];
    } catch (e) {
      print('❌ Excepción al buscar pagos por rango: $e');
      return [];
    }
  }

  /// Sincroniza los pagos de Mercado Pago con las transacciones locales
  Future<int> syncPaymentsToTransactions({
    String? defaultAccountId,
    String appUserId = '',
  }) async {
    if (!await isConnected()) return 0;

    try {
      // Obtener pagos del día
      final payments = await fetchTodayPayments();
      if (payments.isEmpty) return 0;

      // Obtener o crear cuenta de Mercado Pago
      final accounts = await _dbService.getAccounts();

      Account? mpAccount;
      if (defaultAccountId != null) {
        mpAccount = accounts.firstWhere(
          (acc) => acc.id == defaultAccountId,
          orElse: () => accounts.first,
        );
      }

      // Si no hay cuenta específica, buscar una cuenta digital para MP
      if (mpAccount == null) {
        mpAccount = accounts.firstWhere(
          (acc) => acc.name.toLowerCase().contains('mercado pago') ||
                   acc.name.toLowerCase().contains('mercadopago'),
          orElse: () => accounts.firstWhere(
            (acc) => acc.type == AccountType.digital,
            orElse: () => accounts.first,
          ),
        );
      }

      int syncedCount = 0;

      for (final payment in payments) {
        // Verificar si ya existe una transacción con este payment_id
        final existingTransactions = await _dbService.getTransactions();
        final alreadyExists = existingTransactions.any(
          (t) => t.description?.contains('MP#${payment['id']}') ?? false,
        );

        if (!alreadyExists) {
          // Crear transacción desde el pago
          final transaction = _mapPaymentToTransaction(
            payment,
            mpAccount.id,
            appUserId,
          );

          await _dbService.insertTransaction(transaction);
          syncedCount++;
        }
      }

      // Actualizar última fecha de sincronización
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

      return syncedCount;
    } catch (e) {
      return 0;
    }
  }

  /// Sincroniza pagos específicos de Mercado Pago con las transacciones locales
  Future<int> syncSpecificPayments({
    required List<Map<String, dynamic>> payments,
    String? defaultAccountId,
    String appUserId = '',
  }) async {
    if (!await isConnected()) return 0;

    try {
      if (payments.isEmpty) return 0;

      // Obtener o crear cuenta de Mercado Pago
      final accounts = await _dbService.getAccounts();

      Account? mpAccount;
      if (defaultAccountId != null) {
        mpAccount = accounts.firstWhere(
          (acc) => acc.id == defaultAccountId,
          orElse: () => accounts.first,
        );
      }

      // Si no hay cuenta específica, buscar una cuenta digital para MP
      if (mpAccount == null) {
        mpAccount = accounts.firstWhere(
          (acc) => acc.name.toLowerCase().contains('mercado pago') ||
                   acc.name.toLowerCase().contains('mercadopago'),
          orElse: () => accounts.firstWhere(
            (acc) => acc.type == AccountType.digital,
            orElse: () => accounts.first,
          ),
        );
      }

      int syncedCount = 0;

      for (final payment in payments) {
        // Verificar si ya existe una transacción con este payment_id
        final existingTransactions = await _dbService.getTransactions();
        final alreadyExists = existingTransactions.any(
          (t) => t.description?.contains('MP#${payment['id']}') ?? false,
        );

        if (!alreadyExists) {
          // Crear transacción desde el pago
          final transaction = _mapPaymentToTransaction(
            payment,
            mpAccount.id,
            appUserId,
          );

          await _dbService.insertTransaction(transaction);
          syncedCount++;
        }
      }

      // Actualizar última fecha de sincronización
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

      return syncedCount;
    } catch (e) {
      return 0;
    }
  }

  /// Mapea un pago de Mercado Pago a una transacción local
  Transaction _mapPaymentToTransaction(
    Map<String, dynamic> payment,
    String accountId,
    String userId,
  ) {
    // Determinar si es ingreso o gasto
    // En MP, transaction_amount positivo = dinero recibido
    final amount = (payment['transaction_amount'] as num).toDouble();
    final isIncome = amount > 0;

    // Extraer información relevante
    final description = payment['description'] ??
                       payment['additional_info']?['items']?[0]?['title'] ??
                       'Pago de Mercado Pago';

    final paymentId = payment['id'].toString();
    final dateCreated = DateTime.parse(payment['date_created']);

    return Transaction(
      id: '',
      userId: userId,
      transactionTypeId: isIncome ? 1 : 2, // 1 = income, 2 = expense
      type: isIncome ? TransactionType.income : TransactionType.expense,
      accountId: accountId,
      amount: amount.abs(),
      description: '$description (MP#$paymentId)',
      category: _categorizePayment(payment),
      date: dateCreated,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Categoriza un pago basándose en su información
  String? _categorizePayment(Map<String, dynamic> payment) {
    final description = (payment['description'] ?? '').toString().toLowerCase();
    final paymentMethod = (payment['payment_method_id'] ?? '').toString();

    // Categorización básica basada en palabras clave
    if (description.contains('uber') || description.contains('taxi')) {
      return 'Transporte';
    } else if (description.contains('restaurant') ||
               description.contains('comida') ||
               description.contains('food')) {
      return 'Alimentación';
    } else if (description.contains('shop') ||
               description.contains('store') ||
               description.contains('tienda')) {
      return 'Compras';
    } else if (paymentMethod.contains('credit')) {
      return 'Tarjeta de Crédito';
    } else if (paymentMethod.contains('debit')) {
      return 'Tarjeta de Débito';
    }

    return 'Mercado Pago';
  }

  /// Obtiene la última fecha de sincronización
  Future<DateTime?> getLastSyncDate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncString = prefs.getString(_lastSyncKey);

    if (lastSyncString != null) {
      return DateTime.parse(lastSyncString);
    }

    return null;
  }

  /// Obtiene información del usuario de Mercado Pago
  Future<Map<String, dynamic>?> getUserInfo() async {
    final accessToken = await getAccessToken();
    if (accessToken == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/users/me'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
