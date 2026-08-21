
enum TaskPriority { critical, high, medium, low }

class KanbanColumn {
  const KanbanColumn({
    required this.id,
    required this.projectId,
    required this.title,
    required this.position,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String projectId;
  final String title;
  final int position;
  final String? createdBy;
  final DateTime? createdAt;

  factory KanbanColumn.fromMap(Map<String, dynamic> map) {
    return KanbanColumn(
      id: map['id'] as String? ?? '',
      projectId: map['project_id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      position: map['position'] as int? ?? 0,
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'title': title,
        'position': position,
        'created_by': createdBy,
        'created_at': createdAt?.toIso8601String(),
      };
}

class TaskLabel {
  const TaskLabel({
    required this.labelText,
    required this.labelColor,
  });

  final String labelText;
  final String labelColor;

  factory TaskLabel.fromMap(Map<String, dynamic> map) {
    return TaskLabel(
      labelText: map['label_text'] as String? ?? '',
      labelColor: map['label_color'] as String? ?? '#2563EB',
    );
  }

  Map<String, dynamic> toMap() => {
        'label_text': labelText,
        'label_color': labelColor,
      };
}

class TaskChecklistItem {
  const TaskChecklistItem({
    required this.id,
    required this.taskId,
    required this.text,
    required this.isChecked,
    required this.position,
    this.createdBy,
  });

  final String id;
  final String taskId;
  final String text;
  final bool isChecked;
  final int position;
  final String? createdBy;

  factory TaskChecklistItem.fromMap(Map<String, dynamic> map) {
    return TaskChecklistItem(
      id: map['id'] as String? ?? '',
      taskId: map['task_id'] as String? ?? '',
      text: map['text'] as String? ?? '',
      isChecked: map['is_checked'] as bool? ?? false,
      position: map['position'] as int? ?? 0,
      createdBy: map['created_by'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'task_id': taskId,
        'text': text,
        'is_checked': isChecked,
        'position': position,
        'created_by': createdBy,
      };
}

enum AttachmentType { resourceRef, directUpload, voiceNote }

class TaskAttachment {
  const TaskAttachment({
    required this.id,
    required this.taskId,
    required this.attachmentType,
    this.resourceId,
    this.fileUrl,
    required this.fileName,
    this.fileSizeBytes,
    this.durationSeconds,
    this.uploadedBy,
    this.uploadedAt,
  });

  final String id;
  final String taskId;
  final AttachmentType attachmentType;
  final String? resourceId;
  final String? fileUrl;
  final String fileName;
  final int? fileSizeBytes;
  final int? durationSeconds;
  final String? uploadedBy;
  final DateTime? uploadedAt;

  factory TaskAttachment.fromMap(Map<String, dynamic> map) {
    AttachmentType parseType(String? type) {
      switch (type) {
        case 'resource_ref': return AttachmentType.resourceRef;
        case 'direct_upload': return AttachmentType.directUpload;
        case 'voice_note': return AttachmentType.voiceNote;
        default: return AttachmentType.directUpload;
      }
    }

    return TaskAttachment(
      id: map['id'] as String? ?? '',
      taskId: map['task_id'] as String? ?? '',
      attachmentType: parseType(map['attachment_type'] as String?),
      resourceId: map['resource_id'] as String?,
      fileUrl: map['file_url'] as String?,
      fileName: map['file_name'] as String? ?? 'attachment',
      fileSizeBytes: map['file_size_bytes'] as int?,
      durationSeconds: map['duration_seconds'] as int?,
      uploadedBy: map['uploaded_by'] as String?,
      uploadedAt: map['uploaded_at'] != null ? DateTime.parse(map['uploaded_at']) : null,
    );
  }
}

class TaskComment {
  const TaskComment({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.content,
    required this.mentions,
    required this.createdAt,
    this.editedAt,
    this.isDeleted = false,
  });

  final String id;
  final String taskId;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String content;
  final List<String> mentions;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool isDeleted;

  factory TaskComment.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return TaskComment(
      id: map['id'] as String? ?? '',
      taskId: map['task_id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      userName: profile?['full_name'] as String? ?? 'User',
      userAvatarUrl: profile?['avatar_url'] as String?,
      content: map['content'] as String? ?? '',
      mentions: (map['mentions'] as List?)?.cast<String>().toList() ?? const [],
      createdAt: DateTime.parse(map['created_at'] as String? ?? DateTime.now().toIso8601String()),
      editedAt: map['edited_at'] != null ? DateTime.parse(map['edited_at'] as String) : null,
      isDeleted: map['is_deleted'] as bool? ?? false,
    );
  }
}

class TaskActivityLog {
  const TaskActivityLog({
    required this.id,
    required this.taskId,
    required this.projectId,
    required this.actorId,
    required this.actorName,
    required this.actionType,
    required this.actionPayload,
    required this.createdAt,
  });

  final String id;
  final String taskId;
  final String projectId;
  final String actorId;
  final String actorName;
  final String actionType;
  final Map<String, dynamic> actionPayload;
  final DateTime createdAt;

  factory TaskActivityLog.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return TaskActivityLog(
      id: map['id'] as String? ?? '',
      taskId: map['task_id'] as String? ?? '',
      projectId: map['project_id'] as String? ?? '',
      actorId: map['actor_id'] as String? ?? '',
      actorName: profile?['full_name'] as String? ?? 'User',
      actionType: map['action_type'] as String? ?? '',
      actionPayload: map['action_payload'] as Map<String, dynamic>? ?? const {},
      createdAt: DateTime.parse(map['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}

class KanbanTask {
  const KanbanTask({
    required this.id,
    required this.projectId,
    required this.columnId,
    required this.title,
    this.description,
    required this.priority,
    this.dueDate,
    required this.position,
    this.isOverdue = false,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.assignees = const [],
    this.labels = const [],
    this.checklist = const [],
    this.attachments = const [],
    this.comments = const [],
  });

  final String id;
  final String projectId;
  final String columnId;
  final String title;
  final String? description;
  final TaskPriority priority;
  final DateTime? dueDate;
  final double position;
  final bool isOverdue;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<String> assignees; // User IDs
  final List<TaskLabel> labels;
  final List<TaskChecklistItem> checklist;
  final List<TaskAttachment> attachments;
  final List<TaskComment> comments;

  double get checklistCompletionRatio {
    if (checklist.isEmpty) return 0.0;
    final done = checklist.where((item) => item.isChecked).length;
    return done / checklist.length;
  }

  factory KanbanTask.fromMap(Map<String, dynamic> map) {
    TaskPriority parsePriority(String? prio) {
      switch (prio?.toLowerCase()) {
        case 'critical': return TaskPriority.critical;
        case 'high': return TaskPriority.high;
        case 'medium': return TaskPriority.medium;
        case 'low': return TaskPriority.low;
        default: return TaskPriority.medium;
      }
    }

    final rawAssignees = map['task_assignees'] as List?;
    final assignees = rawAssignees != null
        ? rawAssignees.map((a) => a['user_id'] as String).toList()
        : const <String>[];

    final rawLabels = map['task_labels'] as List?;
    final labels = rawLabels != null
        ? rawLabels.map((l) => TaskLabel.fromMap(Map<String, dynamic>.from(l))).toList()
        : const <TaskLabel>[];

    final rawChecklist = map['task_checklist_items'] as List?;
    final checklist = rawChecklist != null
        ? rawChecklist.map((c) => TaskChecklistItem.fromMap(Map<String, dynamic>.from(c))).toList()
        : const <TaskChecklistItem>[];

    final rawAttachments = map['task_attachments'] as List?;
    final attachments = rawAttachments != null
        ? rawAttachments.map((a) => TaskAttachment.fromMap(Map<String, dynamic>.from(a))).toList()
        : const <TaskAttachment>[];

    final rawComments = map['task_comments'] as List?;
    final comments = rawComments != null
        ? rawComments.map((c) => TaskComment.fromMap(Map<String, dynamic>.from(c))).toList()
        : const <TaskComment>[];

    return KanbanTask(
      id: map['id'] as String? ?? '',
      projectId: map['project_id'] as String? ?? '',
      columnId: map['column_id'] as String? ?? '',
      title: map['title'] as String? ?? 'Untitled Task',
      description: map['description'] as String?,
      priority: parsePriority(map['priority'] as String?),
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date']) : null,
      position: (map['position'] as num? ?? 0.0).toDouble(),
      isOverdue: map['is_overdue'] as bool? ?? false,
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      assignees: assignees,
      labels: labels,
      checklist: checklist,
      attachments: attachments,
      comments: comments,
    );
  }
}
