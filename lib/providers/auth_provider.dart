import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../models/usuario.dart' as db_user;
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
    try {
      // 1. Try to get user from local DB first for speed
      final db_user.Usuario? localUser = await _dbService.getUsuarioByEmail(
        firebaseUser.email!,
      );
      if (localUser != null) {
        _user = User.fromUsuario(localUser, firebaseUser);
        notifyListeners(); // Notify early with local data
      }

      // 2. Then, try to get user from Firestore to get the latest data
      final firestoreUser = await _dbService.getUserFromFirestore(
        firebaseUser.uid,
      );
      if (firestoreUser != null) {
        _user = firestoreUser;
        // Sync Firestore data with local DB if it was fetched
        await _dbService.createOrUpdateUserFromAppUser(firestoreUser);
      } else {
        // 3. If not in Firestore and wasn't in local DB, create a basic user
        _user ??= User.fromFirebaseUser(firebaseUser);
      }
    } catch (e) {
      // Fallback to basic user from Firebase if loading fails
      _user ??= User.fromFirebaseUser(firebaseUser);
    } finally {
      // Ensure user is not null if firebaseUser is not null
      _user ??= User.fromFirebaseUser(firebaseUser);
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
      final firebaseUser = await _authService
          .signInWithGoogleAndGetFirebaseUser();
      if (firebaseUser != null) {
        await _loadUserFromFirebase(firebaseUser);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        notifyListeners();
        return false;
      }
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
        await _loadUserFromFirebase(firebaseUser);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      // If user is null, it's a failure, but we must stop loading.
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
        await _loadUserFromFirebase(
          firebaseUser, // This will load the user data correctly
        ); // This will load the user data correctly
        _isLoading = false;
        notifyListeners();
        return true;
      }
      // If user is null, it's a failure, but we must stop loading.
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
