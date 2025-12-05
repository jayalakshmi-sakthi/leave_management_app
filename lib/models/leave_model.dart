class LeaveModel {
  final String leaveId;
  final String userId;
  final String applicationId;
  final String leaveType; // CL, VL, COMP
  final DateTime fromDate;
  final DateTime toDate;
  final int numberOfDays;
  final String reason;
  final String status; // Recorded / Rejected / Approved
  final String? signedFormUrl;
  final String? compensationWorkedDate;
  final String academicYearId;
  final DateTime createdAt;

  LeaveModel({
    required this.leaveId,
    required this.userId,
    required this.applicationId,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.numberOfDays,
    required this.reason,
    required this.status,
    this.signedFormUrl,
    this.compensationWorkedDate,
    required this.academicYearId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // -----------------------------
  // Convert Model → Map
  // -----------------------------
  Map<String, dynamic> toMap() => {
        'leaveId': leaveId,
        'userId': userId,
        'applicationId': applicationId,
        'leaveType': leaveType,
        'fromDate': fromDate.toIso8601String(),
        'toDate': toDate.toIso8601String(),
        'numberOfDays': numberOfDays,
        'reason': reason,
        'status': status,
        'signedFormUrl': signedFormUrl,
        'compensationWorkedDate': compensationWorkedDate,
        'academicYearId': academicYearId,
        'createdAt': createdAt.toIso8601String(),
      };

  // -----------------------------
  // Convert Map → Model
  // Robust + Null-safe
  // -----------------------------
  factory LeaveModel.fromMap(Map<String, dynamic> m) {
    return LeaveModel(
      leaveId: m['leaveId'] ?? '',
      userId: m['userId'] ?? '',
      applicationId: m['applicationId'] ?? '',
      leaveType: m['leaveType'] ?? 'CL',
      fromDate: DateTime.tryParse(m['fromDate'] ?? '') ?? DateTime.now(),
      toDate: DateTime.tryParse(m['toDate'] ?? '') ?? DateTime.now(),
      numberOfDays: (m['numberOfDays'] ?? 1).toInt(),
      reason: m['reason'] ?? '',
      status: m['status'] ?? 'Recorded',
      signedFormUrl: m['signedFormUrl'],
      compensationWorkedDate: m['compensationWorkedDate'],
      academicYearId: m['academicYearId'] ?? '',
      createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  // -----------------------------
  // Firestore snapshot → Model
  // -----------------------------
  factory LeaveModel.fromFirestore(Map<String, dynamic> data, String id) {
    return LeaveModel.fromMap({"leaveId": id, ...data});
  }

  // -----------------------------
  // copyWith() — Useful in updates
  // -----------------------------
  LeaveModel copyWith({
    String? leaveId,
    String? userId,
    String? applicationId,
    String? leaveType,
    DateTime? fromDate,
    DateTime? toDate,
    int? numberOfDays,
    String? reason,
    String? status,
    String? signedFormUrl,
    String? compensationWorkedDate,
    String? academicYearId,
    DateTime? createdAt,
  }) {
    return LeaveModel(
      leaveId: leaveId ?? this.leaveId,
      userId: userId ?? this.userId,
      applicationId: applicationId ?? this.applicationId,
      leaveType: leaveType ?? this.leaveType,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      numberOfDays: numberOfDays ?? this.numberOfDays,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      signedFormUrl: signedFormUrl ?? this.signedFormUrl,
      compensationWorkedDate:
          compensationWorkedDate ?? this.compensationWorkedDate,
      academicYearId: academicYearId ?? this.academicYearId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
