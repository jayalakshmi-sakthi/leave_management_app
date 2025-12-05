// lib/screens/leave_history_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';

class LeaveHistoryScreen extends StatefulWidget {
  const LeaveHistoryScreen({super.key});

  @override
  State<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

class _LeaveHistoryScreenState extends State<LeaveHistoryScreen> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirestoreService();

  String? _academicYear;
  late final String _uid;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    if (user == null) {
      // If not logged in, navigate to login page
      Future.microtask(() {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      });
      return;
    }
    _uid = user.uid;
    _setAcademicYear();
  }

  void _setAcademicYear() {
    final now = DateTime.now();
    final startYear = now.month >= 6 ? now.year : now.year - 1;
    setState(() => _academicYear = "$startYear-${startYear + 1}");
  }

  @override
  Widget build(BuildContext context) {
    if (_academicYear == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Leaves')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _fs.streamUserLeaves(_uid, _academicYear!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final leaves = snapshot.data ?? [];

          if (leaves.isEmpty) {
            return const Center(
              child: Text(
                'No leaves recorded',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            );
          }

          final fmt = DateFormat('yyyy-MM-dd');

          return ListView.builder(
            itemCount: leaves.length,
            itemBuilder: (context, index) {
              final l = leaves[index];
              final from =
                  DateTime.tryParse(l['fromDate'] ?? '') ?? DateTime.now();
              final to = DateTime.tryParse(l['toDate'] ?? '') ?? DateTime.now();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(
                    '${l['applicationId'] ?? 'N/A'} — ${l['leaveType'] ?? 'N/A'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${fmt.format(from)} → ${fmt.format(to)}\nStatus: ${l['status'] ?? 'Pending'}',
                  ),
                  isThreeLine: true,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/detail',
                      arguments: {
                        'leaveId': l['leaveId'] ?? l['applicationId']
                      },
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
