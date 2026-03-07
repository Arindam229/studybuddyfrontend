import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _initialized = false;

  Future<void> initialize() async {
    if (!_initialized) {
      await _googleSignIn.initialize(
        clientId: kIsWeb
            ? '847710015802-or4fqdgap6lq45cl3461vf0gqiq72bof.apps.googleusercontent.com'
            : null,
      );
      _initialized = true;

      if (kIsWeb) {
        print("AuthService: Setting up authenticationEvents listener for Web.");
        _googleSignIn.authenticationEvents.listen((event) async {
          print("AuthService: Received authentication event: $event");
          if (event is GoogleSignInAuthenticationEventSignIn) {
            try {
              final account = event.user;
              final googleAuth = account.authentication;

              final authClient = account.authorizationClient;
              final authz = await authClient.authorizationForScopes(['email']);

              final credential = GoogleAuthProvider.credential(
                accessToken: authz?.accessToken,
                idToken: googleAuth.idToken,
              );
              await _auth.signInWithCredential(credential);
            } catch (e) {
              print("Error during automatic Firebase sign-in: $e");
            }
          }
        });
      }
    }
  }

  Future<void> _ensureInitialized() async {
    await initialize();
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) return null;

    try {
      await _ensureInitialized();

      if (defaultTargetPlatform == TargetPlatform.windows) {
        print(
          "AuthService: Google Sign-In is not currently supported on Windows Desktop by the official plugin.",
        );
        // In a real app, you might use a webview or custom OAuth flow here.
        return null;
      }

      // Trigger the authentication flow
      // On macOS and Android/iOS, this uses the native SDKs
      final GoogleSignInAccount? googleUser = await _googleSignIn
          .authenticate();

      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Get the access token via authorizationClient for newer Identity Services
      final authClient = googleUser.authorizationClient;
      final authz = await authClient.authorizationForScopes(['email']);

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: authz?.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print("Error during Google Sign In ($defaultTargetPlatform): $e");
      return null;
    }
  }

  Future<void> signOut() async {
    await _ensureInitialized();
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<UserCredential?> registerWithEmail(
    String email,
    String password,
  ) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print("Error during Email Registration: $e");
      rethrow;
    }
  }

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print("Error during Email Sign In: $e");
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print("Error during Password Reset Email: $e");
      rethrow;
    }
  }

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<String?> getIdToken() async {
    if (currentUser == null) return null;
    return await currentUser!.getIdToken();
  }
}
