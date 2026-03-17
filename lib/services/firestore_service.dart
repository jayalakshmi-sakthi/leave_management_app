import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../services/cloudinary_service.dart';

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

  Future<String> submitLeaveRequest(Map<String, dynamic> data) async {
    final department = data['department'] ?? 'General';
    final String docId = _uuid.v4();
    await _fire
        .collection('leaveRequests')
        .doc(department)
        .collection('records')
        .doc(docId)
        .set({...data, 'id': docId, 'createdAt': FieldValue.serverTimestamp()});
    return docId;
  }

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
    final String docId = _uuid.v4();
    await _fire
        .collection('compOffRequests')
        .doc(department)
        .collection('records')
        .doc(docId)
        .set({
      'id': docId,
      'userId': userId,
      'employeeId': employeeId,
      'department': department,
      'fromDate': fromDate.toIso8601String(),
      'toDate': toDate.toIso8601String(),
      'days': days,
      'description': description,
      'status': 'Pending',
      'isMultiDay': isMultiDay,
      'proofUrl': proofUrl,
      'activityType': 'comp_off',
      'createdAt': FieldValue.serverTimestamp(),
      'academicYearId': getCurrentAcademicYearString(),
    });
    return docId;
  }

  Future<Map<String, dynamic>?> getLeaveById(String id, String academicYearId) async {
    // Search in all departments if necessary, or pass department
    final snap = await _fire.collectionGroup('records').where('id', isEqualTo: id).get();
    if (snap.docs.isNotEmpty) return snap.docs.first.data();
    return null;
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
    return _fire
        .collection('leaveRequests')
        .doc(department)
        .collection('records')
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      if (academicYearId != null) {
        return list.where((d) => d['academicYearId'] == academicYearId).toList();
      }
      return list;
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
