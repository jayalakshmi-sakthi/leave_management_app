import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A service class to handle Firebase Authentication and Firestore user management.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fire = FirebaseFirestore.instance;

  /// Sign in a user with email and password.
  /// Returns the [User] if successful, otherwise throws [FirebaseAuthException].
  Future<User?> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return cred.user;
    } on FirebaseAuthException catch (e) {
      // Rethrow to handle in UI
      throw e;
    }
  }

  /// Register a new user and store additional details in Firestore.
  /// [role] defaults to 'staff'.
  Future<User?> register(
      String name, String email, String password, String employeeId,
      {String role = 'staff'}) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      final user = cred.user!;

      // Store user details in Firestore
      await _fire.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name,
        'email': email,
        'employeeId': employeeId,
        'role': role,
        'joinDate': DateTime.now().toIso8601String(),
      });

      return user;
    } on FirebaseAuthException catch (e) {
      throw e;
    }
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Get the currently logged-in user.
  User? get currentUser => _auth.currentUser;
}
