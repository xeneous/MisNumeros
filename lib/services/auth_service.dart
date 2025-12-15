import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart' as app_user;
import '../models/user_plan.dart';
import 'database_service.dart'; // Importar DatabaseService
import '../models/usuario.dart'; // Importar el modelo antiguo de Usuario

class AuthService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  AuthService() {
  }

  // Stream to listen to authentication state changes
  Stream<app_user.User?> get user {
    return _auth.authStateChanges().map((firebaseUser) {
      if (firebaseUser != null) {
        return app_user.User(
          id: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          displayName:
              firebaseUser.displayName ??
              firebaseUser.email?.split('@')[0] ??
              'User',
          alias:
              firebaseUser.displayName ??
              firebaseUser.email?.split('@')[0] ??
              'User',
          profileImageUrl: firebaseUser.photoURL,
          userPlan: UserPlan.free, // Default to free, can be updated later
          createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
      return null;
    });
  }

  Stream<firebase_auth.User?> get authStateChanges => _auth.authStateChanges();

  firebase_auth.User? get currentUser => _auth.currentUser;

  // Get current user
  Future<app_user.User?> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      return app_user.User(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName:
            firebaseUser.displayName ??
            firebaseUser.email?.split('@')[0] ??
            'User',
        alias:
            firebaseUser.displayName ??
            firebaseUser.email?.split('@')[0] ??
            'User',
        profileImageUrl: firebaseUser.photoURL,
        userPlan: UserPlan.free,
        createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    return null;
  }

  // Sign in with Google
  Future<firebase_auth.User?> signInWithGoogle() async {
    try {
      // Configure Google Sign-In with the Android OAuth Client ID
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: '977281610510-na64f1un83v3mojjq08te8bei96sb9rd.apps.googleusercontent.com',
      );
      
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled the sign-in

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with email and password
  Future<firebase_auth.User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      rethrow;
    }
  }

  // Register with email and password
  Future<firebase_auth.User?> registerWithEmailAndPassword(
    String email,
    String password,
    String alias,
  ) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        password: password,
        email: email,
      );
      // Update display name
      await _auth.currentUser?.updateDisplayName(alias);
      return _auth.currentUser;
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Check if user is signed in
  Future<bool> isSignedIn() async {
    return _auth.currentUser != null;
  }

  // Helper para obtener el id_usuario de la base de datos local
  Future<int?> _getLocalUserId(firebase_auth.User? firebaseUser) async {
    if (firebaseUser == null || firebaseUser.email == null) return null;

    try {
      final dbService = DatabaseService();
      final Usuario? oldUser = await dbService.getUsuarioByEmail(
        firebaseUser.email!,
      );
      return oldUser?.idUsuario;
    } catch (e) {
      return null;
    }
  }
}
