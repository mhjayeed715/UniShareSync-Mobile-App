import 'package:unisharesync_mobile_app/data/models/user_role.dart';

class ProfileModel {
  const ProfileModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.department,
    this.studentId,
    this.semester,
    this.designation,
    this.avatarUrl,
    this.isActive = true,
  });

  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String? department;
  final String? studentId;
  final String? semester;
  final String? designation;
  final String? avatarUrl;
  final bool isActive;

  ProfileModel copyWith({
    String? id,
    String? email,
    String? fullName,
    UserRole? role,
    String? department,
    String? studentId,
    String? semester,
    String? designation,
    String? avatarUrl,
    bool? isActive,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      department: department ?? this.department,
      studentId: studentId ?? this.studentId,
      semester: semester ?? this.semester,
      designation: designation ?? this.designation,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toUpsertMap() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role.value,
      'department': department,
      'student_id': studentId,
      'semester': semester,
      'designation': designation,
      'avatar_url': avatarUrl,
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      id: (map['id'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      fullName: (map['full_name'] ?? '').toString(),
      role: UserRole.fromString(map['role']?.toString()),
      department: map['department']?.toString(),
      studentId: map['student_id']?.toString(),
      semester: map['semester']?.toString(),
      designation: map['designation']?.toString(),
      avatarUrl: map['avatar_url']?.toString(),
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}
