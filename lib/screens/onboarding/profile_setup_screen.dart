import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/user.dart' as app_user;
import '../../services/database_service.dart';
import '../../providers/auth_provider.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _aliasController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _nationalityController = TextEditingController();

  DateTime? _selectedBirthDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Load current user data into the form fields
    final currentUser = Provider.of<AuthProvider>(context, listen: false).user;
    if (currentUser != null) {
      _aliasController.text = currentUser.alias ?? '';
      _nationalityController.text = currentUser.nationality ?? '';
      if (currentUser.birthDate != null) {
        _selectedBirthDate = currentUser.birthDate;
        _birthDateController.text =
            '${_selectedBirthDate!.day}/${_selectedBirthDate!.month}/${_selectedBirthDate!.year}';
      }
    }
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _birthDateController.dispose();
    _nationalityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.user;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                const Text(
                  'Completa tu perfil',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Solo necesitamos algunos datos básicos para personalizar tu experiencia',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Profile form
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Alias field (required)
                      TextFormField(
                        controller: _aliasController,
                        decoration: InputDecoration(
                          labelText: 'Alias *',
                          hintText: 'Ej: Juan, María, Mi Nombre',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El alias es obligatorio';
                          }
                          if (value.length < 2) {
                            return 'El alias debe tener al menos 2 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Birth date field (optional)
                      TextFormField(
                        controller: _birthDateController,
                        decoration: InputDecoration(
                          labelText: 'Fecha de nacimiento (opcional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.calendar_today),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _birthDateController.clear();
                              setState(() {
                                _selectedBirthDate = null;
                              });
                            },
                          ),
                        ),
                        readOnly: true,
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );

                          if (pickedDate != null) {
                            setState(() {
                              _selectedBirthDate = pickedDate;
                              _birthDateController.text =
                                  '${pickedDate.day}/${pickedDate.month}/${pickedDate.year}';
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 24),

                      // Nationality field (optional)
                      TextFormField(
                        controller: _nationalityController,
                        decoration: InputDecoration(
                          labelText: 'Nacionalidad (opcional)',
                          hintText: 'Ej: Argentina, España, México',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.flag),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Info text
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.privacy_tip,
                                  color: Colors.deepPurple[700],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Privacidad Primero',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Solo solicitamos la información esencial. Puedes cambiar estos datos en cualquier momento desde la configuración.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Continue button
                      ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () async {
                                if (_formKey.currentState!.validate()) {
                                  await _completeProfile(currentUser);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text('Completar Perfil'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _completeProfile(app_user.User? currentUser) async {
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Save to database
      final dbService = DatabaseService();
      final oldUser = await dbService.getUsuarioByEmail(currentUser.email);

      if (oldUser != null) {
        // If user exists, update it
        final updatedOldUser = oldUser.copyWith(
          alias: _aliasController.text.trim(),
          fechaNacimiento: _selectedBirthDate,
          fechaActualizacion: DateTime.now(),
        );
        await dbService.updateUsuario(updatedOldUser);
      } else {
        // If user does not exist in local DB, create it
        await dbService.createInitialUser(
          currentUser.email,
          _aliasController.text.trim(),
        );
      }

      // Update user profile in the provider
      final updatedAppUser = currentUser.copyWith(
        alias: _aliasController.text.trim(),
        birthDate: _selectedBirthDate,
        nationality: _nationalityController.text.trim().isEmpty
            ? null
            : _nationalityController.text.trim(),
        updatedAt: DateTime.now(),
      );

      if (context.mounted) {
        // 1. Update the provider with the new user data
        Provider.of<AuthProvider>(
          context,
          listen: false,
        ).updateUser(updatedAppUser);

        // 2. Update Firestore if available
        try {
          final firestore = FirebaseFirestore.instance;
          await firestore
              .collection('users')
              .doc(currentUser.id)
              .update(updatedAppUser.toMap());
        } catch (e) {
          print('Error updating Firestore: $e');
        }

        // 3. Go back to the previous screen (e.g., settings)
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar perfil: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
