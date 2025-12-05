// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      setState(() {
        _data = snap.data();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
    }
  }

  Widget _infoTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            '$title: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')), // ✅ const okay here
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')), // ✅ const okay here
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _data == null
            ? const Center(child: Text('No profile data available'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoTile('Name', _data!['name'] ?? '—'),
                  _infoTile('Email', _data!['email'] ?? '—'),
                  _infoTile('Employee ID', _data!['employeeId'] ?? '—'),
                  _infoTile('Role', _data!['role'] ?? 'staff'),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _loadProfile,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Profile'),
                  ),
                ],
              ),
      ),
    );
  }
}
