import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
//import 'dart:io';

class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  final _types = ['CL', 'VL', 'COMP'];
  String? _selected;
  DateTime? _from;
  DateTime? _to;
  final _reason = TextEditingController();
  bool _loading = false;

  final _picker = ImagePicker();
  XFile? _pickedFile;

  late final String academicYear;
  final StorageService _storage = StorageService(); // ✅ Instance

  @override
  void initState() {
    super.initState();
    academicYear = _computeAcademicYear();
  }

  String _computeAcademicYear() {
    final now = DateTime.now();
    final startYear = now.month >= 6 ? now.year : now.year - 1;
    return '$startYear-${startYear + 1}';
  }

  Future<void> _pickFile() async {
    final f = await _picker.pickImage(source: ImageSource.gallery);
    if (f != null) setState(() => _pickedFile = f);
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2026),
    );
    if (d != null) setState(() => _from = d);
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2026),
    );
    if (d != null) setState(() => _to = d);
  }

  int _daysBetween(DateTime a, DateTime b) => b.difference(a).inDays + 1;

  Future<void> _submit() async {
    if (_selected == null || _from == null || _to == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select leave type and dates')),
      );
      return;
    }

    if (_from!.isAfter(_to!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('From date cannot be after To date')),
      );
      return;
    }

    if (_selected == "COMP" && _pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload proof for COMP leave')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = userDoc.data();
      final name = data?['name'] ?? 'Employee';
      final empId = data?['employeeId'] ?? user.uid.substring(0, 6);

      final dateStr = DateFormat("yyyyMMdd").format(DateTime.now());
      final random =
          DateTime.now().millisecondsSinceEpoch.toString().substring(9);
      final applicationId = "$empId-$dateStr-$random";

      String? proofUrl;
      if (_pickedFile != null) {
        proofUrl = await _storage.uploadFile(
          file: _pickedFile!,
          path: "leaveProofs/$academicYear/$applicationId.jpg",
        );
      }

      final days = _daysBetween(_from!, _to!);

      await FirebaseFirestore.instance
          .collection("leaveRequests_$academicYear")
          .doc(applicationId)
          .set({
        "applicationId": applicationId,
        "userId": user.uid,
        "employeeId": empId,
        "name": name,
        "leaveType": _selected,
        "fromDate": _from!.toIso8601String(),
        "toDate": _to!.toIso8601String(),
        "numberOfDays": days,
        "reason": _reason.text.trim(),
        "status": "pending",
        "proofUrl": proofUrl,
        "academicYear": academicYear,
        "createdAt": DateTime.now().toIso8601String(),
      });

      // ✅ PDF Generation
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Leave Application Form",
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text("Application ID: $applicationId"),
              pw.Text("Employee Name: $name"),
              pw.Text("Employee ID: $empId"),
              pw.SizedBox(height: 10),
              pw.Text("Leave Type: $_selected"),
              pw.Text("From Date: ${DateFormat('yyyy-MM-dd').format(_from!)}"),
              pw.Text("To Date: ${DateFormat('yyyy-MM-dd').format(_to!)}"),
              pw.Text("Total Days: $days"),
              pw.SizedBox(height: 10),
              pw.Text("Reason: ${_reason.text.trim()}"),
              pw.SizedBox(height: 30),
              pw.Text("Employee Signature: _________________________"),
              pw.SizedBox(height: 20),
              pw.Text("HOD / Principal Approval: ____________________"),
            ],
          ),
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave Applied Successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd');
    return Scaffold(
      appBar: AppBar(title: const Text('Apply Leave')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selected,
              decoration: const InputDecoration(labelText: 'Leave Type'),
              items: _types
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _selected = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _pickFrom,
                    child: Text(
                        'From: ${_from != null ? df.format(_from!) : 'Select'}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _pickTo,
                    child:
                        Text('To: ${_to != null ? df.format(_to!) : 'Select'}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file),
              label: Text(_pickedFile == null
                  ? "Upload Proof (Optional)"
                  : "File Selected"),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loading ? null : _submit,
              icon: const Icon(Icons.check_circle),
              label: const Text("Submit Leave"),
            ),
            if (_loading) const SizedBox(height: 20),
            if (_loading) const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
