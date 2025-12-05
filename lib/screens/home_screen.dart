// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;

  String _name = 'Employee';
  String _uid = '';
  String _employeeId = '';

  int _clUsed = 0;
  int _vlUsed = 0;
  int _compUsed = 0;

  late final String academicYear;

  bool _loadingCounts = true;
  bool _errorLoading = false;

  @override
  void initState() {
    super.initState();
    academicYear = _computeAcademicYear();

    final user = _auth.currentUser;
    if (user == null) {
      Future.microtask(() {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      });
      return;
    }

    _uid = user.uid;
    _loadAll();
  }

  String _computeAcademicYear() {
    final now = DateTime.now();
    final startYear = now.month >= 6 ? now.year : now.year - 1;
    return '$startYear-${startYear + 1}';
  }

  Future<void> _loadAll() async {
    if (!mounted) return;

    setState(() {
      _loadingCounts = true;
      _errorLoading = false;
    });

    try {
      await Future.wait([_loadUserInfo(), _loadLeaveCounts()]);
    } catch (_) {
      if (mounted) setState(() => _errorLoading = true);
    }

    if (mounted) setState(() => _loadingCounts = false);
  }

  Future<void> _loadUserInfo() async {
    if (_uid.isEmpty) return;

    final snap = await _fire.collection('users').doc(_uid).get();
    final data = snap.data();
    if (data != null && mounted) {
      setState(() {
        _name = data['name'] ?? 'Employee';
        _employeeId = data['employeeId'] ?? '';
      });
    }
  }

  Future<void> _loadLeaveCounts() async {
    if (_uid.isEmpty) return;

    final col = _fire.collection('leaveRequests_$academicYear');
    final q = await col.where('userId', isEqualTo: _uid).get();

    int cl = 0, vl = 0, comp = 0;

    for (var d in q.docs) {
      final data = d.data();
      final type = data['leaveType'] ?? '';
      final raw = data['numberOfDays'];

      int days = 1;
      if (raw is int) days = raw;
      if (raw is double) days = raw.toInt();
      if (raw is String) days = int.tryParse(raw) ?? 1;

      if (type == 'CL') cl += days;
      if (type == 'VL') vl += days;
      if (type == 'COMP') comp += days;
    }

    if (mounted) {
      setState(() {
        _clUsed = cl;
        _vlUsed = vl;
        _compUsed = comp;
      });
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final clRemaining =
        (Constants.casualPerYear - _clUsed).clamp(0, Constants.casualPerYear);
    final vlRemaining = (Constants.vacationPerYear - _vlUsed)
        .clamp(0, Constants.vacationPerYear);

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, $_name'),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: _errorLoading
          ? _buildErrorState()
          : _buildMainUI(clRemaining, vlRemaining),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 10),
          const Text("Failed to load data"),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: _loadAll, child: const Text("Retry")),
        ],
      ),
    );
  }

  Widget _buildMainUI(int clRemaining, int vlRemaining) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Employee ID: ${_employeeId.isNotEmpty ? _employeeId : '-'}",
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Chip(label: Text('Academic Year: $academicYear')),
              const SizedBox(width: 8),
              if (_loadingCounts)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: _buildStatCard(
                      "Casual", "$clRemaining left", "Used: $_clUsed")),
              const SizedBox(width: 10),
              Expanded(
                  child: _buildStatCard(
                      "Vacation", "$vlRemaining left", "Used: $_vlUsed")),
              const SizedBox(width: 10),
              Expanded(
                  child: _buildStatCard(
                      "Comp Off", "$_compUsed used", "Earned by extra work")),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/apply'),
            icon: const Icon(Icons.add),
            label: const Text('Apply Leave'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/history'),
            icon: const Icon(Icons.history),
            label: const Text('My Leave History'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/profile'),
            icon: const Icon(Icons.person),
            label: const Text('Profile'),
          ),
          const SizedBox(height: 20),
          const Text("Recent Leaves",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Expanded(child: _buildRecentLeavesList()),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtext) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(subtext,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentLeavesList() {
    final col = _fire.collection('leaveRequests_$academicYear');

    return StreamBuilder<QuerySnapshot>(
      stream: col
          .where('userId', isEqualTo: _uid)
          .orderBy('createdAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text("Error: ${snap.error}"));
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text("No recent leaves"));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final d = docs[index].data() as Map<String, dynamic>;
            final type = d['leaveType'] ?? 'N/A';

            DateTime from;
            DateTime to;
            try {
              from = DateTime.parse(d['fromDate']);
            } catch (_) {
              from = DateTime.now();
            }
            try {
              to = DateTime.parse(d['toDate']);
            } catch (_) {
              to = DateTime.now();
            }

            final status = (d['status'] ?? 'pending').toString().toLowerCase();
            Color statusColor = Colors.orange;
            if (status == 'approved') statusColor = Colors.green;
            if (status == 'rejected') statusColor = Colors.red;

            return Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_month),
                title: Text("$type Leave"),
                subtitle: Text(
                    "${DateFormat('yyyy-MM-dd').format(from)} → ${DateFormat('yyyy-MM-dd').format(to)}"),
                trailing: Text(
                  (d['status'] ?? 'PENDING').toString().toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  if (!mounted) return;
                  Navigator.pushNamed(context, '/detail',
                      arguments: {'leaveId': docs[index].id});
                },
              ),
            );
          },
        );
      },
    );
  }
}
