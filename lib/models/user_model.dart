import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String employeeId;
  final String role; // staff / admin
  final DateTime joinDate;
  final DateTime createdAt;
  final String? manualEmployeeId; // Display ID
  final String? designation;
  final String? profilePicUrl;
  final Map<String, double>? leaveOverrides; // New: Personalized leave counts

  const UserModel({
    // Added const for better performance where applicable
    required this.uid,
    required this.name,
    required this.email,
    required this.employeeId,
    required this.role,
    required this.joinDate,
    required this.createdAt,
    this.manualEmployeeId,
    this.designation,
    this.profilePicUrl,
    this.leaveOverrides,
  });

  // -----------------------------
  // Convert Model → Map (For Firestore Write)
  // -----------------------------
  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'email': email,
        'employeeId': employeeId,
        'role': role,
        'manualEmployeeId': manualEmployeeId,
        'designation': designation,
        'profilePicUrl': profilePicUrl,
        // When writing a new document, the service layer should replace these
        // ISO strings with Firestore's FieldValue.serverTimestamp() for accuracy.
        'joinDate': joinDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'leaveOverrides': leaveOverrides,
      };

  // -----------------------------
  // Convert Map → Model (Robust + Null-safe)
  // Handles reading ISO strings OR native Firestore Timestamps.
  // -----------------------------
  factory UserModel.fromMap(Map<String, dynamic> m) {
    // Helper function to safely parse DateTime from ISO string or Timestamp.
    // The unused parameter has been removed to fix the Dart analyzer warning.
    DateTime _parseDate(dynamic value) {
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      if (value is Timestamp) return value.toDate();
      // Default fallback to ensure required DateTime fields are non-null.
      return DateTime.now();
    }

    return UserModel(
      // Ensure safe casting using 'as String?' and null-coalescing '??'
      uid: m['uid'] as String? ?? '',
      name: m['name'] as String? ?? 'N/A',
      email: m['email'] as String? ?? 'N/A',
      employeeId: m['employeeId'] as String? ?? '0000',
      role: m['role'] as String? ?? 'staff',
      manualEmployeeId: m['manualEmployeeId'] as String?,
      designation: m['designation'] as String?,
      profilePicUrl: m['profilePicUrl'] as String?,
      joinDate: _parseDate(m['joinDate']),
      createdAt: _parseDate(m['createdAt']),
      leaveOverrides: m['leaveOverrides'] != null 
          ? (m['leaveOverrides'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble()))
          : null,
    );
  }

  // -----------------------------
  // Firestore DocumentSnapshot → Model
  // This is the correct way to retrieve user data from a query.
  // -----------------------------
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    // The doc.data() call must be cast to Map<String, dynamic>
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      throw Exception("User document data was null for ID: ${doc.id}");
    }

    // Pass the document ID as the UID and spread the rest of the data.
    return UserModel.fromMap({
      'uid': doc.id,
      ...data,
    });
  }

  // -----------------------------
  // copyWith() — For updating profile
  // -----------------------------
  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? employeeId,
    String? role,
    DateTime? joinDate,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      employeeId: employeeId ?? this.employeeId,
      role: role ?? this.role,
      joinDate: joinDate ?? this.joinDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
