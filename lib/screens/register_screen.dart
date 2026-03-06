import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/responsive_wrapper.dart';
import '../services/auth_service.dart';
import 'package:flutter/services.dart'; // For MethodChannel
import 'package:url_launcher/url_launcher.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  final AuthService _auth = AuthService();

  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isWaitingForVerification = false;
  bool _verificationSent = false;

  // 🔒 UI CONSTANTS (Soulful Palette)
  static const Color primaryBlue = Color(0xFF4F46E5); // Indigo 600
  static const Color darkSlate = Color(0xFF0F172A);
  static const Color softText = Color(0xFF64748B);
  static const Color cardBg = Colors.white;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // REGISTER
  // --------------------------------------------------
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      await _auth.register(
        _name.text.trim(),
        _email.text.trim(),
        _password.text.trim(),
        "staff",
      );

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() => _isLoading = false);
        _showError("User creation failed. Try again.");
        return;
      }

      // 📧 SEND VERIFICATION EMAIL
      if (!user.emailVerified) {
        try {
          await user.sendEmailVerification();
          _verificationSent = true;
        } on FirebaseAuthException catch (e) {
          _showError("Email send failed: ${e.message}");
          // We still proceed to verification screen so they can try "Resend"
        } catch (e) {
          _showError("Could not send email. Please try Resend.");
        }
      }

      // 🛑 MANDATORY WAIT: Show Verification UI
      if (mounted) {
        setState(() {
          _isWaitingForVerification = true;
          _isLoading = false;
          _startAutoCheck(); // Poll for verification
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      _showError(e.message ?? "Registration failed");
    } catch (e) {
      setState(() => _isLoading = false);
      // AuthService now throws mapped strings, but we catch everything for safety
      final errorMsg = e.toString().replaceFirst("Exception: ", "");
      _showError(errorMsg);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ⚡ INSTANT CHECK ON APP RESUME
    if (state == AppLifecycleState.resumed && _isWaitingForVerification) {
       _checkVerificationAndContinue();
    }
  }

  void _startAutoCheck() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      
      if (user != null && user.emailVerified) {
        timer.cancel();
        if (mounted) {
           Navigator.pushReplacementNamed(context, "/profile-setup");
        }
      }
    });
  }

  Future<void> _checkVerificationAndContinue() async {
    final user = FirebaseAuth.instance.currentUser;
    await user?.reload();

    if (user != null && user.emailVerified) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, "/profile-setup");
    } else {
      _showError("Email not verified yet. Please check your inbox.");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFB91C1C)), // Red 700
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Color(0xFF7F1D1D), // Red 900
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFEF2F2), // Red 50
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFFECACA), width: 1), // Red 200
        ),
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    );
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: ResponsiveWrapper(
          child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _isWaitingForVerification
              ? _buildVerificationState()
              : _buildRegisterState(),
      ),
      ),
      ),
    );
  }

  Widget _buildRegisterState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: _cardDecoration(),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Center(
              child: Image.asset(
                'assets/logo.png',
                width: 120,
                height: 120,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Welcome to LeaveX",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: darkSlate,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Professional leave management simplified",
              textAlign: TextAlign.center,
              style: TextStyle(color: softText),
            ),
            const SizedBox(height: 32),
            _input(_name, "Full Name", Icons.person_outline),
            const SizedBox(height: 16),
            _input(
              _email,
              "Email Address",
              Icons.email_outlined,
              keyboard: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return "Email is required";
                final emailRegex = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
                if (!emailRegex.hasMatch(v)) return "Invalid email format";
                return null;
              },
            ),
            const SizedBox(height: 16),
            _passwordInput(
              controller: _password,
              label: "Password",
              show: _showPassword,
              toggle: () => setState(() => _showPassword = !_showPassword),
              validator: (v) {
                if (v == null || v.isEmpty) return "Password is required";
                if (v.length < 6) return "Password must be at least 6 characters";
                return null;
              },
            ),
            const SizedBox(height: 16),
            _passwordInput(
              controller: _confirmPassword,
              label: "Confirm Password",
              show: _showConfirmPassword,
              toggle: () =>
                  setState(() => _showConfirmPassword = !_showConfirmPassword),
              validator: (v) {
                if (v == null || v.isEmpty) return "Required";
                if (v != _password.text) return "Passwords do not match";
                return null;
              },
            ),
            const SizedBox(height: 32),
            _actionButton("Register Now", _handleRegister),
            const SizedBox(height: 20),
            _footer(
              "Already have an account? ",
              "Sign In",
              () => Navigator.pushReplacementNamed(context, "/login"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMailApp() async {
    // 1. Try Native Android Intent (via MethodChannel)
    if (Theme.of(context).platform == TargetPlatform.android) {
      try {
        const platform = MethodChannel('com.example.leave_management_app/channel');
        await platform.invokeMethod('openEmailApp');
        return;
      } catch (e) {
        debugPrint("Native openEmailApp failed: $e");
        // Fallthrough to web/mailto
      }
    }

    // 2. Try iOS Mail
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      final Uri iosUrl = Uri.parse("message://");
      if (await canLaunchUrl(iosUrl)) {
        await launchUrl(iosUrl);
        return;
      }
    }

    // 3. Fallback to Gmail Web (Better than Compose)
    final Uri webGmailUrl = Uri.parse("https://mail.google.com/");
    if (await canLaunchUrl(webGmailUrl)) {
      await launchUrl(webGmailUrl, mode: LaunchMode.externalApplication);
      return;
    }

    // 4. Fallback to generic mailto:
    final Uri mailtoUrl = Uri.parse("mailto:");
    if (await canLaunchUrl(mailtoUrl)) {
      await launchUrl(mailtoUrl);
    } else {
      _showError("Could not open mail app");
    }
  }

  Widget _buildVerificationState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _icon(Icons.mark_email_unread_rounded),
          const SizedBox(height: 24),
          const Text(
            "Verify Your Email",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: darkSlate,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "We sent a verification link to\n${_email.text}",
            textAlign: TextAlign.center,
            style: const TextStyle(color: softText),
          ),
          const SizedBox(height: 8),
          const Text(
            "(Please check your Spam/Junk folder)",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          // 🔄 AUTO-DETECT INDICATOR
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: primaryBlue),
              ),
              const SizedBox(width: 8),
              Text(
                "Waiting for you to verify...",
                style: TextStyle(fontSize: 12, color: primaryBlue.withOpacity(0.8), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 28),
          
          _actionButton("Open Email App", _openMailApp), // 📧 NEW
          const SizedBox(height: 16),
          
          OutlinedButton(
            onPressed: _checkVerificationAndContinue,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: primaryBlue),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            ),
            child: const Text("I’ve verified my email", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
          ),
          
          const SizedBox(height: 16),
          TextButton(
            onPressed: () async {
              try {
                final user = FirebaseAuth.instance.currentUser;
                await user?.sendEmailVerification();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Link resent! Check your inbox."), backgroundColor: Colors.green),
                );
              } catch (e) {
                _showError("Failed to resend: $e");
              }
            },
            child: const Text("Resend Verification Email", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // UI HELPERS (UNCHANGED)
  // --------------------------------------------------
  BoxDecoration _cardDecoration() => BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      );

  Widget _icon(IconData icon) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: primaryBlue.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: primaryBlue, size: 32),
      );

  Widget _input(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: keyboard,
      validator: validator ?? (v) => v == null || v.isEmpty ? "Required" : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: softText),
        prefixIcon: Icon(icon, color: primaryBlue, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _passwordInput({
    required TextEditingController controller,
    required String label,
    required bool show,
    required VoidCallback toggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !show,
      validator: validator ?? (v) => v == null || v.isEmpty ? "Required" : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: softText),
        prefixIcon:
            const Icon(Icons.lock_outline, color: primaryBlue, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            show ? Icons.visibility_off : Icons.visibility,
            color: softText,
            size: 20,
          ),
          onPressed: toggle,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2)
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }

  Widget _footer(String t, String a, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(t, style: const TextStyle(color: softText)),
        GestureDetector(
          onTap: onTap,
          child: Text(
            a,
            style: const TextStyle(
              color: primaryBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
