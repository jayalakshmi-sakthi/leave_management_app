import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/notification_service.dart';

import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fire = FirebaseFirestore.instance;

  static const String _users = "users";

  // --------------------------------------------------
  // LOGIN WITH EMAIL & PASSWORD (BLOCK UNVERIFIED USERS)
  // --------------------------------------------------
  Future<User> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) {
        throw "Login failed. Try again.";
      }

      // 🔐 FETCH ROLE & VERIFY
      final userDoc = await _fire.collection(_users).doc(user.uid).get();
      if (!userDoc.exists) {
        await _auth.signOut();
        throw "User record not found.";
      }

      final role = userDoc.data()?['role'];
      if (role == 'admin' || role == 'super_admin') {
        await _auth.signOut();
        throw "This email is registered for Admin Panel use only. Please use your staff account.";
      }

      // 🔐 BLOCK IF EMAIL NOT VERIFIED
      if (!user.emailVerified) {
        await _auth.signOut();
        throw "Please verify your email before logging in.";
      }

      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint("AuthService Error: ${e.code} - ${e.message}");
      throw _mapError(e);
    } catch (e) {
      debugPrint("Generic Auth Error: $e");
      throw e.toString();
    }
  }

  // --------------------------------------------------
  // REGISTER USER + SEND EMAIL VERIFICATION
  // --------------------------------------------------
  Future<User> register(
    String name,
    String email,
    String password,
    String role,
  ) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user!;
      // final empId = await _generateNextEmployeeId(); // ❌ REMOVED: Managed in Profile Setup

      // 🔐 CREATE FIRESTORE USER DOCUMENT (Critical Step)
      await _fire.collection(_users).doc(user.uid).set({
        "uid": user.uid,
        "name": name,
        "email": email,
        "role": role,
        // "employeeId": empId, // ❌ REMOVED
        "approved": false, // New users need approval
        "createdAt": FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 15));

      // ℹ️ Notification is sent after profile setup (profile_setup_screen.dart)
      // where the admin gets the actual employee ID and designation.

      // 📧 SEND VERIFICATION MAIL (Non-Critical Step)
      try {
        if (!user.emailVerified) {
          await user.sendEmailVerification();
        }
      } catch (e) {
        // Ignore email errors
      }

      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint("AuthService Error: ${e.code} - ${e.message}");
      throw _mapError(e);
    } catch (e) {
      debugPrint("Generic Reg Error: $e");
      throw "Registration failed. Please try again.";
    }
  }

  // --------------------------------------------------
  // GOOGLE SIGN-IN (FORCE EMAIL PICKER)
  // --------------------------------------------------
  Future<User> signInWithGoogle() async {
    try {
      // 🌍 Web Specific Initialization to ensure Client ID is picked up
      final GoogleSignIn googleSignIn = kIsWeb
          ? GoogleSignIn(
              clientId: '476708106662-tkafgjdqu0i04tn6tqffugqa1iemuh0q.apps.googleusercontent.com',
            )
          : GoogleSignIn();

      // ✅ FORCE ACCOUNT SELECTION EVERY TIME
      try {
        await googleSignIn.signOut();
      } catch (e) {
        // Ignore sign out errors on web if not signed in
      }

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw "Google sign-in cancelled.";
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      final user = userCred.user!;

      // 🔐 ENSURE FIRESTORE USER EXISTS
      final doc = await _fire.collection(_users).doc(user.uid).get().timeout(const Duration(seconds: 10));
      if (!doc.exists) {
        // final empId = await _generateNextEmployeeId(); // ❌ REMOVED
        await _fire.collection(_users).doc(user.uid).set({
          "uid": user.uid,
          "name": user.displayName ?? "Google User",
          "email": user.email,
          "role": "staff",
          // "employeeId": empId, // ❌ REMOVED
          "approved": false, // New users need approval
          "createdAt": FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 15));
        
      }

      return user;
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      throw "Sign-in failed: ${e.toString()}";
    }
  }

  // --------------------------------------------------
  /// Public wrapper for generating next ID
  Future<String> generateNextEmployeeIdExternal() => _generateNextEmployeeId();

  // 🆔 ID GENERATOR (TRANSACTIONAL)
  // --------------------------------------------------
  Future<String> _generateNextEmployeeId() async {
    final year = DateTime.now().year;
    final ref = _fire.collection('counters').doc('employees');

    return _fire.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);

      int currentCount = 0;
      if (snapshot.exists) {
        currentCount = snapshot.data()?['count'] ?? 0;
      }

      final newCount = currentCount + 1;
      transaction.set(ref, {'count': newCount}, SetOptions(merge: true));

      // Format: EMP-YYYY-XXXX (e.g. EMP-2024-0042)
      return "EMP-$year-${newCount.toString().padLeft(4, '0')}";
    }).timeout(const Duration(seconds: 10), onTimeout: () => "EMP-$year-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}");
  }

  // --------------------------------------------------
  // RESEND EMAIL VERIFICATION
  // --------------------------------------------------
  Future<void> resendVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // --------------------------------------------------
  // LOGOUT
  // --------------------------------------------------
  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  // --------------------------------------------------
  // ERROR MAPPER
  // --------------------------------------------------
  String _mapError(FirebaseAuthException e) {
    switch (e.code) {
      case "invalid-email":
        return "Invalid email address.";
      case "user-not-found":
        return "User not found.";
      case "wrong-password":
        return "Incorrect password.";
      case "email-already-in-use":
        return "Email already registered.";
      case "weak-password":
        return "Password must be at least 6 characters.";
      case "user-disabled":
        return "This account has been disabled.";
      case "too-many-requests":
        return "Too many attempts. Please try again later.";
      case "invalid-credential":
        return "Incorrect email or password.";
      case "network-request-failed":
        return "Network error. Please check your connection.";
      default:
        return e.message ?? "Authentication failed. Please try again.";
    }
  }

}
