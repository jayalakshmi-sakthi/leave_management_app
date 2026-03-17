import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class CompOffDetailScreen extends StatelessWidget {
  final String docId;
  final String? department; // ✅ Added for faster fetching

  const CompOffDetailScreen({super.key, required this.docId, this.department});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Comp-Off Request Info", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<QuerySnapshot>(
        // ✅ Robust Fetch: Search across all departments using collectionGroup
        future: FirebaseFirestore.instance
            .collectionGroup('records')
            .where(FieldPath.documentId, isEqualTo: docId)
            .limit(1)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Request not found"));
          }

          final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          
          // Parse Dates
          dynamic workedVal = data['workedDate'];
          DateTime workedDate;
          if (workedVal is Timestamp) workedDate = workedVal.toDate();
          else if (workedVal is String) workedDate = DateTime.tryParse(workedVal) ?? DateTime.now();
          else workedDate = DateTime.now();

          final status = data['status'] ?? 'Pending';
          final statusColor = _getStatusColor(status);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🏷️ Status Header
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // 📄 Details Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      _detailTile(Icons.calendar_month, "Worked on", DateFormat('EEE, MMM dd, yyyy').format(workedDate)),
                      const Divider(height: 32),
                      _detailTile(Icons.stars_rounded, "Days Credited", "${data['days'] ?? 0.0}"),
                      const Divider(height: 32),
                      _detailTile(Icons.history_edu, "Academic Year", data['academicYearId'] ?? 'N/A'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 📝 Description
                const Text("Reason & Description", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF64748B))),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                  ),
                  child: Text(
                    data['description'] ?? "No description provided.",
                    style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF0F172A)),
                  ),
                ),
                const SizedBox(height: 24),

                // 📎 Evidence
                if (data['proofUrl'] != null && (data['proofUrl'] as String).isNotEmpty) ...[
                  const Text("Attached Evidence", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF64748B))),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final url = Uri.parse(data['proofUrl']);
                      if (await canLaunchUrl(url)) await launchUrl(url);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.attachment_rounded, color: Color(0xFF3399CC)),
                          SizedBox(width: 12),
                          Text("View Shared Document", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3399CC))),
                          Spacer(),
                          Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF3399CC)),
                        ],
                      ),
                    ),
                  ),
                ],

                // 💡 Feedback for staff
                if (status == 'Rejected') ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.1)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.redAccent),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Your request was not approved. Please contact the administrator for more details.",
                            style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _detailTile(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF64748B), size: 20),
        const SizedBox(width: 16),
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved': return Colors.teal;
      case 'Rejected': return Colors.red;
      default: return Colors.amber;
    }
  }
}
