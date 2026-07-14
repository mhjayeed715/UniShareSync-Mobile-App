class CommunityMemberModel {
  const CommunityMemberModel({
    required this.id,
    required this.communityId,
    required this.userId,
    required this.role, // faculty_head, president, vice_president, secretary, member
    required this.joinedAt,
    required this.assignedRoleAt,
    this.assignedRoleBy,
    required this.isActive,
    required this.fullName,
    this.avatarUrl,
    this.profileSemester,
    this.profileDepartment,
  });

  final String id;
  final String communityId;
  final String userId;
  final String role;
  final DateTime joinedAt;
  final DateTime assignedRoleAt;
  final String? assignedRoleBy;
  final bool isActive;

  // Joined profile fields
  final String fullName;
  final String? avatarUrl;
  final int? profileSemester;
  final String? profileDepartment;

  factory CommunityMemberModel.fromMap(Map<String, dynamic> map) {
    final profile = map['profile'] as Map<String, dynamic>?;
    return CommunityMemberModel(
      id: map['id']?.toString() ?? '',
      communityId: map['community_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      role: map['role']?.toString() ?? 'member',
      joinedAt: DateTime.parse(map['joined_at']?.toString() ?? DateTime.now().toIso8601String()),
      assignedRoleAt: DateTime.parse(map['assigned_role_at']?.toString() ?? DateTime.now().toIso8601String()),
      assignedRoleBy: map['assigned_role_by']?.toString(),
      isActive: map['is_active'] != false,
      fullName: profile?['full_name']?.toString() ?? 'Member',
      avatarUrl: profile?['avatar_url']?.toString(),
      profileSemester: profile != null && profile['semester'] is int ? profile['semester'] as int : null,
      profileDepartment: profile?['department']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'community_id': communityId,
      'user_id': userId,
      'role': role,
      'joined_at': joinedAt.toIso8601String(),
      'assigned_role_at': assignedRoleAt.toIso8601String(),
      'assigned_role_by': assignedRoleBy,
      'is_active': isActive,
    };
  }
}
