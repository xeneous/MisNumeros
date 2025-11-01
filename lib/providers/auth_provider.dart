import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  User? _user;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _initializeAuthListener();
  }

  // Initialize auth state listener
  void _initializeAuthListener() {
    _authService.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser != null) {
        await _loadUserFromFirebase(firebaseUser);
      } else {
        _user = null;
      }
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    });
  }

  Future<void> _loadUserFromFirebase(firebase_auth.User firebaseUser) async {
    print('AuthProvider: _loadUserFromFirebase para UID ${firebaseUser.uid}');
    try {
      // Paso 1: Usar Firestore como la fuente de verdad para los datos del perfil del usuario.
      print(
        'AuthProvider: Buscando usuario en Firestore con UID ${firebaseUser.uid}',
      );
      User? firestoreUser = await _dbService.getUserFromFirestore(
        firebaseUser.uid,
      );

      // Si el usuario no existe en Firestore, se crea un perfil básico.
      if (firestoreUser != null) {
        print(
          'AuthProvider: Usuario de Firestore encontrado. Actualizando datos.',
        );
        _user = firestoreUser;
      } else {
        print(
          'AuthProvider: No se encontró usuario en Firestore. Creando nuevo perfil...',
        );
        // Crear un objeto User básico a partir de los datos de Firebase Auth.
        final newUser = User.fromFirebaseUser(firebaseUser);
        // Guardar este nuevo usuario en Firestore para persistirlo.
        await _dbService.createOrUpdateUserInFirestore(newUser);
        _user = newUser;
        print('AuthProvider: Nuevo usuario creado en Firestore.');
      }

      // Paso 2: OBTENER/CREAR EL ID NUMÉRICO LOCAL (el "puente").
      // Este es el paso clave para usar un ID numérico en las tablas locales de SQLite.
      // El servicio de base de datos se encarga de crear un registro en la tabla 'usuarios'
      // si no existe, y devolver el ID numérico autoincremental.
      print(
        'AuthProvider: Obteniendo/Creando ID numérico local para las tablas de SQLite...',
      );
      final localId = await _dbService.getOrCreateOldUserId(_user!);
      print('AuthProvider: ID numérico local obtenido: $localId');

      // CRITICAL: Migrate existing data from local ID to Firebase UID
      await _dbService.migrateUserDataToFirebaseUID(_user!.id, localId);
      print(
        'AuthProvider: Data migrated from local ID $localId to Firebase UID ${_user!.id}',
      );

      // Asegurarse de que el objeto User en el provider y en Firestore tengan el ID local.
      if (_user?.localId != localId) {
        _user = _user!.copyWith(localId: localId);
        print(
          'AuthProvider: ID numérico local actualizado en el objeto User del provider.',
        );

        // PASO CRÍTICO: Persistir el nuevo localId en Firestore para futuras instalaciones.
        // Esto evita que se genere un nuevo ID si el usuario reinstala la app.
        await _dbService.createOrUpdateUserInFirestore(_user!);
        print(
          'AuthProvider: ID numérico local ($localId) persistido en Firestore.',
        );
      }

      // Paso 3: Sincronizar el estado final del usuario con la tabla 'usuarios' de SQLite.
      // Esto asegura que los datos como el alias o la foto estén actualizados localmente.
      await _dbService.createOrUpdateUserFromAppUser(_user!);
    } catch (e) {
      // Si hay un error, especialmente de red, es crucial que el usuario pueda seguir usando la app
      // con los datos de autenticación básicos. El localId podría no estar disponible.
      print('AuthProvider: ERROR en _loadUserFromFirebase: $e');
      // Fallback to basic user from Firebase if loading fails
      _user ??= User.fromFirebaseUser(firebaseUser);
    } finally {
      // Final notification to ensure UI is up-to-date
      notifyListeners();
    }
  }

  // Initialize auth state - called from main.dart
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isLoading = true;
    notifyListeners();

    try {
      final firebaseUser = _authService.currentUser;
      if (firebaseUser != null) {
        await _loadUserFromFirebase(firebaseUser);
      }
      // _user = await _authService.getCurrentUser();
    } catch (e) {
      _error = _getErrorMessage(e.toString());
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final firebaseUser = await _authService.signInWithGoogle();
      if (firebaseUser != null) {
        // The auth listener will trigger _loadUserFromFirebase automatically.
        return true;
      }
      // If firebaseUser is null, it means the user cancelled.
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = _getErrorMessage(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Sign in with email and password
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final firebaseUser = await _authService.signInWithEmailAndPassword(
        email,
        password,
      );
      if (firebaseUser != null) {
        // The auth listener will trigger _loadUserFromFirebase automatically.
        return true;
      }
      return false;
    } catch (e) {
      _error = _getErrorMessage(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Register with email and password
  Future<bool> registerWithEmailAndPassword(
    String alias,
    String email,
    String password,
  ) async {
    // alias is kept for now to avoid breaking changes in the UI form, but it's not used.
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final firebaseUser = await _authService.registerWithEmailAndPassword(
        email,
        password,
        alias,
      );
      if (firebaseUser != null) {
        // The auth listener will trigger _loadUserFromFirebase automatically.
        return true;
      }
      return false;
    } catch (e) {
      _error = _getErrorMessage(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    // The auth stream listener will handle the state change automatically.
    _isLoading = true;
    await _authService.signOut();
    _isLoading = false;
  }

  // Manually update the user object in the provider
  void updateUser(User newUser) {
    _user = newUser;
    notifyListeners();
  }

  // Reload user data from the service
  Future<void> reloadUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      final firebaseUser = _authService.currentUser;
      if (firebaseUser != null) {
        await _loadUserFromFirebase(firebaseUser);
      }
      // _user = await _authService.getCurrentUser();
    } catch (e) {
      _error = _getErrorMessage(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    try {
      return await _authService.resetPassword(email);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Helper method to convert Firebase errors to user-friendly messages
  String _getErrorMessage(String error) {
    if (error.contains('user-not-found')) {
      return 'Usuario no encontrado. Verifica tu email.';
    } else if (error.contains('wrong-password')) {
      return 'Contraseña incorrecta.';
    } else if (error.contains('email-already-in-use')) {
      return 'Este email ya está registrado.';
    } else if (error.contains('weak-password')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    } else if (error.contains('invalid-email')) {
      return 'Email inválido.';
    } else if (error.contains('network-request-failed')) {
      return 'Error de conexión. Verifica tu internet.';
    } else if (error.contains('too-many-requests')) {
      return 'Demasiados intentos. Intenta más tarde.';
    } else if (error.contains('user-disabled')) {
      return 'Usuario deshabilitado.';
    } else if (error.contains('cloud_firestore/unavailable')) {
      return 'Servicio de datos temporalmente no disponible. La aplicación funcionará con datos locales.';
    } else if (error.contains('Failed to load FirebaseOptions')) {
      return 'Error de configuración de Firebase. Contacta al soporte.';
    } else {
      return 'Error inesperado. Intenta nuevamente.';
    }
  }
}
