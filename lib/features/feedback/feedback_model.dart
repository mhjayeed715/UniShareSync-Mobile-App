import 'package:unisharesync_mobile_app/data/models/user_role.dart';

enum FeedbackCategory { academic, technical, general }

extension FeedbackCategoryX on FeedbackCategory {
  String get label => switch (this) {
        FeedbackCategory.academic => 'Academic',
        FeedbackCategory.technical => 'Technical',
        FeedbackCategory.general => 'General',
      };

  String get storageValue => name;

  static FeedbackCategory fromString(String? value) => switch (value) {
        'technical' => FeedbackCategory.technical,
        'general' => FeedbackCategory.general,
        'academic' => FeedbackCategory.academic,
        _ => FeedbackCategory.general,
      };
}

enum FeedbackStatus { pending, responded, resolved }

extension FeedbackStatusX on FeedbackStatus {
  String get label => switch (this) {
        FeedbackStatus.pending => 'Pending',
        FeedbackStatus.responded => 'Responded',
        FeedbackStatus.resolved => 'Resolved',
      };

  String get storageValue => name;

  static FeedbackStatus fromString(String? value) => switch (value) {
        'responded' => FeedbackStatus.responded,
        'resolved' => FeedbackStatus.resolved,
        'pending' => FeedbackStatus.pending,
        _ => FeedbackStatus.pending,
      };
}

class FeedbackDraft {
  const FeedbackDraft({
    required this.category,
    required this.title,
    required this.content,
    required this.rating,
    required this.isAnonymous,
  });

  final FeedbackCategory category;
  final String title;
  final String content;
  final int rating;
  final bool isAnonymous;
}

class FeedbackEntry {
  const FeedbackEntry({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    required this.rating,
    required this.isAnonymous,
    required this.status,
    required this.submitterId,
    required this.submitterName,
    required this.submitterRole,
    required this.createdAt,
    required this.updatedAt,
    this.adminResponse,
    this.respondedBy,
    this.respondedAt,
    this.submitterAvatarUrl,
  });

  final String id;
  final FeedbackCategory category;
  final String title;
  final String content;
  final int rating;
  final bool isAnonymous;
  final FeedbackStatus status;
  final String? adminResponse;
  final String? respondedBy;
  final DateTime? respondedAt;
  final String submitterId;
  final String submitterName;
  final String? submitterAvatarUrl;
  final UserRole submitterRole;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName => isAnonymous ? 'Anonymous' : submitterName;

  bool get hasAdminResponse => adminResponse != null && adminResponse!.trim().isNotEmpty;

  factory FeedbackEntry.fromMap(Map<String, dynamic> map) {
    return FeedbackEntry(
      id: map['id']?.toString() ?? '',
      category: FeedbackCategoryX.fromString(map['category']?.toString()),
      title: map['title']?.toString() ?? 'Untitled feedback',
      content: map['content']?.toString() ?? '',
      rating: _toRating(map['rating']),
      isAnonymous: map['is_anonymous'] == true,
      status: FeedbackStatusX.fromString(map['status']?.toString()),
      adminResponse: map['admin_response']?.toString(),
      respondedBy: map['responded_by']?.toString(),
      respondedAt: _toNullableDateTime(map['responded_at']),
      submitterId: map['submitter_id']?.toString() ?? '',
      submitterName: map['submitter_name']?.toString() ?? 'Anonymous',
      submitterAvatarUrl: map['submitter_avatar_url']?.toString(),
      submitterRole: UserRole.fromString(map['submitter_role']?.toString()),
      createdAt: _toDateTime(map['created_at']),
      updatedAt: _toDateTime(map['updated_at']),
    );
  }
}

int _toRating(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return 5;
  }
  return parsed.clamp(1, 5);
}

DateTime _toDateTime(dynamic value) {
  if (value is DateTime) {
    return value.toLocal();
  }
  if (value is String && value.trim().isNotEmpty) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed.toLocal();
    }
  }
  return DateTime.now();
}

DateTime? _toNullableDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value.toLocal();
  }
  if (value is String && value.trim().isNotEmpty) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed.toLocal();
    }
  }
  return null;
}
