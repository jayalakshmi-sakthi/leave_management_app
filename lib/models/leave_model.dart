import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveModel {
  final String leaveId;
  final String userId;
  final String userName; // Denormalized for calendar
  final String? employeeId;
  final String applicationId;
  final String leaveType; // CL, VL, COMP, SL, ML, etc.
  final DateTime fromDate;
  final DateTime toDate;
  final double numberOfDays; // Use double for half-day leaves
  final String reason;
  final String status; // Pending / Rejected / Approved / Recorded
  final String? signedFormUrl;
  final String? finalSignedFormUrl; // Distinct field for Signed Copy
  final DateTime? compensationWorkedDate;
  final String academicYearId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isHalfDay;
  final String? halfDaySession;
  final String? department; // <--- ADDED for filtering

  LeaveModel({
    required this.leaveId,
    required this.userId,
    required this.userName,
    this.employeeId,
    required this.applicationId,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.numberOfDays,
    required this.reason,
    required this.status,
    this.signedFormUrl,
    this.finalSignedFormUrl,
    this.compensationWorkedDate,
    required this.academicYearId,
    required this.createdAt,
    required this.updatedAt,
    this.isHalfDay = false,
    this.halfDaySession,
    this.department, // <--- ADDED
  });

  // -----------------------------
  // Convert Model → Map (for Firestore Write)
  // -----------------------------
  Map<String, dynamic> toMap() => {
        'leaveId': leaveId,
        'userId': userId,
        'userName': userName,
        'employeeId': employeeId,
        'applicationId': applicationId,
        'leaveType': leaveType,
        'fromDate': fromDate.toIso8601String(),
        'toDate': toDate.toIso8601String(),
        'numberOfDays': numberOfDays,
        'reason': reason,
        'status': status,
        'signedFormUrl': signedFormUrl,
        'finalSignedFormUrl': finalSignedFormUrl,
        'compensationWorkedDate': compensationWorkedDate?.toIso8601String(),
        'academicYearId': academicYearId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isHalfDay': isHalfDay,
        'halfDaySession': halfDaySession,
        'department': department, // <--- ADDED
      };

  factory LeaveModel.fromMap(Map<String, dynamic> m) {
    DateTime _parseDate(dynamic value) {
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      if (value is Timestamp) return value.toDate();
      return DateTime.now();
    }

    DateTime? _parseOptionalDate(dynamic value) {
      if (value == null) return null;
      if (value is String) return DateTime.tryParse(value);
      if (value is Timestamp) return value.toDate();
      return null;
    }

    final dynamic updatedAtValue = m['updatedAt'] ?? m['createdAt'];

    return LeaveModel(
      leaveId: m['leaveId']?.toString() ?? '',
      userId: m['userId']?.toString() ?? '',
      userName: m['userName']?.toString() ?? 'Unknown',
      employeeId: m['employeeId']?.toString(),
      applicationId: m['applicationId']?.toString() ?? '',
      leaveType: m['leaveType']?.toString() ?? 'CL',
      fromDate: _parseDate(m['fromDate']),
      toDate: _parseDate(m['toDate']),
      numberOfDays: (m['numberOfDays'] is num ? m['numberOfDays'] : 1.0).toDouble(),
      reason: m['reason']?.toString() ?? '',
      status: m['status']?.toString() ?? 'Pending',
      signedFormUrl: m['signedFormUrl']?.toString(),
      finalSignedFormUrl: m['finalSignedFormUrl']?.toString(),
      compensationWorkedDate: _parseOptionalDate(m['compensationWorkedDate']),
      academicYearId: m['academicYearId']?.toString() ?? '',
      createdAt: _parseDate(m['createdAt']),
      updatedAt: _parseDate(updatedAtValue),
      isHalfDay: m['isHalfDay'] as bool? ?? false,
      halfDaySession: m['halfDaySession']?.toString(),
      department: m['department']?.toString(), // <--- ADDED
    );
  }

  factory LeaveModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) throw Exception("Document data was null for ID: ${doc.id}");
    return LeaveModel.fromMap({'leaveId': doc.id, ...data});
  }

  LeaveModel copyWith({
    String? leaveId,
    String? userId,
    String? userName,
    String? employeeId,
    String? applicationId,
    String? leaveType,
    DateTime? fromDate,
    DateTime? toDate,
    double? numberOfDays,
    String? reason,
    String? status,
    String? signedFormUrl,
    String? finalSignedFormUrl,
    DateTime? compensationWorkedDate,
    String? academicYearId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isHalfDay,
    String? halfDaySession,
    String? department, // <--- ADDED
  }) {
    return LeaveModel(
      leaveId: leaveId ?? this.leaveId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      employeeId: employeeId ?? this.employeeId,
      applicationId: applicationId ?? this.applicationId,
      leaveType: leaveType ?? this.leaveType,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      numberOfDays: numberOfDays ?? this.numberOfDays,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      signedFormUrl: signedFormUrl ?? this.signedFormUrl,
      finalSignedFormUrl: finalSignedFormUrl ?? this.finalSignedFormUrl,
      compensationWorkedDate: compensationWorkedDate ?? this.compensationWorkedDate,
      academicYearId: academicYearId ?? this.academicYearId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isHalfDay: isHalfDay ?? this.isHalfDay,
      halfDaySession: halfDaySession ?? this.halfDaySession,
      department: department ?? this.department, // <--- ADDED
    );
  }
}
