// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pwd = TextEditingController();
  final _empId = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;

  void _register() async {
    if (_name.text.isEmpty ||
        _email.text.isEmpty ||
        _pwd.text.isEmpty ||
        _empId.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Fill all fields')));
      return;
    }

    setState(() => _loading = true);

    try {
      final user = await _auth.register(
        _name.text.trim(),
        _email.text.trim(),
        _pwd.text,
        _empId.text.trim(),
      );
      if (user != null) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Register error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pwd.dispose();
    _empId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Register')), // remove const
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _name,
              decoration:
                  InputDecoration(labelText: 'Full name'), // remove const
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _empId,
              decoration:
                  InputDecoration(labelText: 'Employee ID'), // remove const
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _email,
              decoration: InputDecoration(labelText: 'Email'), // remove const
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pwd,
              obscureText: true,
              decoration:
                  InputDecoration(labelText: 'Password'), // remove const
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _register,
              child: _loading
                  ? CircularProgressIndicator()
                  : Text('Register'), // remove const
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/login'),
              child: Text('Already have an account? Login'), // remove const
            ),
          ],
        ),
      ),
    );
  }
}
