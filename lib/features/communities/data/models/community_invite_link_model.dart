class CommunityInviteLinkModel {
  const CommunityInviteLinkModel({
    required this.id,
    required this.communityId,
    required this.token,
    required this.createdBy,
    required this.createdAt,
    required this.expiresAt,
    this.maxUses,
    required this.useCount,
    required this.isActive,
  });

  final String id;
  final String communityId;
  final String token;
  final String createdBy;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int? maxUses;
  final int useCount;
  final bool isActive;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isFull => maxUses != null && useCount >= maxUses!;
  bool get isValid => isActive && !isExpired && !isFull;

  factory CommunityInviteLinkModel.fromMap(Map<String, dynamic> map) {
    return CommunityInviteLinkModel(
      id: map['id']?.toString() ?? '',
      communityId: map['community_id']?.toString() ?? '',
      token: map['token']?.toString() ?? '',
      createdBy: map['created_by']?.toString() ?? '',
      createdAt: DateTime.parse(map['created_at']?.toString() ?? DateTime.now().toIso8601String()),
      expiresAt: DateTime.parse(map['expires_at']?.toString() ?? DateTime.now().toIso8601String()),
      maxUses: map['max_uses'] is int ? map['max_uses'] as int : null,
      useCount: map['use_count'] is int ? map['use_count'] as int : 0,
      isActive: map['is_active'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'community_id': communityId,
      'token': token,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'max_uses': maxUses,
      'use_count': useCount,
      'is_active': isActive,
    };
  }
}
