class LeaveModel {
  final String leaveId;
  final String userId;
  final String leaveType; // "Casual", "Vacation", "Compensation"
  final DateTime startDate;
  final DateTime endDate;
  final String status; // "Pending", "Approved", "Rejected"

  LeaveModel({
    required this.leaveId,
    required this.userId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'leaveId': leaveId,
      'userId': userId,
      'leaveType': leaveType,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'status': status,
    };
  }

  factory LeaveModel.fromMap(Map<String, dynamic> map) {
    return LeaveModel(
      leaveId: map['leaveId'],
      userId: map['userId'],
      leaveType: map['leaveType'],
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      status: map['status'],
    );
  }
}
