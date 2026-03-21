import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart'; // ✅ Added for XFile support
import 'package:flutter/foundation.dart' as foundation;
import '../services/cloudinary_service.dart';
import '../services/notification_service.dart'; // ✅ Added
import '../services/pdf_service.dart' as pdf_service_pkg; // ✅ Added import
import 'pdf_preview_screen.dart'; // ✅ Added
import '../services/firestore_service.dart';
import '../widgets/responsive_wrapper.dart';

class RequestCompOffScreen extends StatefulWidget {
  const RequestCompOffScreen({super.key});

  @override
  State<RequestCompOffScreen> createState() => _RequestCompOffScreenState();
}

class _RequestCompOffScreenState extends State<RequestCompOffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  
  // State for Date Selection
  bool _isMultiDay = false;
  DateTime? _fromDate;
  DateTime? _toDate;
  
  double _daysRequested = 1.0;
  bool _isLoading = false;
  
  // Proof Upload
  PlatformFile? _proofFile;

  // Colors used inline as const Color(0xFF001C3D)
  // static const Color darkSlate = Color(0xFF0F172A); // Use Theme
  // static const Color scaffoldBg = Color(0xFFF8FAFC); // Use Theme

  void _calculateDays() {
    if (_isMultiDay && _fromDate != null && _toDate != null) {
      final diff = _toDate!.difference(_fromDate!).inDays + 1;
      setState(() => _daysRequested = diff.toDouble());
    } else if (!_isMultiDay) {
      // Reset to 1.0 if switching back to single day unless user changes it manually
      if (_daysRequested > 1.0) {
        setState(() => _daysRequested = 1.0);
      }
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_isMultiDay) {
      if (_fromDate == null || _toDate == null) {
        return _showSnackBar("Please select a date range");
      }
    } else {
      if (_fromDate == null) {
        return _showSnackBar("Please select a date");
      }
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final academicYear = (DateTime.now().month >= 6)
          ? "${DateTime.now().year}-${DateTime.now().year + 1}"
          : "${DateTime.now().year - 1}-${DateTime.now().year}";

      // Use fromDate as the primary 'workedDate' for sorting
      final workedDate = _fromDate!; 

      String? proofUrl;
      if (_proofFile != null) {
        if (foundation.kIsWeb) {
           proofUrl = await CloudinaryService.uploadFileBytes(
             _proofFile!.bytes!, 
             _proofFile!.name
           ).timeout(const Duration(seconds: 15));
        } else if (_proofFile!.path != null) {
           proofUrl = await CloudinaryService.uploadFile(XFile(_proofFile!.path!))
               .timeout(const Duration(seconds: 15));
        }
      }

      // --- FETCH USER DETAILS ---
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get().timeout(const Duration(seconds: 10));
      final userData = userDoc.data() ?? {};
      final userName = userData['name'] ?? 'An employee';
      final employeeId = userData['employeeId'] ?? userData['manualEmployeeId'] ?? 'KEC';
      final department = userData['department'] ?? 'General';

      // SUBMIT VIA SERVICE TO GET SEQUENTIAL ID
      final applicationId = await FirestoreService().createCompOffRequest(
        userId: user.uid,
        userName: userName, // ✅ Added
        employeeId: employeeId,
        department: department,
        fromDate: _fromDate!,
        toDate: (_isMultiDay ? _toDate : _fromDate)!,
        days: _daysRequested,
        description: _descriptionController.text.trim(),
        isMultiDay: _isMultiDay,
        proofUrl: proofUrl,
      ).timeout(const Duration(seconds: 15));

      // Prepare Data for PDF (with generated applicationId)
      final pdfData = {
        "userId": user.uid,
        "userName": userName,
        "employeeId": employeeId,
        "applicationId": applicationId, // ✅ RECEIVED FROM SERVICE
        "department": department,
        "leaveType": "Comp-Off Earn",
        "isMultiDay": _isMultiDay,
        "workedDate": workedDate.toIso8601String(),
        "fromDate": _fromDate!.toIso8601String(),
        "toDate": (_isMultiDay ? _toDate : _fromDate)!.toIso8601String(),
        "numberOfDays": _daysRequested,
        "description": _descriptionController.text.trim(),
        "status": "Pending",
        "academicYearId": academicYear,
        "createdAt": DateTime.now().toIso8601String(),
        "proofUrl": proofUrl,
      };

      if (mounted) {
        setState(() => _isLoading = false);
        _showSuccessDialog(pdfData); 
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showSnackBar("Error: $e");
    }
  }

  void _showSuccessDialog(Map<String, dynamic> requestData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: const [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
            SizedBox(height: 12),
            Text("Request Submitted"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Your Comp-Off request has been sent for approval.\nYou will be notified once reviewed.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // PDF Download Button
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  Navigator.pop(ctx); // Close Dialog first
                  Navigator.pop(context); // Close Screen
                  // Navigate to Preview Screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PdfPreviewScreen(requestData: requestData),
                    ),
                  );
                } catch (e) {
                  debugPrint("PDF Error: $e");
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Failed to generate PDF: $e")));
                }
              },
              icon: const Icon(Icons.download_rounded),
              label: const Text("Download Application"),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("Close", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickProof() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    if (result != null) {
      setState(() => _proofFile = result.files.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("Earn Comp-Off Credit",
            style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.titleLarge?.color)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ResponsiveWrapper(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTypeToggle(),
              const SizedBox(height: 24),

              const Text("WORK DETAILS",
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.2)),
              const SizedBox(height: 16),

              _buildDateTile(),
              const SizedBox(height: 20),

              // Duration Dropdown is only for Single Day (Half/Full)
              // For Multi-Day, it's auto-calculated
              if (!_isMultiDay) _buildDropdown(),
              if (_isMultiDay) _buildDaysDisplay(),
              
              const SizedBox(height: 20),

              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                decoration: InputDecoration(
                  labelText: "Description of work done",
                  labelStyle: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  ),
                validator: (v) => v!.isEmpty ? "Description required" : null,
              ),

               const SizedBox(height: 20),

               // --- PROOF UPLOAD ---
               Row(
                 children: [
                   Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(
                         color: Colors.blue.withOpacity(0.1),
                         borderRadius: BorderRadius.circular(12)),
                     child: const Icon(Icons.attach_file, color: const Color(0xFF001C3D)),
                   ),
                   const SizedBox(width: 12),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Text("Work Proof (Optional)",
                             style: TextStyle(fontWeight: FontWeight.bold)),
                         if (_proofFile != null)
                           Text(_proofFile!.name,
                               style: const TextStyle(
                                   color: Colors.green, fontSize: 12),
                               overflow: TextOverflow.ellipsis)
                         else
                           const Text("Attach document (PDF/Image)",
                               style: TextStyle(color: Colors.grey, fontSize: 12)),
                       ],
                     ),
                   ),
                   TextButton(
                     onPressed: _pickProof,
                     child: Text(_proofFile == null ? "Attach" : "Change"),
                   )
                 ],
               ),
               if (_proofFile != null) ...[
                 const SizedBox(height: 8),
                 // Basic text indicator
               ],
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF001C3D),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Submit to Admin",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _toggleButton("Single Day", !_isMultiDay)),
          Expanded(child: _toggleButton("Multiple Days", _isMultiDay)),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, bool isActive) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isMultiDay = label == "Multiple Days";
          _fromDate = null;
          _toDate = null;
          _daysRequested = 1.0;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Theme.of(context).cardColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isActive ? const Color(0xFF001C3D) : Colors.grey),
        ),
      ),
    );
  }

  Widget _buildDateTile() {
    return InkWell(
      onTap: () async {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final colorScheme = isDark 
             ? const ColorScheme.dark(primary: const Color(0xFF001C3D), onPrimary: Colors.white, surface: Color(0xFF1E293B), onSurface: Colors.white)
             : const ColorScheme.light(primary: const Color(0xFF001C3D));

        if (_isMultiDay) {
          final range = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2024),
            lastDate: DateTime.now(),
            builder: (context, child) => Theme(
              data: Theme.of(context).copyWith(
                  colorScheme: colorScheme,
                  dialogTheme: DialogTheme(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
              ),
              child: child!,
            ),
          );
          if (range != null) {
            setState(() {
              _fromDate = range.start;
              _toDate = range.end;
              _calculateDays();
            });
          }
        } else {
          final d = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2024),
            lastDate: DateTime.now(),
             builder: (context, child) => Theme(
              data: Theme.of(context).copyWith(
                  colorScheme: colorScheme,
                  dialogTheme: DialogTheme(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
              ),
              child: child!,
            ),
          );
          if (d != null) {
            setState(() {
              _fromDate = d;
              _toDate = d; // Same day
            });
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded, color: const Color(0xFF001C3D)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isMultiDay ? "From - To Date" : "Worked Date",
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateDisplay(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _fromDate == null ? Colors.grey[400] : Theme.of(context).textTheme.titleMedium?.color,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.unfold_more_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  String _formatDateDisplay() {
    if (_fromDate == null) return "Select Date(s)";
    if (!_isMultiDay) return DateFormat('MMM dd, yyyy').format(_fromDate!);
    if (_toDate == null) return DateFormat('MMM dd, yyyy').format(_fromDate!);
    return "${DateFormat('MMM dd, yyyy').format(_fromDate!)} - ${DateFormat('MMM dd, yyyy').format(_toDate!)}";
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: DropdownButtonFormField<double>(
        value: _daysRequested,
        dropdownColor: Theme.of(context).cardColor,
        decoration: const InputDecoration(
            border: InputBorder.none, labelText: "Duration"),
        items: const [
          DropdownMenuItem(value: 1.0, child: Text("Full Day (1.0)")),
          DropdownMenuItem(value: 0.5, child: Text("Half Day (0.5)")),
        ],
        onChanged: (v) => setState(() => _daysRequested = v!),
      ),
    );
  }

  Widget _buildDaysDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Use primary color for background instead of text color to avoid white-on-white
        color: const Color(0xFF001C3D), 
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          "${_daysRequested.toStringAsFixed(0)} Days Earned",
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}
