import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminLeaveRequestsScreen extends StatefulWidget {
  const AdminLeaveRequestsScreen({super.key});

  @override
  State<AdminLeaveRequestsScreen> createState() =>
      _AdminLeaveRequestsScreenState();
}

class _AdminLeaveRequestsScreenState extends State<AdminLeaveRequestsScreen> {
  static const Color primaryBlue = Color(0xFF4F46E5); // Indigo 600
  static const Color textMain = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  String _getAcademicYear() {
    final now = DateTime.now();
    int startYear = now.month >= 6 ? now.year : now.year - 1;
    return "$startYear-${startYear + 1}";
  }

  /// Update status using department from data to construct correct path
  Future<void> _updateStatus(Map<String, dynamic> data, String docId, String status) async {
    final dept = (data['department'] ?? 'General') as String;
    try {
      await FirebaseFirestore.instance
          .collection('leaveRequests')
          .doc(dept)
          .collection('records')
          .doc(docId)
          .update({'status': status});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text("All Leave Requests",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: Colors.white,
          foregroundColor: textMain,
          elevation: 0,
          centerTitle: true,
          bottom: const TabBar(
            isScrollable: true,
            labelColor: primaryBlue,
            indicatorColor: primaryBlue,
            unselectedLabelColor: textMuted,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: "All"),
              Tab(text: "Pending"),
              Tab(text: "Approved"),
              Tab(text: "Rejected"),
            ],
          ),
        ),
        // Use collectionGroup to read all records for admin view
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collectionGroup('records')
              .where('academicYearId', isEqualTo: _getAcademicYear())
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _emptyState("No leave requests found.");
            }

            // Sort in memory to avoid index requirements
            final allDocs = snapshot.data!.docs.toList();
            allDocs.sort((a, b) {
               final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
               final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
               if (aTime == null || bTime == null) return 0;
               return bTime.compareTo(aTime);
            });

            return TabBarView(
              children: [
                _buildList(allDocs), // All
                _buildList(allDocs
                    .where((d) => d['status'] == 'Pending')
                    .toList()), // Pending
                _buildList(allDocs
                    .where((d) => d['status'] == 'Approved')
                    .toList()), // Approved
                _buildList(allDocs
                    .where((d) => d['status'] == 'Rejected')
                    .toList()), // Rejected
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return _emptyState("No requests in this category.");

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;
        return _buildLeaveCard(data, docs[index].id);
      },
    );
  }

  Widget _emptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(msg, style: const TextStyle(color: textMuted, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> data, String docId) {
    final status = data['status'] ?? 'Pending';
    final isPending = status == 'Pending';
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    final from = parseDate(data['fromDate']);
    final to = parseDate(data['toDate']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: primaryBlue.withOpacity(0.1),
                  child: const Icon(Icons.person, color: primaryBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(data['userId'])
                        .get(),
                    builder: (context, userSnap) {
                      final userName = userSnap.hasData && userSnap.data!.exists
                          ? userSnap.data!['name']
                          : 'Loading...';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(userName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Row(
                            children: [
                              Text(userSnap.hasData && userSnap.data!.exists ? (userSnap.data!.data() as Map<String, dynamic>)['employeeId'] ?? 'EMP-TEMP' : '...',
                                  style: const TextStyle(
                                      color: primaryBlue, fontSize: 11, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              Text("${data['leaveType']} • ${data['numberOfDays']} Days",
                                  style: const TextStyle(
                                      color: textMuted, fontSize: 13)),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
                _statusBadge(status),
              ],
            ),
          ),
          const Divider(height: 1),
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _rowKV("Duration",
                    "${DateFormat('MMM dd').format(from)} - ${DateFormat('MMM dd, yyyy').format(to)}"),
                const SizedBox(height: 8),
                _rowKV("Dept", data['department'] ?? 'N/A'),
                const SizedBox(height: 8),
                _rowKV("Reason", data['reason'] ?? 'No reason provided'),
              ],
            ),
          ),
          // Actions
          if (isPending) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _updateStatus(data, docId, "Rejected"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                      ),
                      child: const Text("Reject"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateStatus(data, docId, "Approved"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: const Text("Approve"),
                    ),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _rowKV(String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
            width: 80,
            child: Text(k,
                style: const TextStyle(
                    color: textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600))),
        Expanded(
          child: Text(v,
              style: const TextStyle(
                  color: textMain, fontSize: 14, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _statusBadge(String status) {
    Color col = status == 'Approved'
        ? Colors.green
        : status == 'Rejected'
            ? Colors.red
            : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(status,
          style:
              TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}
