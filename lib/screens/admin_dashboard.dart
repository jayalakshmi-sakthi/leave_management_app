import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late String currentYear;

  @override
  void initState() {
    super.initState();
    currentYear = _getAcademicYear();
  }

  // Automatically get academic year based on current date
  String _getAcademicYear() {
    final now = DateTime.now();
    int year = now.month >= 6 ? now.year : now.year - 1;
    return "$year-${year + 1}";
  }

  @override
  Widget build(BuildContext context) {
    final collectionName = "leaveRequests_$currentYear";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance.collection(collectionName).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());

          var docs = snap.data!.docs;

          // ------------------- Counters -------------------
          int total = docs.length;
          int approved = docs
              .where((d) =>
                  (d.data() as Map<String, dynamic>)['status'] == "approved")
              .length;
          int rejected = docs
              .where((d) =>
                  (d.data() as Map<String, dynamic>)['status'] == "rejected")
              .length;
          int pending = docs
              .where((d) =>
                  (d.data() as Map<String, dynamic>)['status'] == "pending")
              .length;

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Academic Year: $currentYear",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),

                // ------------------- Summary Cards -------------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _summaryCard("Total", total, Colors.black),
                    _summaryCard("Pending", pending, Colors.orange),
                    _summaryCard("Approved", approved, Colors.green),
                    _summaryCard("Rejected", rejected, Colors.red),
                  ],
                ),
                const SizedBox(height: 20),

                // ------------------- New Academic Year Button -------------------
                ElevatedButton(
                  onPressed: _startNewAcademicYear,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("Start New Academic Year"),
                ),
                const SizedBox(height: 20),

                const Text("Leave Requests",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(),

                // ------------------- Leave Requests List -------------------
                Expanded(
                  child: docs.isEmpty
                      ? const Center(
                          child: Text(
                            "No leave requests found",
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data =
                                docs[index].data() as Map<String, dynamic>;
                            String status = data['status'] ?? 'N/A';
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                title: Text(
                                    "Application ID: ${data['applicationId'] ?? 'Unknown'}"),
                                subtitle: Text("Status: $status"),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.check_circle),
                                      color: Colors.green,
                                      onPressed: () => _updateStatus(
                                          docs[index].id, "approved"),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.cancel),
                                      color: Colors.red,
                                      onPressed: () => _updateStatus(
                                          docs[index].id, "rejected"),
                                    ),
                                  ],
                                ),
                              ),
                            );
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

  // ------------------- Summary Card Widget -------------------
  Widget _summaryCard(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 6),
          Text("$count",
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // ------------------- Update Status -------------------
  Future<void> _updateStatus(String docId, String newStatus) async {
    await FirebaseFirestore.instance
        .collection("leaveRequests_$currentYear")
        .doc(docId)
        .update({"status": newStatus});

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Request marked as $newStatus"),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // ------------------- Start New Academic Year -------------------
  Future<void> _startNewAcademicYear() async {
    String nextYear = _getNextYear(currentYear);
    String newCollection = "leaveRequests_$nextYear";

    var check = await FirebaseFirestore.instance
        .collection(newCollection)
        .limit(1)
        .get();

    if (check.docs.isEmpty) {
      await FirebaseFirestore.instance.collection(newCollection).add({
        "createdAt": DateTime.now().toIso8601String(),
        "init": true,
      });
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("New Academic Year $nextYear Created")),
    );
  }

  String _getNextYear(String current) {
    var parts = current.split("-");
    int y1 = int.parse(parts[0]);
    return "${y1 + 1}-${y1 + 2}";
  }
}
