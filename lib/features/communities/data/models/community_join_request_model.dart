class CommunityJoinRequestModel {
  const CommunityJoinRequestModel({
    required this.id,
    required this.communityId,
    required this.requesterId,
    this.message,
    required this.status, // pending, approved, rejected, withdrawn
    this.reviewedBy,
    this.reviewNote,
    required this.createdAt,
    this.reviewedAt,
    required this.requesterName,
    this.requesterAvatar,
  });

  final String id;
  final String communityId;
  final String requesterId;
  final String? message;
  final String status;
  final String? reviewedBy;
  final String? reviewNote;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  // Pre-fetched details or joined profiles
  final String requesterName;
  final String? requesterAvatar;

  factory CommunityJoinRequestModel.fromMap(Map<String, dynamic> map) {
    final profile = map['profile'] as Map<String, dynamic>?;
    return CommunityJoinRequestModel(
      id: map['id']?.toString() ?? '',
      communityId: map['community_id']?.toString() ?? '',
      requesterId: map['requester_id']?.toString() ?? '',
      message: map['message']?.toString(),
      status: map['status']?.toString() ?? 'pending',
      reviewedBy: map['reviewed_by']?.toString(),
      reviewNote: map['review_note']?.toString(),
      createdAt: DateTime.parse(map['created_at']?.toString() ?? DateTime.now().toIso8601String()),
      reviewedAt: map['reviewed_at'] != null ? DateTime.parse(map['reviewed_at'].toString()) : null,
      requesterName: profile?['full_name']?.toString() ?? 'Student',
      requesterAvatar: profile?['avatar_url']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'community_id': communityId,
      'requester_id': requesterId,
      'message': message,
      'status': status,
      'reviewed_by': reviewedBy,
      'review_note': reviewNote,
      'created_at': createdAt.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
    };
  }
}
