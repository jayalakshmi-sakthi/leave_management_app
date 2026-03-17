import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart'; // ✅ Added
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firestore_service.dart';
import '../services/cloudinary_service.dart'; 
import '../utils/helpers.dart';
import '../services/pdf_service.dart'; // ✅ Added
import 'pdf_preview_screen.dart'; // ✅ Added

class LeaveDetailScreen extends StatefulWidget {
  final String leaveId;
  final String academicYearId;
  final String? department; // ✅ Added for faster fetching

  const LeaveDetailScreen({
    super.key,
    required this.leaveId,
    required this.academicYearId,
    this.department,
  });

  @override
  State<LeaveDetailScreen> createState() => _LeaveDetailScreenState();
}

class _LeaveDetailScreenState extends State<LeaveDetailScreen> {
  final _fs = FirestoreService();
  final _pdfService = PdfService(); // ✅ Added
  final _picker = ImagePicker();

  Map<String, dynamic>? _data;
  bool _loading = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadLeaveDetails();
  }

  // ---------------- Load leave details ----------------
  Future<void> _loadLeaveDetails() async {
    setState(() => _loading = true); // Set loading while fetching
    try {
      final info = await _fs.getLeaveById(widget.leaveId, widget.academicYearId, department: widget.department);
      if (mounted) setState(() => _data = info);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------- Upload signed form (only if approved) ----------------
  Future<void> _uploadSignedForm() async {
    if (_data == null) return;

    if ((_data!['status'] ?? '').toString().toLowerCase() != 'approved') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signed form can be uploaded ONLY after approval'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Result variable
    String? fileUrl;

    // Show options: Camera, Gallery, or File Picker
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF001C3D)),
              title: const Text("Take Photo"),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                if (picked != null) _processAndUpload(picked);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF001C3D)),
              title: const Text("Choose from Gallery"),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                if (picked != null) _processAndUpload(picked);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Color(0xFF001C3D)),
              title: const Text("Upload PDF / File"),
              onTap: () async {
                Navigator.pop(ctx);
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                  withData: foundation.kIsWeb, // Important for Web
                );
                
                if (result != null && result.files.single.path != null || (foundation.kIsWeb && result?.files.single.bytes != null)) {
                   _uploadFilePickerResult(result!.files.single);
                }
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // Helper: Upload file from ImagePicker
  Future<void> _processAndUpload(XFile file) async {
    setState(() => _uploading = true);
    try {
      final url = await CloudinaryService.uploadFile(file);
      if (url != null) await _updateFirestoreAndUI(url);
    } catch (e) {
      _showError("Upload Failed: $e");
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // Helper: Upload file from FilePicker (Handles Web & Mobile)
  Future<void> _uploadFilePickerResult(PlatformFile file) async {
    setState(() => _uploading = true);
    try {
      String? url;
      if (foundation.kIsWeb) {
        if (file.bytes == null) throw Exception("Failed to read file bytes");
        url = await CloudinaryService.uploadFileBytes(file.bytes!, file.name);
      } else {
        if (file.path == null) throw Exception("Invalid file path");
        url = await CloudinaryService.uploadFile(XFile(file.path!));
      }

      if (url != null) {
        await _updateFirestoreAndUI(url);
      } else {
        throw Exception("Upload returned null");
      }
    } catch (e) {
      _showError("Upload Failed: $e");
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // Update Database Logic
  Future<void> _updateFirestoreAndUI(String url) async {
    await _fs.updateSignedForm(widget.leaveId, widget.academicYearId, url);
    if (mounted) {
      setState(() {
        _data!['finalSignedFormUrl'] = url;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploaded successfully!'), backgroundColor: Colors.green),
      );
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  // ---------------- Open URL in browser ----------------
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to open file: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Leave Details")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Leave Details")),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text("Record not found", style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("ID: ${widget.leaveId}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final fmt = DateFormat('dd MMM yyyy'); // Cleaner format

    return Scaffold(
      appBar: AppBar(
        title: Text(_data!['applicationId'] ?? 'Leave Details'),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoTile("Leave Type", _data!['leaveType']),
                  const Divider(),
                  _infoTile("From Date", _formatDate(_data!['fromDate'])),
                  _infoTile("To Date", _formatDate(_data!['toDate'])),
                  _infoTile("No. of Days", "${_data!['numberOfDays']}"),
                  const Divider(),
                  _infoTile("Reason", _data!['reason'] ?? '—'),
                  const Divider(),

                  _statusTile(_data!['status']),

                  const SizedBox(height: 16),
                  
                  // Download Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                         Navigator.push(
                           context,
                           MaterialPageRoute(
                             builder: (_) => PdfPreviewScreen(requestData: _data!),
                           ),
                         );
                      },
                      icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF001C3D)),
                      label: const Text("View/Download Application Form"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFF001C3D)),
                        foregroundColor: Color(0xFF001C3D),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                  
                  // ---------------- View/Upload Section ----------------

                  // If signed form exists (renamed/new field or existing 'signedFormUrl')
                  // NOTE: Data model uses 'signedFormUrl' for the uploaded attachment from USer
                  // User "Uploads Signed Form" -> Should ideally be a DIFFERENT field?
                  // Earlier 'signedFormUrl' was used for initial attachment.
                  // Now user wants to upload "Signed Application".
                  // If I overwrite 'signedFormUrl', I lose the initial attachment.
                  // BUT the user request said "upload the signed application... it can be viewed".
                  // I will overwrite 'signedFormUrl' for now as per previous plan "use existing signedFormUrl field".
                  // Actually, implementation plan Step 482 said: "Update LeaveModel with finalSignedFormUrl".
                  // I should use `finalSignedFormUrl` if I updated the model.
                  // Let's check LeaveModel... I didn't update it yet.
                  // I will use `signedFormUrl` for simplicity as requested in Step 483 ("I will use the existing signedFormUrl field").

                  // View Uploaded Document (Initial Application / Proof)
                  if (_data!['signedFormUrl'] != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openUrl(_data!['signedFormUrl']),
                        icon: const Icon(Icons.description, color: Color(0xFF001C3D)),
                        label: const Text("View Application / Attachment"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Color(0xFF001C3D)),
                          foregroundColor: Color(0xFF001C3D),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // View Signed Copy (If uploaded)
                  if (_data!['finalSignedFormUrl'] != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openUrl(_data!['finalSignedFormUrl']),
                        icon: const Icon(Icons.verified_user, color: Colors.green),
                        label: const Text("View Signed Copy"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.green),
                          foregroundColor: Colors.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Upload Signed Copy Button
                  if ((_data!['status'] ?? '').toString().toLowerCase() == 'approved') ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _uploading ? null : _uploadSignedForm,
                        icon: const Icon(Icons.upload_file, color: Colors.white),
                        label: Text(_data!['finalSignedFormUrl'] == null
                            ? "Upload Signed Copy"
                            : "Re-upload Signed Copy"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF001C3D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "* Please upload the printed application form signed by the Principal.",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_uploading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '-';
    try {
      if (dateStr is Timestamp) {
        return DateFormat('dd MMM yyyy').format(dateStr.toDate());
      } else if (dateStr is String) {
        final d = DateTime.tryParse(dateStr) ?? DateTime.now();
        return DateFormat('dd MMM yyyy').format(d);
      }
      return dateStr.toString();
    } catch (e) {
      return dateStr.toString();
    }
  }

  Widget _infoTile(String title, dynamic value) {
    bool isType = title == "Leave Type";
    IconData? icon;
    Color iconCol = Colors.grey;
    String displayValue = value?.toString() ?? '-';

    if (isType && value != null) {
      icon = Helpers.getLeaveIcon(displayValue);
      iconCol = Helpers.getLeaveColor(displayValue);
      displayValue = Helpers.getLeaveName(displayValue);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text("$title",
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.grey)),
          ),
          Expanded(
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: iconCol),
                  const SizedBox(width: 8),
                ],
                Text(displayValue,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _statusTile(String status) {
    Color col = Helpers.getStatusColor(status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 120, child: Text("Status", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey))),
           Container(
             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
             decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
             child: Text(status.toUpperCase(), style: TextStyle(color: col, fontWeight: FontWeight.bold)),
           )
        ],
      ),
    );
  }
}
