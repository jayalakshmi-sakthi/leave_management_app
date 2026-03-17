// lib/utils/constants.dart
import 'package:flutter/material.dart';

// Central place for app-wide constants and configuration strings
class Constants {
  // --- 1. Leave Policy (Configuration) ---

  static const int casualPerYear = 12; // CL allowed in a year
  static const int vacationPerYear = 6; // VL allowed in a year
  static const int sickPerYear = 7; // SL allowed in a year (Example)
  static const int maxCompOff = 999;

  // --- 2. Leave Type Identifiers (Strings) ---

  // Use these strings in LeaveModel, FirestoreService, and UI logic
  static const String leaveTypeCasual = 'CL';
  static const String leaveTypeVacation = 'VL';
  static const String leaveTypeSick = 'SL';
  static const String leaveTypeMaternity = 'ML';
  static const String leaveTypeCompOff = 'COMP';

  // --- 3. User Roles Identifiers ---

  static const String roleStaff = 'staff';
  static const String roleApprover = 'approver';
  static const String roleAdmin = 'admin';

  // --- 4. Firestore Collection Paths ---

  // Using constants prevents typos in collection names across the app
  static const String collectionUsers = 'users';
  static const String collectionLeaveRequests = 'leaveRequests';
  static const String collectionAcademicYears = 'academicYears';

  // --- 5. UI Spacing & Sizing ---

  // Standardized values for padding, margins, and border radii
  static const double padding = 16.0;
  static const double cardRadius = 12.0;
  static const double gap = 12.0;
  static const double buttonHeight = 50.0;

  // --- 6. Academic Year Handling ---

  // The month number (1-12) when the academic year starts
  static const int academicYearStartMonth = 6; // June
  // Removed static const String currentAcademicYear = "2024-2025";
  // -> Calculated dynamically in FirestoreService

  // --- 7. Date/Time Formatting ---

  // Standard format for displaying dates in the UI (e.g., "Jan 01, 2025")
  static const String uiDateFormat = 'MMM dd, yyyy';

  // --- 8. Statuses ---

  static const String statusPending = 'Pending';
  static const String statusApproved = 'Approved';
  static const String statusRejected = 'Rejected';
  static const String statusRecorded = 'Recorded';

  // --- 9. Colors (Consistent with Admin Panel) ---
  static const Color colorStatusPending = Color(0xFFF59E0B); // Amber 500
  static const Color colorStatusApproved = Color(0xFF00A389); // Teal (Admin Match)
  static const Color colorStatusRejected = Color(0xFFEF4444); // Red 500
  static const Color colorStatusRecorded = Color(0xFF64748B); // Slate 500

  // --- 10. Leave Type Colors (Consistent) ---
  static const Color colorCL = Color(0xFF4F46E5); // Indigo 600
  static const Color colorVL = Color(0xFF10B981); // Emerald 500
  static const Color colorCOMP = Color(0xFF8B5CF6); // Violet 500
  static const Color colorSL = Color(0xFFEF4444); // Red 500
  static const Color colorOD = Color(0xFF0EA5E9); // Sky 500
}
