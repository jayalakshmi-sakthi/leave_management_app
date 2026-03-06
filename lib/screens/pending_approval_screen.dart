import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> with SingleTickerProviderStateMixin {
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // Delay to ensure context is ready or auth is stable
    Future.delayed(Duration.zero, _startListeningForApproval);

    // ⏳ SAND CLOCK ANIMATION
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );

    // Loop: Run forward, wait, run backward (or reset and run)
    _startAnimationLoop();
  }

  void _startAnimationLoop() async {
    while (mounted) {
      await _controller.forward(); // Spin 180
      await Future.delayed(const Duration(seconds: 1)); // Wait
      if (!mounted) break;
      await _controller.reverse(); // Spin back
      await Future.delayed(const Duration(seconds: 1)); // Wait
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _userSubscription?.cancel();
    super.dispose();
  }

  void _startListeningForApproval() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        final isApproved = data?['approved'] ?? false;

        if (isApproved) {
          if (mounted) {
             Navigator.pushReplacementNamed(context, '/home');
          }
        }
      }
    }, onError: (e) {
      debugPrint("Error listening for approval: $e");
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  shape: BoxShape.circle,
                ),
                child: RotationTransition(
                  turns: _animation,
                  child: Icon(
                    Icons.hourglass_top_rounded,
                    size: 64,
                    color: Colors.amber.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Title
              Text(
                "Approval Pending",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              
              // Message
              Text(
                "Your account setup is complete!\nYour request has been sent to the Admin for approval.\n\nYou will be notified via email once approved.\nApp will auto-refresh once approved.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              
              // Logout Button
              SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF4338CA)], // Indigo 600 -> 700
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4F46E5).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              await FirebaseAuth.instance.signOut();
                              if (context.mounted) {
                                Navigator.pushReplacementNamed(context, '/login');
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    "Back to Login",
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
              ),
            ],
          ),
        ),
      ),
    );
  }
}
