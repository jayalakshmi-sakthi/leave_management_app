import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/firestore_service.dart';
import '../services/excel_service.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:image_cropper/image_cropper.dart'; // Removed
import 'dart:typed_data'; // Added for bytes
import '../services/cloudinary_service.dart'; // Added
import 'crop_screen.dart';
// import 'dart:io'; // REMOVED for Web Compatibility
import 'dart:typed_data'; // For Uint8List
import '../utils/helpers.dart';
import '../widgets/responsive_wrapper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fire = FirebaseFirestore.instance; // ✅ Added
  final FirestoreService _fs = FirestoreService();
  Map<String, dynamic>? _data;
  bool _loading = true;

  // Analytics State
  List<String> _academicYears = [];
  String? _selectedYear;

  // Colors defined inline as const Color(0xFF001C3D) / const Color(0xFF003366)

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadYears();
  }

  Future<void> _loadYears() async {
    final years = await _fs.getAcademicYears();
    if (mounted) {
      setState(() {
        _academicYears = years;
        if (_academicYears.isNotEmpty) {
          _selectedYear = _academicYears.first; // Default to most recent
        }
      });
    }
  }

  Future<void> _loadProfile() async {
    if (mounted) setState(() => _loading = true);
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (mounted) {
        setState(() {
          _data = snap.data();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF001C3D),
          ),
        ),
        title: const Text("My Profile",
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () => _showEditProfileDialog(),
            icon: const Icon(Icons.edit_rounded, color: Colors.white),
            tooltip: "Edit Profile",
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_data == null) {
      return Center(
          child: TextButton.icon(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry")));
    }

    final name = _data!['name'] ?? 'User';
    final email = _data!['email'] ?? '—';
    // Removed redundant Role (System Level)
    final empId = (_data!['manualEmployeeId'] ?? _data!['employeeId'] ?? 'Not Assigned').toString();
    final designation = _data!['designation'] ?? 'Placement Staff';

    return ResponsiveWrapper(
      child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // LARGE AVATAR
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF001C3D).withOpacity(0.2), width: 4)),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFF001C3D).withOpacity(0.1),
              backgroundImage: _data!['profilePicUrl'] != null 
                  ? NetworkImage(_data!['profilePicUrl']) 
                  : null,
              child: _data!['profilePicUrl'] == null 
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF001C3D)))
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.w900, 
                color: Theme.of(context).textTheme.titleLarge?.color
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
                color: const Color(0xFF001C3D).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Text(empId,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: empId == 'Not Assigned' ? const Color(0xFFF59E0B) : const Color(0xFF001C3D),
                    letterSpacing: 1)),
          ),
          const SizedBox(height: 40),
          _profileItem(Icons.email_outlined, "Email Address", email),
          const SizedBox(height: 16),
          _profileItem(Icons.work_outline_rounded, "Designation", designation),
          const SizedBox(height: 16),
          _profileItem(Icons.domain_rounded, "Department", _data!['department'] ?? 'Not Selected'),
          const SizedBox(height: 32),
          _buildAnalyticsSection(),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text("Sign Out", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildAnalyticsSection() {
    if (_academicYears.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 12),
          child: Text("ANALYTICS & HISTORY",
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF001C3D),
                  letterSpacing: 1.2)),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              // Year Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Academic Year:",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedYear,
                      underline: const SizedBox(),
                      items: _academicYears
                          .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedYear = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // 📊 ADMIN-STYLE STATS ROW
              if (_selectedYear != null)
                FutureBuilder<Map<String, int>>(
                   future: _fetchYearlyStats(_selectedYear!),
                   builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final stats = snapshot.data!;
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _statCard(stats['total']!, "Total", Icons.folder_open_rounded, const Color(0xFF001C3D))),
                              const SizedBox(width: 12),
                              Expanded(child: _statCard(stats['pending']!, "Pending", Icons.hourglass_empty_rounded, const Color(0xFFF59E0B))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _statCard(stats['approved']!, "Approved", Icons.verified_rounded, const Color(0xFF10B981))),
                              const SizedBox(width: 12),
                              Expanded(child: _statCard(stats['rejected']!, "Rejected", Icons.cancel_outlined, const Color(0xFFEF4444))),
                            ],
                          ),
                        ],
                      );
                   },
                ),

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                        Icons.download_rounded, "Excel Report", _exportHistoricalExcel),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _actionButton(
                        Icons.calendar_month_rounded, "Calendar View", _showHistoricalCalendar),
                  ),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  Future<Map<String, int>> _fetchYearlyStats(String year) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {'total': 0, 'pending': 0, 'approved': 0, 'rejected': 0};

    final department = _data?['department'] ?? 'General';
    final snap = await _fire.collection('leaveRequests')
        .doc(department)
        .collection('records')
        .where('userId', isEqualTo: uid)
        .where('academicYearId', isEqualTo: year)
        .get();

    final docs = snap.docs;
    return {
      'total': docs.length,
      'pending': docs.where((d) => d['status'] == 'Pending').length,
      'approved': docs.where((d) => d['status'] == 'Approved').length,
      'rejected': docs.where((d) => d['status'] == 'Rejected').length,
    };
  }

  Widget _statCard(int value, String label, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(value.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.textTheme.titleLarge?.color)),
          Text(label, style: TextStyle(fontSize: 11, color: theme.textTheme.bodyMedium?.color)),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFF001C3D).withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF001C3D).withOpacity(0.1))),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF001C3D), size: 24),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF001C3D))),
          ],
        ),
      ),
    );
  }

  Future<void> _exportHistoricalExcel() async {
    if (_selectedYear == null) return;
    
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Generating advanced report..."), duration: Duration(seconds: 2))
    );

    try {
      // 1. Fetch leaves for the selected year
      final userDept = _data?['department'] ?? 'General';
      final leaveSnap = await _fire
          .collection("leaveRequests")
          .doc(userDept)
          .collection('records')
          .where('userId', isEqualTo: uid)
          .where('academicYearId', isEqualTo: _selectedYear)
          .get();

      final leaves = leaveSnap.docs.map((d) => d.data()).toList();

      if (leaves.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No records for this year")));
         return;
      }

      // 2. Fetch leave types configuration
      final leaveTypes = await _fs.getLeaveTypes(department: userDept);
      
      // 3. Add Comp-Off as a leave type
      final compOffStats = await _fs.getCompOffStats(uid, _selectedYear!);
      final finalLeaveTypes = List<Map<String, dynamic>>.from(leaveTypes);
      
      bool hasComp = finalLeaveTypes.any((t) => t['name'] == 'COMP' || (t['leaveType'] != null && t['leaveType'] == 'COMP'));
      if (!hasComp) {
        finalLeaveTypes.add({
          'name': 'COMP',
          'days': compOffStats['limit'],
        });
      }

      // 4. Generate & Save (Universal)
      await ExcelService.generateAdvancedLeaveReport(
          userName: _data?['name'] ?? 'User',
          employeeId: (_data?['employeeId'] ?? 'N/A').toString(),
          academicYear: _selectedYear!,
          leaves: leaves,
          leaveTypes: finalLeaveTypes,
      );

      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Report generated successfully"), backgroundColor: Colors.green)
         );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red));
      }
    }
  }


  void _showHistoricalCalendar() async {
    if (_selectedYear == null) return;
    
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Fetch ONLY Approved leaves for the calendar
    final userDept = _data?['department'] ?? 'General';
    final snap = await _fire
        .collection("leaveRequests")
        .doc(userDept)
        .collection('records')
        .where('userId', isEqualTo: uid)
        .where('academicYearId', isEqualTo: _selectedYear)
        .where('status', isEqualTo: 'Approved')
        .get();

    final Map<DateTime, List<dynamic>> events = {};
    for (var doc in snap.docs) {
      final l = doc.data();
      final fromVal = l['fromDate'];
      final toVal = l['toDate'];
      
      DateTime from;
      if (fromVal is Timestamp) from = fromVal.toDate();
      else if (fromVal is String) from = DateTime.tryParse(fromVal) ?? DateTime.now();
      else from = DateTime.now();
      
      DateTime to;
      if (toVal is Timestamp) to = toVal.toDate();
      else if (toVal is String) to = DateTime.tryParse(toVal) ?? DateTime.now();
      else to = DateTime.now();

      DateTime current = DateTime(from.year, from.month, from.day);
      final end = DateTime(to.year, to.month, to.day);

      while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
        final d = DateTime(current.year, current.month, current.day);
        if (events[d] == null) events[d] = [];
        events[d]!.add(l);
        current = current.add(const Duration(days: 1));
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;

          return Container(
            decoration: BoxDecoration(
              color: theme.cardColor, // Dynamic Background
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: ListView(
              controller: scrollController,
              children: [
                 const SizedBox(height: 12),
                 Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.grey[700] : Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                 const SizedBox(height: 24),
                 Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text("Analytics View - $_selectedYear", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: theme.textTheme.titleLarge?.color)),
                 ),
                 const SizedBox(height: 16),
                 TableCalendar(
                   firstDay: DateTime.utc(2023, 1, 1),
                   lastDay: DateTime.utc(2028, 12, 31),
                   focusedDay: events.keys.isNotEmpty ? events.keys.first : DateTime.now(),
                   eventLoader: (day) => events[DateTime(day.year, day.month, day.day)] ?? [],
                   calendarFormat: CalendarFormat.month,
                   headerStyle: HeaderStyle( // Explicit text color for header
                      titleCentered: true,
                      formatButtonVisible: false,
                      titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor),
                      leftChevronIcon: Icon(Icons.chevron_left, color: textColor),
                      rightChevronIcon: Icon(Icons.chevron_right, color: textColor),
                   ),
                   calendarStyle: CalendarStyle(
                     todayDecoration: const BoxDecoration(color: const Color(0xFF001C3D), shape: BoxShape.circle),
                     markerDecoration: const BoxDecoration(color: Colors.transparent),
                     defaultTextStyle: TextStyle(color: textColor), // Explicit text
                     weekendTextStyle: const TextStyle(color: Color(0xFFF43F5E)),
                     outsideDaysVisible: false,
                   ),
                 calendarBuilders: CalendarBuilders(
                   markerBuilder: (context, date, events) {
                     if (events.isEmpty) return const SizedBox.shrink();
                     return Positioned(
                       bottom: 4,
                       child: Row(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: events.map((e) {
                            final type = (e as Map<String, dynamic>)['leaveType'] as String;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1.5),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Helpers.getLeaveColor(type),
                                shape: BoxShape.circle,
                              ),
                            );
                         }).toList(),
                       ),
                     );
                   },
                 ),
               ),
               const SizedBox(height: 32),
            ],
          ),
        );
      },
    ),
  );
  }

  Widget _profileItem(IconData icon, String label, String value,
      {bool isLocked = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 10))
          ]),
      child: Row(
        children: [
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFF001C3D).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: const Color(0xFF001C3D), size: 22)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodySmall?.color)),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).textTheme.titleMedium?.color)),
              ],
            ),
          ),
          if (isLocked)
            const Icon(Icons.lock_rounded, size: 18, color: Colors.grey)
        ],
      ),
    );

  }



  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _data?['name']);
    final idCtrl = TextEditingController(text: _data?['manualEmployeeId'] ?? _data?['employeeId']);
    final desigCtrl = TextEditingController(text: _data?['designation']);
    String? selectedDept = _data?['department']; // Load existing dept
    
    // Web Compatible: Use XFile and Bytes
    XFile? newImageFile;
    Uint8List? newImageBytes;
    bool uploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24, left: 24, right: 24),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 5)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                   children: [
                     const Text("Edit Profile", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                     const Spacer(),
                     IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded))
                   ],
                ),
                const SizedBox(height: 24),
                
                // Image Picker
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                    if (img != null) {
                      // Crop Image
                      final cropped = await _cropImage(img);
                      if (cropped != null) {
                        final bytes = await cropped.readAsBytes();
                        setModalState(() {
                          newImageFile = cropped;
                          newImageBytes = bytes;
                        });
                      }
                    }
                  },
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF001C3D).withOpacity(0.2), width: 4),
                          image: newImageBytes != null 
                              ? DecorationImage(image: MemoryImage(newImageBytes!), fit: BoxFit.cover)
                              : (_data?['profilePicUrl'] != null 
                                  ? DecorationImage(image: NetworkImage(_data!['profilePicUrl']), fit: BoxFit.cover)
                                  : null),
                        ),
                        child: (newImageBytes == null && _data?['profilePicUrl'] == null)
                            ? Center(child: Text((nameCtrl.text.isNotEmpty ? nameCtrl.text[0] : 'U').toUpperCase(), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: const Color(0xFF001C3D))))
                            : null,
                      ),
                       Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: const Color(0xFF001C3D), shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text("Tap to change • Pinch to crop", style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 32),

                _buildTextField(nameCtrl, "Full Name", Icons.person_outline),
                const SizedBox(height: 16),
                _buildTextField(idCtrl, "Employee ID", Icons.badge_outlined),
                const SizedBox(height: 16),
                _buildTextField(desigCtrl, "Designation / Role", Icons.work_outline_rounded),
                const SizedBox(height: 16),
                
                // Department Dropdown
                DropdownButtonFormField<String>(
                  value: Helpers.departments.contains(selectedDept) ? selectedDept : null,
                  decoration: InputDecoration(
                    labelText: "Department",
                    prefixIcon: const Icon(Icons.domain_rounded, color: const Color(0xFF001C3D)),
                    filled: true,
                    fillColor: const Color(0xFF001C3D).withOpacity(0.03),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  items: Helpers.departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (val) => setModalState(() => selectedDept = val),
                ),
                
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: uploading ? null : () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name cannot be empty"), backgroundColor: Colors.red));
                        return;
                      }
                      setModalState(() => uploading = true);
                      
                      try {
                        String? url;
                        if (newImageFile != null) {
                           debugPrint("Starting upload...");
                           final rawUrl = await _fs.uploadProfileImage(newImageFile!, _auth.currentUser!.uid);
                           // Append timestamp to force cache refresh since we are overwriting
                           url = "$rawUrl?v=${DateTime.now().millisecondsSinceEpoch}";
                           debugPrint("Upload complete: $url");
                        }
                        
                        await _fs.updateUserProfile(
                           _auth.currentUser!.uid,
                           nameCtrl.text.trim(),
                           idCtrl.text.trim(),
                           desigCtrl.text.trim(),
                           profilePicUrl: url,
                           department: selectedDept, // ✅ Pass Department
                         );
                         
                         if (mounted) {
                           _loadProfile();
                           Navigator.pop(context);
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated!"), backgroundColor: Colors.green));
                         }
                      } catch (e) {
                         setModalState(() => uploading = false);
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF001C3D),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: uploading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Save Changes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {String? helper}) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        prefixIcon: Icon(icon, color: const Color(0xFF001C3D)),
        filled: true,
        fillColor: const Color(0xFF001C3D).withOpacity(0.03),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: const Color(0xFF001C3D), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
  
  Future<XFile?> _cropImage(XFile imageFile) async {
      try {
        final bytes = await imageFile.readAsBytes();
        if (!mounted) return null;
        
        final Uint8List? croppedBytes = await Navigator.push(
          context, 
          MaterialPageRoute(builder: (ctx) => CropScreen(image: bytes))
        );
        
        if (croppedBytes != null) {
          // Create a named XFile from bytes so Cloudinary can handle it (if needed)
          return XFile.fromData(
            croppedBytes, 
            name: 'cropped_${DateTime.now().millisecondsSinceEpoch}.jpg',
            mimeType: 'image/jpeg'
          );
        }
        return null; // Cancelled
      } catch (e) {
        debugPrint("Error cropping: $e");
        return null;
      }
  }
}
// End
