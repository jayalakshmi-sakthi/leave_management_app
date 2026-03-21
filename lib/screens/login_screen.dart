import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/responsive_wrapper.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final AuthService _auth = AuthService();

  bool _loading = false;
  bool _showPassword = false;

  // Premium Palette (Unified KEC Navy)
  static const Color primaryBlue = Color(0xFF001C3D); // KEC Navy
  static const Color darkText = Color(0xFF1E293B); // Slate-800
  static const Color mutedText = Color(0xFF64748B); // Slate-500
  static const Color inputFill = Color(0xFFF1F5F9); // Slate-100

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : primaryBlue,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      await _auth.signIn(_email.text.trim(), _password.text.trim());
      await _checkUserStatus();
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? "Login failed");
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _loading = true);
    try {
      await _auth.signInWithGoogle();
      await _checkUserStatus();
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkUserStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw "Login failed.";
    
    // Auth Guard in main.dart handles startup, but for manual login:
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get().timeout(const Duration(seconds: 10));
    
    if (!user.emailVerified) {
      await FirebaseAuth.instance.signOut();
      throw "Please verify your email.";
    }
    
    // Google Sign In might delay doc creation
    if (!userDoc.exists) {
       await Future.delayed(const Duration(milliseconds: 1000));
       // If still no doc, assume new user -> Profile Setup
       if (mounted) Navigator.pushReplacementNamed(context, "/profile-setup");
       return;
    }

    final data = userDoc.data();
    
    // 1️⃣ Check Profile
    final bool hasProfile = (data?['designation'] != null && data?['designation'].toString().isNotEmpty == true) &&
                            (data?['profilePicUrl'] != null && data?['profilePicUrl'].toString().isNotEmpty == true);

    if (!hasProfile) {
      if (mounted) Navigator.pushReplacementNamed(context, "/profile-setup");
      return;
    }

    // 2️⃣ Check Approval
    final isApproved = (data?['approved'] ?? false) == true;

    if (!isApproved) {
      if (mounted) Navigator.pushReplacementNamed(context, "/pending-approval");
      return;
    }

    if (mounted) {
      NotificationService().setUserId(user.uid);
      Navigator.pushReplacementNamed(context, "/home");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // Avoid resizing when keyboard opens to keep layout "fixed"
      // User can scroll if absolutely needed due to LayoutBuilder overflow protection
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 800;
          final contentHeight = constraints.maxHeight;
          final isShortScreen = contentHeight < 700;

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Container(
                  width: isDesktop ? 450 : double.infinity,
                  height: isShortScreen ? null : contentHeight, // Force full height if screen is tall enough
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // --- Spacer Top (Flexible) ---
                      if (!isShortScreen) const Spacer(), 
                      if (isShortScreen) const SizedBox(height: 60),

                      // --- Form Card ---
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32), // Reduced horizontal padding
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Logo Restored Inside
                              Center(
                                child: Image.asset('assets/logo.png', width: 80, height: 80),
                              ),
                              const SizedBox(height: 20),

                              Text(
                                "Welcome Back",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 24, // Slightly smaller
                                  fontWeight: FontWeight.w700,
                                  color: darkText,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Sign in to access your dashboard",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: mutedText,
                                ),
                              ),
                              const SizedBox(height: 32),
                              
                              _buildTextField(
                                controller: _email,
                                label: "Email Address",
                                icon: Icons.alternate_email_rounded,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _password,
                                label: "Password",
                                icon: Icons.lock_outline_rounded,
                                isObscure: !_showPassword,
                                onToggleEye: () => setState(() => _showPassword = !_showPassword),
                              ),
                              
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    // Todo: Forgot Password
                                  },
                                  child: Text(
                                    "Forgot Password?",
                                    style: GoogleFonts.inter(
                                      color: primaryBlue,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              _buildPrimaryButton("Sign In", _handleLogin),
                              
                              const SizedBox(height: 24),
                              _buildGoogleSignIn(),
                            ],
                          ),
                        ),
                      ),

                      // --- Spacer Bottom (Flexible) ---
                      if (!isShortScreen) const Spacer(),
                      if (isShortScreen) const SizedBox(height: 40),

                      // --- Footer ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Don't have an account? ", style: GoogleFonts.inter(color: mutedText)),
                          GestureDetector(
                            onTap: () => Navigator.pushReplacementNamed(context, "/register"), 
                            // Verify route: default is often '/register' or '/profile-setup'
                            // Previous code looked for '/register'. I'll stick to that.
                            child: Text(
                              "Sign Up",
                              style: GoogleFonts.inter(
                                color: primaryBlue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Image.asset('assets/logo.png', width: 64, height: 64), 
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isObscure = false,
    VoidCallback? onToggleEye,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      style: GoogleFonts.inter(color: darkText, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: mutedText, fontSize: 14),
        floatingLabelStyle: GoogleFonts.inter(color: primaryBlue, fontWeight: FontWeight.w600),
        prefixIcon: Icon(icon, color: mutedText, size: 22),
        suffixIcon: onToggleEye != null 
          ? IconButton(
              icon: Icon(isObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: mutedText, size: 20),
              onPressed: onToggleEye,
            )
          : null,
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      ),
      validator: (val) => val == null || val.isEmpty ? "Required" : null,
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: _loading 
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
          : Text(
              text,
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600),
            ),
      ),
    );
  }

  Widget _buildGoogleSignIn() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: _loading ? null : _handleGoogleLogin,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/google_logo.png', height: 24),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                "Continue with Google",
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: darkText,
                  fontSize: 15, // Reduced from 16
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
