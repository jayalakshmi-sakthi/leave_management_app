// lib/utils/helpers.dart
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'constants.dart'; // Import the Constants file for centralized status colors

class Helpers {
  // Use a static instance of DateFormat for performance
  static final _dateFormatter =
      DateFormat(Constants.uiDateFormat); // Using the format from Constants

  // --- Date Formatting ---

  /// Formats a DateTime object into a standard UI string (e.g., "Jan 1, 2025").
  static String formatDate(DateTime date) {
    return _dateFormatter.format(date);
  }

  // --- String Manipulation ---

  /// Capitalizes the first letter of a string.
  static String capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Creates a label for the number of days, correctly handling singular/plural.
  static String daysLabel(double days) {
    // Changed to double to align with LeaveModel
    if (days == 1.0) return "1 Day";
    if (days == 0.5) return "Half Day";
    return "${days.toStringAsFixed(1)} Days"; // Use toStringAsFixed(1) for precision
  }

  // --- Status/UI Helpers ---

  /// Returns the corresponding [Color] object for a given status string,
  /// using centralized colors from the Constants file.
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Constants.colorStatusApproved; // Returns Teal-Green
      case 'rejected':
        return Constants.colorStatusRejected; // Returns Colors.red
      case 'recorded':
        return Constants.colorStatusRecorded; // Returns Colors.blueGrey
      case 'pending':
      default:
        return Constants.colorStatusPending; // Returns Amber (Default/Pending)
    }
  }

  /// Returns a simple human-readable label for a status.
  static String getStatusLabel(String status) {
    return capitalize(status);
  }

  // --- Leave Type Helpers (Integrity) ---

  /// Returns the standardized icon for a leave type
  static IconData getLeaveIcon(String type) {
    final t = type.toUpperCase();
    if (t == 'CL' || t.contains('CASUAL')) return Icons.person;
    if (t == 'VL' || t.contains('VACATION')) return Icons.beach_access;
    if (t == 'COMP' || t.contains('COMP')) return Icons.stars_rounded;
    if (t == 'OD' || t.contains('DUTY')) return Icons.business_center;
    if (t == 'SL' || t.contains('SICK')) return Icons.local_hospital;
    if (t.contains('FESTIVAL')) return Icons.celebration;
    return Icons.event_note_rounded;
  }

  /// Helper to safely load icons from DB without breaking Web Icon Tree Shaker
  static IconData getIconFromCodePoint(int codePoint, [IconData fallback = Icons.stars]) {
    final allIcons = [
      Icons.person_outline_rounded,
      Icons.beach_access_rounded,
      Icons.stars_rounded,
      Icons.business_center_rounded,
      Icons.local_hospital_rounded,
      Icons.flight_takeoff_rounded,
      Icons.home_work_rounded,
      Icons.school_rounded,
      Icons.local_library_rounded,
      Icons.emoji_events_rounded,
      Icons.light_mode_rounded,
      Icons.person,
      Icons.beach_access,
      Icons.business_center,
      Icons.local_hospital,
      Icons.celebration,
      Icons.stars,
      Icons.event_note_rounded,
    ];
    for (var icon in allIcons) {
      if (icon.codePoint == codePoint) return icon;
    }
    return fallback;
  }

  /// Returns the standardized color for a leave type
  static Color getLeaveColor(String type) {
    final t = type.toUpperCase();
    if (t == 'CL' || t.contains('CASUAL')) return Constants.colorCL;
    if (t == 'VL' || t.contains('VACATION')) return Constants.colorVL;
    if (t == 'COMP' || t.contains('COMP')) return Constants.colorCOMP;
    if (t == 'OD' || t.contains('DUTY')) return Constants.colorOD;
    if (t == 'SL' || t.contains('SICK')) return Constants.colorSL;
    if (t.contains('FESTIVAL')) return Constants.colorStatusPending; // Reuse Amber or add custom
    return Colors.blueGrey;
  }

  /// Returns the full name for a leave code
  static String getLeaveName(String type) {
    final t = type.toUpperCase();
    if (t == 'CL' || t == 'CASUAL LEAVE') return "Casual Leave";
    if (t == 'VL' || t == 'VACATION LEAVE') return "Vacation Leave";
    if (t == 'COMP' || t == 'COMP OFF') return "Comp Off";
    if (t == 'COMP-OFF EARN') return "Comp-Off Credit"; // ✅ Added
    if (t == 'OD' || t == 'ON DUTY') return "On Duty";
    if (t == 'SL' || t == 'SICK LEAVE') return "Sick Leave";
    if (t == 'SL' || t == 'SICK LEAVE') return "Sick Leave";
    return type;
  }

  // --- Department List (Standardized) ---
  static const List<String> departments = [
    'Placement Cell', 
    // Engineering
    'CIVIL', 'MECH', 'MTS', 'AUTO', 'CHEM', 'FT',
    'EEE', 'ECE', 'EIE', 'CSE', 'IT', 'CSD', 'AIDS', 'AIML',
    // PG
    'MBA', 'MCA',
    // Science
    'B.Sc CSD', 'B.Sc IS', 'B.Sc SS', 'M.Sc SS',
    // Others
    'Ph.D', 'General'
  ];
}
