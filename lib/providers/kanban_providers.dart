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
    
    // Subscribing to postgres changes on kanban_tasks for this project
    _channel = client.channel('project_kanban_$_projectId').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'kanban_tasks',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'project_id',
        value: _projectId,
      ),
      callback: (payload) {
        _handleRealtimeUpdate(payload);
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
      // Avoid inserting duplicates
      if (!state.tasks.any((t) => t.id == newTask.id)) {
        state = state.copyWith(tasks: [...state.tasks, newTask]);
      }
    } else if (eventType == PostgresChangeEvent.update && record.isNotEmpty) {
      final updatedTask = KanbanTask.fromMap(record);
      state = state.copyWith(
        tasks: state.tasks.map((t) {
          if (t.id == updatedTask.id) {
            // Keep relations that aren't in payload unless we reload
            return updatedTask;
          }
          return t;
        }).toList(),
      );
      // Reload relations in background to ensure correct joins
      _reloadTaskJoins(updatedTask.id);
    } else if (eventType == PostgresChangeEvent.delete && oldRecord.isNotEmpty) {
      final deletedId = oldRecord['id'] as String;
      state = state.copyWith(
        tasks: state.tasks.where((t) => t.id != deletedId).toList(),
      );
    }
  }

  Future<void> _reloadTaskJoins(String taskId) async {
    try {
      final updatedTasks = await _service.fetchTasks(_projectId);
      final freshTask = updatedTasks.firstWhere((t) => t.id == taskId);
      state = state.copyWith(
        tasks: state.tasks.map((t) => t.id == taskId ? freshTask : t).toList(),
      );
    } catch (_) {}
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
