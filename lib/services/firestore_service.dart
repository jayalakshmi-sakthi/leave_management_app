import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart'; // For XFile
import 'dart:async'; // ✅ Added for StreamController
import 'cloudinary_service.dart';
import 'package:uuid/uuid.dart';
import '../models/leave_model.dart';
import '../models/user_model.dart'; // ✅ Added
import '../utils/constants.dart';
import 'notification_service.dart';

/// Service to handle all Firestore operations related to leaves.
class FirestoreService {
  final FirebaseFirestore _fire = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // ──────────────────────────────────────────────────────────
  // 🚀 IN-MEMORY CACHES (avoid repeat network calls)
  // ──────────────────────────────────────────────────────────
  static final Map<String, dynamic> _settingsCache = {};
  static final List<Map<String, dynamic>> _leaveTypesCache = [];
  static List<String> _academicYearsCache = [];

  /// Helper to get legacy/global collection name for backward compatibility
  String _getCollectionName(String academicYearId) {
    return 'leaveRequests';
  }

  /// Helper to get dynamic collection name for a department
  CollectionReference _getDeptLeaveCollection(String department) {
    return _fire.collection('leaveRequests').doc(department).collection('records');
  }

  /// Helper to get dynamic comp-off collection for a department
  CollectionReference _getDeptCompOffCollection(String department) {
    return _fire.collection('compOffRequests').doc(department).collection('records');
  }

  /// Calculates the current academic year string locally (e.g. "2024-2025").
  /// This should match the Admin Panel's logic: June (6) is the cutoff.
  String getCurrentAcademicYearString() {
    final now = DateTime.now();
    final startYear = now.month >= 6 ? now.year : now.year - 1;
    return '$startYear-${startYear + 1}';
  }

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
        'lastSequence': 0, // Legacy
        'lastLeaveSequence': 0, // ✅ NEW
        'lastCompOffSequence': 0, // ✅ NEW
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
    required double numberOfDays,
    String reason = '',
    DateTime? compensationWorkedDate,
  }) async {
    final academicYearId = await _getCurrentAcademicYearId();
    final now = DateTime.now();

    // 1. First fetch user details to get department
    final userDoc = await _fire.collection('users').doc(userId).get();
    final userData = userDoc.data() ?? {};
    final userDept = userData['department'] ?? 'General';
    final userName = userData['name'] ?? 'An employee';

    // 2. Department-specific counter path
    final counterRef = _fire.collection('academicYears').doc(academicYearId)
                           .collection('deptCounters').doc(userDept);

    return _fire.runTransaction((tx) async {
      final counterSnap = await tx.get(counterRef);
      final lastSeq = (counterSnap.data()?['lastLeaveSequence'] ?? 0) as int;
      final newSeq = lastSeq + 1;

      final seqStr = newSeq.toString().padLeft(3, '0');
      final applicationId = 'LAPP-$seqStr';

      final leaveId = _uuid.v4();
      final leaveDocRef = _getDeptLeaveCollection(userDept).doc(leaveId);

      final leave = LeaveModel(
        leaveId: leaveId,
        userId: userId,
        userName: userName,
        applicationId: applicationId,
        leaveType: leaveType,
        fromDate: fromDate,
        toDate: toDate,
        numberOfDays: numberOfDays,
        reason: reason,
        status: 'Pending',
        signedFormUrl: null,
        compensationWorkedDate: compensationWorkedDate,
        academicYearId: academicYearId,
        createdAt: now,
        updatedAt: now,
        department: userDept,
      );

      tx.set(leaveDocRef, leave.toMap());
      tx.set(counterRef, {'lastLeaveSequence': newSeq}, SetOptions(merge: true));
 
      // 🔔 NOTIFY ADMINS
      try {
        NotificationService().notifyAdmins(
          title: 'New Leave Request',
          body: '$userName has requested ${leaveType.toUpperCase()} leave.',
          type: 'leave_request',
          relatedId: leaveId,
          leaveType: leaveType, 
          academicYearId: academicYearId,
          targetDepartment: userDept,
        );
      } catch (e) {
        print("Silent notification failure: $e");
      }
 
      return applicationId;
    });
  }

  /// Create a new Comp-Off Credit (Earn) request.
  /// Uses a transaction to generate a sequential applicationId.
  Future<String> createCompOffRequest({
    required String userId,
    required String employeeId,
    required String department,
    required DateTime fromDate,
    required DateTime toDate,
    required double days,
    required String description,
    required bool isMultiDay,
    String? proofUrl,
  }) async {
    final academicYearId = await _getCurrentAcademicYearId();
    final counterRef = _fire.collection('academicYears').doc(academicYearId)
                           .collection('deptCounters').doc(department);

    return _fire.runTransaction((tx) async {
      final counterSnap = await tx.get(counterRef);
      final lastSeq = (counterSnap.data()?['lastCompOffSequence'] ?? 0) as int;
      final newSeq = lastSeq + 1;

      final seqStr = newSeq.toString().padLeft(3, '0');
      final applicationId = 'ECAPP-$seqStr';

      final userSnap = await tx.get(_fire.collection('users').doc(userId));
      final userData = userSnap.data() ?? {};
      final userName = userData['name'] ?? 'An employee';

      final docId = _uuid.v4();
      final docRef = _getDeptCompOffCollection(department).doc(docId);

      final requestData = {
        "id": docId,
        "userId": userId,
        "userName": userName,
        "employeeId": employeeId,
        "applicationId": applicationId,
        "department": department,
        "leaveType": "Comp-Off Earn",
        "isMultiDay": isMultiDay,
        "workedDate": fromDate.toIso8601String(),
        "fromDate": fromDate.toIso8601String(),
        "toDate": toDate.toIso8601String(),
        "numberOfDays": days,
        "days": days,
        "description": description,
        "reason": description,
        "status": "Pending",
        "academicYearId": academicYearId,
        "createdAt": FieldValue.serverTimestamp(),
        "proofUrl": proofUrl,
      };

      tx.set(docRef, requestData);
      tx.set(counterRef, {'lastCompOffSequence': newSeq}, SetOptions(merge: true));

      // 🔔 NOTIFY ADMINS
      try {
        NotificationService().notifyAdmins(
          title: 'New Comp-Off Request',
          body: '$userName has requested Comp-Off Credit.',
          type: 'comp_off_request',
          relatedId: docId,
          academicYearId: academicYearId,
          targetDepartment: department,
        );
      } catch (e) {
        print("Notification error: $e");
      }

      return applicationId;
    });
  }

  // --- Read/Stream Methods ---

  /// Stream combined activity (Leaves + Comp Off Requests)
  Stream<List<Map<String, dynamic>>> getCombinedActivityStream(String userId) {
    // 1. Get user dept first (simpler to use a Future here or assume we have it)
    final controller = StreamController<List<Map<String, dynamic>>>();
    List<Map<String, dynamic>> leaves = [];
    List<Map<String, dynamic>> compOffs = [];

    void emitCombined() {
      final all = [...leaves, ...compOffs];
      all.sort((a, b) {
        final tA = a['createdAt'] as Timestamp?;
        final tB = b['createdAt'] as Timestamp?;
        if (tA == null) return 1; 
        if (tB == null) return -1;
        return tB.compareTo(tA);
      });
      controller.add(all);
    }

    _fire.collection('users').doc(userId).get().then((userDoc) {
      final dept = userDoc.data()?['department'] ?? 'General';
      
      // Listen to Dept Leaves
      _getDeptLeaveCollection(dept)
         .where('userId', isEqualTo: userId)
         .snapshots()
         .listen((snap) {
           leaves = snap.docs.map((d) {
             final data = d.data() as Map<String, dynamic>;
             data['id'] = d.id;
             data['activityType'] = 'leave';
             return data;
           }).toList();
           emitCombined();
         });

      // Listen to Dept Comp Offs
      _getDeptCompOffCollection(dept)
         .where('userId', isEqualTo: userId)
         .snapshots()
         .listen((snap) {
           compOffs = snap.docs.map((d) {
             final data = d.data() as Map<String, dynamic>;
             data['id'] = d.id;
             data['activityType'] = 'comp_off';
             data['leaveType'] = 'Comp-Off Earn';
             return data;
           }).toList();
           emitCombined();
         });
    });

    return controller.stream;
  }

  /// Stream all approved/pending leaves for the departmental calendar.
  /// If [department] is provided, queries the isolated dept collection.
  Stream<List<Map<String, dynamic>>> streamAllLeaves({String? academicYearId, String? department}) {
    final yearId = academicYearId ?? getCurrentAcademicYearString();
    
    // If we have a specific department, use the isolated path
    if (department != null && department.isNotEmpty && department != 'All') {
      return _getDeptLeaveCollection(department)
          .where('academicYearId', isEqualTo: yearId)
          .limit(100) // ✅ Limit to prevent huge reads
          .snapshots()
          .map((snap) => snap.docs.map((d) {
                final data = d.data() as Map<String, dynamic>;
                data['id'] = d.id;
                return data;
              }).toList());
    }
    
    // Fallback: Use collectionGroup if we need "All" (requires index)
    return _fire
        .collectionGroup('records')
        .where('academicYearId', isEqualTo: yearId)
        .limit(100) // ✅ Limit global search
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              data['id'] = d.id;
              return data;
            }).toList());
  }

  /// Stream the list of leaves for a specific user, searching across all departments.
  Stream<List<Map<String, dynamic>>> streamUserLeaves(String userId, {String? academicYearId}) {
    final yearId = academicYearId ?? getCurrentAcademicYearString();
    
    // Since users now live in dept sub-collections, we use collectionGroup to find them by userId
    return _fire.collectionGroup('records')
        .where('userId', isEqualTo: userId)
        .where('academicYearId', isEqualTo: yearId)
        .limit(100) // ✅ Limit user history
        .snapshots()
        .map((snap) {
          final docs = snap.docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            data['id'] = d.id;
            return data;
          }).toList();
          docs.sort((a, b) {
            final tA = a['createdAt'] as Timestamp?;
            final tB = b['createdAt'] as Timestamp?;
            if (tA == null) return 1;
            if (tB == null) return -1;
            return tB.compareTo(tA);
          });
          return docs;
        });
  }

  /// Get leave details by leave ID.
  /// NOTE: Now requires [academicYearId] to find the correct collection.
  Future<Map<String, dynamic>?> getLeaveById(String leaveId, String academicYearId) async {
    // Search across ALL departments using collectionGroup
    final snap = await _fire.collectionGroup('records')
        .where(FieldPath.documentId, isEqualTo: leaveId)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      final data = snap.docs.first.data() as Map<String, dynamic>;
      data['id'] = snap.docs.first.id;
      return data;
    }
    return null;
  }

  // --- Config / Settings Methods ---

  /// Fetch the active Academic Year configuration from Admin Settings.
  /// Returns a Map with 'label' (e.g. 2024-2025), 'start', 'end'.
  /// If not found, returns a default computed value.
  Future<Map<String, dynamic>> getAcademicYearSettings({required String department}) async {
    final cacheKey = 'ay_$department';
    if (_settingsCache.containsKey(cacheKey)) return _settingsCache[cacheKey] as Map<String, dynamic>; // ✅ Cached

    try {
      final doc = await _fire
          .collection('departments')
          .doc(department)
          .collection('settings')
          .doc('academic_year')
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final label = data['label'] as String?;
        if (label != null && label.isNotEmpty) {
          _settingsCache[cacheKey] = data;
          return data;
        }
      }
    } catch (e) {
      // Fallback
    }
    // Fallback logic
    final now = DateTime.now();
    final startYear = now.month >= 6 ? now.year : now.year - 1;
    final label = '$startYear-${startYear + 1}';
    return {
      'label': label,
      'start': DateTime(startYear, 6, 1),
      'end': DateTime(startYear + 1, 5, 31)
    };
  }

  /// Fetch configured Leave Types from Admin Settings.
  Future<List<Map<String, dynamic>>> getLeaveTypes({required String department}) async {
    // ⚠️ Skipping local cache for getLeaveTypes because we want the latest limits
    try {
      final doc = await _fire
          .collection('departments')
          .doc(department)
          .collection('settings')
          .doc('leave_types')
          .get();
      if (doc.exists) {
        final List<dynamic> types = doc.data()?['types'] ?? [];
        if (types.isNotEmpty) {
          final result = types.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          return result;
        }
      }
    } catch (e) {
      debugPrint("Error fetching leave types: $e");
    }
    // Default fallback if nothing configured or doc is empty
    return [
      {'name': 'CL', 'days': 12},
      {'name': 'VL', 'days': 6}, // Vacation
      {'name': 'OD', 'days': 10},
    ];
  }

  /// Update the status of a specific leave request.
  Future<void> updateLeaveStatus(
      String leaveId, String academicYearId, String newStatus, String approverId,
      {String? rejectionReason}) async {
    final nowIso = DateTime.now().toIso8601String();
    final updateData = <String, dynamic>{
      'status': newStatus,
      'updatedAt': nowIso,
      'approverId': approverId,
      'approvalDate': nowIso,
    };

    if (newStatus.toLowerCase() == 'rejected' && rejectionReason != null) {
      updateData['rejectionReason'] = rejectionReason;
    }

    final snap = await _fire.collectionGroup('records')
        .where(FieldPath.documentId, isEqualTo: leaveId)
        .limit(1)
        .get();
    
    if (snap.docs.isNotEmpty) {
      await snap.docs.first.reference.update(updateData);
    } else {
      throw "Leave request not found";
    }
  }

  /// Get distinct academic years from the dedicated collection
  /// Fixed: Previously scanned 'leaveRequests' which caused Permission Denied for Staff
  Future<List<String>> getAcademicYears() async {
    if (_academicYearsCache.isNotEmpty) return _academicYearsCache; // ✅ Cached

    try {
      final snapshot = await _fire.collection('academicYears')
          .orderBy('id', descending: true)
          .limit(10) // ✅ Limit
          .get();
          
      if (snapshot.docs.isNotEmpty) {
        final years = snapshot.docs.map((doc) => doc.id).toList();
        _academicYearsCache = years;
        return years;
      }
    } catch (e) {
      print("Error fetching academic years: $e");
    }
    
    // Fallback: Return current year if fetch fails or empty
    return [getCurrentAcademicYearString()];
  }

  /// NEW: Get Comp Off Stats (Granted Limit vs Used)
  Future<Map<String, double>> getCompOffStats(String userId, String academicYear) async {
    try {
      // ✅ Parallelized queries with Future.wait and limits
      final results = await Future.wait([
        _fire.collection('users').doc(userId).collection('compOffGrants').limit(50).get(),
        _fire.collection('compOffGrants')
            .where('userId', isEqualTo: userId)
            .where('academicYearId', isEqualTo: academicYear).limit(50).get(),
        _fire.collectionGroup('records')
            .where('userId', isEqualTo: userId)
            .where('academicYearId', isEqualTo: academicYear).limit(100).get()
      ]);

      double totalGranted = 0.0;
      double safeParse(dynamic v) {
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v) ?? 0.0;
        return 0.0;
      }

      for (var d in results[0].docs) totalGranted += safeParse(d.data()['days']);
      for (var d in results[1].docs) totalGranted += safeParse(d.data()['days']);

      double totalUsed = 0.0;
      for (var d in results[2].docs) {
        final data = d.data();
        if (data['leaveType'] == 'COMP' && data['status'] != 'Rejected') {
           totalUsed += safeParse(data['numberOfDays']);
        }
      }

      return {'limit': totalGranted, 'used': totalUsed};
    } catch (e) {
      debugPrint("Error fetching comp-off stats: $e");
      return {'limit': 0.0, 'used': 0.0};
    }
  }

  /// Update only the signed form URL for an approved leave
  Future<void> updateSignedForm(String leaveId, String academicYearId, String url) async {
    final snap = await _fire.collectionGroup('records')
        .where(FieldPath.documentId, isEqualTo: leaveId)
        .limit(1)
        .get();
    
    if (snap.docs.isNotEmpty) {
      await snap.docs.first.reference.update({
        'finalSignedFormUrl': url,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
  }

  /// NEW: Get combined information for a user (Limits + Usage + Overrides)
  Future<Map<String, dynamic>> getUserBalances(String userId) async {
    try {
      final academicYear = getCurrentAcademicYearString();
      
      // 1. Fetch User Doc (for overrides)
      final userSnap = await _fire.collection('users').doc(userId).get();
      final userDept = userSnap.data()?['department'] ?? 'General';
      final Map<String, dynamic> overrides = (userSnap.data()?['leaveOverrides'] ?? {}).cast<String, dynamic>();

      // 2. Fetch Global Limits
      final globalLimits = await getLeaveTypes(department: userDept);

      // 3. Calculate Effective Limits
      final Map<String, double> effectiveLimits = {};
      for (var limit in globalLimits) {
        final name = limit['name'] as String;
        double days = (limit['days'] ?? 0.0).toDouble();
        
        // ✅ UNLIMITED OD CHECK
        if (name == 'OD' || name == 'On Duty') {
          days = 999.0; // Effectively unlimited
        }

        effectiveLimits[name] = overrides.containsKey(name) ? (overrides[name] as num).toDouble() : days;
      }

      // 4. Fetch Usage (Approved + Pending)
      final usageSnap = await _fire.collectionGroup('records')
        .where('userId', isEqualTo: userId)
        .where('academicYearId', isEqualTo: academicYear)
        .get();

      final Map<String, double> usedMap = {};
      for (var doc in usageSnap.docs) {
        final data = doc.data();
        if (data['status'] == 'Rejected') continue; // ✅ Skip Rejected

        final type = data['leaveType'] as String? ?? 'Other';
        final days = (data['numberOfDays'] ?? 0).toDouble();
        usedMap[type] = (usedMap[type] ?? 0) + days;
      }

      // 5. Combine into Balance Map
      final Map<String, double> balances = {};
      effectiveLimits.forEach((type, limit) {
        final used = usedMap[type] ?? 0.0;
        balances[type] = (limit - used).clamp(0.0, 99.0);
      });

      // Special case for COMP (handled separately via grants)
      final compStats = await getCompOffStats(userId, academicYear);
      balances['COMP'] = (compStats['limit']! - compStats['used']!).clamp(0.0, 99.0);

      return {
        'balances': balances,
        'limits': effectiveLimits,
      };
    } catch (e) {
      debugPrint("Error fetching user balances: $e");
      // Return empty defaults to prevent app crash
      return {
        'balances': {'CL': 12.0, 'VL': 6.0, 'COMP': 0.0},
        'limits': {'CL': 12.0, 'VL': 6.0, 'COMP': 0.0},
      };
    }
  }
  /// NEW: Update user profile (Name, ID, Designation, Pic, Dept)
  Future<void> updateUserProfile(String uid, String name, String manualId, String designation, {String? profilePicUrl, String? department}) async {
    final data = {
      'name': name,
      'manualEmployeeId': manualId,
      'designation': designation,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (department != null) {
      data['department'] = department;
    }
    if (profilePicUrl != null) {
      data['profilePicUrl'] = profilePicUrl;
    }
    await _fire.collection('users').doc(uid).update(data);
  }

  /// NEW: Upload Profile Image (Cloudinary)
  Future<String> uploadProfileImage(XFile imageFile, String uid) async {
    // Try to overwrite existing image (with fallback)
    return await CloudinaryService.uploadFile(imageFile, publicId: 'profile_$uid');
  }

  /// Stream user profile for real-time updates
  Stream<UserModel?> getUserStream(String uid) {
    return _fire.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc); // ✅ Fixed: Use existing factory
    });
  }
}
