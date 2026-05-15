enum NoticePriority { normal, important, urgent }

extension NoticePriorityX on NoticePriority {
  String get label => switch (this) {
        NoticePriority.normal => 'Normal',
        NoticePriority.important => 'Important',
        NoticePriority.urgent => 'Urgent',
      };

  static NoticePriority fromString(String? value) => switch (value) {
        'important' => NoticePriority.important,
        'urgent' => NoticePriority.urgent,
        _ => NoticePriority.normal,
      };
}

class NoticeModel {
  const NoticeModel({
    required this.id,
    required this.title,
    required this.content,
    required this.priority,
    required this.createdAt,
    this.attachmentUrl,
    this.attachmentType,
    this.postedBy,
    this.targetRoles = const ['student', 'faculty', 'admin'],
    this.targetSemesters = const [],
  });

  final String id;
  final String title;
  final String content;
  final NoticePriority priority;
  final DateTime createdAt;
  final String? attachmentUrl;
  final String? attachmentType; // 'pdf' | 'image'
  final String? postedBy;
  final List<String> targetRoles; // ['student', 'faculty', 'admin']
  final List<int> targetSemesters; // [1, 2, 3, ...] or empty for all

  factory NoticeModel.fromMap(Map<String, dynamic> map) {
    return NoticeModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Untitled',
      content: map['content']?.toString() ?? map['body']?.toString() ?? '',
      priority: NoticePriorityX.fromString(map['priority']?.toString()),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString()).toLocal()
          : DateTime.now(),
      attachmentUrl: map['attachment_url']?.toString(),
      attachmentType: map['attachment_type']?.toString(),
      postedBy: map['posted_by']?.toString(),
      targetRoles: (map['target_roles'] as List?)?.cast<String>() ?? ['student', 'faculty', 'admin'],
      targetSemesters: (map['target_semesters'] as List?)?.cast<int>() ?? [],
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'title': title,
        'body': content,
        'content': content,
        'priority': priority.name,
        'target_roles': targetRoles,
        'target_semesters': targetSemesters,
        'posted_by': postedBy,
        if (attachmentUrl != null) 'attachment_url': attachmentUrl,
        if (attachmentType != null) 'attachment_type': attachmentType,
      };
}
