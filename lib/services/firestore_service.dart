import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/leave_model.dart';
import '../utils/constants.dart';

/// Service to handle all Firestore operations related to leaves.
class FirestoreService {
  final FirebaseFirestore _fire = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  /// Get or create the current academic year document and return its ID.
  Future<String> _getCurrentAcademicYearId() async {
    final now = DateTime.now();
    final startYear =
        now.month >= Constants.academicYearStartMonth ? now.year : now.year - 1;
    final id = '$startYear-${startYear + 1}';
    final docRef = _fire.collection('academicYears').doc(id);

    final snap = await docRef.get();
    if (!snap.exists) {
      await docRef.set({
        'id': id,
        'startDate': DateTime(startYear, Constants.academicYearStartMonth, 1)
            .toIso8601String(),
        'endDate': DateTime(startYear + 1, Constants.academicYearStartMonth, 1)
            .subtract(const Duration(days: 1))
            .toIso8601String(),
        'lastSequence': 0,
        'createdAt': DateTime.now().toIso8601String(),
      });
    }

    return id;
  }

  /// Create a new leave request.
  /// Returns the generated [applicationId].
  Future<String> createLeave({
    required String userId,
    required String employeeId,
    required String leaveType,
    required DateTime fromDate,
    required DateTime toDate,
    required int numberOfDays,
    String reason = '',
    String? compensationWorkedDateIso,
  }) async {
    final academicYearId = await _getCurrentAcademicYearId();
    final ayRef = _fire.collection('academicYears').doc(academicYearId);

    return _fire.runTransaction((tx) async {
      final aySnap = await tx.get(ayRef);
      final lastSeq = (aySnap.data()?['lastSequence'] ?? 0) as int;
      final newSeq = lastSeq + 1;

      final seqStr = newSeq.toString().padLeft(3, '0');
      final applicationId =
          'LMS-${academicYearId.split('-').first}-$employeeId-$leaveType-$seqStr';

      final leaveId = _uuid.v4();
      final leaveDocRef = _fire.collection('leaveRequests').doc(leaveId);

      final leave = LeaveModel(
        leaveId: leaveId,
        userId: userId,
        applicationId: applicationId,
        leaveType: leaveType,
        fromDate: fromDate,
        toDate: toDate,
        numberOfDays: numberOfDays,
        reason: reason,
        status: 'Recorded',
        signedFormUrl: null,
        compensationWorkedDate: compensationWorkedDateIso,
        academicYearId: academicYearId,
      );

      tx.set(leaveDocRef, leave.toMap());
      tx.update(ayRef, {'lastSequence': newSeq});
      return applicationId;
    });
  }

  /// Stream the list of leaves for a specific user and academic year.
  Stream<List<Map<String, dynamic>>> streamUserLeaves(
      String userId, String academicYearId) {
    return _fire
        .collection('leaveRequests')
        .where('userId', isEqualTo: userId)
        .where('academicYearId', isEqualTo: academicYearId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  /// Get leave details by leave ID.
  Future<Map<String, dynamic>?> getLeaveById(String leaveId) async {
    final snap = await _fire.collection('leaveRequests').doc(leaveId).get();
    return snap.exists ? snap.data() : null;
  }
}
