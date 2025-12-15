import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../services/mercado_pago_service.dart';
import '../../providers/auth_provider.dart';
import 'mercado_pago_auth_screen.dart';

/// Pantalla de configuración y gestión de la integración con Mercado Pago
class MercadoPagoSettingsScreen extends StatefulWidget {
  const MercadoPagoSettingsScreen({super.key});

  @override
  State<MercadoPagoSettingsScreen> createState() =>
      _MercadoPagoSettingsScreenState();
}

class _MercadoPagoSettingsScreenState extends State<MercadoPagoSettingsScreen> {
  final _mpService = MercadoPagoService();
  bool _isConnected = false;
  bool _isLoading = true;
  bool _isSyncing = false;
  DateTime? _lastSyncDate;
  Map<String, dynamic>? _userInfo;

  @override
  void initState() {
    super.initState();
    _loadConnectionStatus();
  }

  Future<void> _loadConnectionStatus() async {
    setState(() => _isLoading = true);

    final connected = await _mpService.isConnected();
    final lastSync = await _mpService.getLastSyncDate();

    if (connected) {
      final userInfo = await _mpService.getUserInfo();
      setState(() {
        _userInfo = userInfo;
      });
    }

    setState(() {
      _isConnected = connected;
      _lastSyncDate = lastSync;
      _isLoading = false;
    });
  }

  Future<void> _connectToMercadoPago() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MercadoPagoAuthScreen(),
      ),
    );

    if (result == true) {
      await _loadConnectionStatus();
    }
  }

  Future<void> _disconnectFromMercadoPago() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desconectar Mercado Pago'),
        content: const Text(
          '¿Estás seguro que deseas desconectar tu cuenta de Mercado Pago?\n\n'
          'Las transacciones ya sincronizadas no se eliminarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Desconectar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _mpService.disconnect();
      await _loadConnectionStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuenta de Mercado Pago desconectada'),
          ),
        );
      }
    }
  }

  Future<void> _syncPayments() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.id ?? '';

      final syncedCount = await _mpService.syncPaymentsToTransactions(
        appUserId: userId,
      );

      await _loadConnectionStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              syncedCount > 0
                  ? '¡$syncedCount pago(s) sincronizado(s)!'
                  : 'No hay nuevos pagos para sincronizar',
            ),
            backgroundColor: syncedCount > 0 ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al sincronizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mercado Pago'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header con logo
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[700]!, Colors.blue[500]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        size: 64,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Mercado Pago',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isConnected
                            ? 'Cuenta conectada'
                            : 'No conectado',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // User info card (si está conectado)
                if (_isConnected && _userInfo != null) ...[
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        child: Icon(Icons.person, color: Colors.blue[700]),
                      ),
                      title: Text(
                        _userInfo!['first_name'] ?? 'Usuario',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(_userInfo!['email'] ?? ''),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Last sync info
                if (_isConnected && _lastSyncDate != null) ...[
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.sync, color: Colors.green[700]),
                      title: const Text('Última sincronización'),
                      subtitle: Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(_lastSyncDate!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Connection button
                if (!_isConnected) ...[
                  ElevatedButton.icon(
                    onPressed: _connectToMercadoPago,
                    icon: const Icon(Icons.link),
                    label: const Text('Conectar con Mercado Pago'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Info card
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Text(
                                'Beneficios de conectar',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildBenefitRow('Sincronización automática de pagos'),
                          _buildBenefitRow('Categorización inteligente'),
                          _buildBenefitRow('Historial completo de transacciones'),
                          _buildBenefitRow('Actualización en tiempo real'),
                        ],
                      ),
                    ),
                  ),
                ],

                // Sync and disconnect buttons (si está conectado)
                if (_isConnected) ...[
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.pushNamed(
                        context,
                        '/mercado-pago-payments',
                      );
                      if (result == true) {
                        await _loadConnectionStatus();
                      }
                    },
                    icon: const Icon(Icons.list_alt),
                    label: const Text('Ver Todos los Pagos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isSyncing ? null : _syncPayments,
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.sync),
                    label: Text(_isSyncing ? 'Sincronizando...' : 'Sincronizar Rápido'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _disconnectFromMercadoPago,
                    icon: const Icon(Icons.link_off),
                    label: const Text('Desconectar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Help section
                Card(
                  child: ExpansionTile(
                    leading: Icon(Icons.help_outline, color: Colors.grey[700]),
                    title: const Text('¿Cómo funciona?'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHelpStep(
                              '1',
                              'Conecta tu cuenta',
                              'Autoriza la app para acceder a tu información de Mercado Pago',
                            ),
                            const SizedBox(height: 12),
                            _buildHelpStep(
                              '2',
                              'Sincroniza tus pagos',
                              'La app descargará automáticamente tus pagos del día',
                            ),
                            const SizedBox(height: 12),
                            _buildHelpStep(
                              '3',
                              'Revisa tus transacciones',
                              'Los pagos aparecerán en tu cuenta de Mercado Pago',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBenefitRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildHelpStep(String number, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.blue[700],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
