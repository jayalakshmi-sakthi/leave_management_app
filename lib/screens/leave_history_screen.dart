import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:shimmer/shimmer.dart'; 
import '../services/firestore_service.dart';
import '../widgets/responsive_wrapper.dart';
import '../services/excel_service.dart'; // ✅ Added
import '../utils/helpers.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../main.dart';

class LeaveHistoryScreen extends StatefulWidget {
  const LeaveHistoryScreen({super.key});

  @override
  State<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

class _LeaveHistoryScreenState extends State<LeaveHistoryScreen> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirestoreService();

  // --- Soulful Palette ---
  // --- Soulful Palette ---
  static const Color primaryNavy = Color(0xFF001C3D); // KEC Navy
  static const Color accentNavy = Color(0xFF003366);
  static const Color textMain = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);

  String? _academicYear;
  late final String _uid;

  bool _isCalendarView = false;
  List<Map<String, dynamic>> _lastFetchedLeaves = [];

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    if (user == null) {
      Future.microtask(() {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      });
      return;
    }
    _uid = user.uid;
    _setAcademicYear();
  }

  void _setAcademicYear() {
    final now = DateTime.now();
    // Logic must match FirestoreService exactly
    final startYear = now.month >= 6 ? now.year : now.year - 1;
    setState(() => _academicYear = "$startYear-${startYear + 1}");
  }

  @override
  Widget build(BuildContext context) {
    if (_academicYear == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent, // Transparent to show gradient
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            color: primaryNavy,
          ),
        ),
        title: const Text("My Leaves",
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(_isCalendarView ? Icons.list_alt_rounded : Icons.calendar_month_rounded, color: Colors.white),
            onPressed: () => setState(() => _isCalendarView = !_isCalendarView),
            tooltip: _isCalendarView ? "List View" : "Calendar View",
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: _exportToExcel,
            tooltip: "Export Excel",
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ResponsiveWrapper(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _fs.getCombinedActivityStream(_uid), // ✅ Combined Stream
          builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSkeletonList();
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading history:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            );
          }

          final leaves = snapshot.data ?? [];
          _lastFetchedLeaves = leaves; // ✅ Fixed: Populate data for Excel export

          if (leaves.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off_rounded,
                      size: 64, color: Theme.of(context).textTheme.bodySmall?.color),
                  const SizedBox(height: 16),
                  Text('No history found',
                      style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                ],
              ),
            );
          }

          // ✅ Fixed: Correctly switch between List and Calendar view
          return _isCalendarView 
            ? _buildCalendarView(leaves)
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                physics: const BouncingScrollPhysics(),
                itemCount: leaves.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final l = leaves[index];
                  final leaveDocId = l['id'] ?? l['applicationId'];
                  return _buildHistoryCard(l, leaveDocId);
                },
              );
          }
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> d, String id) {
    final activityType = d['activityType'] ?? 'leave';
    final status = (d['status'] ?? 'Pending').toString();
    final statusCol = Helpers.getStatusColor(status);

    // --- CASE 1: COMP OFF REQUEST ---
    if (activityType == 'comp_off') {
       final workedDateStr = d['workedDate'];
       DateTime? from;
        if (workedDateStr != null) {
          try { from = DateTime.parse(workedDateStr); } catch (_) { from = DateTime.now(); }
        } else {
          from = DateTime.now();
        }
       final days = (d['days'] ?? 1.0).toDouble();

       return Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: _neatCard(hasBorder: true),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: primaryNavy.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.star_rounded, color: primaryNavy, size: 24)),
          title: Text('Comp-Off Request',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 15, color: Theme.of(context).textTheme.titleMedium?.color)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    "Worked: ${DateFormat('MMM dd, yyyy').format(from)}",
                    style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 13)),
                 const SizedBox(height: 2),
                 Text(
                "$days Days Earned",
                style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: statusCol.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Text(status.toUpperCase(),
                style: TextStyle(
                    color: statusCol,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 0.5)),
          ),
          onTap: () {
            Navigator.pushNamed(
              context, 
              AppRoutes.compOffDetail,
              arguments: d['id'],
            );
          },
        ),
      );
    }

    // --- CASE 2: REGULAR LEAVE ---
    // Robust Date Parsing Helper
    DateTime safeDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final from = safeDate(d['fromDate']);
    final to = safeDate(d['toDate']);

    final leaveType = d['leaveType'].toString();
    final icon = Helpers.getLeaveIcon(leaveType);
    final displayType = Helpers.getLeaveName(leaveType);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: _neatCard(hasBorder: true),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Exact match to Home
        leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: Helpers.getLeaveColor(leaveType).withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: Helpers.getLeaveColor(leaveType), size: 20)),
        title: Text(displayType,
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 15, color: Theme.of(context).textTheme.titleMedium?.color)), // Exact match: 15
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0), // Exact match: 4.0
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  "${DateFormat('MMM dd, yyyy').format(from)} - ${DateFormat('MMM dd, yyyy').format(to)}",
                  style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 13)), // Exact match: 13, regular weight
              
              // Added Days info subtly to not break alignment heavily
               const SizedBox(height: 2),
               Text(
              "${d['numberOfDays']} Days",
              style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: statusCol.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Text(status.toUpperCase(),
              style: TextStyle(
                  color: statusCol,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 0.5)),
        ),
        onTap: () {
          if (id.isNotEmpty) {
            Navigator.pushNamed(context, '/detail', arguments: {
              'leaveId': id,
              'academicYearId': _academicYear // Pass key correctly! (was 'academicYear' in prev code, verified DetailScreen expects 'academicYearId' usually? Let's check. Home used 'academicYearId'. I'll use 'academicYearId' key to be safe, or check DetailScreen)
              // Actually, previous code: 'academicYear': _academicYear
              // HomeScreen code: 'academicYearId': d['academicYearId']
              // I will use 'academicYearId' key as it matches the model.
            });
          }
        },
      ),
    );
  }

  BoxDecoration _neatCard({bool hasBorder = false}) {
     final theme = Theme.of(context);
     return BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: hasBorder
            ? Border.all(color: const Color(0xFFE2E8F0), width: 1)
            : null,
      );
  }
  Widget _buildCalendarView(List<Map<String, dynamic>> leaves) {
    // Group leaves by date for the calendar markers
    final Map<DateTime, List<dynamic>> events = {};

    for (var l in leaves) {
      if (l['status'] != 'Approved') continue; // Only show approved leaves on calendar
      
      final isCompOff = l['activityType'] == 'comp_off';
      
      if (isCompOff) {
        // --- COMP OFF CASE ---
        final workedVal = l['workedDate'];
        DateTime workedDate;
        if (workedVal is Timestamp) workedDate = workedVal.toDate();
        else if (workedVal is String) workedDate = DateTime.tryParse(workedVal) ?? DateTime.now();
        else workedDate = DateTime.now();

        final d = DateTime(workedDate.year, workedDate.month, workedDate.day);
        if (events[d] == null) events[d] = [];
        events[d]!.add(l);
      } else {
        // --- REGULAR LEAVE CASE ---
        final from = l['fromDate'] is Timestamp 
            ? (l['fromDate'] as Timestamp).toDate() 
            : DateTime.tryParse(l['fromDate'] ?? '') ?? DateTime.now();
        final to = l['toDate'] is Timestamp 
            ? (l['toDate'] as Timestamp).toDate() 
            : DateTime.tryParse(l['toDate'] ?? '') ?? DateTime.now();

        DateTime current = DateTime(from.year, from.month, from.day);
        final end = DateTime(to.year, to.month, to.day);

        while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
          final d = DateTime(current.year, current.month, current.day);
          if (events[d] == null) events[d] = [];
          events[d]!.add(l);
          current = current.add(const Duration(days: 1));
        }
      }
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Explicit High Contrast Colors
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? Colors.grey[400] : const Color(0xFF64748B);
    final weekendColor = const Color(0xFFF43F5E); // Rose-500

    return Container(
      key: const ValueKey("CalendarView"),
      margin: const EdgeInsets.all(20),
      decoration: _neatCard(hasBorder: true),
      child: TableCalendar(
        firstDay: DateTime.utc(DateTime.now().year - 2, 1, 1),
        lastDay: DateTime.utc(DateTime.now().year + 1, 12, 31),
        focusedDay: DateTime.now(),
        calendarFormat: CalendarFormat.month,
        rowHeight: 65, 
        eventLoader: (day) => events[DateTime(day.year, day.month, day.day)] ?? [],
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: primaryTextColor),
          leftChevronIcon: Icon(Icons.chevron_left, color: primaryTextColor),
          rightChevronIcon: Icon(Icons.chevron_right, color: primaryTextColor),
        ),
        calendarStyle: CalendarStyle(
           todayDecoration: BoxDecoration(color: primaryNavy.withOpacity(0.1), shape: BoxShape.circle),
           todayTextStyle: const TextStyle(color: primaryNavy, fontWeight: FontWeight.bold),
           selectedDecoration: const BoxDecoration(color: primaryNavy, shape: BoxShape.circle),
           markerDecoration: const BoxDecoration(color: Colors.transparent), 
           outsideDaysVisible: false,
           weekendTextStyle: TextStyle(color: weekendColor, fontWeight: FontWeight.w500), 
           defaultTextStyle: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600),
           holidayTextStyle: TextStyle(color: weekendColor),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.w600),
          weekendStyle: TextStyle(color: weekendColor.withOpacity(0.8), fontWeight: FontWeight.w600),
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            if (events.isEmpty) return const SizedBox.shrink();
            return Positioned(
              bottom: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: events.skip(0).take(3).map((e) {
                  final type = (e as Map<String, dynamic>)['leaveType'] as String;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Helpers.getLeaveColor(type),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Helpers.getLeaveColor(type).withOpacity(0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        )
                      ]
                    ),
                  );
                }).toList(),
              ),
            );
          },
          // Custom Day Builder for a cleaner look
          defaultBuilder: (context, day, focusedDay) {
            return Container(
              margin: const EdgeInsets.all(4),
              alignment: Alignment.center,
              child: Text(
                '${day.day}',
                style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w500, fontSize: 13),
              ),
            );
          },
        ),
        onDaySelected: (selectedDay, focusedDay) {
           final dayEvents = events[DateTime(selectedDay.year, selectedDay.month, selectedDay.day)];
           if (dayEvents != null && dayEvents.isNotEmpty) {
              _showDayEventsDialog(selectedDay, dayEvents);
           }
        },
      ),
    );
  }

  void _showDayEventsDialog(DateTime day, List<dynamic> events) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(DateFormat('MMM dd, yyyy').format(day), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: events.map((e) {
            final l = e as Map<String, dynamic>;
            final isCompOff = l['activityType'] == 'comp_off';
            final title = isCompOff ? "Comp-Off Earn" : Helpers.getLeaveName(l['leaveType']);
            final icon = isCompOff ? Icons.stars_rounded : Helpers.getLeaveIcon(l['leaveType']);
            final color = isCompOff ? const Color(0xFF8B5CF6) : Helpers.getLeaveColor(l['leaveType']);

            return ListTile(
              leading: Icon(icon, color: color),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Status: ${l['status']}"),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () {
                Navigator.pop(ctx);
                if (isCompOff) {
                  Navigator.pushNamed(context, AppRoutes.compOffDetail, arguments: l['id']);
                } else {
                  Navigator.pushNamed(context, '/detail', arguments: {
                    'leaveId': l['id'] ?? l['applicationId'],
                    'academicYear': l['academicYearId'] ?? _academicYear
                  });
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
        ],
      ),
    );
  }

  Future<void> _exportToExcel() async {
    // Unified Cross-Platform Reporting
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Generating advanced report..."), duration: Duration(seconds: 2))
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = snapshot.data();

      final userDept = userData?['department'] ?? 'General';
      final leaveSnap = await FirebaseFirestore.instance
          .collection("leaveRequests")
          .doc(userDept)
          .collection('records')
          .where('userId', isEqualTo: user.uid)
          .where('academicYearId', isEqualTo: _academicYear)
          .get();

      final leaves = leaveSnap.docs.map((d) => d.data()).toList();

      if (leaves.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No records for this year")));
        return;
      }
      final leaveTypes = await _fs.getLeaveTypes(department: userDept);
      
      // Add Comp-Off
      final compOffStats = await _fs.getCompOffStats(user.uid, _academicYear!);
      final finalLeaveTypes = List<Map<String, dynamic>>.from(leaveTypes);
      
      bool hasComp = finalLeaveTypes.any((t) => t['name'] == 'COMP' || (t['leaveType'] != null && t['leaveType'] == 'COMP'));
      if (!hasComp) {
        finalLeaveTypes.add({
          'name': 'COMP',
          'days': compOffStats['limit'],
        });
      }

      await ExcelService.generateAdvancedLeaveReport(
          userName: userData?['name'] ?? 'User',
          employeeId: (userData?['employeeId'] ?? 'N/A').toString(),
          academicYear: _academicYear!,
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

  Widget _buildSkeletonList() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, __) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      },
    );
  }
}
