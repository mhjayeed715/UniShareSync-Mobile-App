import 'package:unisharesync_mobile_app/data/models/user_role.dart';

enum ResourceFileType {
  pdf,
  docx,
  ppt,
  image;

  static ResourceFileType fromString(String? raw) {
    switch ((raw ?? '').toLowerCase().trim()) {
      case 'docx':
        return ResourceFileType.docx;
      case 'ppt':
        return ResourceFileType.ppt;
      case 'image':
        return ResourceFileType.image;
      case 'pdf':
      default:
        return ResourceFileType.pdf;
    }
  }

  String get value => name;

  String get label {
    switch (this) {
      case ResourceFileType.pdf:
        return 'PDF';
      case ResourceFileType.docx:
        return 'DOCX';
      case ResourceFileType.ppt:
        return 'PPT';
      case ResourceFileType.image:
        return 'Image';
    }
  }
}

enum ResourceKind {
  notes,
  slides,
  assignment,
  lab,
  exam,
  book,
  other;

  static ResourceKind fromString(String? raw) {
    switch ((raw ?? '').toLowerCase().trim()) {
      case 'slides':
        return ResourceKind.slides;
      case 'assignment':
        return ResourceKind.assignment;
      case 'lab':
        return ResourceKind.lab;
      case 'exam':
        return ResourceKind.exam;
      case 'book':
        return ResourceKind.book;
      case 'other':
        return ResourceKind.other;
      case 'notes':
      default:
        return ResourceKind.notes;
    }
  }

  String get value => name;

  String get label {
    switch (this) {
      case ResourceKind.notes:
        return 'Notes';
      case ResourceKind.slides:
        return 'Slides';
      case ResourceKind.assignment:
        return 'Assignment';
      case ResourceKind.lab:
        return 'Lab';
      case ResourceKind.exam:
        return 'Exam';
      case ResourceKind.book:
        return 'Book';
      case ResourceKind.other:
        return 'Other';
    }
  }
}

enum ResourceApprovalStatus {
  pending,
  approved,
  rejected;

  static ResourceApprovalStatus fromString(String? raw) {
    switch ((raw ?? '').toLowerCase().trim()) {
      case 'pending':
        return ResourceApprovalStatus.pending;
      case 'rejected':
        return ResourceApprovalStatus.rejected;
      case 'approved':
      default:
        return ResourceApprovalStatus.approved;
    }
  }

  String get label {
    switch (this) {
      case ResourceApprovalStatus.pending:
        return 'Pending';
      case ResourceApprovalStatus.approved:
        return 'Approved';
      case ResourceApprovalStatus.rejected:
        return 'Rejected';
    }
  }
}

class CourseOption {
  const CourseOption({
    required this.semesterNo,
    required this.semesterLabel,
    required this.courseCode,
    required this.courseTitle,
    this.credits,
    this.creditHours,
  });

  final int semesterNo;
  final String semesterLabel;
  final String courseCode;
  final String courseTitle;
  final double? credits;
  final double? creditHours;

  factory CourseOption.fromMap(Map<String, dynamic> map) {
    return CourseOption(
      semesterNo: _toInt(map['semester_no']) ?? 0,
      semesterLabel: (map['semester_label'] ?? '').toString(),
      courseCode: (map['course_code'] ?? '').toString(),
      courseTitle: (map['course_title'] ?? '').toString(),
      credits: _toDouble(map['credits']),
      creditHours: _toDouble(map['credit_hours']),
    );
  }

  static int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }

  static double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }
}

class ResourceItem {
  const ResourceItem({
    required this.id,
    required this.title,
    required this.courseCode,
    required this.courseTitle,
    required this.semesterNo,
    required this.resourceType,
    required this.fileType,
    required this.driveUrl,
    required this.approvalStatus,
    required this.totalDownloads,
    required this.uploaderId,
    required this.uploaderName,
    required this.uploaderRole,
    required this.createdAt,
    this.description,
    this.originalFileName,
    this.previewUrl,
    this.uploaderAvatarUrl,
  });

  final String id;
  final String title;
  final String? description;
  final String? originalFileName;
  final String courseCode;
  final String courseTitle;
  final int semesterNo;
  final ResourceKind resourceType;
  final ResourceFileType fileType;
  final String driveUrl;
  final String? previewUrl;
  final ResourceApprovalStatus approvalStatus;
  final int totalDownloads;
  final String uploaderId;
  final String uploaderName;
  final String? uploaderAvatarUrl;
  final UserRole uploaderRole;
  final DateTime createdAt;

  bool get supportsPreview =>
      fileType == ResourceFileType.pdf || fileType == ResourceFileType.image;

  String get semesterLabel => 'Semester $semesterNo';

  factory ResourceItem.fromSearchMap(Map<String, dynamic> map) {
    return ResourceItem(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: map['description']?.toString(),
      originalFileName: map['original_file_name']?.toString(),
      courseCode: (map['course_code'] ?? '').toString(),
      courseTitle: (map['course_title'] ?? '').toString(),
      semesterNo: _toInt(map['semester_no']) ?? 0,
      resourceType: ResourceKind.fromString(map['resource_type']?.toString()),
      fileType: ResourceFileType.fromString(map['file_type']?.toString()),
      driveUrl: (map['drive_url'] ?? '').toString(),
      previewUrl: map['preview_url']?.toString(),
      approvalStatus:
          ResourceApprovalStatus.fromString(map['approval_status']?.toString()),
      totalDownloads: _toInt(map['total_downloads']) ?? 0,
      uploaderId: (map['uploader_id'] ?? '').toString(),
      uploaderName: _uploaderNameFromMap(map),
      uploaderAvatarUrl: map['uploader_avatar_url']?.toString(),
      uploaderRole: UserRole.fromString(map['uploader_role']?.toString()),
      createdAt: _toDateTime(map['created_at']) ?? DateTime.now(),
    );
  }

  factory ResourceItem.fromResourceTableMap(
    Map<String, dynamic> map, {
    String? resolvedCourseTitle,
  }) {
    return ResourceItem(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: map['description']?.toString(),
      originalFileName: map['original_file_name']?.toString(),
      courseCode: (map['course_code'] ?? '').toString(),
      courseTitle:
          resolvedCourseTitle ?? (map['course_title'] ?? '').toString(),
      semesterNo: _toInt(map['semester_no']) ?? 0,
      resourceType: ResourceKind.fromString(map['resource_type']?.toString()),
      fileType: ResourceFileType.fromString(map['file_type']?.toString()),
      driveUrl: (map['drive_url'] ?? '').toString(),
      previewUrl: map['preview_url']?.toString(),
      approvalStatus:
          ResourceApprovalStatus.fromString(map['approval_status']?.toString()),
      totalDownloads: _toInt(map['total_downloads']) ?? 0,
      uploaderId: (map['uploader_id'] ?? '').toString(),
      uploaderName: _uploaderNameFromMap(map),
      uploaderAvatarUrl: map['uploader_avatar_url']?.toString(),
      uploaderRole: UserRole.fromString(map['uploader_role']?.toString()),
      createdAt: _toDateTime(map['created_at']) ?? DateTime.now(),
    );
  }

  ResourceItem copyWith({
    int? totalDownloads,
    String? title,
    String? description,
    String? originalFileName,
    String? driveUrl,
    ResourceApprovalStatus? approvalStatus,
  }) {
    return ResourceItem(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      originalFileName: originalFileName ?? this.originalFileName,
      courseCode: courseCode,
      courseTitle: courseTitle,
      semesterNo: semesterNo,
      resourceType: resourceType,
      fileType: fileType,
      driveUrl: driveUrl ?? this.driveUrl,
      previewUrl: previewUrl,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      totalDownloads: totalDownloads ?? this.totalDownloads,
      uploaderId: uploaderId,
      uploaderName: uploaderName,
      uploaderAvatarUrl: uploaderAvatarUrl,
      uploaderRole: uploaderRole,
      createdAt: createdAt,
    );
  }

  static String _uploaderNameFromMap(Map<String, dynamic> map) {
    final directName = map['uploader_name']?.toString().trim();
    if (directName != null && directName.isNotEmpty) {
      return directName;
    }

    final uploaderId = (map['uploader_id'] ?? '').toString().trim();
    if (uploaderId.isEmpty) {
      return 'Unknown Uploader';
    }

    if (uploaderId.length <= 8) {
      return uploaderId;
    }

    return uploaderId.substring(0, 8);
  }

  static int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value.toLocal();
    }
    return DateTime.tryParse(value.toString())?.toLocal();
  }
}
