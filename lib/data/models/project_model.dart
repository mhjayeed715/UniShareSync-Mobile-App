import 'package:unisharesync_mobile_app/data/models/user_role.dart';

enum ProjectStatus { recruiting, active, onHold, completed, archived }

extension ProjectStatusExtension on ProjectStatus {
  String get displayName {
    switch (this) {
      case ProjectStatus.recruiting:
        return 'Recruiting';
      case ProjectStatus.active:
        return 'Active';
      case ProjectStatus.onHold:
        return 'On Hold';
      case ProjectStatus.completed:
        return 'Completed';
      case ProjectStatus.archived:
        return 'Archived';
    }
  }

  String get storageValue {
    switch (this) {
      case ProjectStatus.recruiting:
        return 'recruiting';
      case ProjectStatus.active:
        return 'active';
      case ProjectStatus.onHold:
        return 'on_hold';
      case ProjectStatus.completed:
        return 'completed';
      case ProjectStatus.archived:
        return 'archived';
    }
  }

  int get priority {
    switch (this) {
      case ProjectStatus.recruiting:
        return 0;
      case ProjectStatus.active:
        return 1;
      case ProjectStatus.onHold:
        return 2;
      case ProjectStatus.completed:
        return 3;
      case ProjectStatus.archived:
        return 4;
    }
  }
}

enum ProjectType {
  courseProject,
  researchProject,
  personalSideProject,
  capstoneThesis,
  hackathon,
  clubProject;

  String get value {
    switch (this) {
      case ProjectType.courseProject: return 'course_project';
      case ProjectType.researchProject: return 'research_project';
      case ProjectType.personalSideProject: return 'personal_side_project';
      case ProjectType.capstoneThesis: return 'capstone_thesis';
      case ProjectType.hackathon: return 'hackathon';
      case ProjectType.clubProject: return 'club_project';
    }
  }

  String get displayName {
    switch (this) {
      case ProjectType.courseProject: return 'Course Project';
      case ProjectType.researchProject: return 'Research Project';
      case ProjectType.personalSideProject: return 'Personal/Side Project';
      case ProjectType.capstoneThesis: return 'Capstone/Thesis';
      case ProjectType.hackathon: return 'Hackathon';
      case ProjectType.clubProject: return 'community Project';
    }
  }

  static ProjectType fromString(String? val) {
    switch (val) {
      case 'course_project': return ProjectType.courseProject;
      case 'research_project': return ProjectType.researchProject;
      case 'personal_side_project': return ProjectType.personalSideProject;
      case 'capstone_thesis': return ProjectType.capstoneThesis;
      case 'hackathon': return ProjectType.hackathon;
      case 'club_project': return ProjectType.clubProject;
      default: return ProjectType.courseProject;
    }
  }
}

enum ProjectCategory {
  webDevelopment,
  mobileDevelopment,
  aiMl,
  iotEmbedded,
  dataScience,
  cybersecurity,
  gameDevelopment,
  networking,
  database,
  other;

  String get value {
    switch (this) {
      case ProjectCategory.webDevelopment: return 'web_development';
      case ProjectCategory.mobileDevelopment: return 'mobile_development';
      case ProjectCategory.aiMl: return 'ai_ml';
      case ProjectCategory.iotEmbedded: return 'iot_embedded';
      case ProjectCategory.dataScience: return 'data_science';
      case ProjectCategory.cybersecurity: return 'cybersecurity';
      case ProjectCategory.gameDevelopment: return 'game_development';
      case ProjectCategory.networking: return 'networking';
      case ProjectCategory.database: return 'database';
      case ProjectCategory.other: return 'other';
    }
  }

  String get displayName {
    switch (this) {
      case ProjectCategory.webDevelopment: return 'Web Development';
      case ProjectCategory.mobileDevelopment: return 'Mobile Development';
      case ProjectCategory.aiMl: return 'AI & ML';
      case ProjectCategory.iotEmbedded: return 'IoT & Embedded';
      case ProjectCategory.dataScience: return 'Data Science';
      case ProjectCategory.cybersecurity: return 'Cybersecurity';
      case ProjectCategory.gameDevelopment: return 'Game Development';
      case ProjectCategory.networking: return 'Networking';
      case ProjectCategory.database: return 'Database';
      case ProjectCategory.other: return 'Other';
    }
  }

  static ProjectCategory fromString(String? val) {
    switch (val) {
      case 'web_development': return ProjectCategory.webDevelopment;
      case 'mobile_development': return ProjectCategory.mobileDevelopment;
      case 'ai_ml': return ProjectCategory.aiMl;
      case 'iot_embedded': return ProjectCategory.iotEmbedded;
      case 'data_science': return ProjectCategory.dataScience;
      case 'cybersecurity': return ProjectCategory.cybersecurity;
      case 'game_development': return ProjectCategory.gameDevelopment;
      case 'networking': return ProjectCategory.networking;
      case 'database': return ProjectCategory.database;
      case 'other': return ProjectCategory.other;
      default: return ProjectCategory.other;
    }
  }
}

enum ProjectVisibility {
  public,
  private,
  courseOnly;

  String get value {
    switch (this) {
      case ProjectVisibility.public: return 'public';
      case ProjectVisibility.private: return 'private';
      case ProjectVisibility.courseOnly: return 'course_only';
    }
  }

  String get displayName {
    switch (this) {
      case ProjectVisibility.public: return 'Public';
      case ProjectVisibility.private: return 'Private';
      case ProjectVisibility.courseOnly: return 'Course-Only';
    }
  }

  static ProjectVisibility fromString(String? val) {
    switch (val) {
      case 'public': return ProjectVisibility.public;
      case 'private': return ProjectVisibility.private;
      case 'course_only': return ProjectVisibility.courseOnly;
      default: return ProjectVisibility.public;
    }
  }
}

enum SupervisorInviteStatus { pending, accepted, declined, resigned }

class ProjectSupervisorModel {
  const ProjectSupervisorModel({
    required this.id,
    required this.projectId,
    required this.facultyId,
    required this.facultyName,
    this.facultyAvatarUrl,
    required this.status,
    required this.invitedBy,
    required this.invitedAt,
    this.respondedAt,
    this.feedbackNote,
    this.lastReviewStatus,
    this.gradeNote,
  });

  final String id;
  final String projectId;
  final String facultyId;
  final String facultyName;
  final String? facultyAvatarUrl;
  final SupervisorInviteStatus status;
  final String invitedBy;
  final DateTime invitedAt;
  final DateTime? respondedAt;
  final String? feedbackNote;
  final String? lastReviewStatus; // 'reviewed', 'needs_revision', null
  final String? gradeNote;

  factory ProjectSupervisorModel.fromMap(Map<String, dynamic> map) {
    return ProjectSupervisorModel(
      id: map['id'] as String? ?? '',
      projectId: map['project_id'] as String? ?? '',
      facultyId: map['faculty_id'] as String? ?? '',
      facultyName: map['faculty_name'] as String? ?? (map['profiles']?['full_name'] as String? ?? 'Faculty'),
      facultyAvatarUrl: map['faculty_avatar_url'] as String? ?? (map['profiles']?['avatar_url'] as String?),
      status: _parseInviteStatus(map['status']),
      invitedBy: map['invited_by'] as String? ?? '',
      invitedAt: _parseDateTime(map['invited_at']),
      respondedAt: map['responded_at'] != null ? _parseDateTime(map['responded_at']) : null,
      feedbackNote: map['feedback_note'] as String?,
      lastReviewStatus: map['last_review_status'] as String?,
      gradeNote: map['grade_note'] as String?,
    );
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
    this.courseCode,
    this.courseName,
    this.projectType = ProjectType.courseProject,
    this.visibility = ProjectVisibility.public,
    this.bannerUrl,
  });

  final String? id;
  final String title;
  final String description;
  final ProjectCategory category;
  final int semesterNo;
  final int maxMembers;
  final List<String> requiredSkills;
  final DateTime deadline;
  final String? courseCode;
  final String? courseName;
  final ProjectType projectType;
  final ProjectVisibility visibility;
  final String? bannerUrl;
}

class ProjectModel {
  const ProjectModel({
    required this.id,
    required this.projectCode,
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
    required this.updatedAt,
    required this.visibility,
    required this.projectType,
    required this.progressPct,
    required this.isAtRisk,
    this.courseCode,
    this.courseName,
    this.bannerUrl,
    this.lastActivityAt,
    this.userRole,
    this.hasUserJoined = false,
    this.joinRequestPending = false,
    this.memberNames = const [],
    this.supervisors = const [],
  });

  final String id;
  final String projectCode;
  final String title;
  final String description;
  final String ownerId;
  final String ownerName;
  final String? ownerAvatarUrl;
  final ProjectStatus status;
  final int semesterNo;
  final ProjectCategory category;
  final int maxMembers;
  final int currentMembers;
  final List<String> requiredSkills;
  final DateTime deadline;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ProjectVisibility visibility;
  final ProjectType projectType;
  final int progressPct;
  final bool isAtRisk;
  final String? courseCode;
  final String? courseName;
  final String? bannerUrl;
  final DateTime? lastActivityAt;
  final UserRole? userRole;
  final bool hasUserJoined;
  final bool joinRequestPending;
  final List<String> memberNames;
  final List<ProjectSupervisorModel> supervisors;

  String get semesterLabel => 'Semester $semesterNo';

  int get availableSlots => maxMembers - currentMembers;

  bool get isFull => availableSlots <= 0;

  bool get isDeadlinePassed => DateTime.now().isAfter(deadline);

  bool get isRecruiting => status == ProjectStatus.recruiting && !isFull;

  factory ProjectModel.fromMap(Map<String, dynamic> map) {
    final rawSemester = map['semester_no'] ?? map['semester'];
    final semesterNo = _parseSemester(rawSemester);

    // Parse supervisors if present
    final rawSupervisors = map['project_supervisors'] as List?;
    final supervisors = rawSupervisors != null
        ? rawSupervisors
            .map((s) => ProjectSupervisorModel.fromMap(Map<String, dynamic>.from(s)))
            .toList()
        : const <ProjectSupervisorModel>[];

    return ProjectModel(
      id: map['id'] as String? ?? '',
      projectCode: map['project_code'] as String? ?? '',
      title: map['title'] as String? ?? 'Untitled Project',
      description: map['description'] as String? ?? '',
      ownerId: map['owner_id'] as String? ?? '',
      ownerName: map['owner_name'] as String? ?? 'Unknown',
      ownerAvatarUrl: map['owner_avatar_url'] as String?,
      status: _parseStatus(map['status']),
      semesterNo: semesterNo,
      category: ProjectCategory.fromString(map['category'] as String?),
      maxMembers: map['max_members'] as int? ?? 5,
      currentMembers: map['current_members'] as int? ?? 1,
      requiredSkills: (map['required_skills'] as List?)
              ?.cast<String>()
              .toList() ??
          [],
      deadline: _parseDateTime(map['deadline']),
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at'] ?? map['created_at']),
      visibility: ProjectVisibility.fromString(map['visibility'] as String?),
      projectType: ProjectType.fromString(map['project_type'] as String?),
      progressPct: map['progress_pct'] as int? ?? 0,
      isAtRisk: map['is_at_risk'] as bool? ?? false,
      courseCode: map['course_code'] as String?,
      courseName: map['course_name'] as String?,
      bannerUrl: map['banner_url'] as String?,
      lastActivityAt: map['last_activity_at'] != null ? _parseDateTime(map['last_activity_at']) : null,
      userRole: null,
      hasUserJoined: map['has_user_joined'] as bool? ?? false,
      joinRequestPending: map['join_request_pending'] as bool? ?? false,
      memberNames: (map['member_names'] as List?)
              ?.cast<String>()
              .toList() ??
          [],
      supervisors: supervisors,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_code': projectCode,
        'title': title,
        'description': description,
        'owner_id': ownerId,
        'owner_name': ownerName,
        'owner_avatar_url': ownerAvatarUrl,
        'status': status.storageValue,
        'semester_no': semesterNo,
        'category': category.value,
        'max_members': maxMembers,
        'current_members': currentMembers,
        'required_skills': requiredSkills,
        'deadline': deadline.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'visibility': visibility.value,
        'project_type': projectType.value,
        'progress_pct': progressPct,
        'is_at_risk': isAtRisk,
        'course_code': courseCode,
        'course_name': courseName,
        'banner_url': bannerUrl,
        'last_activity_at': lastActivityAt?.toIso8601String(),
      };

  ProjectModel copyWith({
    String? id,
    String? projectCode,
    String? title,
    String? description,
    String? ownerId,
    String? ownerName,
    String? ownerAvatarUrl,
    ProjectStatus? status,
    int? semesterNo,
    ProjectCategory? category,
    int? maxMembers,
    int? currentMembers,
    List<String>? requiredSkills,
    DateTime? deadline,
    DateTime? createdAt,
    DateTime? updatedAt,
    ProjectVisibility? visibility,
    ProjectType? projectType,
    int? progressPct,
    bool? isAtRisk,
    String? courseCode,
    String? courseName,
    String? bannerUrl,
    DateTime? lastActivityAt,
    UserRole? userRole,
    bool? hasUserJoined,
    bool? joinRequestPending,
    List<String>? memberNames,
    List<ProjectSupervisorModel>? supervisors,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      projectCode: projectCode ?? this.projectCode,
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
      updatedAt: updatedAt ?? this.updatedAt,
      visibility: visibility ?? this.visibility,
      projectType: projectType ?? this.projectType,
      progressPct: progressPct ?? this.progressPct,
      isAtRisk: isAtRisk ?? this.isAtRisk,
      courseCode: courseCode ?? this.courseCode,
      courseName: courseName ?? this.courseName,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      userRole: userRole ?? this.userRole,
      hasUserJoined: hasUserJoined ?? this.hasUserJoined,
      joinRequestPending: joinRequestPending ?? this.joinRequestPending,
      memberNames: memberNames ?? this.memberNames,
      supervisors: supervisors ?? this.supervisors,
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
      case 'on_hold':
      case 'onhold':
        return ProjectStatus.onHold;
      case 'completed':
        return ProjectStatus.completed;
      case 'archived':
        return ProjectStatus.archived;
    }
  }
  return ProjectStatus.recruiting;
}

SupervisorInviteStatus _parseInviteStatus(dynamic status) {
  if (status is SupervisorInviteStatus) return status;
  if (status is String) {
    switch (status.toLowerCase()) {
      case 'pending': return SupervisorInviteStatus.pending;
      case 'accepted': return SupervisorInviteStatus.accepted;
      case 'declined': return SupervisorInviteStatus.declined;
      case 'resigned': return SupervisorInviteStatus.resigned;
    }
  }
  return SupervisorInviteStatus.pending;
}

int _parseSemester(dynamic value) {
  if (value is int) {
    return value.clamp(1, 12);
  }
  if (value is String) {
    final trimmed = value.toLowerCase().replaceAll('semester', '').trim();
    final parsed = int.tryParse(trimmed);
    if (parsed != null) {
      return parsed.clamp(1, 12);
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

