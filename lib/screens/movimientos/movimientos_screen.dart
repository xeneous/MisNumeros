import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/sample_data_service.dart';
import '../../models/tipo_movimiento.dart';

class MovimientosScreen extends StatefulWidget {
  const MovimientosScreen({super.key});

  @override
  State<MovimientosScreen> createState() => _MovimientosScreenState();
}

class _MovimientosScreenState extends State<MovimientosScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final SampleDataService _sampleDataService = SampleDataService();

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.user;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Movimientos'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddMovimientoDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadSampleData(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumen de tablas
            _buildSummaryCards(),
            const SizedBox(height: 24),

            // Gestión de tablas
            _buildManagementSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📊 Resumen del Sistema',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Movimientos',
                Icons.account_balance_wallet,
                Colors.blue,
                'Sistema de movimientos implementado',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Gastos',
                Icons.money_off,
                Colors.red,
                'Gestión de gastos por periodicidad',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Contactos',
                Icons.people,
                Colors.green,
                'Lista de contactos para transacciones',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Conceptos',
                Icons.category,
                Colors.orange,
                'Catálogo de conceptos',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    IconData icon,
    Color color,
    String description,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
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
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '⚙️ Gestión de Tablas',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildManagementButton(
          'Gestionar Movimientos',
          Icons.account_balance_wallet,
          Colors.blue,
          () => _showMovimientosList(context),
        ),
        const SizedBox(height: 8),
        _buildManagementButton(
          'Gestionar Gastos',
          Icons.money_off,
          Colors.red,
          () => _showGastosList(context),
        ),
        const SizedBox(height: 8),
        _buildManagementButton(
          'Gestionar Contactos',
          Icons.people,
          Colors.green,
          () => _showContactosList(context),
        ),
        const SizedBox(height: 8),
        _buildManagementButton(
          'Gestionar Conceptos',
          Icons.category,
          Colors.orange,
          () => _showConceptosList(context),
        ),
        const SizedBox(height: 8),
        _buildManagementButton(
          'Tipos de Movimiento',
          Icons.swap_horiz,
          Colors.purple,
          () => _showTiposMovimientoList(context),
        ),
        const SizedBox(height: 8),
        _buildManagementButton(
          'Periodicidades',
          Icons.schedule,
          Colors.teal,
          () => _showPeriodicidadesList(context),
        ),
        const SizedBox(height: 8),
        _buildManagementButton(
          'Operaciones',
          Icons.work,
          Colors.indigo,
          () => _showOperacionesList(context),
        ),
      ],
    );
  }

  Widget _buildUserManagementSection() {
    return _buildManagementButton(
      'Gestionar Usuarios',
      Icons.supervised_user_circle,
      Colors.cyan,
      () => _showUsuariosList(context),
    );
  }

  Widget _buildManagementButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showAddMovimientoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Movimiento'),
        content: const Text(
          'Funcionalidad para agregar movimientos - Próximamente',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMovimientosList(BuildContext context) async {
    try {
      final movimientos = await _databaseService.getMovimientos(
        'default_wallet',
      );

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Lista de Movimientos'),
          content: SizedBox(
            width: double.maxFinite,
            child: movimientos.isEmpty
                ? const Text(
                    'No hay movimientos registrados.\nPresiona el botón de refresh para cargar datos de ejemplo.',
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: movimientos.length,
                    itemBuilder: (context, index) {
                      final movimiento = movimientos[index];
                      return ListTile(
                        title: Text(
                          '${movimiento.concepto} - \$${movimiento.importe}',
                        ),
                        subtitle: Text(
                          '${movimiento.fecha.toString().split(' ')[0]} - ${movimiento.contacto ?? 'Sin contacto'}',
                        ),
                        leading: Icon(
                          movimiento.codigoMovimiento == 'ING'
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: movimiento.codigoMovimiento == 'ING'
                              ? Colors.green
                              : Colors.red,
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Error cargando movimientos: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showGastosList(BuildContext context) async {
    try {
      final gastos = await _databaseService.getGastos('default_wallet');

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Lista de Gastos'),
          content: SizedBox(
            width: double.maxFinite,
            child: gastos.isEmpty
                ? const Text(
                    'No hay gastos registrados.\nPresiona el botón de refresh para cargar datos de ejemplo.',
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: gastos.length,
                    itemBuilder: (context, index) {
                      final gasto = gastos[index];
                      return ListTile(
                        title: Text('${gasto.concepto} - \$${gasto.importe}'),
                        subtitle: Text(
                          '${gasto.fecha.toString().split(' ')[0]} - ${gasto.periodicidad}',
                        ),
                        leading: const Icon(Icons.money_off, color: Colors.red),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Error cargando gastos: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showContactosList(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;

    if (currentUser == null) return;

    try {
      final contactos = await _databaseService.getContactos(
        // Removed the extra `await`
        (await _databaseService.getUsuarioByEmail(
              currentUser.email,
            ))?.idUsuario ??
            0,
      );

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Lista de Contactos'),
          content: SizedBox(
            width: double.maxFinite,
            child: contactos.isEmpty
                ? const Text(
                    'No hay contactos registrados.\nPresiona el botón de refresh para cargar datos de ejemplo.',
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: contactos.length,
                    itemBuilder: (context, index) {
                      final contacto = contactos[index];
                      return ListTile(
                        title: Text(contacto.nombre),
                        subtitle: Text(
                          contacto.email ??
                              contacto.telefono ??
                              'Sin datos adicionales',
                        ),
                        leading: const Icon(Icons.person, color: Colors.blue),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Error cargando contactos: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showUsuariosList(BuildContext context) async {
    try {
      final usuarios = await _databaseService.getAllUsuarios();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Lista de Usuarios (Tabla Local)'),
          content: SizedBox(
            width: double.maxFinite,
            child: usuarios.isEmpty
                ? const Text('No hay usuarios registrados en la tabla local.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: usuarios.length,
                    itemBuilder: (context, index) {
                      final usuario = usuarios[index];
                      return ListTile(
                        title: Text(
                          'Alias: ${usuario.alias}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'ID: ${usuario.idUsuario} | Email: ${usuario.email}',
                        ),
                        leading: CircleAvatar(
                          child: Text(usuario.idUsuario.toString()),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando usuarios: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showConceptosList(BuildContext context) async {
    try {
      final conceptos = await _databaseService.getConceptos();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Lista de Conceptos'),
          content: SizedBox(
            width: double.maxFinite,
            child: conceptos.isEmpty
                ? const Text(
                    'No hay conceptos registrados.\nPresiona el botón de refresh para cargar datos de ejemplo.',
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: conceptos.length,
                    itemBuilder: (context, index) {
                      final concepto = conceptos[index];
                      return ListTile(
                        title: Text(concepto.concepto),
                        subtitle: Text(concepto.descripcion),
                        leading: const Icon(
                          Icons.category,
                          color: Colors.orange,
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Error cargando conceptos: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showTiposMovimientoList(BuildContext context) async {
    try {
      final tiposMovimiento = await _databaseService.getTiposMovimiento();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Tipos de Movimiento'),
          content: SizedBox(
            width: double.maxFinite,
            child: tiposMovimiento.isEmpty
                ? const Text(
                    'No hay tipos de movimiento registrados.\nPresiona el botón de refresh para cargar datos de ejemplo.',
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: tiposMovimiento.length,
                    itemBuilder: (context, index) {
                      final tipoMovimiento = tiposMovimiento[index];
                      return ListTile(
                        title: Text(tipoMovimiento.codigoMovimiento),
                        subtitle: Text(tipoMovimiento.descripcion),
                        leading: Icon(
                          tipoMovimiento.signo == SignoMovimiento.ingreso
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: tipoMovimiento.signo == SignoMovimiento.ingreso
                              ? Colors.green
                              : Colors.red,
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Error cargando tipos de movimiento: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showPeriodicidadesList(BuildContext context) async {
    try {
      final periodicidades = await _databaseService.getPeriodicidades();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Periodicidades'),
          content: SizedBox(
            width: double.maxFinite,
            child: periodicidades.isEmpty
                ? const Text(
                    'No hay periodicidades registradas.\nPresiona el botón de refresh para cargar datos de ejemplo.',
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: periodicidades.length,
                    itemBuilder: (context, index) {
                      final periodicidad = periodicidades[index];
                      return ListTile(
                        title: Text(periodicidad.codigo),
                        subtitle: Text(periodicidad.descripcion),
                        leading: const Icon(Icons.schedule, color: Colors.teal),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Error cargando periodicidades: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showOperacionesList(BuildContext context) async {
    try {
      final operaciones = await _databaseService.getOperaciones();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Operaciones'),
          content: SizedBox(
            width: double.maxFinite,
            child: operaciones.isEmpty
                ? const Text(
                    'No hay operaciones registradas.\nPresiona el botón de refresh para cargar datos de ejemplo.',
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: operaciones.length,
                    itemBuilder: (context, index) {
                      final operacion = operaciones[index];
                      return ListTile(
                        title: Text(operacion.operacion),
                        subtitle: Text(operacion.descripcion),
                        leading: const Icon(Icons.work, color: Colors.indigo),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Error cargando operaciones: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _loadSampleData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _sampleDataService.insertSampleData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datos de ejemplo cargados correctamente'),
          backgroundColor: Colors.green,
        ),
      );

      // Recargar la pantalla para mostrar los nuevos datos
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando datos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
