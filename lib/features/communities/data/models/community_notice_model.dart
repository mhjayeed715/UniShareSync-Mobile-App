class CommunityNoticeModel {
  const CommunityNoticeModel({
    required this.id,
    required this.communityId,
    required this.postedBy,
    required this.noticeType, // announcement, meeting, reminder, achievement, urgent
    required this.priority, // normal, high, urgent
    required this.title,
    required this.body,
    this.imageUrl,
    this.attachmentUrl,
    this.attachmentName,
    required this.createdAt,
    required this.updatedAt,
    required this.isPinned,
    this.reactions = const [],
  });

  final String id;
  final String communityId;
  final String postedBy;
  final String noticeType;
  final String priority;
  final String title;
  final String body;
  final String? imageUrl;
  final String? attachmentUrl;
  final String? attachmentName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final List<CommunityNoticeReactionModel> reactions;

  factory CommunityNoticeModel.fromMap(Map<String, dynamic> map) {
    var reactionList = <CommunityNoticeReactionModel>[];
    if (map['reactions'] != null) {
      reactionList = (map['reactions'] as List)
          .map((r) => CommunityNoticeReactionModel.fromMap(r as Map<String, dynamic>))
          .toList();
    }
    return CommunityNoticeModel(
      id: map['id']?.toString() ?? '',
      communityId: map['community_id']?.toString() ?? '',
      postedBy: map['posted_by']?.toString() ?? '',
      noticeType: map['notice_type']?.toString() ?? 'announcement',
      priority: map['priority']?.toString() ?? 'normal',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      imageUrl: map['image_url']?.toString(),
      attachmentUrl: map['attachment_url']?.toString(),
      attachmentName: map['attachment_name']?.toString(),
      createdAt: DateTime.parse(map['created_at']?.toString() ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at']?.toString() ?? DateTime.now().toIso8601String()),
      isPinned: map['is_pinned'] == true,
      reactions: reactionList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'community_id': communityId,
      'posted_by': postedBy,
      'notice_type': noticeType,
      'priority': priority,
      'title': title,
      'body': body,
      'image_url': imageUrl,
      'attachment_url': attachmentUrl,
      'attachment_name': attachmentName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_pinned': isPinned,
    };
  }
}

class CommunityNoticeReactionModel {
  const CommunityNoticeReactionModel({
    required this.id,
    required this.noticeId,
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  final String id;
  final String noticeId;
  final String userId;
  final String emoji;
  final DateTime createdAt;

  factory CommunityNoticeReactionModel.fromMap(Map<String, dynamic> map) {
    return CommunityNoticeReactionModel(
      id: map['id']?.toString() ?? '',
      noticeId: map['notice_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      emoji: map['emoji']?.toString() ?? '👍',
      createdAt: DateTime.parse(map['created_at']?.toString() ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'notice_id': noticeId,
      'user_id': userId,
      'emoji': emoji,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
