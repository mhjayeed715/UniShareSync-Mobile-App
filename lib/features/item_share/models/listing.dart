enum ListingType { borrow, rent, sell }

enum ListingStatus {
  available, requested, agreementPending, approved, active,
  overdue, severelyOverdue, returnInitiated, returnConfirmed,
  completed, disputed, sold, cancelled
}

enum ItemCategory {
  developmentBoard, sensorModule, measurementTool, labEquipment,
  electronicComponents, textbook, referenceBook, other
}

enum ItemCondition { excellent, good, fair, forParts }

class Listing {
  final String id;
  final String userId;
  final String title;
  final String description;
  final ItemCategory category;
  final ItemCondition condition;
  final List<String> semesterTags;
  final List<String> photos;
  final ListingType type;
  final ListingStatus status;
  final int trustScoreRequired;
  final bool adminApproved;
  final bool isDraft;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userName;
  final String? userAvatarUrl;

  const Listing({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.category,
    required this.condition,
    required this.semesterTags,
    required this.photos,
    required this.type,
    required this.status,
    this.trustScoreRequired = 30,
    this.adminApproved = true,
    this.isDraft = false,
    required this.createdAt,
    required this.updatedAt,
    this.userName,
    this.userAvatarUrl,
  });

  factory Listing.fromJson(Map<String, dynamic> json) => Listing(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        category: ItemCategory.values.firstWhere(
          (e) => e.name == _toCamel(json['category'] as String),
          orElse: () => ItemCategory.other,
        ),
        condition: ItemCondition.values.firstWhere(
          (e) => e.name == _toCamel(json['condition'] as String),
          orElse: () => ItemCondition.good,
        ),
        semesterTags: List<String>.from(json['semester_tags'] ?? []),
        photos: List<String>.from(json['photos'] ?? []),
        type: ListingType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => ListingType.borrow,
        ),
        status: ListingStatus.values.firstWhere(
          (e) => e.name == _toCamel(json['status'] as String),
          orElse: () => ListingStatus.available,
        ),
        trustScoreRequired: json['trust_score_required'] as int? ?? 30,
        adminApproved: json['admin_approved'] as bool? ?? true,
        isDraft: json['is_draft'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        userName: json['user_name'] as String?,
        userAvatarUrl: json['user_avatar_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'title': title,
        'description': description,
        'category': toSnake(category.name),
        'condition': toSnake(condition.name),
        'semester_tags': semesterTags,
        'photos': photos,
        'type': type.name,
        'status': toSnake(status.name),
        'trust_score_required': trustScoreRequired,
        'admin_approved': adminApproved,
        'is_draft': isDraft,
      };

  Listing copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    ItemCategory? category,
    ItemCondition? condition,
    List<String>? semesterTags,
    List<String>? photos,
    ListingType? type,
    ListingStatus? status,
    int? trustScoreRequired,
    bool? adminApproved,
    bool? isDraft,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userName,
    String? userAvatarUrl,
  }) {
    return Listing(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      condition: condition ?? this.condition,
      semesterTags: semesterTags ?? this.semesterTags,
      photos: photos ?? this.photos,
      type: type ?? this.type,
      status: status ?? this.status,
      trustScoreRequired: trustScoreRequired ?? this.trustScoreRequired,
      adminApproved: adminApproved ?? this.adminApproved,
      isDraft: isDraft ?? this.isDraft,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
    );
  }

  // snake_case ↔ camelCase helpers for DB enum values (public for service use)
  static String _toCamel(String s) {
    final parts = s.split('_');
    return parts.first +
        parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
  }

  static String toSnake(String s) =>
      s.replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');
}
