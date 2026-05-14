import 'package:unisharesync_mobile_app/data/models/user_role.dart';

enum ProjectStatus { recruiting, active, completed }

extension ProjectStatusExtension on ProjectStatus {
  String get displayName {
    switch (this) {
      case ProjectStatus.recruiting:
        return 'Recruiting';
      case ProjectStatus.active:
        return 'Active';
      case ProjectStatus.completed:
        return 'Completed';
    }
  }

  String get storageValue {
    switch (this) {
      case ProjectStatus.recruiting:
        return 'recruiting';
      case ProjectStatus.active:
        return 'active';
      case ProjectStatus.completed:
        return 'completed';
    }
  }

  int get priority {
    switch (this) {
      case ProjectStatus.recruiting:
        return 0;
      case ProjectStatus.active:
        return 1;
      case ProjectStatus.completed:
        return 2;
    }
  }
}

class ProjectDraft {
  const ProjectDraft({
    this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.semesterNo,
    required this.maxMembers,
    required this.requiredSkills,
    required this.deadline,
  });

  final String? id;
  final String title;
  final String description;
  final String category;
  final int semesterNo;
  final int maxMembers;
  final List<String> requiredSkills;
  final DateTime deadline;
}

class ProjectModel {
  const ProjectModel({
    required this.id,
    required this.title,
    required this.description,
    required this.ownerId,
    required this.ownerName,
    required this.ownerAvatarUrl,
    required this.status,
    required this.semesterNo,
    required this.category,
    required this.maxMembers,
    required this.currentMembers,
    required this.requiredSkills,
    required this.deadline,
    required this.createdAt,
    this.userRole,
    this.hasUserJoined = false,
    this.joinRequestPending = false,
  });

  final String id;
  final String title;
  final String description;
  final String ownerId;
  final String ownerName;
  final String? ownerAvatarUrl;
  final ProjectStatus status;
  final int semesterNo;
  final String category;
  final int maxMembers;
  final int currentMembers;
  final List<String> requiredSkills;
  final DateTime deadline;
  final DateTime createdAt;
  final UserRole? userRole;
  final bool hasUserJoined;
  final bool joinRequestPending;

  String get semesterLabel => 'Semester $semesterNo';

  int get availableSlots => maxMembers - currentMembers;

  bool get isFull => availableSlots <= 0;

  bool get isDeadlinePassed => DateTime.now().isAfter(deadline);

  bool get isRecruiting => status == ProjectStatus.recruiting && !isFull;

  factory ProjectModel.fromMap(Map<String, dynamic> map) {
    final rawSemester = map['semester_no'] ?? map['semester'];
    final semesterNo = _parseSemester(rawSemester);

    return ProjectModel(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Untitled Project',
      description: map['description'] as String? ?? '',
      ownerId: map['owner_id'] as String? ?? '',
      ownerName: map['owner_name'] as String? ?? 'Unknown',
      ownerAvatarUrl: map['owner_avatar_url'] as String?,
      status: _parseStatus(map['status']),
      semesterNo: semesterNo,
      category: map['category'] as String? ?? '',
      maxMembers: map['max_members'] as int? ?? 5,
      currentMembers: map['current_members'] as int? ?? 1,
      requiredSkills: (map['required_skills'] as List?)
              ?.cast<String>()
              .toList() ??
          [],
      deadline: _parseDateTime(map['deadline']),
      createdAt: _parseDateTime(map['created_at']),
      userRole: null,
      hasUserJoined: map['has_user_joined'] as bool? ?? false,
      joinRequestPending: map['join_request_pending'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'owner_id': ownerId,
        'owner_name': ownerName,
        'owner_avatar_url': ownerAvatarUrl,
      'status': status.storageValue,
      'semester_no': semesterNo,
        'category': category,
        'max_members': maxMembers,
        'current_members': currentMembers,
        'required_skills': requiredSkills,
        'deadline': deadline.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  ProjectModel copyWith({
    String? id,
    String? title,
    String? description,
    String? ownerId,
    String? ownerName,
    String? ownerAvatarUrl,
    ProjectStatus? status,
    int? semesterNo,
    String? category,
    int? maxMembers,
    int? currentMembers,
    List<String>? requiredSkills,
    DateTime? deadline,
    DateTime? createdAt,
    UserRole? userRole,
    bool? hasUserJoined,
    bool? joinRequestPending,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      ownerAvatarUrl: ownerAvatarUrl ?? this.ownerAvatarUrl,
      status: status ?? this.status,
      semesterNo: semesterNo ?? this.semesterNo,
      category: category ?? this.category,
      maxMembers: maxMembers ?? this.maxMembers,
      currentMembers: currentMembers ?? this.currentMembers,
      requiredSkills: requiredSkills ?? this.requiredSkills,
      deadline: deadline ?? this.deadline,
      createdAt: createdAt ?? this.createdAt,
      userRole: userRole ?? this.userRole,
      hasUserJoined: hasUserJoined ?? this.hasUserJoined,
      joinRequestPending: joinRequestPending ?? this.joinRequestPending,
    );
  }
}

ProjectStatus _parseStatus(dynamic status) {
  if (status is ProjectStatus) return status;
  if (status is String) {
    switch (status.toLowerCase()) {
      case 'recruiting':
        return ProjectStatus.recruiting;
      case 'active':
        return ProjectStatus.active;
      case 'completed':
        return ProjectStatus.completed;
    }
  }
  return ProjectStatus.recruiting;
}

int _parseSemester(dynamic value) {
  if (value is int) {
    return value.clamp(1, 10);
  }
  if (value is String) {
    final trimmed = value.toLowerCase().replaceAll('semester', '').trim();
    final parsed = int.tryParse(trimmed);
    if (parsed != null) {
      return parsed.clamp(1, 10);
    }
  }
  return 1;
}

DateTime _parseDateTime(dynamic dateTime) {
  if (dateTime is DateTime) return dateTime;
  if (dateTime is String) {
    try {
      return DateTime.parse(dateTime);
    } catch (_) {}
  }
  return DateTime.now();
}
