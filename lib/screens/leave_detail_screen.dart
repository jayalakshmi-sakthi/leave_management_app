// lib/screens/leave_detail_screen.dart
import 'dart:io'; // Only needed for mobile apps
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

class LeaveDetailScreen extends StatefulWidget {
  final String leaveId;
  const LeaveDetailScreen({super.key, required this.leaveId});

  @override
  State<LeaveDetailScreen> createState() => _LeaveDetailScreenState();
}

class _LeaveDetailScreenState extends State<LeaveDetailScreen> {
  final _fs = FirestoreService();
  final _picker = ImagePicker();
  final _storage = StorageService();

  Map<String, dynamic>? _data;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadLeaveDetails();
  }

  // ---------------- Load leave details ----------------
  Future<void> _loadLeaveDetails() async {
    final info = await _fs.getLeaveById(widget.leaveId);
    if (mounted) setState(() => _data = info);
  }

  // ---------------- Upload signed form (only if approved) ----------------
  Future<void> _uploadSignedForm() async {
    if (_data == null) return;

    if ((_data!['status'] ?? '').toString().toLowerCase() != 'approved') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signed form can be uploaded ONLY after approval'),
        ),
      );
      return;
    }

    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (picked == null) return;

    setState(() => _loading = true);

    final file = File(picked.path);
    final leaveId = widget.leaveId;
    final academicYear = _data!['academicYear'] ?? "2024-2025";

    try {
      final url = await _storage.uploadSignedForm(leaveId, file);

      await FirebaseFirestore.instance
          .collection("leaveRequests_$academicYear")
          .doc(leaveId)
          .update({'signedFormUrl': url});

      await _loadLeaveDetails();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed form uploaded successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------- Open URL in browser ----------------
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open file: $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Leave Details")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final fmt = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(
        title: Text(_data!['applicationId'] ?? 'Leave Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoTile("Leave Type", _data!['leaveType']),
              _infoTile(
                  "From Date", fmt.format(DateTime.parse(_data!['fromDate']))),
              _infoTile(
                  "To Date", fmt.format(DateTime.parse(_data!['toDate']))),
              _infoTile("No. of Days", "${_data!['numberOfDays']}"),
              _infoTile("Reason", _data!['reason'] ?? '—'),
              _infoTile("Status", _data!['status']),
              const SizedBox(height: 20),

              // ---------------- View signed form if exists ----------------
              if (_data!['signedFormUrl'] != null)
                ElevatedButton.icon(
                  onPressed: () => _openUrl(_data!['signedFormUrl']),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text("View Uploaded Signed Form"),
                ),

              const SizedBox(height: 10),

              // ---------------- Upload signed form ----------------
              ElevatedButton.icon(
                onPressed: _loading ? null : _uploadSignedForm,
                icon: const Icon(Icons.camera_alt),
                label: const Text("Upload Signed Form"),
              ),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- Reusable info tile ----------------
  Widget _infoTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$title: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }
}
