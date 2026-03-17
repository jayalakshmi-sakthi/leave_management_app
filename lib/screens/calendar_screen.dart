import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../services/pdf_service.dart';
import '../utils/helpers.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final FirestoreService _firestoreService = FirestoreService();
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  String? _userDept;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchUserDept();
  }

  Future<void> _fetchUserDept() async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
    if (mounted) {
      setState(() {
        _userDept = userDoc.data()?['department'];
      });
    }
  }

  Map<DateTime, List<Map<String, dynamic>>> _groupLeaves(List<Map<String, dynamic>> leaves) {
    Map<DateTime, List<Map<String, dynamic>>> data = {};
    
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    for (var d in leaves) {
      // Skip Rejected leaves
      if (d['status'] == 'Rejected') continue;

      DateTime start = parseDate(d['fromDate']);
      DateTime end = parseDate(d['toDate']);
      
      DateTime startDay = DateTime(start.year, start.month, start.day);
      DateTime endDay = DateTime(end.year, end.month, end.day);
      
      int days = endDay.difference(startDay).inDays + 1;
      for (int i = 0; i < days; i++) {
         DateTime day = DateTime(startDay.year, startDay.month, startDay.day + i);
         DateTime key = DateTime.utc(day.year, day.month, day.day);
         
         if (data[key] == null) data[key] = [];
         data[key]!.add(d);
      }
    }
    return data;
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    DateTime key = DateTime.utc(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Department Calendar", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: theme.textTheme.bodyLarge?.color,
      ),
      body: _userDept == null 
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _firestoreService.streamAllLeaves(department: _userDept!),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  _events = _groupLeaves(snapshot.data!);
                }

          return Column(
            children: [
              // Calendar Card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: TableCalendar(
                  firstDay: DateTime.utc(2023, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  eventLoader: _getEventsForDay,
                  calendarFormat: CalendarFormat.month,
                  startingDayOfWeek: StartingDayOfWeek.sunday, // Standard Sunday start
                  rowHeight: 52,
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF001C3D)),
                    leftChevronIcon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF001C3D)),
                    rightChevronIcon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF001C3D)),
                    headerPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13),
                    weekendStyle: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  calendarStyle: const CalendarStyle(
                    outsideDaysVisible: false,
                    markersAlignment: Alignment.bottomCenter,
                    markerMargin: EdgeInsets.only(top: 2),
                  ),
                  builders: CalendarBuilders(
                    // --- Today ---
                    todayBuilder: (context, date, _) {
                      return Container(
                        margin: const EdgeInsets.all(6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF001C3D).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF001C3D).withOpacity(0.2), width: 1),
                        ),
                        child: Text(
                          "${date.day}",
                          style: const TextStyle(color: Color(0xFF001C3D), fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                    // --- Selected ---
                    selectedBuilder: (context, date, _) {
                      return Container(
                        margin: const EdgeInsets.all(6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF001C3D),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF001C3D).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Text(
                          "${date.day}",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                    // --- Default Days ---
                    defaultBuilder: (context, date, _) {
                      return Container(
                        alignment: Alignment.center,
                        child: Text(
                          "${date.day}",
                          style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w500),
                        ),
                      );
                    },
                    // --- Event Markers ---
                    markerBuilder: (context, date, events) {
                      if (events.isEmpty) return const SizedBox.shrink();
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: events.take(3).map((e) {
                           final color = Helpers.getLeaveColor(e['leaveType'] ?? '');
                           return Container(
                             margin: const EdgeInsets.symmetric(horizontal: 1),
                             width: 5,
                             height: 5,
                             decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                           );
                        }).toList(),
                      );
                    },
                  ),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                ),
              ),
              
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: -10, offset: const Offset(0, -5))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Row(
                         children: [
                           Text(
                             _selectedDay != null 
                                ? DateFormat('MMMM dd, yyyy').format(_selectedDay!)
                                : "Select Date",
                             style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: theme.textTheme.titleLarge?.color),
                           ),
                           const Spacer(),
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                             decoration: BoxDecoration(
                               color: const Color(0xFF001C3D).withOpacity(0.05), 
                               borderRadius: BorderRadius.circular(12),
                               border: Border.all(color: const Color(0xFF001C3D).withOpacity(0.1)),
                             ),
                             child: Text(
                               "${_getEventsForDay(_selectedDay ?? DateTime.now()).length} Records", 
                               style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF001C3D), fontSize: 13)
                             ),
                           )
                         ],
                       ),
                       const SizedBox(height: 20),
                       Expanded(
                         child: _buildEventList(),
                       ),
                    ],
                  ),
                ),
              )
            ],
          );
        }
      ),
    );
  }

  Widget _buildEventList() {
    final events = _selectedDay != null ? _getEventsForDay(_selectedDay!) : [];
    
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text("No leaves scheduled", style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final event = events[index];
        final name = event['userName'] ?? 'Unknown User';
        final type = event['leaveType'] ?? 'Leave';
        final color = Helpers.getLeaveColor(type);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withOpacity(0.1),
                child: Text(name[0], style: TextStyle(fontWeight: FontWeight.bold, color: color)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(Helpers.getLeaveName(type), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                    )
                  ],
                ),
              ),
              IconButton(
                onPressed: () => PdfService().generateApplicationPdf(event),
                icon: const Icon(Icons.download_rounded, size: 20, color: Colors.blue),
                tooltip: "Download Application",
              )
            ],
          ),
        );
      },
    );
  }
}
