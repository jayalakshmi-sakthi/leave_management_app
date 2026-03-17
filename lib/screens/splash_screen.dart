import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

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
                width: 200, 
                height: 200,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 24),

              // App name
              Text(
                "LeaveX",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: const Color(0xFF1E293B),
                ),
              ),

              const SizedBox(height: 8),

              // Tagline (clean, not loud)
              const Text(
                "Work • Balance • Progress",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.6,
                  color: Color(0xFF64748B),
                ),
              ),

              const SizedBox(height: 32),

              // Loader
              const SizedBox(
                height: 32,
                width: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3.0,
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
