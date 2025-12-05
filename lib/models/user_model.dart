class UserModel {
  final String uid;
  final String name;
  final String email;
  final String employeeId;
  final String role; // staff / admin
  final DateTime joinDate;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.employeeId,
    required this.role,
    required this.joinDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // -----------------------------
  // Convert Model → Map (Firestore)
  // -----------------------------
  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'email': email,
        'employeeId': employeeId,
        'role': role,
        'joinDate': joinDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  // -----------------------------
  // Convert Map → Model (Safe)
  // -----------------------------
  factory UserModel.fromMap(Map<String, dynamic> m) {
    return UserModel(
      uid: m['uid'] ?? '',
      name: m['name'] ?? '',
      email: m['email'] ?? '',
      employeeId: m['employeeId'] ?? '',
      role: m['role'] ?? 'staff',
      joinDate: DateTime.tryParse(m['joinDate'] ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  // -----------------------------
  // Firestore Snapshot → Model
  // -----------------------------
  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    return UserModel.fromMap({"uid": id, ...data});
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
