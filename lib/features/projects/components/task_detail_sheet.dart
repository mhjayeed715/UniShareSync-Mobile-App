import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unisharesync_mobile_app/data/models/kanban_model.dart';
import 'package:unisharesync_mobile_app/providers/kanban_providers.dart';

class TaskDetailSheet extends ConsumerStatefulWidget {
  const TaskDetailSheet({super.key, required this.taskId, required this.projectId});

  final String taskId;
  final String projectId;

  @override
  ConsumerState<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends ConsumerState<TaskDetailSheet> {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _checklistController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  
  KanbanTask? _task;
  List<KanbanColumn> _columns = [];
  bool _isLoading = true;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadTaskDetails();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _checklistController.dispose();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadTaskDetails() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await ref.read(kanbanServiceProvider).fetchTasks(widget.projectId);
      final match = tasks.firstWhere((t) => t.id == widget.taskId);
      final cols = await ref.read(kanbanServiceProvider).fetchColumns(widget.projectId);
      setState(() {
        _task = match;
        _columns = cols;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTaskDetails() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      await ref.read(kanbanServiceProvider).updateTaskDetails(
        taskId: _task!.id,
        title: title,
        description: _descController.text.trim(),
        priority: _task!.priority,
        dueDate: _task!.dueDate,
        projectId: widget.projectId,
      );
      setState(() => _isEditing = false);
      await _loadTaskDetails();
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _confirmDeleteTask(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task? This action cannot be undone.'),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              setState(() => _isLoading = true);
              try {
                await ref.read(kanbanServiceProvider).deleteTask(_task!.id, widget.projectId);
                if (mounted) {
                  Navigator.pop(context); // Close sheet
                }
              } catch (_) {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kanbanState = ref.watch(kanbanBoardProvider(widget.projectId));
    
    // Find task from provider first for real-time reactivity
    KanbanTask? activeTask;
    try {
      activeTask = kanbanState.tasks.firstWhere((t) => t.id == widget.taskId);
    } catch (_) {
      activeTask = _task;
    }

    if (_isLoading && activeTask == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (activeTask == null) {
      return const Center(child: Text('Task details not found.', style: TextStyle(color: Color(0xFF0F172A))));
    }

    final task = activeTask;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isEditing) ...[
              TextField(
                controller: _titleController,
                style: const TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Task Title',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                style: const TextStyle(color: Color(0xFF475569), fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black12)),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => setState(() => _isEditing = false),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                    onPressed: _saveTaskDetails,
                    child: const Text('Save', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: const TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blueAccent),
                    onPressed: () {
                      _titleController.text = task.title;
                      _descController.text = task.description ?? '';
                      setState(() => _isEditing = true);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _confirmDeleteTask(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (task.description != null && task.description!.isNotEmpty) ...[
                Text(
                  task.description!,
                  style: const TextStyle(color: Color(0xFF475569), fontSize: 14),
                ),
                const SizedBox(height: 16),
              ],
            ],

            // Status & Priority Dropdowns
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      DropdownButton<String>(
                        value: task.columnId,
                        isExpanded: true,
                        style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 14),
                        underline: const SizedBox(),
                        items: _columns.map((c) {
                          return DropdownMenuItem(
                            value: c.id,
                            child: Text(c.title),
                          );
                        }).toList(),
                        onChanged: (newColId) async {
                          if (newColId != null && newColId != task.columnId) {
                            final currentTaskId = task.id;
                            final tasksInNewCol = (await ref.read(kanbanServiceProvider).fetchTasks(widget.projectId)).where((t) => t.columnId == newColId).toList();
                            final newPos = tasksInNewCol.isEmpty ? 1.0 : tasksInNewCol.last.position + 1.0;
                            await ref.read(kanbanServiceProvider).updateTaskPosition(
                              taskId: currentTaskId,
                              columnId: newColId,
                              position: newPos,
                              projectId: widget.projectId,
                            );
                            _loadTaskDetails();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Priority',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      DropdownButton<TaskPriority>(
                        value: task.priority,
                        isExpanded: true,
                        style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 14),
                        underline: const SizedBox(),
                        items: TaskPriority.values.map((p) {
                          return DropdownMenuItem(
                            value: p,
                            child: Text(p.name.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (newPriority) async {
                          if (newPriority != null && newPriority != task.priority) {
                            await ref.read(kanbanServiceProvider).updateTaskDetails(
                              taskId: task.id,
                              title: task.title,
                              description: task.description,
                              priority: newPriority,
                              dueDate: task.dueDate,
                              projectId: widget.projectId,
                            );
                            _loadTaskDetails();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.black12, height: 24),

            // Checklist Section
            _buildSectionHeader('Checklist'),
            _buildChecklistBuilder(task),
            const SizedBox(height: 20),

            // Comments Board
            _buildSectionHeader('Comments'),
            _buildCommentsDeck(task),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistBuilder(KanbanTask activeTask) {
    return Column(
      children: [
        ...activeTask.checklist.map((item) {
          return CheckboxListTile(
            title: Text(item.text, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14)),
            value: item.isChecked,
            activeColor: const Color(0xFF2563EB),
            onChanged: (val) async {
              if (val != null) {
                await ref.read(kanbanServiceProvider).updateChecklistItem(
                      item.id,
                      val,
                      widget.taskId,
                      widget.projectId,
                    );
                _loadTaskDetails();
              }
            },
          );
        }),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _checklistController,
                style: const TextStyle(color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  hintText: 'Add checklist sub-task...',
                  hintStyle: TextStyle(color: Colors.black38),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black12)),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add, color: Color(0xFFF97316)),
              onPressed: () async {
                final txt = _checklistController.text.trim();
                if (txt.isNotEmpty) {
                  await ref.read(kanbanServiceProvider).addChecklistItem(
                        widget.taskId,
                        txt,
                        activeTask.checklist.length + 1,
                        widget.projectId,
                      );
                  _checklistController.clear();
                  _loadTaskDetails();
                }
              },
            )
          ],
        )
      ],
    );
  }



  Widget _buildCommentsDeck(KanbanTask activeTask) {
    return Column(
      children: [
        // Add Comment
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                style: const TextStyle(color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  hintText: 'Post a comment...',
                  hintStyle: TextStyle(color: Colors.black38),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black12)),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Color(0xFF2563EB)),
              onPressed: () async {
                final text = _commentController.text.trim();
                if (text.isNotEmpty) {
                  await ref.read(kanbanServiceProvider).addTaskComment(
                        widget.taskId,
                        text,
                        [],
                        widget.projectId,
                      );
                  _commentController.clear();
                  _loadTaskDetails();
                }
              },
            )
          ],
        ),
        const SizedBox(height: 12),
 
        // Comments List
        if (activeTask.comments.isEmpty)
          const Text('No comments posted yet.', style: TextStyle(color: Colors.black38))
        else
          ...activeTask.comments.map((comment) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF4F9EFF).withOpacity(0.2),
                child: Text(
                  comment.userName.isEmpty ? 'U' : comment.userName[0].toUpperCase(),
                  style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(comment.userName, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(comment.content, style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
            );
          })
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 12.0),
      child: Text(
        title,
        style: const TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }
}
