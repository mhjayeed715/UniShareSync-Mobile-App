import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unisharesync_mobile_app/data/models/kanban_model.dart';
import 'package:unisharesync_mobile_app/features/projects/components/task_detail_sheet.dart';
import 'package:unisharesync_mobile_app/providers/kanban_providers.dart';

class KanbanBoardScreen extends ConsumerStatefulWidget {
  const KanbanBoardScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<KanbanBoardScreen> createState() => _KanbanBoardScreenState();
}

class _KanbanBoardScreenState extends ConsumerState<KanbanBoardScreen> {
  @override
  Widget build(BuildContext context) {
    final kanbanState = ref.watch(kanbanBoardProvider(widget.projectId));
    final notifier = ref.read(kanbanBoardProvider(widget.projectId).notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Task Kanban',
          style: TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF0F172A)),
            onPressed: () => _showAddColumnDialog(context, notifier),
          )
        ],
      ),
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: 200,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4F9EFF).withOpacity(0.08),
              ),
            ),
          ),

          kanbanState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : kanbanState.errorMessage != null
                  ? Center(child: Text('Error: ${kanbanState.errorMessage}', style: const TextStyle(color: Colors.redAccent)))
                  : _buildBoard(kanbanState, notifier),
        ],
      ),
    );
  }

  Widget _buildBoard(KanbanBoardState state, KanbanBoardNotifier notifier) {
    if (state.columns.isEmpty) {
      return const Center(child: Text('No columns. Create one to begin!', style: TextStyle(color: Color(0xFF64748B))));
    }

    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return DefaultTabController(
        length: state.columns.length,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              labelColor: const Color(0xFFF97316),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFFF97316),
              dividerColor: Colors.transparent,
              tabs: state.columns.map((col) {
                final count = state.tasks.where((t) => t.columnId == col.id).length;
                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(col.title),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            Expanded(
              child: TabBarView(
                children: state.columns.map((col) {
                  final colTasks = state.tasks.where((t) => t.columnId == col.id).toList();
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildColumnLane(col, colTasks, notifier, width: null),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: state.columns.length,
      itemBuilder: (context, index) {
        final col = state.columns[index];
        final colTasks = state.tasks.where((t) => t.columnId == col.id).toList();

        return _buildColumnLane(col, colTasks, notifier, width: 300);
      },
    );
  }

  Widget _buildColumnLane(KanbanColumn col, List<KanbanTask> tasks, KanbanBoardNotifier notifier, {double? width}) {
    return DragTarget<KanbanTask>(
      onWillAcceptWithDetails: (details) => details.data.columnId != col.id,
      onAcceptWithDetails: (details) {
        // Move task to this column at the bottom (position = count + 1)
        final newPos = (tasks.isEmpty ? 1.0 : tasks.last.position + 1.0);
        notifier.moveTaskOptimistic(
          taskId: details.data.id,
          targetColumnId: col.id,
          newPosition: newPos,
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isOver = candidateData.isNotEmpty;
        return Container(
          width: width,
          margin: EdgeInsets.only(right: width == null ? 0 : 16),
          decoration: BoxDecoration(
            color: isOver ? const Color(0xFFE2E8F0) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column title
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      col.title,
                      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${tasks.length}',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              // Task List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: tasks.length,
                  itemBuilder: (context, idx) {
                    final task = tasks[idx];
                    return _buildTaskDraggableCard(task);
                  },
                ),
              ),

              // Add Task Button
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextButton.icon(
                  icon: const Icon(Icons.add, color: Color(0xFFF97316)),
                  label: const Text('Add Task', style: TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold)),
                  onPressed: () => _showAddTaskDialog(context, col.id, tasks.length, notifier),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskDraggableCard(KanbanTask task) {
    return LongPressDraggable<KanbanTask>(
      delay: const Duration(milliseconds: 100),
      data: task,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 276,
          child: _buildTaskCardContent(task, isDragging: true),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _buildTaskCardContent(task),
      ),
      child: _buildTaskCardContent(task),
    );
  }

  Widget _buildTaskCardContent(KanbanTask task, {bool isDragging = false}) {
    Color priorityColor;
    switch (task.priority) {
      case TaskPriority.critical: priorityColor = Colors.redAccent; break;
      case TaskPriority.high: priorityColor = Colors.orangeAccent; break;
      case TaskPriority.medium: priorityColor = Colors.blueAccent; break;
      case TaskPriority.low: priorityColor = Colors.grey; break;
    }

    return Card(
      color: isDragging ? const Color(0xFFF1F5F9) : Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: task.isOverdue
              ? Colors.redAccent.withOpacity(0.5)
              : Colors.grey.shade200,
          width: task.isOverdue ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => TaskDetailSheet(taskId: task.id, projectId: widget.projectId),
          ).then((_) => ref.refresh(kanbanBoardProvider(widget.projectId)));
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: priorityColor),
                  ),
                  if (task.dueDate != null)
                    Text(
                      'Due ${task.dueDate!.day}/${task.dueDate!.month}',
                      style: TextStyle(
                        color: task.isOverdue ? Colors.redAccent : Colors.grey.shade500,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                task.title,
                style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14),
              ),
              if (task.description != null && task.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  task.description!,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (task.checklist.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.check_box_outlined, color: Colors.grey.shade500, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${(task.checklistCompletionRatio * task.checklist.length).toInt()}/${task.checklist.length}',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                    ),
                  ],
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  void _showAddColumnDialog(BuildContext context, KanbanBoardNotifier notifier) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Column'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Column Title'),
        ),
        actions: [
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
          TextButton(
            child: const Text('Create'),
            onPressed: () {
              final title = controller.text.trim();
              if (title.isNotEmpty) {
                // Set position to size + 1
                final columnsCount = ref.read(kanbanBoardProvider(widget.projectId)).columns.length;
                ref.read(kanbanServiceProvider).createColumn(widget.projectId, title, columnsCount + 1).then((_) {
                  ref.refresh(kanbanBoardProvider(widget.projectId));
                  Navigator.pop(context);
                });
              }
            },
          )
        ],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, String columnId, int tasksCount, KanbanBoardNotifier notifier) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    TaskPriority priority = TaskPriority.medium;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Task Title'),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Priority:'),
                    DropdownButton<TaskPriority>(
                      value: priority,
                      items: TaskPriority.values.map((p) {
                        return DropdownMenuItem(value: p, child: Text(p.name.toUpperCase()));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => priority = val);
                        }
                      },
                    )
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(ctx)),
            TextButton(
              child: const Text('Create'),
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isNotEmpty) {
                  ref
                      .read(kanbanServiceProvider)
                      .createTask(
                        projectId: widget.projectId,
                        columnId: columnId,
                        title: title,
                        description: descController.text.trim(),
                        priority: priority,
                        position: tasksCount + 1.0,
                      )
                      .then((_) {
                    ref.refresh(kanbanBoardProvider(widget.projectId));
                    Navigator.pop(ctx);
                  });
                }
              },
            )
          ],
        ),
      ),
    );
  }
}
