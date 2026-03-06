import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Added
import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      try {
        await user.reload(); // Sync status
        if (!user.emailVerified) {
          // 1. Not Verified -> Force Logout
          await FirebaseAuth.instance.signOut();
          if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
          return;
        }

        // 2. Check Profile Completion & Approval
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        
        if (!doc.exists) {
           // No record at all -> Profile Setup
           if (mounted) Navigator.pushReplacementNamed(context, '/profile-setup');
           return;
        }

        final data = doc.data() ?? {};

        // 3. Check Profile Completeness (consistent with main.dart and login_screen.dart)
        final bool hasProfile = (data['designation'] != null && data['designation'].toString().isNotEmpty) &&
                                (data['profilePicUrl'] != null && data['profilePicUrl'].toString().isNotEmpty);

        if (!hasProfile) {
           if (mounted) Navigator.pushReplacementNamed(context, '/profile-setup');
           return;
        }

        // 4. Check for Admin Approval
        final approved = data['approved'] ?? false;
        if (!approved) {
           if (mounted) Navigator.pushReplacementNamed(context, '/pending-approval');
           return;
        }

        // 5. All Good -> Home
        if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.home);

      } catch (e) {
        // Error (e.g. network/deleted) -> Logout to be safe
        debugPrint("Splash Error: $e");
        await FirebaseAuth.instance.signOut();
        if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _timer?.cancel(); // ✔ prevents test & memory issues
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF4F6FA),
              Color(0xFFE8EDF6),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Enhanced Logo Presentation
              Image.asset(
                'assets/logo.png',
                width: 320, // Maximize size
                height: 320,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 36),

              // App name
              const Text(
                "LeaveX",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),

              const SizedBox(height: 8),

              // Tagline (clean, not loud)
              Text(
                "Work • Balance • Progress",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.6,
                  color: Colors.grey.shade700,
                ),
              ),

              const SizedBox(height: 42),

              // Loader
              const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Color(0xFF7C3AED), // Violet 600
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
