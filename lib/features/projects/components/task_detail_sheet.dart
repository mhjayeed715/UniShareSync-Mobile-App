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
  
  KanbanTask? _task;
  List<KanbanColumn> _columns = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTaskDetails();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _checklistController.dispose();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_task == null) {
      return const Center(child: Text('Task details not found.', style: TextStyle(color: Color(0xFF0F172A))));
    }

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
            // Title
            Text(
              _task!.title,
              style: const TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            // Description
            if (_task!.description != null && _task!.description!.isNotEmpty) ...[
              Text(
                _task!.description!,
                style: const TextStyle(color: Color(0xFF475569), fontSize: 14),
              ),
              const SizedBox(height: 16),
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
                        value: _task!.columnId,
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
                          if (newColId != null && newColId != _task!.columnId) {
                            final tasksInNewCol = (await ref.read(kanbanServiceProvider).fetchTasks(widget.projectId)).where((t) => t.columnId == newColId).toList();
                            final newPos = tasksInNewCol.isEmpty ? 1.0 : tasksInNewCol.last.position + 1.0;
                            await ref.read(kanbanServiceProvider).updateTaskPosition(
                              taskId: _task!.id,
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
                        value: _task!.priority,
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
                          if (newPriority != null && newPriority != _task!.priority) {
                            await ref.read(kanbanServiceProvider).updateTaskDetails(
                              taskId: _task!.id,
                              title: _task!.title,
                              description: _task!.description,
                              priority: newPriority,
                              dueDate: _task!.dueDate,
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
            _buildChecklistBuilder(),
            const SizedBox(height: 20),

            // Comments Board
            _buildSectionHeader('Comments'),
            _buildCommentsDeck(),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistBuilder() {
    return Column(
      children: [
        ..._task!.checklist.map((item) {
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
                        _task!.checklist.length + 1,
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



  Widget _buildCommentsDeck() {
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
        if (_task!.comments.isEmpty)
          const Text('No comments posted yet.', style: TextStyle(color: Colors.black38))
        else
          ..._task!.comments.map((comment) {
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
