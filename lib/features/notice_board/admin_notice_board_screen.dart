import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'notice_model.dart';
import 'notice_service.dart';

class AdminNoticeBoardScreen extends StatefulWidget {
  const AdminNoticeBoardScreen({super.key});

  @override
  State<AdminNoticeBoardScreen> createState() => _AdminNoticeBoardScreenState();
}

class _AdminNoticeBoardScreenState extends State<AdminNoticeBoardScreen> {
  final _service = NoticeService();

  static const _teal = Color(0xFF2DD4BF);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFEF4444);
  static const _bg = Color(0xFFF4F8FF);

  bool _showForm = false;
  bool _submitting = false;

  // Edit state
  String? _editingId;
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  NoticePriority _priority = NoticePriority.normal;
  Uint8List? _pickedBytes;
  String? _pickedFileName;
  Set<String> _selectedRoles = {'student', 'faculty', 'admin'};
  Set<int> _selectedSemesters = {};

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  void _openCreateForm() {
    _editingId = null;
    _titleCtrl.clear();
    _contentCtrl.clear();
    _priority = NoticePriority.normal;
    _pickedBytes = null;
    _pickedFileName = null;
    _selectedRoles = {'student', 'faculty', 'admin'};
    _selectedSemesters = {};
    setState(() => _showForm = true);
  }

  void _openEditForm(NoticeModel notice) {
    _editingId = notice.id;
    _titleCtrl.text = notice.title;
    _contentCtrl.text = notice.content;
    _priority = notice.priority;
    _pickedBytes = null;
    _pickedFileName = null;
    _selectedRoles = notice.targetRoles.toSet();
    _selectedSemesters = notice.targetSemesters.toSet();
    setState(() => _showForm = true);
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _pickedBytes = file.bytes;
            _pickedFileName = file.name;
          });
          _snack('File selected: ${file.name}');
        }
      }
    } catch (e) {
      _snack('Error picking file: $e');
    }
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty || content.isEmpty) {
      _snack('Title and content are required.');
      return;
    }
    setState(() => _submitting = true);
    try {
      if (_editingId != null) {
        await _service.updateNotice(
          id: _editingId!,
          title: title,
          content: content,
          priority: _priority,
        );
        _snack('Notice updated.');
      } else {
        await _service.createNotice(
          title: title,
          content: content,
          priority: _priority,
          attachmentBytes: _pickedBytes,
          attachmentFileName: _pickedFileName,
          targetRoles: _selectedRoles.toList(),
          targetSemesters: _selectedSemesters.toList(),
        );
        _snack('Notice created and push notification sent.');
      }
      setState(() => _showForm = false);
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Notice'),
        content: const Text('Are you sure you want to delete this notice?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteNotice(id);
      _snack('Notice deleted.');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Color _priorityColor(NoticePriority p) => switch (p) {
        NoticePriority.urgent => _red,
        NoticePriority.important => _amber,
        NoticePriority.normal => const Color(0xFF64748B),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Manage Campus Notices',
          style: TextStyle(
              color: Color(0xFF0F172A), fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _teal),
              onPressed: _openCreateForm,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Notice'),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF8FBFF), Color(0xFFEAF6FF)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (_showForm) ...[
                  _buildForm(),
                  const SizedBox(height: 20),
                ],
                StreamBuilder<List<NoticeModel>>(
                  stream: _service.watchAllNotices(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    final notices = snapshot.data ?? [];
                    if (notices.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Text('No notices yet. Create one above.'),
                        ),
                      );
                    }
                    return Column(
                      children: notices
                          .map((n) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _AdminNoticeCard(
                                  notice: n,
                                  priorityColor: _priorityColor(n.priority),
                                  onEdit: () => _openEditForm(n),
                                  onDelete: () => _delete(n.id),
                                ),
                              ))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _editingId != null ? 'Edit Notice' : 'Create New Notice',
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 14),
          _label('Title'),
          const SizedBox(height: 6),
          TextField(
            controller: _titleCtrl,
            decoration: _inputDecoration('Enter notice title'),
          ),
          const SizedBox(height: 12),
          _label('Content'),
          const SizedBox(height: 6),
          TextField(
            controller: _contentCtrl,
            maxLines: 4,
            decoration: _inputDecoration('Enter notice content'),
          ),
          const SizedBox(height: 12),
          _label('Priority'),
          const SizedBox(height: 6),
          DropdownButtonFormField<NoticePriority>(
            initialValue: _priority,
            decoration: _inputDecoration(null),
            items: NoticePriority.values
                .map((p) => DropdownMenuItem(
                    value: p, child: Text(p.label)))
                .toList(),
            onChanged: (v) => setState(() => _priority = v!),
          ),
          if (_editingId == null) ...[
            const SizedBox(height: 12),
            _label('Image or PDF (Optional)'),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.attach_file),
              label: Text(_pickedFileName ?? 'Choose File'),
            ),
          ],
          const SizedBox(height: 12),
          _label('Send To'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Students'),
                selected: _selectedRoles.contains('student'),
                onSelected: (v) => setState(() {
                  if (v) {
                    _selectedRoles.add('student');
                  } else {
                    _selectedRoles.remove('student');
                  }
                }),
              ),
              FilterChip(
                label: const Text('Faculty'),
                selected: _selectedRoles.contains('faculty'),
                onSelected: (v) => setState(() {
                  if (v) {
                    _selectedRoles.add('faculty');
                  } else {
                    _selectedRoles.remove('faculty');
                  }
                }),
              ),
              FilterChip(
                label: const Text('Admins'),
                selected: _selectedRoles.contains('admin'),
                onSelected: (v) => setState(() {
                  if (v) {
                    _selectedRoles.add('admin');
                  } else {
                    _selectedRoles.remove('admin');
                  }
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _label('Specific Semesters (Leave empty for all)'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List.generate(12, (i) {
              final sem = i + 1;
              return FilterChip(
                label: Text('Sem $sem'),
                selected: _selectedSemesters.contains(sem),
                onSelected: (v) => setState(() {
                  if (v) {
                    _selectedSemesters.add(sem);
                  } else {
                    _selectedSemesters.remove(sem);
                  }
                }),
              );
            }),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _teal),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(_editingId != null
                        ? 'Update Notice'
                        : 'Create Notice'),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () => setState(() => _showForm = false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontWeight: FontWeight.w700, color: Color(0xFF334155)));

  InputDecoration _inputDecoration(String? hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF2DD4BF))),
      );
}

class _AdminNoticeCard extends StatelessWidget {
  const _AdminNoticeCard({
    required this.notice,
    required this.priorityColor,
    required this.onEdit,
    required this.onDelete,
  });

  final NoticeModel notice;
  final Color priorityColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notice.title.toUpperCase(),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A)),
                          ),
                        ),
                        if (notice.priority != NoticePriority.normal)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: priorityColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              notice.priority.label,
                              style: TextStyle(
                                  color: priorityColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notice.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.grey.shade700, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: Color(0xFF4F9EFF), size: 20),
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Color(0xFFEF4444), size: 20),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
            ],
          ),
          if (notice.attachmentUrl != null && notice.attachmentUrl!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _AttachmentChip(
              type: notice.attachmentType,
              url: notice.attachmentUrl!,
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Posted on ${_formatDate(notice.createdAt)}',
            style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11.5,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.month}/${dt.day}/${dt.year}';
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.type, required this.url});

  final String? type;
  final String url;

  @override
  Widget build(BuildContext context) {
    final isPdf = type == 'pdf';
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isPdf
              ? const Color(0xFFFEE2E2)
              : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPdf ? Icons.picture_as_pdf : Icons.image_outlined,
              color: isPdf
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF4F9EFF),
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              isPdf ? 'PDF Attachment' : 'Image Attachment',
              style: TextStyle(
                color: isPdf
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF4F9EFF),
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.82),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F9EFF).withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
