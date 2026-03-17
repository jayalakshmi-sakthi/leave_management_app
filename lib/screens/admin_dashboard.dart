import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:leave_management_app/services/firestore_service.dart';
import 'package:leave_management_app/services/notification_service.dart';
import 'package:leave_management_app/utils/helpers.dart';
import 'package:leave_management_app/screens/notifications_screen.dart';

// Assuming you have access to your AppColors (e.g., via import '../main.dart';)
const Color primaryColor = Color(0xFF1E3A8A);
const Color surfaceColor = Colors.white;

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late String currentYear;
  // Cache for user names to avoid repeated Firestore reads
  final Map<String, String> _userNameCache = {};
  String _adminDepartment = 'General'; // ✅ Added for isolation
  bool _isSuperAdmin = false; // ✅ Added
  @override
  void initState() {
    super.initState();
    currentYear = _getAcademicYear();
    _loadAdminProfile(); // ✅ Added
  }

  Future<void> _loadAdminProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _isSuperAdmin = doc.data()?['role'] == 'super_admin';
          _adminDepartment = doc.data()?['department'] ?? 'General';
        });
      }
    }
  }

  // --- Utility Functions ---

  // Automatically get academic year (e.g., 2025-2026)
  String _getAcademicYear() {
    final now = DateTime.now();
    // Academic year starts in June (month 6)
    int startYear = now.month >= 6 ? now.year : now.year - 1;
    return "$startYear-${startYear + 1}";
  }

  // Calculate the next academic year (e.g., 2025-2026 -> 2026-2027)
  String _getNextYear(String current) {
    var parts = current.split("-");
    int y1 = int.parse(parts[0]);
    return "${y1 + 1}-${y1 + 2}";
  }

  // --- Data Fetching and Caching ---

  // Fetches the user's name from the 'users' collection using their UID
  Future<String> _fetchUserName(String userId) async {
    // 1. Check cache first
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }

    try {
      // 2. Fetch from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        final name = userDoc.data()!['name'] as String? ?? 'User Not Found';
        // 3. Update cache
        _userNameCache[userId] = name;
        return name;
      }
      return 'User Not Found';
    } catch (e) {
      // Handle potential errors like permissions or network issues
      return 'Error fetching name';
    }
  }

  // --- Firestore Actions ---

  Future<void> _updateStatus(String docId, String newStatus) async {
    try {
      final approverId = FirebaseAuth.instance.currentUser?.uid ?? '';
      await FirestoreService().updateLeaveStatus(
        docId, 
        currentYear, 
        newStatus, 
        approverId
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Request updated to: ${newStatus.toUpperCase()}"),
          backgroundColor: newStatus == 'approved' ? Colors.green : Colors.red,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to update status."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // --- Admin Actions ---

  Future<void> _startNewAcademicYear() async {
    // Consolidated schema: No need to create new collections.
    // Just ensure the user knows it's automatic.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Academic Year setup is automatic in the new system."))
    );
  }

  // --- UI Builder Widgets ---

  // Summary Card Widget (Premium design)
  Widget _summaryCard(String title, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 8),
            Text(
              "$count",
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold, 
                color: color,
                letterSpacing: -0.5,
              )
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 10, 
                fontWeight: FontWeight.w600, 
                color: color.withOpacity(0.7),
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Leave Request List Tile
  Widget _buildLeaveTile(Map<String, dynamic> data, Color statusColor) {
    final String docId = data['id'] ?? '';
    final String userId = data['userId'] ?? '';
    final String leaveType = data['leaveType'] ?? 'N/A';
    final String status = data['status'] ?? 'pending';

    return FutureBuilder<String>(
      future: _fetchUserName(userId),
      builder: (context, snapshot) {
        final userName = snapshot.data ?? 'Loading User...';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ListTile(
            onTap: () {
              // Navigate to detail screen to see reason, dates, etc.
              Navigator.pushNamed(context, '/detail',
                  arguments: {'leaveId': docId});
            },
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Helpers.getLeaveIcon(leaveType),
                color: statusColor,
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Expanded(child: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold))),
                if (_isSuperAdmin && data['department'] != null)
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                     decoration: BoxDecoration(
                       color: Helpers.getDeptColor(data['department']).withOpacity(0.1),
                       borderRadius: BorderRadius.circular(4),
                     ),
                     child: Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Icon(Helpers.getDeptIcon(data['department']), size: 8, color: Helpers.getDeptColor(data['department'])),
                         const SizedBox(width: 4),
                         Text(data['department'], style: TextStyle(color: Helpers.getDeptColor(data['department']), fontSize: 8, fontWeight: FontWeight.bold)),
                       ],
                     ),
                   ),
              ],
            ),
            subtitle: Text(
                "$leaveType - Days: ${data['numberOfDays'] ?? 'N/A'}\nApplication: ${data['applicationId'] ?? 'N/A'}"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status != 'approved')
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline),
                    color: Colors.green,
                    tooltip: 'Approve',
                    onPressed: () => _updateStatus(docId, "approved"),
                  ),
                if (status != 'rejected')
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined),
                    color: Colors.red,
                    tooltip: 'Reject',
                    onPressed: () => _updateStatus(docId, "rejected"),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Main Build Method ---

  @override
  Widget build(BuildContext context) {
    final collectionName = "leaveRequests";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard 📊"),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: surfaceColor,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Notifications',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotificationsScreen(departmentFilter: _adminDepartment)
                    ),
                  );
                },
              ),
              StreamBuilder<int>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .where('toUserId', isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '')
                    .where('isRead', isEqualTo: false)
                    .snapshots()
                    .map((snap) => snap.docs.length),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  return Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ),
                  );
                },
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'Manage Employees',
            onPressed: () {
              Navigator.pushNamed(context, '/employees');
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirestoreService().streamAllLeaves(
          academicYearId: currentYear,
          department: _adminDepartment,
        ),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "No leave requests found for the year.",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _startNewAcademicYear,
                    icon: const Icon(Icons.add_circle_outline),
                    label: Text("Initialize $currentYear"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                    ),
                  ),
                ],
              ),
            );
          }

          // Data casting and counting
          int total = docs.length;
          int approved = docs.where((d) => d['status']?.toString().toLowerCase() == "approved").length;
          int rejected = docs.where((d) => d['status']?.toString().toLowerCase() == "rejected").length;
          int pending = docs.where((d) => d['status']?.toString().toLowerCase() == "pending").length;

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Academic Year Header
                Text("Academic Year: $currentYear",
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor)),
                const SizedBox(height: 15),

                // Summary Cards
                Row(
                  children: [
                    _summaryCard("Total", total, primaryColor, Icons.folder_open_rounded),
                    _summaryCard("Pending", pending, Colors.orange, Icons.hourglass_empty_rounded),
                    _summaryCard("Approved", approved, Colors.green, Icons.verified_rounded),
                    _summaryCard("Rejected", rejected, Colors.red, Icons.block_flipped),
                  ],
                ),
                const SizedBox(height: 20),

                // New Academic Year Button (Placed in a cleaner layout)
                TextButton.icon(
                  onPressed: _startNewAcademicYear,
                  icon: const Icon(Icons.event_note, color: primaryColor),
                  label: Text(
                      "Setup Next Academic Year (${_getNextYear(currentYear)})",
                      style: const TextStyle(
                          color: primaryColor, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Pending Requests",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/admin-leaves'),
                      child: const Text("View All"),
                    ),
                  ],
                ),
                const Divider(),

                // Leave Requests List
                Expanded(
                  child: ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index];
                      final status = data['status']?.toString().toLowerCase() ?? 'pending';

                      Color statusColor;
                      switch (status) {
                        case 'approved':
                          statusColor = Colors.green;
                          break;
                        case 'rejected':
                          statusColor = Colors.red;
                          break;
                        default:
                          statusColor = Colors.orange;
                      }

                      // Only show pending requests in the main list
                      if (status == 'pending') {
                        return _buildLeaveTile(data, statusColor);
                      } else {
                        // Return an empty SizedBox for non-pending items (optional filter)
                        return const SizedBox.shrink();
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
