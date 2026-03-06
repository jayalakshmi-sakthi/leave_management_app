import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart'; // Keep for XFile
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart' as pd;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/cloudinary_service.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart'; 
import '../utils/helpers.dart';
import '../widgets/responsive_wrapper.dart';
import 'pdf_preview_screen.dart'; // ✅ Added for Preview Screen

class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  // final _types = ['CL', 'VL', 'COMP', 'SL']; // Removed: Using dynamic list
  String? _selected;
  DateTime? _from;
  DateTime? _to;
  final _reason = TextEditingController();
  // final _compDate = TextEditingController(); // Removed
  bool _loading = false;
  Map<String, dynamic>? _lastRequestData; // ✅ Added for PDF Preview // Restored

  // final _picker = ImagePicker(); // Removed
  PlatformFile? _pickedFile;
  // late final String academicYear; // Removed duplicate
  // --- Soulful Palette ---
  // --- Soulful Palette ---
  static const Color primaryPurple = Color(0xFF7C3AED); // Violet 600
  static const Color accentPurple = Color(0xFF5B21B6); // Violet 800
  // Helper getters for colors if needed, but prefer Theme.of(context) in build
  // Re-introducing static colors locally if they are used outside build or as quick fixes
  // but better to use dynamic values.
  // For now, let's define them to fix compilation, but marked as fallback.
  static const Color darkSlate = Color(0xFF0F172A);
  static const Color softText = Color(0xFF64748B);
  static const Color glassBorder = Color(0xFFE2E8F0);
  static const Color cardBg = Colors.white; // Default for light mode fallback

  // --- Config State ---
  String academicYear = ""; // Will be fetched
  bool _configLoading = true;
  
  // Dynamic Leave Types
  List<String> _types = []; 

  // --- Logic State ---
  // DateTime? _from; // Already declared above
  // DateTime? _to; // Already declared above
  // String? _selected; // Already declared above
  // bool _loading = false; // Already declared above
  bool _loadingEx = false;
  
  bool _isMultiDay = false; // ✅ Added Toggle State
  bool _startHalfDay = false;
  bool _endHalfDay = false;
  
  double _daysRequested = 0.0; // ✅ Added State Variable
  
  // --- Half Day Logic ---
  bool _isHalfDay = false;
  String _halfDaySession = 'FN';

  DateTime? _selectedCompDate;

  List<Map<String, dynamic>> _compGrants = [];

  // --- Real-time Balances ---
  Map<String, double> _balances = {};

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
       // Fetch valid Academic Year & Leave Types from Admin Settings
       final fs = FirestoreService();
       final userId = FirebaseAuth.instance.currentUser?.uid;
       
       if (userId == null) return;

       final userSnap = await FirebaseFirestore.instance.collection('users').doc(userId).get();
       final userDept = userSnap.data()?['department'] ?? 'General';

       final balanceData = await fs.getUserBalances(userId);
       final acSettings = await fs.getAcademicYearSettings(department: userDept);
       final typesList = await fs.getLeaveTypes(department: userDept);
       
       if (mounted) {
         setState(() {
           _balances = balanceData['balances'];
           academicYear = acSettings['label'] ?? "2024-2025";
           
           // Convert regex/maps to simple string list for dropdown
           // Also ensure COMP is present if logic demands, or rely on admin config?
           // The UI logic heavily relies on 'COMP' string for conditionals.
           // Admin Config 'name' usually matches.
           
           _types = typesList
               .map((e) => e['name'] as String)
               .where((name) => name != 'SL' && name != 'OD') // Force remove SL and OD (OD has separate menu)
               .toList();
           
           // Safety Fallback: Baseline types if settings are empty
           if (_types.isEmpty) _types = ['CL', 'VL'];
           
           // Ensure COMP is in the list if implementation expects it
           if (!_types.contains('COMP')) _types.add('COMP');
           
           // CRITICAL FIX: Preserve 'OD' if it was added by didChangeDependencies (Deep Link)
           if (_selected == 'OD' && !_types.contains('OD')) {
             _types.add('OD');
           }
           
           _configLoading = false;
         });
       }
    } catch (e) {
      debugPrint("Config Load Error: $e");
      // Fallback
      if (mounted) {
         setState(() {
           academicYear = "2024-2025";
           _types = ['CL', 'VL', 'COMP']; 
           _configLoading = false;
         });
      }
    }
  }

  // --- Argument Handling ---
  bool _isLocked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['type'] == 'OD') {
      setState(() {
         // Temporarily add OD if not in list yet, will be handled in build
         if (!_types.contains('OD')) _types.add('OD');
         _selected = 'OD';
         _isLocked = true;
      });
    }
  }

  double _calculateWorkingDays(DateTime a, DateTime b) {
    if (a.isAfter(b)) return 0.0;
    
    // Normalize to midnight to avoid time-of-day edge cases
    DateTime start = DateTime(a.year, a.month, a.day);
    DateTime end = DateTime(b.year, b.month, b.day);

    // If Single Day, return 0.5 or 1.0 based on _isHalfDay
    if (!_isMultiDay) {
       // if Sunday, 0 working days
       if (start.weekday == 7) return 0.0;
       return _isHalfDay ? 0.5 : 1.0;
    }

    double days = 0;
    DateTime current = start;
    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      // weekday: 1=Mon, 6=Sat, 7=Sun
      if (current.weekday < 7) { 
        days += 1.0;
      }
      current = current.add(const Duration(days: 1));
    }
    
    // Subtract 0.5 for each partial day checked in multi-day mode
    if (_startHalfDay) days -= 0.5;
    if (_endHalfDay) days -= 0.5;
    
    return days < 0 ? 0 : days;
  }

  // --- COMP OFF LOGIC START ---

  // Multi-select state
  final Set<String> _selectedCompGrantIds = {};

  Future<void> _fetchCompData() async {
    setState(() => _loadingEx = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Fetch All Grants (Earned)
      // 1. Fetch from Subcollection
      final qSub = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('compOffGrants')
          .get();

      // 2. Fetch from Root
      final qRoot = await FirebaseFirestore.instance
          .collection('compOffGrants')
          .where('userId', isEqualTo: user.uid)
          .where('academicYearId', isEqualTo: academicYear)
          .get();

      // Merge and Sort
      final allDocs = [...qSub.docs, ...qRoot.docs];
      allDocs.sort((a, b) {
         dynamic valA = a.data()['workedDate'];
         dynamic valB = b.data()['workedDate'];
         DateTime dA;
         DateTime dB;
         
         if (valA is Timestamp) dA = valA.toDate();
         else if (valA is String) dA = DateTime.parse(valA);
         else dA = DateTime(1970);
         
         if (valB is Timestamp) dB = valB.toDate();
         else if (valB is String) dB = DateTime.parse(valB);
         else dB = DateTime(1970);
         
         return dA.compareTo(dB);
      });
      
      final grantDocs = allDocs;

      // 2. Fetch All Usage (Spent)
      final usageSnap = await FirebaseFirestore.instance
          .collection("leaveRequests")
          .where('userId', isEqualTo: user.uid)
          .where('academicYearId', isEqualTo: academicYear)
          .get();

      double totalUsed = 0;
      
      // Helper
      double safeParse(dynamic v) {
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v) ?? 0.0;
        return 0.0;
      }

      for (var doc in usageSnap.docs) {
        final d = doc.data();
        if (d['leaveType'] == 'COMP' && d['status'] != 'Rejected') {
           totalUsed += safeParse(d['numberOfDays']);
        }
      }

      List<Map<String, dynamic>> processed = [];
      String? firstAvailableId;
      DateTime? firstAvailableDate;

      for (var doc in grantDocs) {
        final data = doc.data();
        final grantId = doc.id;
        
        // Robust Date Parsing
        dynamic wVal = data['workedDate'];
        DateTime workedDate;
        if (wVal is Timestamp) workedDate = wVal.toDate();
        else if (wVal is String) workedDate = DateTime.parse(wVal);
        else workedDate = DateTime.now();

        // Robust Days Parsing
        final daysGranted = safeParse(data['days']);

        // FIFO Consumption Logic
        double consumedFromThis = 0;
        String status = "Available"; // Available, Partial, Used

        if (totalUsed >= daysGranted) {
          consumedFromThis = daysGranted;
          totalUsed -= daysGranted;
          status = "Used";
        } else if (totalUsed > 0) {
           consumedFromThis = totalUsed;
           totalUsed = 0;
           status = "Partial"; // Some balance remains
        } else {
          consumedFromThis = 0;
          status = "Available";
        }

        double remaining = daysGranted - consumedFromThis;

        // Auto-detect first available (optional default)
        if ((status == "Available" || status == "Partial") &&
            firstAvailableId == null && remaining > 0) {
          firstAvailableId = grantId;
          firstAvailableDate = workedDate;
        }

        processed.add({
          'id': grantId,
          'date': workedDate,
          'total': daysGranted,
          'remaining': remaining,
          'status': status,
          'reason': data['reason'] ?? ''
        });
      }

      // SORTING: Prefer Available/Partial first, then by Date
      processed.sort((a, b) {
        final statusA = a['status'] as String;
        final statusB = b['status'] as String;
        final dateA = a['date'] as DateTime;
        final dateB = b['date'] as DateTime;

        final isUsedA = statusA == 'Used';
        final isUsedB = statusB == 'Used';

        if (isUsedA != isUsedB) {
          // If A is used and B is not, A goes after B (return 1)
          return isUsedA ? 1 : -1;
        }
        // Both same status category, sort by date ascending (FIFO)
        return dateA.compareTo(dateB);
      });

      setState(() {
        _compGrants = processed;
        // Default select ONE if none selected, or keep existing?
        // User asked to select multiple. Let's start with EMPTY or First?
        // Let's standardly select the first available for convenience, 
        // but put it in the SET.
        if (_selectedCompGrantIds.isEmpty && firstAvailableId != null) {
          _selectedCompGrantIds.add(firstAvailableId);
          _selectedCompDate = firstAvailableDate; // Primary date
        }
      });
    } catch (e) {
      debugPrint("Error fetching comp data: $e");
    } finally {
      setState(() => _loadingEx = false);
    }
  }

  Widget _buildCompOffSelector() {
    if (_selected != 'COMP') return const SizedBox.shrink();

    if (_loadingEx) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_compGrants.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withOpacity(0.3))),
        child: Column(
          children: [
            Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 12),
                Expanded(
                    child: Text(
                        "No Earned Comp Offs available. Please Request Comp Off first.",
                        style: TextStyle(
                            color: Colors.orange, fontWeight: FontWeight.bold))),
              ],
            ),
          ],
        ),
      );
    }

    // Calculate total selected days
    double totalSelectedDays = 0;
    for (var g in _compGrants) {
      if (_selectedCompGrantIds.contains(g['id'])) {
        totalSelectedDays += (g['remaining'] as double);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             _buildHeaderSection("Select Earned Comp Off", "Oldest Credits Applied First"),
             if (totalSelectedDays > 0)
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                 decoration: BoxDecoration(
                   color: Colors.blue.withOpacity(0.1),
                   borderRadius: BorderRadius.circular(12),
                   border: Border.all(color: Colors.blue.withOpacity(0.3))
                 ),
                 child: Text(
                   "Selected: ${totalSelectedDays.toString().replaceAll(RegExp(r'\.0$'), '')} Days",
                   style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                 ),
               )
          ],
        ),
        
        const SizedBox(height: 14),
        Container(
          height: 155, 
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _compGrants.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = _compGrants[index];
              final date = item['date'] as DateTime;
              final remaining = item['remaining'] as double;
              final reason = item['reason'] as String;
              final grantId = item['id'] as String;
              
              final isSelected = _selectedCompGrantIds.contains(grantId); // Set check
              final isUsed = remaining <= 0;

              // Formatting "Days Left"
              String daysLeftText;
              if (isUsed) {
                daysLeftText = "USED";
              } else {
                final val = remaining.toString().replaceAll(RegExp(r'\.0$'), '');
                daysLeftText = "$val ${remaining == 1 ? 'Day' : 'Days'} Left";
              }

              return InkWell(
                onTap: isUsed
                    ? null
                    : () {
                        setState(() {
                          if (isSelected) {
                            _selectedCompGrantIds.remove(grantId);
                           if (_selectedCompGrantIds.isEmpty) _selectedCompDate = null;
                          } else {
                            _selectedCompGrantIds.add(grantId);
                            // Update primary date to this one if it's the first or just latest clicked
                            _selectedCompDate = date; 
                          }
                        });
                      },
                borderRadius: BorderRadius.circular(16),
                child: Opacity(
                  opacity: isUsed ? 0.5 : 1.0,
                  child: Container(
                    width: 150,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primaryPurple.withOpacity(0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: isSelected ? primaryPurple : glassBorder,
                          width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('MMM dd, yyyy').format(date),
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: isSelected ? primaryPurple : darkSlate),
                        ),
                        Text(
                          DateFormat('yyyy').format(date),
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  isSelected ? primaryPurple : Colors.grey[600]),
                        ),
                        const SizedBox(height: 4),
                        // Reason Text
                        Text(
                          reason.isEmpty ? "Work Check-in" : reason,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[700]),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: isUsed
                                  ? Colors.grey[200]
                                  : (isSelected
                                      ? primaryPurple
                                      : Colors.green[50]),
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            daysLeftText,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isUsed
                                    ? Colors.grey
                                    : (isSelected
                                        ? Colors.white
                                        : Colors.green)),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- COMP OFF LOGIC END ---

// Modified _pickDate to handle Half Day logic
  Future<void> _pickDate(bool isFromDate) async {
    HapticFeedback.mediumImpact();
    
    // Calculate initial date for picker
    final initial = isFromDate
        ? (_from ?? DateTime.now())
        : (_to ?? _from ?? DateTime.now());

    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2023),
      lastDate: DateTime(2028),
      builder: (context, child) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return Theme(
          data: theme.copyWith(
            colorScheme: isDark 
                ? const ColorScheme.dark(primary: primaryPurple, onPrimary: Colors.white, surface: Color(0xFF1E293B), onSurface: Colors.white)
                : const ColorScheme.light(primary: primaryPurple, onSurface: darkSlate),
            dialogTheme: DialogTheme(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28))),
          ),
          child: child!,
        );
      },
    );

    if (d != null) {
      setState(() {
        if (!_isMultiDay) {
           // Single Day Mode: Both are same
           _from = d;
           _to = d;
        } else {
           // Multi Day Mode
           if (isFromDate) {
             _from = d;
             // Ensure To is valid
             if (_to != null && _from!.isAfter(_to!)) _to = null;
           } else {
             _to = d;
             // Ensure From is valid
             if (_from != null && _to!.isBefore(_from!)) _from = _to;
           }
        }
      });
    }
  }

  void _showSuccessOverlay({pw.Document? pdf, String? error}) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                    color: darkSlate.withOpacity(0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 20))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(error == null ? Icons.check_circle_rounded : Icons.warning_rounded,
                    color: error == null ? Colors.green : Colors.orange, size: 80),
                const SizedBox(height: 24),
                Text(error == null ? "Request Sent!" : "Request Sent (PDF Error)",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: darkSlate)),
                const SizedBox(height: 12),
                Text("Your application has been received.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: softText, fontSize: 15)),
                if (error != null) ...[
                   const SizedBox(height: 12),
                   Flexible( // ✅ Added Flexible to prevent overflow
                     child: SingleChildScrollView(
                       child: Container(
                         padding: const EdgeInsets.all(8),
                         decoration: BoxDecoration(
                           color: Colors.red.withOpacity(0.1),
                           borderRadius: BorderRadius.circular(8)
                         ),
                         child: Text("PDF Generation Failed:\n$error\n\nYou can download it later from Leave Details.",
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red, fontSize: 13)),
                       ),
                     ),
                   )
                ],
                const SizedBox(height: 32),
                
                // 📄 DOWNLOAD OPTION
                if (pdf != null) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PdfPreviewScreen(requestData: _lastRequestData!),
                          ),
                        );
                      },
                      icon: const Icon(Icons.download_rounded, color: primaryPurple),
                      label: const Text("Download Application",
                          style: TextStyle(
                              color: primaryPurple, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: primaryPurple, width: 2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16))),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx); // Close dialog
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/home',
                        (route) => false,
                      ); // Navigate to home and clear stack
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: darkSlate,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16))),
                    child: const Text("Return Home",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
       // Ensure navigation happens even if dialog is dismissed by tapping outside
       if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
       }
    });

  }

  // --------------------------------------------------
  // 🆔 ID GENERATOR (TRANSACTIONAL)
  // --------------------------------------------------
  Future<String> _generateApplicationId() async {
    final year = DateTime.now().year;
    final ref = FirebaseFirestore.instance.collection('counters').doc('applications');

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);

      int currentCount = 0;
      if (snapshot.exists) {
        currentCount = snapshot.data()?['count'] ?? 0;
      }

      final newCount = currentCount + 1;
      transaction.set(ref, {'count': newCount}, SetOptions(merge: true));

      // Format: APP-YYYY-XXXX (e.g. APP-2026-0042)
      return "APP-$year-${newCount.toString().padLeft(4, '0')}";
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_from == null || _to == null) return _showSnackBar('Select dates.');

    if (_selected == 'COMP') {
      if (_selectedCompGrantIds.isEmpty) {
        return _showSnackBar("Please select at least one Comp-Off Grant.");
      }

      // 🛑 VALIDATION: Check if selected credits cover the requested days
      double totalCredits = 0;
      for (var g in _compGrants) {
        if (_selectedCompGrantIds.contains(g['id'])) {
          totalCredits += (g['remaining'] as double);
        }
      }

      final requested = _isHalfDay ? 0.5 : _calculateWorkingDays(_from!, _to!);
      
      if (totalCredits < requested) {
        return _showSnackBar("Insufficient credits! Selected: ${totalCredits.toStringAsFixed(1)}, Requested: $requested");
      }
    }

    // 🛑 VALIDATION: Check Balance (Before loading starts)
    final days = _calculateWorkingDays(_from!, _to!);
    final requestedDays = _isHalfDay ? 0.5 : days;

    if (_selected != 'COMP' && _selected != 'OD') {
      final currentBalance = _balances[_selected] ?? 0.0;
      if (requestedDays > currentBalance) {
         return _showSnackBar("Insufficient balance! Remaining: ${currentBalance.toStringAsFixed(1)}, Requested: $requestedDays");
      }
    }

    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      // 🆔 Generate Sequential ID
      final applicationId = await _generateApplicationId();
      
      String? fileUrl;
      // ☁️ UPLOAD TO CLOUDINARY IF FILE PICKED
      if (_pickedFile != null) {
        try {
          if (foundation.kIsWeb) {
            fileUrl = await CloudinaryService.uploadFileBytes(
              _pickedFile!.bytes!,
              _pickedFile!.name,
            );
          } else if (_pickedFile!.path != null) {
            fileUrl = await CloudinaryService.uploadFile(XFile(_pickedFile!.path!));
          }
        } catch (e) {
          debugPrint("Cloudinary Upload Failed: $e");
        }
      }

      // --- FETCH USER DETAILS FIRST ---
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      final userData = userDoc.data() ?? {};
      final userName = userData['name'] ?? 'N/A';
      final employeeId = userData['employeeId'] ?? 'N/A';
      final department = userData['department'] ?? 'General';
      final departmentId = userData['departmentId'] ?? 'general';

      final data = {
        "applicationId": applicationId, // ✅ Meaningful ID
        "userId": user.uid,
        "userName": userName, // ✅ Saved for Admin Panel
        "employeeId": employeeId, // ✅ Saved for Admin Panel
        "department": department, // ✅ Saved for Filtering
        "departmentId": departmentId, // ✅ Saved for Filtering
        "leaveType": _selected,
        "fromDate": Timestamp.fromDate(_from!),
        "toDate": Timestamp.fromDate(_to!),
        "numberOfDays": _isHalfDay ? 0.5 : days,
        "reason": _reason.text.trim(),
        "status": "Pending",
        "createdAt": FieldValue.serverTimestamp(),
        "isHalfDay": _isHalfDay,
        "halfDaySession": _isHalfDay ? _halfDaySession : null,
        "signedFormUrl": fileUrl, // ✅ Save Cloudinary URL
        "academicYearId": academicYear, // ✅ Required for Admin Panel Sync
      };

      if (_selected == 'COMP') {
        data['compensationWorkedDate'] =
            Timestamp.fromDate(_selectedCompDate!);
      }

      await FirebaseFirestore.instance
          .collection("leaveRequests") 
          .doc(applicationId)
          .set(data);

      // 🔔 SEND NOTIFICATION TO ADMIN
      // Note: In future, we can filter notifications by department too
      await NotificationService().sendNotification(
        toUserId: 'admin',
        title: 'New Leave Request ($department)',
        body: '$userName ($department) has applied for ${Helpers.getLeaveName(_selected!)}.',
        type: 'request',
        relatedId: applicationId,
      );

      // User details already fetched above

      try {
        final pdf = pw.Document();
        final font = pw.Font.helvetica();
        final fontBold = pw.Font.helveticaBold();

        pdf.addPage(
          pw.Page(
            pageTheme: pw.PageTheme(
              pageFormat: pd.PdfPageFormat.a4,
              theme: pw.ThemeData.withFont(base: font, bold: fontBold), // ✅ Moved here
              margin: const pw.EdgeInsets.all(24),
              buildBackground: (context) => pw.FullPage(
                ignoreMargins: true,
                child: pw.Container(color: pd.PdfColors.white),
              ),
            ), 
            build: (pw.Context context) {
              return pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: pd.PdfColors.black, width: 2),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // 🏛️ Header
                    pw.Center(
                      child: pw.Column(
                        children: [
                          pw.Text("KONGU ENGINEERING COLLEGE",
                              style: pw.TextStyle(
                                  font: fontBold, fontSize: 18)),
                          pw.Text("(Autonomous)",
                              style: pw.TextStyle(font: font, fontSize: 12)),
                          pw.Text("PERUNDURAI, ERODE - 638 060",
                              style: pw.TextStyle(font: font, fontSize: 12)),
                          pw.SizedBox(height: 10),
                          pw.Text("LEAVE APPLICATION FORM",
                              style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 16,
                                  decoration: pw.TextDecoration.underline)),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 25),

                    // 📋 Application Details Table
                    pw.Table(
                      border: pw.TableBorder.all(color: pd.PdfColors.black),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(2),
                        1: const pw.FlexColumnWidth(3),
                      },
                      children: [
                        _buildPdfRow("Application No", applicationId, font, fontBold),
                        _buildPdfRow("Date of Application",
                            DateFormat('dd-MMM-yyyy').format(DateTime.now()),
                            font, fontBold),
                        _buildPdfRow("Name of the Applicant", userName.toUpperCase(),
                            font, fontBold),
                        _buildPdfRow("Employee ID", employeeId, font, fontBold),
                        _buildPdfRow("Type of Leave", _selected ?? "-", font, fontBold),
                        if (_isHalfDay)
                          _buildPdfRow(
                              "Session",
                              "${_halfDaySession == 'FN' ? 'Forenoon' : 'Afternoon'} Half Day",
                              font,
                              fontBold),
                        _buildPdfRow(
                            "Period of Leave",
                            "${DateFormat('dd-MM-yyyy').format(_from!)}  to  ${DateFormat('dd-MM-yyyy').format(_to!)}",
                            font,
                            fontBold),
                        _buildPdfRow("No. of Days",
                            "${_isHalfDay ? 0.5 : days} Days", font, fontBold),
                        _buildPdfRow("Reason for Leave", _reason.text, font, fontBold),
                        if (_selected == 'COMP' && _selectedCompGrantIds.isNotEmpty) ...[
                          _buildPdfRow(
                              "Compensating Dates",
                              _compGrants
                                  .where((g) => _selectedCompGrantIds.contains(g['id']))
                                  .map((g) => DateFormat('dd-MM-yyyy').format(g['date'] as DateTime))
                                  .join(', '),
                              font,
                              fontBold),
                        ],
                      ],
                    ),

                    pw.SizedBox(height: 20),

                    // 📝 Declaration
                    pw.Text("Declaration:",
                        style: pw.TextStyle(font: fontBold, fontSize: 12)),
                    pw.SizedBox(height: 5),
                    pw.Text(
                        "I hereby request that the above leave may kindly be granted. I have made alternative arrangements for my duties during my absence.",
                        style: pw.TextStyle(font: font, fontSize: 11, lineSpacing: 1.5),
                        textAlign: pw.TextAlign.justify),

                    pw.SizedBox(height: 60),

                    // ✍️ Signatures
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(children: [
                          pw.Container(width: 80, height: 1, color: pd.PdfColors.black),
                          pw.SizedBox(height: 4),
                          pw.Text("Signature of the Staff",
                              style: pw.TextStyle(font: fontBold, fontSize: 10)),
                        ]),
                        pw.Column(children: [
                          pw.Container(width: 80, height: 1, color: pd.PdfColors.black),
                          pw.SizedBox(height: 4),
                          pw.Text("Placement Officer",
                              style: pw.TextStyle(font: fontBold, fontSize: 10)),
                        ]),
                        pw.Column(children: [
                          pw.Container(width: 80, height: 1, color: pd.PdfColors.black),
                          pw.SizedBox(height: 4),
                          pw.Text("Principal",
                              style: pw.TextStyle(font: fontBold, fontSize: 10)),
                        ]),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
         // _showPdfPreview(pdf); // ⚠️ Disabled due to Web issues, using Direct Download in Overlay instead
         _lastRequestData = data; // Save for Preview
         _showSuccessOverlay(pdf: pdf);
      } catch (e) {
        debugPrint("PDF Generation Error: $e");
        // Don't show success overlay if PDF fails, but maybe show snackbar
        _showSnackBar("Leave Submitted, but PDF failed: $e");
         _showSuccessOverlay(error: e.toString()); // Fallback with Error Message
      }
      
      setState(() => _loading = false);
      // Removed direct _showSuccessOverlay call to prevent skipping PDF
    } catch (e) {
      setState(() => _loading = false);
      _showSnackBar("Error: $e");
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(msg, maxLines: 3, overflow: TextOverflow.ellipsis)),
        ],
      ),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Calculate days for display and logic
    final days = (_from != null && _to != null)
        ? (_isHalfDay ? 0.5 : _calculateWorkingDays(_from!, _to!))
        : 0.0;
        
    // Keep internal state in sync (optional but safe for the condition below)
    _daysRequested = days;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selected == 'OD') 
               const Padding(
                 padding: EdgeInsets.only(right: 8.0),
                 child: Icon(Icons.business_center_rounded, color: primaryPurple, size: 24),
               ),
            Text(_selected == 'OD' ? 'On-Duty Application' : 'Leave Request',
                style: TextStyle(
                    fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.titleLarge?.color, fontSize: 18)),
          ],
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        centerTitle: true,
        elevation: 0,
        leading: _buildPremiumBackButton(),
      ),
      body: ResponsiveWrapper(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hide Category Selection for On-Duty (User Request)
                if (_selected != 'OD') ...[
                  _buildHeaderSection("Category", "Select your leave type"),
                  const SizedBox(height: 14),
                  _buildPremiumDropdown(),
                  const SizedBox(height: 28),
                ],

                // Insert Comp Off Selector Here
                _buildCompOffSelector(),
                if (_selected == 'COMP') const SizedBox(height: 28),

                // --- Half Day Toggle ---
                // Show if Single Day AND NOT Comp Off
                if (!_isMultiDay && _selected != 'COMP') ...[
                  _buildHalfDayToggle(),
                  const SizedBox(height: 20),
                ],

                _buildHeaderSection("Period", "Select duration for absence"),
                const SizedBox(height: 14),
                
                // Toggle Button
                _buildTypeToggle(),
                const SizedBox(height: 16),
                
                _buildDateGrid(), 
                
                // Fractional Days for Multi-Day
                if (_isMultiDay && _daysRequested > 1.0) ...[
                   const SizedBox(height: 12),
                   Row(
                     children: [
                        Expanded(child: _buildCheckbox("Start Half Day", _startHalfDay, (v) => setState(() => _startHalfDay = v!))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildCheckbox("End Half Day", _endHalfDay, (v) => setState(() => _endHalfDay = v!))),
                     ],
                   )
                ],

                const SizedBox(height: 16),
                _buildWorkingDaysBadge(days),
                const SizedBox(height: 28),

                _buildHeaderSection(
                  "Information", 
                  _selected == 'OD' ? "Provide details" : "Provide a detailed reason"
                ),
                const SizedBox(height: 14),
                _buildPremiumField(
                    _reason, 
                    _selected == 'OD' ? "Enter details..." : "Enter reason...", 
                    Icons.notes_rounded, 
                    4
                ),
                const SizedBox(height: 32),

                _buildPremiumUploadButton(),
                const SizedBox(height: 40),

                _buildGradientSubmitButton(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildPremiumBackButton() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor)),
        child: IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: theme.iconTheme.color, size: 20),
            onPressed: () => Navigator.pop(context)),
      ),
    );
  }

  Widget _buildHeaderSection(String title, String subtitle) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: primaryPurple,
                letterSpacing: 1.2)),
        Text(subtitle, style: TextStyle(fontSize: 13, color: theme.textTheme.bodySmall?.color)),
      ],
    );
  }

  Widget _buildPremiumDropdown() {
    if (_configLoading) {
       return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Center(
             child: Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                 const SizedBox(width: 12),
                 Text("Loading Leave Types...", style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
               ],
             )
          ),
       );
    }

    return Container(
      decoration: BoxDecoration(boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10))
      ]),
      child: DropdownButtonFormField<String>(
        value: _selected,
        isExpanded: true, 
        decoration: _premiumInputDecoration(
            Icons.auto_awesome_mosaic_rounded, "Select Type"),
        // If locked, only allow the selected item or disable the dropdown
        onChanged: _isLocked ? null : (v) { // Setting onChanged to null disables the dropdown
          if (v == null) return;
          
          final balance = _balances[v] ?? 0.0;
          if (balance <= 0 && v != 'COMP' && v != 'OD') { 
            _showSnackBar("You have no remaining days for ${Helpers.getLeaveName(v)}");
            return;
          }

          setState(() {
            _selected = v;
            if (v == 'COMP') {
               _isMultiDay = false; 
            }
          });
          if (v == 'COMP') {
            _fetchCompData();
          }
        },
        items: _types.map((t) {
          final label = Helpers.getLeaveName(t);
          final icon = Helpers.getLeaveIcon(t);
          final color = Helpers.getLeaveColor(t);
          final balance = _balances[t] ?? 0.0;
          // Don't exhaust COMP or OD
          final isExhausted = balance <= 0 && t != 'COMP' && t != 'OD';

          return DropdownMenuItem(
            value: t,
            enabled: !isExhausted, 
            child: Opacity(
              opacity: isExhausted ? 0.4 : 1.0,
              child: Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))),
                  if (t != 'COMP' && t != 'OD')
                    Text(
                      "Rem: ${balance.toInt()}",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isExhausted ? Colors.red : primaryPurple,
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
        validator: (v) => v == null ? 'Required' : null,
      ),
    );
  }

  Widget _buildDateGrid() {
    return Row(
      children: [
        Expanded(child: _dateTile(_isMultiDay ? "FROM DATE" : "DATE", _from, true)),
        if (_isMultiDay) ...[
          const SizedBox(width: 12),
          Expanded(child: _dateTile("TO DATE", _to, false)),
        ]
      ],
    );
  }

  Widget _dateTile(String label, DateTime? date, bool isFrom) {
    bool active = date != null;
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _pickDate(isFrom),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: active ? primaryPurple : theme.dividerColor, width: 1.5),
          boxShadow: [
            BoxShadow(
                color: active
                    ? primaryPurple.withOpacity(0.08)
                    : Colors.black.withOpacity(0.02),
                blurRadius: 15)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: theme.textTheme.bodySmall?.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            FittedBox(
              // Prevents text overflow on small screens
              fit: BoxFit.scaleDown,
              child: Text(
                  active ? Helpers.formatDate(date!) : "Select",
                  style: TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 14, color: theme.textTheme.titleMedium?.color)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkingDaysBadge(double days) {
    if (days <= 0) return const SizedBox();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
          color: darkSlate, borderRadius: BorderRadius.circular(18)),
      child: Center(
          child: Text("$days Working Days",
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14))),
    );
  }

  Widget _buildPremiumField(TextEditingController controller, String hint,
      IconData icon, int maxLines) {
    return Container(
      decoration: BoxDecoration(boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10))
      ]),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontWeight: FontWeight.w700),
        decoration: _premiumInputDecoration(icon, hint),
        validator: (v) => v!.isEmpty ? "Required" : null,
      ),
    );
  }

  Widget _buildPremiumUploadButton() {
    bool isPicked = _pickedFile != null;
    bool isPdf = isPicked && _pickedFile!.extension == 'pdf';
    final theme = Theme.of(context);

    return InkWell(
      onTap: () async {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.any,
        );
        if (result != null) {
          setState(() => _pickedFile = result.files.first);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isPicked ? (isPdf ? Colors.red.withOpacity(0.05) : Colors.green.withOpacity(0.05)) : theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isPicked ? (isPdf ? Colors.red : Colors.green) : theme.dividerColor, width: 1.5),
        ),
        child: Column(
          children: [
            if (isPicked)
               isPdf 
                ? const Icon(Icons.picture_as_pdf, color: Colors.red, size: 48)
                : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: foundation.kIsWeb || _pickedFile?.bytes != null
                    ? Image.memory(
                        _pickedFile!.bytes!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.insert_drive_file, size: 48, color: Colors.blue),
                )
            else
              Icon(
                Icons.cloud_upload_rounded,
                color: primaryPurple,
                size: 28),
            const SizedBox(height: 8),
            Text(isPicked ? "File Selected: ${_pickedFile!.name}" : "Upload Document (PDF/Image)",
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: theme.textTheme.titleMedium?.color,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientSubmitButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [primaryPurple, accentPurple]),
        boxShadow: [
          BoxShadow(
              color: primaryPurple.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: ElevatedButton(
        onPressed: _loading ? null : _submit,
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20))),
        child: _loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 3))
            : const Text("SUBMIT APPLICATION",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1)),
      ),
    );
  }

  InputDecoration _premiumInputDecoration(IconData icon, String label) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
          color: theme.textTheme.bodySmall?.color, fontSize: 13, fontWeight: FontWeight.w600),
      prefixIcon: Icon(icon, color: primaryPurple, size: 22),
      filled: true,
      fillColor: theme.cardColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: theme.dividerColor)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: primaryPurple, width: 2)),
    );
  }
  pw.TableRow _buildPdfRow(String label, String value, pw.Font font, pw.Font fontBold) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(label, style: pw.TextStyle(font: fontBold)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(value, style: pw.TextStyle(font: font)),
        ),
      ],
    );
  }

  Widget _buildHalfDayToggle() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _isHalfDay ? primaryPurple : theme.dividerColor),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_rounded, color: primaryPurple, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Half Day Leave",
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Theme.of(context).textTheme.titleMedium?.color),
                ),
              ),
              Switch.adaptive(
                value: _isHalfDay,
                activeColor: primaryPurple,
                onChanged: (val) {
                  setState(() {
                    _isHalfDay = val;
                    if (_isHalfDay && _from != null) {
                      _to = _from; // Auto-sync to single day
                    }
                  });
                },
              ),
            ],
          ),
          if (_isHalfDay) ...[
             const Padding(
               padding: EdgeInsets.symmetric(vertical: 8), 
               child: Divider(height: 1),
             ),
             Row(
               children: [
                 const Text("Session:", style: TextStyle(color: softText, fontWeight: FontWeight.bold)),
                 const SizedBox(width: 16),
                 Expanded(
                   child: Row(
                     children: [
                       _buildRadioSession("Forenoon", "FN"),
                       const SizedBox(width: 12),
                       _buildRadioSession("Afternoon", "AN"),
                     ],
                   ),
                 )
               ],
             )
          ]
        ],
      ),
    );
  }

  Widget _buildRadioSession(String label, String value) {
    bool selected = _halfDaySession == value;
    return InkWell(
      onTap: () => setState(() => _halfDaySession = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? primaryPurple.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? primaryPurple : Colors.grey.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? primaryPurple : Theme.of(context).textTheme.bodySmall?.color,
            fontWeight: FontWeight.bold,
            fontSize: 13
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(String label, bool value, Function(bool?) onChanged) {
    return Container(
      decoration: BoxDecoration(
         color: cardBg,
         borderRadius: BorderRadius.circular(12),
         border: Border.all(color: glassBorder)
      ),
      child: CheckboxListTile(
        title: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodySmall?.color)),
        value: value,
        onChanged: onChanged,
        dense: true,
        activeColor: primaryPurple,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  // --- Toggle Widgets Added ---
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
    bool isDisabled = false; // Unblocked for Comp-Off
    
    return GestureDetector(
      onTap: isDisabled ? null : () {
        setState(() {
          _isMultiDay = label == "Multiple Days";
          // Reset logic
          if (!_isMultiDay) {
            // Switched to single: To = From
            if (_from != null) _to = _from;
          } else {
             _isHalfDay = false; // Reset halfday
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: isDisabled ? Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.4) : (isActive ? primaryPurple : Theme.of(context).textTheme.bodySmall?.color),
          ),
        ),
      ),
    );
  }

  void _showPdfPreview(pw.Document pdf) {
    // 🧠 REAL-TIME FLOW: Use pushReplacement so user can't go back to the form
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (ctx) => _ZoomablePdfScreen(
          pdf: pdf,
          onComplete: () => _handlePdfCompletion(ctx),
        ),
      ),
    );
  }

  void _handlePdfCompletion(BuildContext dialogCtx) async {
    // Show brief success message using the DIALOG context BEFORE navigation
    ScaffoldMessenger.of(dialogCtx).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Leave application submitted successfully!',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Navigate to home and clear everything
    Navigator.of(dialogCtx).pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
    );
  }
}



// =============================================================================
// 🧠 CUSTOM ZOOMABLE PDF VIEWER
// =============================================================================
class _ZoomablePdfScreen extends StatefulWidget {
  final pw.Document pdf;
  final VoidCallback onComplete;

  const _ZoomablePdfScreen({required this.pdf, required this.onComplete});

  @override
  State<_ZoomablePdfScreen> createState() => _ZoomablePdfScreenState();
}

class _ZoomablePdfScreenState extends State<_ZoomablePdfScreen> {
  final TransformationController _transformationController = TransformationController();
  Uint8List? _imageBytes;
  bool _rasterizing = true;

  @override
  void initState() {
    super.initState();
    _rasterizePdf();
  }

  Future<void> _rasterizePdf() async {
    try {
      final pdfBytes = await widget.pdf.save();
      // Render first page (Leave Applications are single page)
      // Increasing Scale for better quality (2.0 = 2x resolution)
      // Printing.raster uses 'dpi' in newer versions, usually defaults to 72. 
      // 2.0 scale approx 144 dpi.
      await for (final page in Printing.raster(pdfBytes, pages: [0], dpi: 144)) {
        final image = await page.toPng();
        if (mounted) {
          setState(() {
            _imageBytes = image;
            _rasterizing = false;
          });
        }
        break; // Only need first page
      }
    } catch (e) {
      debugPrint("Rasterization Error: $e");
      if (mounted) setState(() => _rasterizing = false);
    }
  }

  void _zoom(bool zoomIn) {
    const double factor = 0.2;
    final Matrix4 current = _transformationController.value;
    final double currentScale = current.getMaxScaleOnAxis();
    
    // Limits
    if (zoomIn && currentScale >= 3.0) return;
    if (!zoomIn && currentScale <= 0.5) return;

    final double newScale = zoomIn ? currentScale + factor : currentScale - factor;
    final Matrix4 newMatrix = Matrix4.identity()..scale(newScale);
    _transformationController.value = newMatrix;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark Slate
      appBar: AppBar(
        title: const Text("Application Preview"),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onComplete,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded, color: Colors.white70),
            onPressed: () async => await Printing.layoutPdf(onLayout: (_) => widget.pdf.save()),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white70),
            onPressed: () async => await Printing.sharePdf(bytes: await widget.pdf.save(), filename: 'leave_application.pdf'),
          ),
           IconButton(
             icon: const Icon(Icons.done_all_rounded, color: Colors.greenAccent),
             onPressed: widget.onComplete,
           ),
           const SizedBox(width: 8),
        ],
      ),
      body: _rasterizing
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _imageBytes == null
              ? const Center(child: Text("Failed to render PDF", style: TextStyle(color: Colors.white)))
              : Center(
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.memory(
                      _imageBytes!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
      floatingActionButton: _imageBytes == null ? null : Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: "zoom_in",
            onPressed: () => _zoom(true),
            backgroundColor: const Color(0xFF1E293B),
            child: const Icon(Icons.add, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
             heroTag: "zoom_out",
            onPressed: () => _zoom(false),
            backgroundColor: const Color(0xFF1E293B),
            child: const Icon(Icons.remove, color: Colors.white),
          ),
          const SizedBox(height: 60), // Space for bottom
        ],
      ),
    );
  }
}
