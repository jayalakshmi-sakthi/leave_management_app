import 'package:flutter_test/flutter_test.dart';
import 'package:leave_management_app/models/leave_model.dart';

void main() {
  group('LeaveModel Tests', () {
    final DateTime now = DateTime.now();

    test('should correctly serialize department field to Map', () {
      final leave = LeaveModel(
        leaveId: '123',
        userId: 'user_456',
        applicationId: 'APP-001',
        leaveType: 'CL',
        fromDate: now,
        toDate: now,
        numberOfDays: 1.0,
        reason: 'Test Leave',
        status: 'Pending',
        academicYearId: '2024-2025',
        createdAt: now,
        updatedAt: now,
        department: 'CSE', 
        userName: 'Test User',
      );

      final map = leave.toMap();

      expect(map['department'], 'CSE');
      expect(map['leaveId'], '123');
    });

    test('should correctly deserialize department field from Map', () {
      final map = {
        'leaveId': '123',
        'userId': 'user_456',
        'applicationId': 'APP-001',
        'leaveType': 'CL',
        'fromDate': now.toIso8601String(),
        'toDate': now.toIso8601String(),
        'numberOfDays': 1.0,
        'reason': 'Test Leave',
        'status': 'Pending',
        'academicYearId': '2024-2025',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'department': 'ECE', // ✅ Testing this
      };

      final leave = LeaveModel.fromMap(map);

      expect(leave.department, 'ECE');
      expect(leave.leaveId, '123');
    });

    test('should handle missing department field (Backward Compatibility)', () {
      final map = {
        'leaveId': 'old_123',
        'userId': 'user_789',
        'applicationId': 'APP-OLD',
        'leaveType': 'SL',
        'fromDate': now.toIso8601String(),
        'toDate': now.toIso8601String(),
        'numberOfDays': 1.0,
        'reason': 'Legacy Leave',
        'status': 'Approved',
        'academicYearId': '2023-2024',
        'createdAt': now.toIso8601String(),
        // 'department' is missing
      };

      final leave = LeaveModel.fromMap(map);

      expect(leave.department, null); // Should be null, not crash
      expect(leave.leaveId, 'old_123');
    });

    test('copyWith should update department', () {
      final leave = LeaveModel(
        leaveId: '123',
        userId: 'user',
        applicationId: 'app',
        leaveType: 'CL',
        fromDate: now,
        toDate: now,
        numberOfDays: 1,
        reason: 'reason',
        status: 'Pending',
        academicYearId: 'year',
        createdAt: now,
        updatedAt: now,
        department: 'CSE',
        userName: 'Test User',
      );

      final updatedLeave = leave.copyWith(department: 'IT');

      expect(updatedLeave.department, 'IT');
      expect(updatedLeave.leaveId, '123'); // Unchanged
    });
  });
}
