import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:unisharesync_mobile_app/data/models/resource_item.dart';
import 'package:unisharesync_mobile_app/features/resources/resources_tab_view.dart'
    show showResourceUploadSheet;
import 'package:unisharesync_mobile_app/services/resource_service.dart';

class AdminResourcesScreen extends StatefulWidget {
  const AdminResourcesScreen({super.key});

  @override
  State<AdminResourcesScreen> createState() => _AdminResourcesScreenState();
}

class _AdminResourcesScreenState extends State<AdminResourcesScreen> {
  final ResourceService _service = ResourceService();

  List<ResourceItem> _resources = [];
  List<CourseOption> _courses = [];
  bool _loading = true;
  String? _error;

  ResourceApprovalStatus? _statusFilter;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  static const _blue = Color(0xFF4F9EFF);
  static const _bg = Color(0xFFF4F8FF);

  List<ResourceItem> get _filtered {
    return _resources.where((r) {
      final matchStatus =
          _statusFilter == null || r.approvalStatus == _statusFilter;
      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          r.title.toLowerCase().contains(q) ||
          r.courseCode.toLowerCase().contains(q) ||
          r.uploaderName.toLowerCase().contains(q);
      return matchStatus && matchSearch;
    }).toList();
  }

  int get _pendingCount =>
      _resources.where((r) => r.approvalStatus == ResourceApprovalStatus.pending).length;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.searchResources(limit: 200),
        _service.fetchCourseOptions(),
      ]);
      if (!mounted) return;
      setState(() {
        _resources = results[0] as List<ResourceItem>;
        _courses = results[1] as List<CourseOption>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _openUpload() async {
    final uploaded = await showResourceUploadSheet(
      context,
      preloadedCourses: _courses,
    );
    if (!mounted || uploaded == null) return;
    _snack('Resource uploaded successfully.');
    _load();
  }

  Future<void> _openEdit(ResourceItem item) async {
    final updated = await showResourceUploadSheet(
      context,
      preloadedCourses: _courses,
      existingResource: item,
    );
    if (!mounted || updated == null) return;
    _snack('Resource updated successfully.');
    _load();
  }

  Future<void> _delete(ResourceItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Resource?'),
        content: Text('This will permanently remove "${item.title}".'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _service.deleteResource(resourceId: item.id);
      if (!mounted) return;
      _snack('Resource deleted.');
      _load();
    } catch (e) {
      if (!mounted) return;
      _snack('Delete failed: $e');
    }
  }

  Future<void> _approve(ResourceItem item) async {
    try {
      await _service.reviewResource(resourceId: item.id, approve: true);
      if (!mounted) return;
      _snack('Resource approved.');
      _load();
    } catch (e) {
      if (!mounted) return;
      _snack('Approval failed: $e');
    }
  }

  Future<void> _reject(ResourceItem item) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Resource'),
        content: TextField(
          controller: ctrl,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Rejection reason (required)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(context, ctrl.text.trim());
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (reason == null || reason.isEmpty) return;
    try {
      await _service.reviewResource(
          resourceId: item.id, approve: false, rejectionReason: reason);
      if (!mounted) return;
      _snack('Resource rejected.');
      _load();
    } catch (e) {
      if (!mounted) return;
      _snack('Rejection failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Resource Management',
          style: TextStyle(
              color: Color(0xFF0F172A), fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded,
                  color: Color(0xFF0F172A))),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openUpload,
        backgroundColor: _blue,
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('Add Resource'),
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
          Column(
            children: [
              _buildTopBar(),
              if (!_loading && _error == null) _buildPendingBanner(),
              Expanded(child: _buildBody()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search by title, course, uploader…',
              hintStyle:
                  TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon:
                  Icon(Icons.search_rounded, color: Colors.grey.shade400),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: Colors.grey.shade400),
                      onPressed: () => _searchCtrl.clear())
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _blue, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                    label: 'All',
                    count: _resources.length,
                    selected: _statusFilter == null,
                    color: const Color(0xFF64748B),
                    onTap: () => setState(() => _statusFilter = null)),
                const SizedBox(width: 6),
                _FilterChip(
                    label: 'Pending',
                    count: _resources
                        .where((r) =>
                            r.approvalStatus ==
                            ResourceApprovalStatus.pending)
                        .length,
                    selected:
                        _statusFilter == ResourceApprovalStatus.pending,
                    color: const Color(0xFFD97706),
                    onTap: () => setState(() =>
                        _statusFilter = ResourceApprovalStatus.pending)),
                const SizedBox(width: 6),
                _FilterChip(
                    label: 'Approved',
                    count: _resources
                        .where((r) =>
                            r.approvalStatus ==
                            ResourceApprovalStatus.approved)
                        .length,
                    selected:
                        _statusFilter == ResourceApprovalStatus.approved,
                    color: const Color(0xFF059669),
                    onTap: () => setState(() =>
                        _statusFilter = ResourceApprovalStatus.approved)),
                const SizedBox(width: 6),
                _FilterChip(
                    label: 'Rejected',
                    count: _resources
                        .where((r) =>
                            r.approvalStatus ==
                            ResourceApprovalStatus.rejected)
                        .length,
                    selected:
                        _statusFilter == ResourceApprovalStatus.rejected,
                    color: const Color(0xFFDC2626),
                    onTap: () => setState(() =>
                        _statusFilter = ResourceApprovalStatus.rejected)),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildPendingBanner() {
    if (_pendingCount == 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.pending_actions_rounded,
              color: Color(0xFFD97706), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$_pendingCount resource${_pendingCount == 1 ? '' : 's'} pending your review',
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () =>
                setState(() => _statusFilter = ResourceApprovalStatus.pending),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD97706),
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text('Review'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 34, color: Color(0xFF64748B)),
            const SizedBox(height: 10),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_rounded,
                size: 36, color: Color(0xFF64748B)),
            const SizedBox(height: 10),
            const Text('No resources found',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A))),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _openUpload,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Upload Resource'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 120),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _AdminResourceCard(
          item: items[i],
          onEdit: () => _openEdit(items[i]),
          onDelete: () => _delete(items[i]),
          onApprove: () => _approve(items[i]),
          onReject: () => _reject(items[i]),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.grey.shade300),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _AdminResourceCard extends StatelessWidget {
  const _AdminResourceCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onApprove,
    required this.onReject,
  });

  final ResourceItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F9EFF).withOpacity(0.07),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _fileColor(item.fileType).withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_fileIcon(item.fileType),
                        color: _fileColor(item.fileType)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${item.courseCode} • Sem ${item.semesterNo} • ${item.resourceType.label}',
                          style: TextStyle(
                              fontSize: 12.5, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'By ${item.uploaderName} • ${item.uploaderRole.displayName}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded,
                        color: Color(0xFF64748B)),
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'edit', child: Text('Edit Resource')),
                      PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete Resource',
                              style: TextStyle(color: Colors.redAccent))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _StatusBadge(status: item.approvalStatus),
                  const SizedBox(width: 8),
                  Icon(Icons.download_rounded,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 3),
                  Text('${item.totalDownloads}',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              if (item.approvalStatus == ResourceApprovalStatus.rejected &&
                  (item.rejectionReason ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text(
                    'Reason: ${item.rejectionReason}',
                    style: const TextStyle(
                        color: Color(0xFF991B1B),
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                  ),
                ),
              ],
              if (item.approvalStatus == ResourceApprovalStatus.pending) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB91C1C),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Approve'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _fileColor(ResourceFileType t) {
    switch (t) {
      case ResourceFileType.pdf:
        return const Color(0xFFDC2626);
      case ResourceFileType.docx:
        return const Color(0xFF1D4ED8);
      case ResourceFileType.ppt:
        return const Color(0xFFEA580C);
      case ResourceFileType.image:
        return const Color(0xFF0F766E);
    }
  }

  IconData _fileIcon(ResourceFileType t) {
    switch (t) {
      case ResourceFileType.pdf:
        return Icons.picture_as_pdf_rounded;
      case ResourceFileType.docx:
        return Icons.description_rounded;
      case ResourceFileType.ppt:
        return Icons.slideshow_rounded;
      case ResourceFileType.image:
        return Icons.image_rounded;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final ResourceApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ResourceApprovalStatus.pending => const Color(0xFFD97706),
      ResourceApprovalStatus.approved => const Color(0xFF059669),
      ResourceApprovalStatus.rejected => const Color(0xFFDC2626),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
            fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
