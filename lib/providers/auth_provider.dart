import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user.dart' as app_user;
import '../services/supabase_auth_service.dart';

/// Provider for managing authentication state with Supabase
class AuthProvider with ChangeNotifier {
  final SupabaseAuthService _authService = SupabaseAuthService();
  
  app_user.User? _user;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  app_user.User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;

  AuthProvider() {
    _initializeAuthListener();
    initialize(); // Auto-initialize when provider is created
  }

  /// Initialize auth state listener
  void _initializeAuthListener() {
    _authService.authStateChanges.listen((AuthState data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        _loadUserFromSupabase(data.session?.user.id);
      } else if (event == AuthChangeEvent.signedOut) {
        _user = null;
        notifyListeners();
      }
    });
  }

  /// Load user from Supabase when authenticated
  Future<void> _loadUserFromSupabase(String? userId) async {
    if (userId == null) return;
    
    try {
      final user = await _authService.getUserFromSupabase(userId);
      if (user != null) {
        _user = user;
        notifyListeners();
      }
    } catch (e) {
    }
  }

  /// Initialize the provider
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Check if user is already logged in
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        await _loadUserFromSupabase(currentUser.id);
      }
      
      _isInitialized = true;
    } catch (e) {
      _error = 'Error al inicializar: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        _user = user;
        _isLoading = false;
        notifyListeners();
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

  /// Sign in with email and password
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _authService.signInWithEmailAndPassword(email, password);
      if (user != null) {
        _user = user;
        _isLoading = false;
        notifyListeners();
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

  /// Register with email and password
  Future<bool> registerWithEmailAndPassword(
    String alias,
    String email,
    String password,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _authService.registerWithEmailAndPassword(
        email,
        password,
        alias,
      );
      
      if (user != null) {
        _user = user;
        _isLoading = false;
        notifyListeners();
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

  /// Sign out
  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    notifyListeners();
  }

  /// Update user profile
  Future<void> updateUser(app_user.User newUser) async {
    await _authService.updateUserProfile(newUser);
    _user = newUser;
    notifyListeners();
  }

  /// Reload user data
  Future<void> reloadUser() async {
    if (_user == null) return;
    
    try {
      final updatedUser = await _authService.getUserFromSupabase(_user!.id);
      if (updatedUser != null) {
        _user = updatedUser;
        notifyListeners();
      }
    } catch (e) {
    }
  }

  /// Reset password
  Future<bool> resetPassword(String email) async {
    try {
      return await _authService.resetPassword(email);
    } catch (e) {
      _error = _getErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Get user-friendly error message
  String _getErrorMessage(String error) {
    final errorLower = error.toLowerCase();
    
    // PostgreSQL/RLS errors
    if (errorLower.contains('requested path is invalid') || 
        errorLower.contains('row level security') ||
        errorLower.contains('permission denied for table')) {
      return 'Error de configuración de base de datos. Por favor contacta al administrador.';
    }
    
    // Supabase auth errors
    if (errorLower.contains('invalid login credentials')) {
      return 'Email o contraseña incorrectos';
    } else if (errorLower.contains('email not confirmed')) {
      return 'Email no confirmado. Verifica tu correo o contacta al administrador.';
    } else if (errorLower.contains('user already registered')) {
      return 'Este email ya está registrado';
    } else if (errorLower.contains('weak-password')) {
      return 'La contraseña es muy débil';
    } else if (errorLower.contains('email-already-in-use')) {
      return 'Este email ya está en uso';
    } else if (errorLower.contains('network')) {
      return 'Error de conexión. Verifica tu internet';
    }
    
    // For debugging: show the actual error
    return 'Error: $error';
  }
}
