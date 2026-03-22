import 'dart:async';
import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../services/cloudinary_service.dart';
import '../services/notification_service.dart';

class FirestoreService {
  final FirebaseFirestore _fire = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // ──────────────────────────────────────────────────────────
  // 🚀 HELPERS & UTILS
  // ──────────────────────────────────────────────────────────

  String getCurrentAcademicYearString() {
    final now = DateTime.now();
    final startYear = now.month >= 6 ? now.year : now.year - 1;
    return '$startYear-${startYear + 1}';
  }

  // ──────────────────────────────────────────────────────────
  // 👤 USER DATA & PROFILE
  // ──────────────────────────────────────────────────────────

  Stream<UserModel> getUserStream(String uid) {
    return _fire.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) throw Exception('User not found');
      return UserModel.fromFirestore(doc);
    });
  }

  Future<void> updateUserProfile(
    String uid,
    String name,
    String employeeId,
    String designation, {
    String? profilePicUrl,
    String? department,
  }) async {
    final updates = {
      'name': name,
      'manualEmployeeId': employeeId,
      'designation': designation,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (profilePicUrl != null) updates['profilePicUrl'] = profilePicUrl;
    if (department != null) updates['department'] = department;

    await _fire.collection('users').doc(uid).update(updates);
  }

  Future<String> uploadProfileImage(XFile image, String uid) async {
    // Staff app uses CloudinaryService
    final url = await CloudinaryService.uploadFile(image);
    if (url == null) throw Exception("Failed to upload image");
    return url;
  }

  // ──────────────────────────────────────────────────────────
  // ⚙️ REAL-TIME SYNC (Settings & Balances)
  // ──────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> streamLeaveTypes({required String department}) {
    return _fire.collection('departments').doc(department).snapshots().map((doc) {
      if (doc.exists) {
        final List<dynamic> types = doc.data()?['leaveTypes'] ?? [];
        if (types.isNotEmpty) {
          return types.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [
        {'name': 'CL', 'days': 12},
        {'name': 'VL', 'days': 6},
        {'name': 'OD', 'days': 10},
      ];
    });
  }

  Stream<Map<String, dynamic>> streamAcademicYearSettings({required String department}) {
    return _fire.collection('departments').doc(department).snapshots().map((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'label': data['currentAcademicYear'] ?? getCurrentAcademicYearString(),
          'start': data['academicYearStart'],
          'end': data['academicYearEnd'],
        };
      }
      return {'label': getCurrentAcademicYearString()};
    });
  }

  Stream<Map<String, double>> streamDynamicUserBalances(String userId, String department) {
    // 1. Get Leave Types (Limits)
    final typesStream = streamLeaveTypes(department: department);
    
    // 2. Get Academic Year
    return streamAcademicYearSettings(department: department).asyncExpand((settings) {
      final academicYear = settings['label'] ?? getCurrentAcademicYearString();
      
      // 3. Get Leave Records
      return _fire
          .collection('leaveRequests')
          .doc(department)
          .collection('records')
          .where('userId', isEqualTo: userId)
          .where('academicYearId', isEqualTo: academicYear)
          .where('status', isEqualTo: 'Approved')
          .snapshots()
          .asyncMap((leaveSnap) async {
            final Map<String, double> balances = {};
            final types = await getLeaveTypes(department: department);
            
            final Map<String, double> usedMap = {};
            for (var doc in leaveSnap.docs) {
              final d = doc.data();
              final type = d['leaveType'] as String? ?? 'Other';
              final days = (d['numberOfDays'] ?? 0).toDouble();
              usedMap[type] = (usedMap[type] ?? 0) + days;
            }

            for (var type in types) {
              final name = type['name'] as String;
              final limit = (type['days'] as num).toDouble();
              final used = usedMap[name] ?? 0.0;
              balances[name] = (limit - used).clamp(0.0, 999.0);
            }
            return balances;
          });
    });
  }

  Stream<Map<String, dynamic>> streamUserBalances(String userId) {
    return _fire.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return {'balances': <String, double>{}};
      final data = doc.data()!;
      final Map<String, double> balances = {};
      final raw = data['leaveBalances'] as Map<String, dynamic>? ?? {};
      raw.forEach((k, v) => balances[k] = (v as num).toDouble());
      return {'balances': balances};
    });
  }

  Future<Map<String, dynamic>> getUserBalances(String userId) async {
    final doc = await _fire.collection('users').doc(userId).get();
    if (!doc.exists) return {'balances': <String, double>{}};
    final data = doc.data()!;
    final Map<String, double> balances = {};
    final raw = data['leaveBalances'] as Map<String, dynamic>? ?? {};
    raw.forEach((k, v) => balances[k] = (v as num).toDouble());
    return {'balances': balances};
  }

  Future<List<String>> getAcademicYears() async {
    // Fallback: Can be fetched from a central config or hardcoded
    return [getCurrentAcademicYearString(), "2023-2024"];
  }

  Future<List<Map<String, dynamic>>> getLeaveTypes({required String department}) async {
    final doc = await _fire.collection('departments').doc(department).get();
    if (doc.exists) {
      final List<dynamic> types = doc.data()?['leaveTypes'] ?? [];
      if (types.isNotEmpty) return types.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [
      {'name': 'CL', 'days': 12},
      {'name': 'VL', 'days': 6},
      {'name': 'OD', 'days': 10},
    ];
  }

  Future<Map<String, dynamic>> getAcademicYearSettings({required String department}) async {
    final doc = await _fire.collection('departments').doc(department).get();
    if (doc.exists) {
      final data = doc.data()!;
      return {
        'label': data['currentAcademicYear'] ?? getCurrentAcademicYearString(),
        'start': data['academicYearStart'],
        'end': data['academicYearEnd'],
      };
    }
    return {'label': getCurrentAcademicYearString()};
  }

  // ──────────────────────────────────────────────────────────
  // 📝 LEAVE & COMP-OFF LOGIC
  // ──────────────────────────────────────────────────────────

  /// Generates a sequential application ID department-wise.
  /// Example: CSE-CO-2024-0001 or CSE-LV-2024-0001
  Future<String> generateApplicationId(String department, String prefix) async {
    final year = DateTime.now().year;
    final deptSlug = department.replaceAll(' ', '_').toUpperCase();
    final counterRef = _fire.collection('counters').doc('$deptSlug-$prefix');

    return _fire.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);
      int currentCount = 0;
      if (snapshot.exists) {
        currentCount = snapshot.data()?['count'] ?? 0;
      }
      final newCount = currentCount + 1;
      transaction.set(counterRef, {'count': newCount}, SetOptions(merge: true));

      // Padding to 4 digits (e.g. 0001)
      final paddedCount = newCount.toString().padLeft(4, '0');
      return "$deptSlug-$prefix-$year-$paddedCount";
    }).timeout(
      const Duration(seconds: 10),
      onTimeout: () => "$deptSlug-$prefix-$year-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}",
    );
  }

  Future<String> submitLeaveRequest(Map<String, dynamic> data) async {
    final department = data['department'] ?? 'General';
    final typeId = (data['leaveType'] as String? ?? 'LV').toUpperCase();
    
    // 🆔 Generate Sequential ID if not provided (ApplyLeaveScreen might still generate it but better here)
    String appId = data['applicationId'] ?? await generateApplicationId(department, typeId);
    
    final String docId = _uuid.v4();
    await _fire
        .collection('leaveRequests')
        .doc(department)
        .collection('records')
        .doc(docId)
        .set({
      ...data, 
      'id': docId, 
      'applicationId': appId, // Ensure it's saved
      'createdAt': FieldValue.serverTimestamp()
    });
    
    // 🔔 Notify Admins
    try {
      await NotificationService().notifyAdmins(
        title: 'New Leave Request',
        body: '${data['userName']} applied for ${data['leaveType']} (${data['numberOfDays']} days)',
        type: 'leave_request', // Matching Admin Tab
        relatedId: docId,
        leaveType: data['leaveType'],
        academicYearId: data['academicYearId'],
        targetDepartment: department,
        triggeringUserId: data['userId'],
      );
    } catch(e) {
      debugPrint("🔔 Staff Notification Failed: $e");
    }

    return appId; // Returning applicationId for PDF/UI
  }

  Future<String> createCompOffRequest({
    required String userId,
    required String userName,
    required String employeeId,
    required String department,
    required DateTime fromDate,
    required DateTime toDate,
    required double days,
    required String description,
    required bool isMultiDay,
    String? proofUrl,
  }) async {
    // 🆔 Generate Sequential ID
    final applicationId = await generateApplicationId(department, 'CO');
    
    final String docId = _uuid.v4();
    await _fire
        .collection('compOffRequests')
        .doc(department)
        .collection('records')
        .doc(docId)
        .set({
      'id': docId,
      'applicationId': applicationId, // ✅ ADDED
      'userId': userId,
      'userName': userName,
      'employeeId': employeeId,
      'department': department,
      'fromDate': Timestamp.fromDate(fromDate),
      'toDate': Timestamp.fromDate(toDate),
      'leaveType': 'COMP-OFF EARN',
      'days': days,
      'description': description,
      'status': 'Pending',
      'isMultiDay': isMultiDay,
      'proofUrl': proofUrl,
      'activityType': 'comp_off',
      'createdAt': FieldValue.serverTimestamp(),
      'academicYearId': getCurrentAcademicYearString(),
    });

    // 🔔 Notify Admins
    try {
      await NotificationService().notifyAdmins(
        title: 'New Comp-Off Earn Request',
        body: '$userName has submitted a Comp-Off request for $days days.',
        type: 'comp_off_request', // Matching Admin Tab
        relatedId: docId,
        leaveType: 'COMP-OFF EARN',
        academicYearId: getCurrentAcademicYearString(),
        targetDepartment: department,
        triggeringUserId: userId,
      );
    } catch(e) {
      debugPrint("🔔 Staff Notification Failed: $e");
    }

    return applicationId; // Return sequential ID 
  }

  Future<Map<String, dynamic>?> getLeaveById(String id, String academicYearId, {String? department}) async {
    try {
      String? deptToTry = department;
      
      // 0. Fallback: If department is unknown, try current user's department
      if (deptToTry == null || deptToTry.isEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final userDoc = await _fire.collection('users').doc(user.uid).get();
          if (userDoc.exists) {
            deptToTry = userDoc.data()?['department'] as String?;
          }
        }
      }

      // 1. DIRECT FETCH (Fastest, avoids index requirements)
      if (deptToTry != null && deptToTry.isNotEmpty) {
        // --- 1.1 Try by Document ID ---
        var doc = await _fire.collection('leaveRequests').doc(deptToTry).collection('records').doc(id).get();
        if (doc.exists) return doc.data();

        doc = await _fire.collection('compOffRequests').doc(deptToTry).collection('records').doc(id).get();
        if (doc.exists) return doc.data();

        // --- 1.2 Try by Field search within department ---
        final snapL = await _fire.collection('leaveRequests').doc(deptToTry).collection('records')
            .where('applicationId', isEqualTo: id).limit(1).get();
        if (snapL.docs.isNotEmpty) return snapL.docs.first.data();

        final snapC = await _fire.collection('compOffRequests').doc(deptToTry).collection('records')
            .where('applicationId', isEqualTo: id).limit(1).get();
        if (snapC.docs.isNotEmpty) return snapC.docs.first.data();
      }

      // 2. Fall-safe: Search within user's own records in memory
      // (Bypasses collectionGroup index requirements because userId index usually exists)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userSnap = await _fire.collectionGroup('records')
            .where('userId', isEqualTo: user.uid)
            .get();
        for (var doc in userSnap.docs) {
          final data = doc.data();
          if (doc.id == id || data['id'] == id || data['applicationId'] == id) {
             return data;
          }
        }
      }

      // 3. Last Resort: Global Search (Likely to fail without index, but kept as backup)
      var snap = await _fire.collectionGroup('records').where('id', isEqualTo: id).limit(1).get();
      if (snap.docs.isNotEmpty) return snap.docs.first.data();
      
      return null;
    } catch (e) {
      debugPrint("❌ Error fetching leave details: $e");
      return null;
    }
  }

  Future<void> updateSignedForm(String id, String academicYearId, String url) async {
    final snap = await _fire.collectionGroup('records').where('id', isEqualTo: id).get();
    if (snap.docs.isNotEmpty) {
      await snap.docs.first.reference.update({'signedFormUrl': url});
    }
  }

  // ──────────────────────────────────────────────────────────
  // 📊 ACTIVITY STREAMS
  // ──────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getCombinedActivityStream(String uid) {
    final leaveStream = _fire
        .collectionGroup('records')
        .where('userId', isEqualTo: uid)
        .snapshots();

    // Stream 1: Leave Requests
    // Stream 2: Comp Off Requests (if stored in same collectionGroup with activityType filter or different one)
    // Actually, looking at the code, they seem to be in collectionGroup 'records' 
    // but the ones in compOffRequests might also be under 'records'.
    
    return leaveStream.map((snap) {
      final list = snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      list.sort((a, b) {
        final da = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final db = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return db.compareTo(da);
      });
      return list;
    });
  }

  Stream<List<Map<String, dynamic>>> streamAllLeaves({String? academicYearId, required String department}) {
    final leaveStream = _fire
        .collection('leaveRequests')
        .doc(department)
        .collection('records')
        .snapshots();

    final compOffStream = _fire
        .collection('compOffRequests')
        .doc(department)
        .collection('records')
        .snapshots();

    return StreamZip([leaveStream, compOffStream]).map((snaps) {
      final List<Map<String, dynamic>> combined = [];
      
      // Add regular leaves
      combined.addAll(snaps[0].docs.map((doc) => {'id': doc.id, 'activityType': 'leave', ...doc.data() as Map<String, dynamic>}));
      
      // Add Comp-Off EARN requests (where staff worked)
      combined.addAll(snaps[1].docs.map((doc) => {'id': doc.id, 'activityType': 'comp_off', ...doc.data() as Map<String, dynamic>}));
      
      if (academicYearId != null) {
        return combined.where((d) => d['academicYearId'] == academicYearId).toList();
      }
      return combined;
    });
  }

  // ──────────────────────────────────────────────────────────
  // 📈 COMP-OFF STATS
  // ──────────────────────────────────────────────────────────

  Future<Map<String, double>> getCompOffStats(String userId, String academicYear) async {
    try {
      final snap = await _fire.collectionGroup('compOffGrants')
          .where('userId', isEqualTo: userId)
          .where('academicYearId', isEqualTo: academicYear)
          .get();

      double totalGranted = 0.0;
      for (var doc in snap.docs) {
        totalGranted += (doc.data()['days'] ?? 0.0).toDouble();
      }

      final leaveSnap = await _fire.collectionGroup('records')
          .where('userId', isEqualTo: userId)
          .where('academicYearId', isEqualTo: academicYear)
          .where('leaveType', isEqualTo: 'COMP')
          .where('status', isEqualTo: 'Approved')
          .get();

      double totalUsed = 0.0;
      for (var doc in leaveSnap.docs) {
        totalUsed += (doc.data()['numberOfDays'] ?? 0.0).toDouble();
      }

      return {'limit': totalGranted, 'used': totalUsed};
    } catch (e) {
      return {'limit': 0.0, 'used': 0.0};
    }
  }

  // ──────────────────────────────────────────────────────────
  // 🛡️ ADMIN (In Staff App Dashboard)
  // ──────────────────────────────────────────────────────────

  Future<void> updateLeaveStatus(String id, String academicYearId, String status, String adminId, {String? department}) async {
    final dept = department ?? 'General';
    await _fire
        .collection('leaveRequests')
        .doc(dept)
        .collection('records')
        .doc(id)
        .update({
      'status': status,
      'approvedBy': adminId,
      'approvedAt': FieldValue.serverTimestamp(),
      'academicYearId': academicYearId,
    });
  }
}
