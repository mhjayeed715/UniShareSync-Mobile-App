class CommunityModel {
  const CommunityModel({
    required this.id,
    required this.name,
    required this.type, // programming_club, robotics_club, cultural_club, etc.
    required this.tagline,
    required this.description,
    required this.joinType, // open, request, invite_only
    required this.visibility, // public, private
    this.coverPhotoUrl,
    this.logoUrl,
    this.facebookUrl,
    this.githubUrl,
    this.websiteUrl,
    required this.tags,
    required this.maxMembers,
    required this.memberCount,
    required this.activityScore,
    required this.foundedDate,
    required this.isActive,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.isUserMember = false,
    this.joinRequestStatus,
    this.userMemberRole,
  });

  final String id;
  final String name;
  final String type;
  final String tagline;
  final String description;
  final String joinType;
  final String visibility;
  final String? coverPhotoUrl;
  final String? logoUrl;
  final String? facebookUrl;
  final String? githubUrl;
  final String? websiteUrl;
  final List<String> tags;
  final int maxMembers;
  final int memberCount;
  final int activityScore;
  final DateTime foundedDate;
  final bool isActive;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isUserMember;
  final String? joinRequestStatus; // 'pending', 'approved', 'rejected', or null
  final String? userMemberRole;

  bool get hasRequestPending => joinRequestStatus?.toLowerCase() == 'pending';

  factory CommunityModel.fromMap(Map<String, dynamic> map) {
    List<String> tagsList = [];
    if (map['tags'] != null) {
      if (map['tags'] is List) {
        tagsList = (map['tags'] as List).map((t) => t.toString()).toList();
      }
    }
    return CommunityModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      type: map['type']?.toString() ?? 'other',
      tagline: map['tagline']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      joinType: map['join_type']?.toString() ?? 'open',
      visibility: map['visibility']?.toString() ?? 'public',
      coverPhotoUrl: map['cover_photo_url']?.toString(),
      logoUrl: map['logo_url']?.toString(),
      facebookUrl: map['facebook_url']?.toString(),
      githubUrl: map['github_url']?.toString(),
      websiteUrl: map['website_url']?.toString(),
      tags: tagsList,
      maxMembers: map['max_members'] is int ? map['max_members'] as int : 200,
      memberCount: map['member_count'] is int ? map['member_count'] as int : 0,
      activityScore: map['activity_score'] is int ? map['activity_score'] as int : 0,
      foundedDate: DateTime.parse(map['founded_date']?.toString() ?? DateTime.now().toIso8601String()),
      isActive: map['is_active'] != false,
      createdBy: map['created_by']?.toString() ?? '',
      createdAt: DateTime.parse(map['created_at']?.toString() ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at']?.toString() ?? DateTime.now().toIso8601String()),
      isUserMember: map['is_user_member'] == true,
      joinRequestStatus: map['join_request_status']?.toString(),
      userMemberRole: map['user_member_role']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'tagline': tagline,
      'description': description,
      'join_type': joinType,
      'visibility': visibility,
      'cover_photo_url': coverPhotoUrl,
      'logo_url': logoUrl,
      'facebook_url': facebookUrl,
      'github_url': githubUrl,
      'website_url': websiteUrl,
      'tags': tags,
      'max_members': maxMembers,
      'member_count': memberCount,
      'activity_score': activityScore,
      'founded_date': foundedDate.toIso8601String().substring(0, 10),
      'is_active': isActive,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  CommunityModel copyWith({
    String? id,
    String? name,
    String? type,
    String? tagline,
    String? description,
    String? joinType,
    String? visibility,
    String? coverPhotoUrl,
    String? logoUrl,
    String? facebookUrl,
    String? githubUrl,
    String? websiteUrl,
    List<String>? tags,
    int? maxMembers,
    int? memberCount,
    int? activityScore,
    DateTime? foundedDate,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isUserMember,
    String? joinRequestStatus,
    String? userMemberRole,
  }) {
    return CommunityModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      tagline: tagline ?? this.tagline,
      description: description ?? this.description,
      joinType: joinType ?? this.joinType,
      visibility: visibility ?? this.visibility,
      coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      facebookUrl: facebookUrl ?? this.facebookUrl,
      githubUrl: githubUrl ?? this.githubUrl,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      tags: tags ?? this.tags,
      maxMembers: maxMembers ?? this.maxMembers,
      memberCount: memberCount ?? this.memberCount,
      activityScore: activityScore ?? this.activityScore,
      foundedDate: foundedDate ?? this.foundedDate,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isUserMember: isUserMember ?? this.isUserMember,
      joinRequestStatus: joinRequestStatus ?? this.joinRequestStatus,
      userMemberRole: userMemberRole ?? this.userMemberRole,
    );
  }
}

