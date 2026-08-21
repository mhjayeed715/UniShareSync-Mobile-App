import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/data/models/kanban_model.dart';
import 'package:unisharesync_mobile_app/services/kanban_service.dart';

final kanbanServiceProvider = Provider<KanbanService>((ref) {
  return KanbanService();
});

class KanbanBoardState {
  const KanbanBoardState({
    required this.columns,
    required this.tasks,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<KanbanColumn> columns;
  final List<KanbanTask> tasks;
  final bool isLoading;
  final String? errorMessage;

  KanbanBoardState copyWith({
    List<KanbanColumn>? columns,
    List<KanbanTask>? tasks,
    bool? isLoading,
    String? errorMessage,
  }) {
    return KanbanBoardState(
      columns: columns ?? this.columns,
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class KanbanBoardNotifier extends StateNotifier<KanbanBoardState> {
  KanbanBoardNotifier(this._service, String projectId)
      : _projectId = projectId,
        super(const KanbanBoardState(columns: [], tasks: [], isLoading: true)) {
    _init();
  }

  final KanbanService _service;
  final String _projectId;
  RealtimeChannel? _channel;

  Future<void> _init() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final cols = await _service.fetchColumns(_projectId);
      final tks = await _service.fetchTasks(_projectId);

      state = state.copyWith(columns: cols, tasks: tks, isLoading: false);
      _subscribeToRealtime();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void _subscribeToRealtime() {
    final client = Supabase.instance.client;
    
    // Subscribing to postgres changes on kanban_tasks and kanban_columns without project_id filter to allow DELETE events to be captured (as delete oldRecord lacks project_id)
    _channel = client.channel('project_kanban_$_projectId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'kanban_tasks',
        callback: (payload) {
          _handleRealtimeUpdate(payload);
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'kanban_columns',
        callback: (payload) {
          _handleColumnRealtimeUpdate(payload);
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'task_comments',
        callback: (payload) {
          _handleSubTableRealtimeUpdate(payload);
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'task_checklist_items',
        callback: (payload) {
          _handleSubTableRealtimeUpdate(payload);
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'task_assignees',
        callback: (payload) {
          _handleSubTableRealtimeUpdate(payload);
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'task_labels',
        callback: (payload) {
          _handleSubTableRealtimeUpdate(payload);
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'task_attachments',
        callback: (payload) {
          _handleSubTableRealtimeUpdate(payload);
        },
      );
    
    _channel?.subscribe();
  }

  Future<void> _handleRealtimeUpdate(dynamic payload) async {
    final eventType = payload.eventType;
    final record = payload.newRecord;
    final oldRecord = payload.oldRecord;

    if (eventType == PostgresChangeEvent.insert && record.isNotEmpty) {
      final newTask = KanbanTask.fromMap(record);
      if (newTask.projectId != _projectId) return;
      
      // Avoid inserting duplicates
      if (!state.tasks.any((t) => t.id == newTask.id)) {
        state = state.copyWith(tasks: [...state.tasks, newTask]);
      }
    } else if (eventType == PostgresChangeEvent.update && record.isNotEmpty) {
      final updatedTask = KanbanTask.fromMap(record);
      if (updatedTask.projectId != _projectId) return;

      state = state.copyWith(
        tasks: state.tasks.map((t) {
          if (t.id == updatedTask.id) {
            // Keep relations that aren't in payload unless we reload
            return KanbanTask(
              id: updatedTask.id,
              projectId: updatedTask.projectId,
              columnId: updatedTask.columnId,
              title: updatedTask.title,
              description: updatedTask.description,
              priority: updatedTask.priority,
              dueDate: updatedTask.dueDate,
              position: updatedTask.position,
              isOverdue: updatedTask.isOverdue,
              createdBy: updatedTask.createdBy,
              createdAt: updatedTask.createdAt,
              updatedAt: updatedTask.updatedAt,
              assignees: t.assignees,
              labels: t.labels,
              checklist: t.checklist,
              attachments: t.attachments,
              comments: t.comments,
            );
          }
          return t;
        }).toList(),
      );
      // Reload relations in background using single task fetch to ensure correct joins
      _reloadTaskJoins(updatedTask.id);
    } else if (eventType == PostgresChangeEvent.delete && oldRecord.isNotEmpty) {
      final deletedId = oldRecord['id'] as String;
      if (state.tasks.any((t) => t.id == deletedId)) {
        state = state.copyWith(
          tasks: state.tasks.where((t) => t.id != deletedId).toList(),
        );
      }
    }
  }

  Future<void> _reloadTaskJoins(String taskId) async {
    try {
      final freshTask = await _service.fetchTask(taskId);
      if (freshTask.projectId == _projectId) {
        state = state.copyWith(
          tasks: state.tasks.map((t) => t.id == taskId ? freshTask : t).toList(),
        );
      }
    } catch (_) {}
  }

  Future<void> _handleColumnRealtimeUpdate(dynamic payload) async {
    final eventType = payload.eventType;
    final record = payload.newRecord;
    final oldRecord = payload.oldRecord;

    if (eventType == PostgresChangeEvent.insert && record.isNotEmpty) {
      final newCol = KanbanColumn.fromMap(record);
      if (newCol.projectId != _projectId) return;

      if (!state.columns.any((c) => c.id == newCol.id)) {
        final updatedCols = [...state.columns, newCol]..sort((a, b) => a.position.compareTo(b.position));
        state = state.copyWith(columns: updatedCols);
      }
    } else if (eventType == PostgresChangeEvent.update && record.isNotEmpty) {
      final updatedCol = KanbanColumn.fromMap(record);
      if (updatedCol.projectId != _projectId) return;

      final updatedCols = state.columns.map((c) => c.id == updatedCol.id ? updatedCol : c).toList()
        ..sort((a, b) => a.position.compareTo(b.position));
      state = state.copyWith(columns: updatedCols);
    } else if (eventType == PostgresChangeEvent.delete && oldRecord.isNotEmpty) {
      final deletedId = oldRecord['id'] as String;
      if (state.columns.any((c) => c.id == deletedId)) {
        state = state.copyWith(
          columns: state.columns.where((c) => c.id != deletedId).toList(),
          tasks: state.tasks.where((t) => t.columnId != deletedId).toList(),
        );
      }
    }
  }

  void _handleSubTableRealtimeUpdate(dynamic payload) {
    final record = payload.newRecord;
    final oldRecord = payload.oldRecord;
    final taskId = (record.isNotEmpty ? record['task_id'] : oldRecord['task_id']) as String?;
    if (taskId != null) {
      _reloadTaskJoins(taskId);
    }
  }

  // --- Optimistic Local UI Moves ---

  Future<void> moveTaskOptimistic({
    required String taskId,
    required String targetColumnId,
    required double newPosition,
  }) async {
    // 1. Snapshot old state in case we need to roll back
    final previousTasks = state.tasks;

    // 2. Perform optimistic state change on local list
    state = state.copyWith(
      tasks: state.tasks.map((t) {
        if (t.id == taskId) {
          return KanbanTask(
            id: t.id,
            projectId: t.projectId,
            columnId: targetColumnId,
            title: t.title,
            description: t.description,
            priority: t.priority,
            dueDate: t.dueDate,
            position: newPosition,
            isOverdue: t.isOverdue,
            createdBy: t.createdBy,
            createdAt: t.createdAt,
            updatedAt: DateTime.now(),
            assignees: t.assignees,
            labels: t.labels,
            checklist: t.checklist,
            attachments: t.attachments,
            comments: t.comments,
          );
        }
        return t;
      }).toList()..sort((a, b) => a.position.compareTo(b.position)),
    );

    // 3. Make server call
    try {
      await _service.updateTaskPosition(
        taskId: taskId,
        columnId: targetColumnId,
        position: newPosition,
        projectId: _projectId,
      );
    } catch (e) {
      // Revert if database write fails
      state = state.copyWith(tasks: previousTasks);
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final kanbanBoardProvider = StateNotifierProvider.family<KanbanBoardNotifier, KanbanBoardState, String>((ref, projectId) {
  final service = ref.watch(kanbanServiceProvider);
  return KanbanBoardNotifier(service, projectId);
});
