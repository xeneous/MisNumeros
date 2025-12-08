import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user.dart' as app_user;

/// Service for Supabase authentication
class SupabaseAuthService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get current session
  Session? get currentSession => _client.auth.currentSession;

  /// Get current user
  User? get currentUser => _client.auth.currentUser;

  /// Stream of auth state changes
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Sign in with email and password
  Future<app_user.User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        return await _getUserFromSupabase(response.user!.id);
      }
      return null;
    } catch (e) {
      print('Sign in error: $e');
      rethrow;
    }
  }

  /// Register with email and password
  Future<app_user.User?> registerWithEmailAndPassword(
    String email,
    String password,
    String alias,
  ) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Create user profile in public.users table
        await _client.from('users').insert({
          'id': response.user!.id,
          'email': email,
          'alias': alias,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        return app_user.User(
          id: response.user!.id,
          email: email,
          alias: alias,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
      return null;
    } catch (e) {
      print('Registration error: $e');
      rethrow;
    }
  }

  /// Sign in with Google
  Future<app_user.User?> signInWithGoogle() async {
    try {
      final response = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.posicion://login-callback',
      );

      if (response) {
        // Wait for the auth state to update
        await Future.delayed(const Duration(seconds: 2));
        final user = currentUser;
        if (user != null) {
          return await _getUserFromSupabase(user.id);
        }
      }
      return null;
    } catch (e) {
      print('Google sign in error: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
      rethrow;
    }
  }

  /// Reset password
  Future<bool> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      print('Password reset error: $e');
      return false;
    }
  }

  /// Get user from Supabase public.users table
  Future<app_user.User?> _getUserFromSupabase(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      return app_user.User(
        id: response['id'],
        email: response['email'],
        alias: response['alias'],
        displayName: response['display_name'],
        profileImageUrl: response['profile_image_url'],
        birthDate: response['birth_date'] != null
            ? DateTime.parse(response['birth_date'])
            : null,
        createdAt: DateTime.parse(response['created_at']),
        updatedAt: DateTime.parse(response['updated_at']),
      );
    } catch (e) {
      print('Error getting user from Supabase: $e');
      
      // If user doesn't exist in public.users, create it from auth.users
      final authUser = currentUser;
      if (authUser != null && authUser.id == userId) {
        await _client.from('users').insert({
          'id': userId,
          'email': authUser.email,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        return app_user.User(
          id: userId,
          email: authUser.email ?? '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
      return null;
    }
  }

  /// Update user profile
  Future<void> updateUserProfile(app_user.User user) async {
    try {
      await _client.from('users').update({
        'alias': user.alias,
        'display_name': user.displayName,
        'profile_image_url': user.profileImageUrl,
        'birth_date': user.birthDate?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }
}
