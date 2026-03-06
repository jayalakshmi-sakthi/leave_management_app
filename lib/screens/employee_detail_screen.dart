import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final String userName;
  final String userId;

  const EmployeeDetailScreen({
    super.key,
    required this.userName,
    required this.userId,
  });

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  late String _currentYear;

  @override
  void initState() {
    super.initState();
    _currentYear = _calculateAcademicYear();
  }

  String _calculateAcademicYear() {
    final now = DateTime.now();
    final startYear = now.month >= 6 ? now.year : now.year - 1;
    return "$startYear-${startYear + 1}";
  }

  // Helper for status colors
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Matching AdminDashboard logic
    final collectionName = "leaveRequests";

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header Profile
            Center(
              child: Column(
                children: [
                   const CircleAvatar(
                    radius: 40,
                    child: Icon(Icons.person, size: 40),
                   ),
                   const SizedBox(height: 10),
                   Text(
                     widget.userName,
                     style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                   ),
                   Text(
                     "UID: ${widget.userId}",
                     style: const TextStyle(color: Colors.grey, fontSize: 12),
                   ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Stats Section (Optional - can be computed from stream below)
            // For now, directly showing list

            Text(
              "Leave History ($_currentYear)",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),

            // List of leaves
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(collectionName)
                  .where('userId', isEqualTo: widget.userId)
                  .where('academicYearId', isEqualTo: _currentYear)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text("Error loading leaves: ${snapshot.error}");
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator())
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text("No leave records found for this year.")),
                  );
                }

                // Sort in memory to avoid index requirements
                final docs = snapshot.data!.docs.toList();
                docs.sort((a, b) {
                   final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                   final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                   if (aTime == null || bTime == null) return 0;
                   return bTime.compareTo(aTime);
                });

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final type = data['leaveType'] ?? 'Leave';
                    final status = data['status'] ?? 'Pending';
                    final days = data['numberOfDays'] ?? 0;
                    
                    // Safe Date Parsing
                    DateTime? from;
                    if (data['fromDate'] is Timestamp) {
                      from = (data['fromDate'] as Timestamp).toDate();
                    }
                    
                    final dateStr = from != null 
                        ? DateFormat('MMM dd, yyyy').format(from)
                        : 'Unknown Date';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(status).withOpacity(0.2),
                          child: Icon(
                            Icons.calendar_today, 
                            color: _getStatusColor(status)
                          ),
                        ),
                        title: Text("$type - $days Day(s)"),
                        subtitle: Text(dateStr),
                        trailing: Chip(
                          label: Text(
                            status.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10, 
                              color: Colors.white,
                              fontWeight: FontWeight.bold
                            ),
                          ),
                          backgroundColor: _getStatusColor(status),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onTap: () {
                          // Navigate to detailed view (existing screen)
                           Navigator.pushNamed(context, '/detail',
                              arguments: {'leaveId': docs[index].id});
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
