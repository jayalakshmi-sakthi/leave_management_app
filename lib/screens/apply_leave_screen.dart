import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/leave_model.dart';

class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  String? selectedLeaveType;
  DateTime? startDate;
  DateTime? endDate;

  final leaveTypes = ['Casual', 'Vacation', 'Compensation'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Apply Leave")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: "Leave Type"),
              items: leaveTypes
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      ))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  selectedLeaveType = val;
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() {
                    startDate = picked;
                  });
                }
              },
              child: Text(
                  "Select Start Date: ${startDate != null ? startDate!.toLocal().toString().split(' ')[0] : 'Not selected'}"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: startDate ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() {
                    endDate = picked;
                  });
                }
              },
              child: Text(
                  "Select End Date: ${endDate != null ? endDate!.toLocal().toString().split(' ')[0] : 'Not selected'}"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // Validation
                if (selectedLeaveType == null ||
                    startDate == null ||
                    endDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }

                // Generate unique leave ID
                String leaveId =
                    FirebaseFirestore.instance.collection('leaves').doc().id;

                LeaveModel leave = LeaveModel(
                  leaveId: leaveId,
                  userId:
                      'employee_001', // TODO: Replace with real logged-in user ID later
                  leaveType: selectedLeaveType!,
                  startDate: startDate!,
                  endDate: endDate!,
                  status: 'Pending',
                );

                // Save to Firestore
                await FirebaseFirestore.instance
                    .collection('leaves')
                    .doc(leaveId)
                    .set(leave.toMap());

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Leave submitted successfully')),
                );

                // Go back to HomeScreen
                Navigator.pop(context);
              },
              child: const Text("Submit Leave"),
            ),
          ],
        ),
      ),
    );
  }
}
