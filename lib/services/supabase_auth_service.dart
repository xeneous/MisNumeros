import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
        return await getUserFromSupabase(response.user!.id);
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
        // Note: User profile in public.users is created automatically by trigger
        // We need to update the alias since the trigger only sets email
        print('User registered successfully: ${response.user!.id}');
        
        // Wait a moment for the trigger to complete
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Update the alias
        await _client.from('users').update({
          'alias': alias,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', response.user!.id);

        // Fetch the complete user profile
        final user = await getUserFromSupabase(response.user!.id);
        if (user != null) {
          return user;
        }
        
        // Fallback if getUserFromSupabase fails
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

  /// Sign in with Google using native Google Sign-In
  /// Uses the access token instead of ID token to avoid audience validation
  Future<app_user.User?> signInWithGoogle() async {
    try {
      print('Supabase: Starting native Google Sign-In...');

      // Configure Google Sign-In with Web Client ID
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: '977281610510-ts0oe13aj54973cdthnr9nr2kul7qv98.apps.googleusercontent.com',
        scopes: ['email', 'profile', 'openid'],
      );

      // Trigger Google Sign-In
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        print('Supabase: Google Sign-In cancelled by user');
        return null;
      }

      print('Supabase: Google user selected: ${googleUser.email}');

      // Get authentication tokens
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      if (idToken == null || accessToken == null) {
        throw Exception('No tokens from Google Sign-In');
      }

      print('Supabase: Got tokens, authenticating with Supabase...');

      // Try signInWithIdToken WITHOUT the nonce parameter
      // The key is to not pass nonce at all, not to pass it as empty
      final AuthResponse response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
        // Do NOT include nonce parameter at all
      );

      print('Supabase: Authentication response received');

      if (response.user != null) {
        print('Supabase: User authenticated: ${response.user!.id}');

        // Get or create user in public.users table
        final appUser = await getUserFromSupabase(response.user!.id);

        if (appUser == null) {
          // Create user if doesn't exist
          print('Supabase: Creating new user profile...');
          await _client.from('users').insert({
            'id': response.user!.id,
            'email': response.user!.email ?? googleUser.email,
            'display_name': response.user!.userMetadata?['full_name'] ?? googleUser.displayName ?? 'Usuario',
            'avatar_url': response.user!.userMetadata?['avatar_url'] ?? googleUser.photoUrl,
            'created_at': DateTime.now().toIso8601String(),
          });

          return await getUserFromSupabase(response.user!.id);
        }

        return appUser;
      }

      print('Supabase: No user in response');
      return null;
    } catch (e) {
      print('Supabase Google sign in error: $e');
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
  Future<app_user.User?> getUserFromSupabase(String userId) async {
    try {
      print('Fetching user from Supabase: $userId');
      final response = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      print('User data received: $response');
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
      print('❌ Error getting user from Supabase: $e');
      print('Error type: ${e.runtimeType}');
      
      // Check for specific PostgreSQL/RLS errors
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('requested path is invalid') || 
          errorString.contains('row level security') ||
          errorString.contains('permission denied')) {
        print('⚠️  RLS Error detected: La tabla users no tiene las políticas de seguridad configuradas.');
        print('⚠️  Por favor ejecuta el script supabase_setup.sql en tu proyecto de Supabase.');
        throw Exception(
          'Error de configuración de base de datos. '
          'Por favor contacta al administrador o ejecuta el script de configuración.'
        );
      }
      
      // If user doesn't exist yet (e.g., just registered), wait and retry
      if (errorString.contains('not found') || errorString.contains('no rows')) {
        print('⚠️  User not found in public.users, waiting for trigger...');
        await Future.delayed(const Duration(seconds: 1));
        
        try {
          final retryResponse = await _client
              .from('users')
              .select()
              .eq('id', userId)
              .single();
              
          return app_user.User(
            id: retryResponse['id'],
            email: retryResponse['email'],
            alias: retryResponse['alias'],
            displayName: retryResponse['display_name'],
            profileImageUrl: retryResponse['profile_image_url'],
            birthDate: retryResponse['birth_date'] != null
                ? DateTime.parse(retryResponse['birth_date'])
                : null,
            createdAt: DateTime.parse(retryResponse['created_at']),
            updatedAt: DateTime.parse(retryResponse['updated_at']),
          );
        } catch (retryError) {
          print('❌ Retry failed: $retryError');
        }
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
