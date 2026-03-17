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
        title: const Text("Department Calendar", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 20)),
        backgroundColor: const Color(0xFF001C3D),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        ),
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
              // 📅 Calendar Container (Premium Card)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF001C3D).withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                ),
                child: TableCalendar(
                  firstDay: DateTime.utc(2023, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  eventLoader: _getEventsForDay,
                  calendarFormat: CalendarFormat.month,
                  startingDayOfWeek: StartingDayOfWeek.sunday,
                  rowHeight: 58,
                  
                  // --- Header Style ---
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: const TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.w900, 
                      color: Color(0xFF001C3D),
                      letterSpacing: -0.5,
                    ),
                    leftChevronIcon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF001C3D).withOpacity(0.05), shape: BoxShape.circle),
                      child: const Icon(Icons.chevron_left_rounded, color: Color(0xFF001C3D), size: 20),
                    ),
                    rightChevronIcon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF001C3D).withOpacity(0.05), shape: BoxShape.circle),
                      child: const Icon(Icons.chevron_right_rounded, color: Color(0xFF001C3D), size: 20),
                    ),
                    headerPadding: const EdgeInsets.only(bottom: 12),
                  ),

                  // --- Days of Week Style ---
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 13),
                    weekendStyle: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 13),
                  ),

                  // --- Calendar Style ---
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: const Color(0xFF001C3D).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: const TextStyle(color: Color(0xFF001C3D), fontWeight: FontWeight.bold),
                    selectedDecoration: const BoxDecoration(
                      color: Color(0xFF001C3D),
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    markerDecoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    outsideDaysVisible: false,
                  ),

                  // --- Custom Builders ---
                  builders: CalendarBuilders(
                    todayBuilder: (context, date, _) {
                      return Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF001C3D).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF001C3D).withOpacity(0.2)),
                          ),
                          child: Text("${date.day}", style: const TextStyle(color: Color(0xFF001C3D), fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                    selectedBuilder: (context, date, _) {
                      return Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF001C3D),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF001C3D).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Text("${date.day}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                    markerBuilder: (context, date, events) {
                      if (events.isEmpty) return null;
                      return Positioned(
                        bottom: 4,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: events.take(4).map((e) {
                            final color = Helpers.getLeaveColor(e['leaveType'] ?? '');
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 0.5),
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            );
                          }).toList(),
                        ),
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
              
              // 📋 Selection Details Panel
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 30, offset: const Offset(0, -10))
                    ],
                    border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text(
                                 _selectedDay == null ? "Select Date" : DateFormat('EEE, MMM dd').format(_selectedDay!),
                                 style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
                               ),
                               if (_selectedDay != null)
                                 Text(DateFormat('yyyy').format(_selectedDay!), style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13)),
                             ],
                           ),
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                             decoration: BoxDecoration(
                               color: const Color(0xFF001C3D).withOpacity(0.08), 
                               borderRadius: BorderRadius.circular(14),
                             ),
                             child: Text(
                               "${_getEventsForDay(_selectedDay ?? DateTime.now()).length} Records", 
                               style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF001C3D), fontSize: 13, letterSpacing: -0.2)
                             ),
                           )
                         ],
                       ),
                       const SizedBox(height: 24),
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
