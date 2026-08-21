import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/data/models/kanban_model.dart';

class KanbanService {
  KanbanService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  // --- Column Operations ---

  Future<List<KanbanColumn>> fetchColumns(String projectId) async {
    final response = await _client
        .from('kanban_columns')
        .select()
        .eq('project_id', projectId)
        .order('position', ascending: true);

    return (response as List)
        .map((x) => KanbanColumn.fromMap(Map<String, dynamic>.from(x)))
        .toList();
  }

  Future<KanbanColumn> createColumn(String projectId, String title, int position) async {
    final response = await _client
        .from('kanban_columns')
        .insert({
          'project_id': projectId,
          'title': title,
          'position': position,
          'created_by': currentUserId,
        })
        .select()
        .single();

    return KanbanColumn.fromMap(Map<String, dynamic>.from(response));
  }

  Future<void> updateColumnPosition(String columnId, int position) async {
    await _client
        .from('kanban_columns')
        .update({'position': position})
        .eq('id', columnId);
  }

  Future<void> deleteColumn(String columnId, String moveTasksToColumnId) async {
    // 1. Move tasks in the column to the other column
    await _client
        .from('kanban_tasks')
        .update({'column_id': moveTasksToColumnId})
        .eq('column_id', columnId);

    // 2. Delete the column
    await _client.from('kanban_columns').delete().eq('id', columnId);
  }

  // --- Task Operations ---

  Future<List<KanbanTask>> fetchTasks(String projectId) async {
    // We select tasks and use Supabase nested selects to fetch relations
    final response = await _client.from('kanban_tasks').select('''
          *,
          task_assignees(*),
          task_labels(*),
          task_checklist_items(*),
          task_attachments(*),
          task_comments(*, profiles!user_id(full_name, avatar_url))
        ''').eq('project_id', projectId).order('position', ascending: true);

    return (response as List)
        .map((x) => KanbanTask.fromMap(Map<String, dynamic>.from(x)))
        .toList();
  }

  Future<KanbanTask> fetchTask(String taskId) async {
    final response = await _client.from('kanban_tasks').select('''
          *,
          task_assignees(*),
          task_labels(*),
          task_checklist_items(*),
          task_attachments(*),
          task_comments(*, profiles!user_id(full_name, avatar_url))
        ''').eq('id', taskId).single();

    return KanbanTask.fromMap(Map<String, dynamic>.from(response));
  }

  Future<KanbanTask> createTask({
    required String projectId,
    required String columnId,
    required String title,
    String? description,
    required TaskPriority priority,
    DateTime? dueDate,
    required double position,
  }) async {
    final response = await _client
        .from('kanban_tasks')
        .insert({
          'project_id': projectId,
          'column_id': columnId,
          'title': title,
          'description': description,
          'priority': priority.name,
          'due_date': dueDate?.toIso8601String(),
          'position': position,
          'created_by': currentUserId,
        })
        .select()
        .single();

    final task = KanbanTask.fromMap(Map<String, dynamic>.from(response));
    await logActivity(task.id, projectId, 'created', {'title': title});
    return task;
  }

  Future<void> updateTaskPosition({
    required String taskId,
    required String columnId,
    required double position,
    required String projectId,
  }) async {
    // Fetch the task first to log previous column
    final oldTask = await _client.from('kanban_tasks').select('column_id').eq('id', taskId).single();

    await _client
        .from('kanban_tasks')
        .update({
          'column_id': columnId,
          'position': position,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', taskId);

    if (oldTask['column_id'] != columnId) {
      await logActivity(taskId, projectId, 'moved', {
        'from_column': oldTask['column_id'],
        'to_column': columnId,
      });
    }
  }

  Future<void> updateTaskDetails({
    required String taskId,
    required String title,
    String? description,
    required TaskPriority priority,
    DateTime? dueDate,
    required String projectId,
  }) async {
    await _client
        .from('kanban_tasks')
        .update({
          'title': title,
          'description': description,
          'priority': priority.name,
          'due_date': dueDate?.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', taskId);

    await logActivity(taskId, projectId, 'details_updated', {'title': title});
  }

  Future<void> deleteTask(String taskId, String projectId) async {
    await _client.from('kanban_tasks').delete().eq('id', taskId);
    await logActivity(taskId, projectId, 'deleted', {});
  }

  // --- Assignees & Labels ---

  Future<void> assignUserToTask(String taskId, String userId, String projectId) async {
    await _client.from('task_assignees').insert({
      'task_id': taskId,
      'user_id': userId,
      'assigned_by': currentUserId,
    });
    await logActivity(taskId, projectId, 'assigned', {'assigned_user_id': userId});
  }

  Future<void> unassignUserFromTask(String taskId, String userId, String projectId) async {
    await _client
        .from('task_assignees')
        .delete()
        .eq('task_id', taskId)
        .eq('user_id', userId);
    await logActivity(taskId, projectId, 'unassigned', {'unassigned_user_id': userId});
  }

  Future<void> addTaskLabel(String taskId, String text, String color, String projectId) async {
    await _client.from('task_labels').insert({
      'task_id': taskId,
      'label_text': text,
      'label_color': color,
    });
    await logActivity(taskId, projectId, 'label_added', {'label': text, 'color': color});
  }

  Future<void> removeTaskLabel(String taskId, String text, String projectId) async {
    await _client
        .from('task_labels')
        .delete()
        .eq('task_id', taskId)
        .eq('label_text', text);
    await logActivity(taskId, projectId, 'label_removed', {'label': text});
  }

  // --- Checklist Sub-Tasks ---

  Future<TaskChecklistItem> addChecklistItem(String taskId, String text, int position, String projectId) async {
    final response = await _client
        .from('task_checklist_items')
        .insert({
          'task_id': taskId,
          'text': text,
          'position': position,
          'created_by': currentUserId,
        })
        .select()
        .single();

    await logActivity(taskId, projectId, 'checklist_added', {'item': text});
    return TaskChecklistItem.fromMap(Map<String, dynamic>.from(response));
  }

  Future<void> updateChecklistItem(String itemId, bool isChecked, String taskId, String projectId) async {
    await _client
        .from('task_checklist_items')
        .update({'is_checked': isChecked})
        .eq('id', itemId);

    await logActivity(taskId, projectId, 'checklist_checked', {
      'item_id': itemId,
      'is_checked': isChecked,
    });
  }

  Future<void> deleteChecklistItem(String itemId, String taskId, String projectId) async {
    await _client.from('task_checklist_items').delete().eq('id', itemId);
    await logActivity(taskId, projectId, 'checklist_removed', {'item_id': itemId});
  }

  // --- Attachments ---

  Future<TaskAttachment> addTaskAttachment({
    required String taskId,
    required AttachmentType type,
    required String fileName,
    String? fileUrl,
    String? resourceId,
    int? fileSizeBytes,
    int? durationSeconds,
    required String projectId,
  }) async {
    String storageType;
    switch (type) {
      case AttachmentType.resourceRef: storageType = 'resource_ref'; break;
      case AttachmentType.directUpload: storageType = 'direct_upload'; break;
      case AttachmentType.voiceNote: storageType = 'voice_note'; break;
    }

    final response = await _client
        .from('task_attachments')
        .insert({
          'task_id': taskId,
          'attachment_type': storageType,
          'file_name': fileName,
          'file_url': fileUrl,
          'resource_id': resourceId,
          'file_size_bytes': fileSizeBytes,
          'duration_seconds': durationSeconds,
          'uploaded_by': currentUserId,
        })
        .select()
        .single();

    await logActivity(taskId, projectId, 'attachment_added', {
      'file_name': fileName,
      'type': storageType,
    });

    return TaskAttachment.fromMap(Map<String, dynamic>.from(response));
  }

  Future<void> deleteTaskAttachment(String attachmentId, String taskId, String projectId) async {
    await _client.from('task_attachments').delete().eq('id', attachmentId);
    await logActivity(taskId, projectId, 'attachment_removed', {'attachment_id': attachmentId});
  }

  // --- Comments ---

  Future<TaskComment> addTaskComment(String taskId, String content, List<String> mentions, String projectId) async {
    final response = await _client
        .from('task_comments')
        .insert({
          'task_id': taskId,
          'user_id': currentUserId,
          'content': content,
          'mentions': mentions,
        })
        .select('*, profiles!user_id(full_name, avatar_url)')
        .single();

    await logActivity(taskId, projectId, 'commented', {'comment_length': content.length});
    return TaskComment.fromMap(Map<String, dynamic>.from(response));
  }

  Future<void> deleteTaskComment(String commentId) async {
    await _client
        .from('task_comments')
        .update({'is_deleted': true})
        .eq('id', commentId);
  }

  // --- Activity Logger helper ---

  Future<void> logActivity(String taskId, String projectId, String actionType, Map<String, dynamic> payload) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      await _client.from('task_activity_log').insert({
        'task_id': taskId,
        'project_id': projectId,
        'actor_id': userId,
        'action_type': actionType,
        'action_payload': payload,
      });
    } catch (_) {
      // Non-blocking logger fails
    }
  }

  Future<List<TaskActivityLog>> fetchActivityLog(String projectId) async {
    final response = await _client
        .from('task_activity_log')
        .select('*, profiles!actor_id(full_name, avatar_url)')
        .eq('project_id', projectId)
        .order('created_at', ascending: false)
        .limit(50);

    return (response as List)
        .map((x) => TaskActivityLog.fromMap(Map<String, dynamic>.from(x)))
        .toList();
  }
}
