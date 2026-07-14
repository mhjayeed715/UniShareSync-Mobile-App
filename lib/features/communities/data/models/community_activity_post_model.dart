class CommunityActivityPostModel {
  const CommunityActivityPostModel({
    required this.id,
    required this.communityId,
    required this.postedBy,
    required this.postType, // achievement, meeting_minutes, project_update, photo_gallery, member_spotlight, general_update
    required this.title,
    required this.body,
    this.attachmentUrl,
    required this.createdAt,
    required this.updatedAt,
    this.photos = const [],
    this.reactions = const [],
  });

  final String id;
  final String communityId;
  final String postedBy;
  final String postType;
  final String title;
  final String body;
  final String? attachmentUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<CommunityActivityPhotoModel> photos;
  final List<CommunityActivityReactionModel> reactions;

  factory CommunityActivityPostModel.fromMap(Map<String, dynamic> map) {
    var photoList = <CommunityActivityPhotoModel>[];
    if (map['community_activity_photos'] != null) {
      photoList = (map['community_activity_photos'] as List)
          .map((p) => CommunityActivityPhotoModel.fromMap(p as Map<String, dynamic>))
          .toList();
    }
    var reactionList = <CommunityActivityReactionModel>[];
    if (map['reactions'] != null) {
      reactionList = (map['reactions'] as List)
          .map((r) => CommunityActivityReactionModel.fromMap(r as Map<String, dynamic>))
          .toList();
    }
    return CommunityActivityPostModel(
      id: map['id']?.toString() ?? '',
      communityId: map['community_id']?.toString() ?? '',
      postedBy: map['posted_by']?.toString() ?? '',
      postType: map['post_type']?.toString() ?? 'general_update',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      attachmentUrl: map['attachment_url']?.toString(),
      createdAt: DateTime.parse(map['created_at']?.toString() ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at']?.toString() ?? DateTime.now().toIso8601String()),
      photos: photoList,
      reactions: reactionList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'community_id': communityId,
      'posted_by': postedBy,
      'post_type': postType,
      'title': title,
      'body': body,
      'attachment_url': attachmentUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class CommunityActivityPhotoModel {
  const CommunityActivityPhotoModel({
    required this.id,
    required this.activityPostId,
    required this.photoUrl,
    this.caption,
    required this.displayOrder,
  });

  final String id;
  final String activityPostId;
  final String photoUrl;
  final String? caption;
  final int displayOrder;

  factory CommunityActivityPhotoModel.fromMap(Map<String, dynamic> map) {
    return CommunityActivityPhotoModel(
      id: map['id']?.toString() ?? '',
      activityPostId: map['activity_post_id']?.toString() ?? '',
      photoUrl: map['photo_url']?.toString() ?? '',
      caption: map['caption']?.toString(),
      displayOrder: map['display_order'] is int ? map['display_order'] as int : 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'activity_post_id': activityPostId,
      'photo_url': photoUrl,
      'caption': caption,
      'display_order': displayOrder,
    };
  }
}

class CommunityActivityReactionModel {
  const CommunityActivityReactionModel({
    required this.id,
    required this.activityPostId,
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  final String id;
  final String activityPostId;
  final String userId;
  final String emoji;
  final DateTime createdAt;

  factory CommunityActivityReactionModel.fromMap(Map<String, dynamic> map) {
    return CommunityActivityReactionModel(
      id: map['id']?.toString() ?? '',
      activityPostId: map['activity_post_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      emoji: map['emoji']?.toString() ?? '👍',
      createdAt: DateTime.parse(map['created_at']?.toString() ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'activity_post_id': activityPostId,
      'user_id': userId,
      'emoji': emoji,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
