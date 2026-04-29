import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream of auth state changes — emits User or null
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Current signed-in user (null if not authenticated)
  User? get currentUser => _auth.currentUser;

  bool get isSignedIn => _auth.currentUser != null;

  // ── Email & Password Flow ────────────────────────────────────────────

  /// Step 1: Sign Up a new user
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Step 2: Sign In an existing user
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
