import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unisharesync_mobile_app/data/models/resource_item.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';
import 'package:unisharesync_mobile_app/services/resource_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ResourcesTabView extends StatefulWidget {
  const ResourcesTabView({
    super.key,
    required this.currentRole,
    required this.isLocalAdmin,
    this.refreshTick = 0,
  });

  final UserRole currentRole;
  final bool isLocalAdmin;
  final int refreshTick;

  @override
  State<ResourcesTabView> createState() => _ResourcesTabViewState();
}

class ResourcesStandaloneScreen extends StatelessWidget {
  const ResourcesStandaloneScreen({
    super.key,
    required this.currentRole,
    required this.isLocalAdmin,
  });

  final UserRole currentRole;
  final bool isLocalAdmin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Resources',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
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
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: ResourcesTabView(
                currentRole: currentRole,
                isLocalAdmin: isLocalAdmin,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourcesTabViewState extends State<ResourcesTabView> {
  final ResourceService _resourceService = ResourceService();
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;
  bool _isLoading = true;
  String? _errorMessage;

  List<CourseOption> _courseOptions = const <CourseOption>[];
  List<ResourceItem> _resources = const <ResourceItem>[];

  int? _selectedSemester;
  String? _selectedCourseCode;
  ResourceFileType? _selectedFileType;
  bool _pendingOnlyForAdmin = false;

  bool get _isAdminView => widget.currentRole == UserRole.admin;

  int get _pendingReviewCount {
    return _resources
        .where((item) => item.approvalStatus == ResourceApprovalStatus.pending)
        .length;
  }

  List<ResourceItem> get _visibleResources {
    if (_isAdminView && _pendingOnlyForAdmin) {
      return _resources
          .where(
            (item) => item.approvalStatus == ResourceApprovalStatus.pending,
          )
          .toList(growable: false);
    }

    return _resources;
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant ResourcesTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      _refreshResources(showLoader: false);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final options = await _resourceService.fetchCourseOptions();

      if (!mounted) {
        return;
      }

      setState(() {
        _courseOptions = options;
      });

      await _refreshResources(showLoader: false);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = '$error';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshResources({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final items = await _resourceService.searchResources(
        query: _searchController.text,
        semesterNo: _selectedSemester,
        courseCode: _selectedCourseCode,
        fileType: _selectedFileType,
        limit: 120,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _resources = items;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = '$error';
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 330), () {
      _refreshResources();
    });
  }

  List<int> get _semesterOptions {
    final values = _courseOptions.map((option) => option.semesterNo).toSet();
    final sorted = values.toList()..sort();
    return sorted;
  }

  List<CourseOption> get _courseOptionsForSelectedSemester {
    if (_selectedSemester == null) {
      return const <CourseOption>[];
    }

    final filtered = _courseOptions
        .where((option) => option.semesterNo == _selectedSemester)
        .toList(growable: false);

    return filtered;
  }

  Future<void> _openUploadSheet() async {
    if (widget.isLocalAdmin) {
      _showMessage(
        'Local admin mode has no active backend user. Sign in with a real admin/faculty/student account to upload.',
      );
      return;
    }

    final uploaded = await showResourceUploadSheet(
      context,
      preloadedCourses: _courseOptions,
    );

    if (!mounted || uploaded == null) {
      return;
    }

    _showMessage(
      uploaded.approvalStatus == ResourceApprovalStatus.pending
          ? 'Resource submitted. It is now pending approval.'
          : 'Resource uploaded and published successfully.',
    );

    await _refreshResources(showLoader: false);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool _canManageResource(ResourceItem item) {
    if (_isAdminView) {
      return true;
    }

    final currentUserId = _resourceService.currentUserId;
    if (currentUserId == null || currentUserId.trim().isEmpty) {
      return false;
    }

    return currentUserId == item.uploaderId;
  }

  bool _canReviewResource(ResourceItem item) {
    return _isAdminView &&
        item.approvalStatus == ResourceApprovalStatus.pending &&
        !widget.isLocalAdmin;
  }

  Future<void> _openEditSheet(ResourceItem item) async {
    final updated = await showResourceUploadSheet(
      context,
      preloadedCourses: _courseOptions,
      existingResource: item,
    );

    if (!mounted || updated == null) {
      return;
    }

    _showMessage('Resource updated successfully.');
    await _refreshResources(showLoader: false);
  }

  Future<void> _deleteResource(ResourceItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Resource?'),
        content: Text(
          'This will permanently remove "${item.title}" from the database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _resourceService.deleteResource(resourceId: item.id);
      if (!mounted) {
        return;
      }
      _showMessage('Resource deleted.');
      await _refreshResources(showLoader: false);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Delete failed: $error');
    }
  }

  Future<void> _approveResource(ResourceItem item) async {
    try {
      await _resourceService.reviewResource(
        resourceId: item.id,
        approve: true,
      );
      if (!mounted) {
        return;
      }
      _showMessage('Resource approved successfully.');
      await _refreshResources(showLoader: false);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Approval failed: $error');
    }
  }

  Future<void> _rejectResource(ResourceItem item) async {
    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Resource'),
        content: TextField(
          controller: reasonController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter rejection reason',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = reasonController.text.trim();
              if (text.isEmpty) {
                return;
              }
              Navigator.of(context).pop(text);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    reasonController.dispose();

    if (reason == null || reason.trim().isEmpty) {
      return;
    }

    try {
      await _resourceService.reviewResource(
        resourceId: item.id,
        approve: false,
        rejectionReason: reason,
      );
      if (!mounted) {
        return;
      }
      _showMessage('Resource rejected.');
      await _refreshResources(showLoader: false);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Rejection failed: $error');
    }
  }

  Future<void> _openResourceDetail(ResourceItem item) async {
    final updated = await Navigator.of(context).push<ResourceItem>(
      MaterialPageRoute(
        builder: (_) => ResourceDetailScreen(resource: item),
      ),
    );

    if (!mounted || updated == null) {
      return;
    }

    setState(() {
      _resources = _resources
          .map((current) => current.id == updated.id ? updated : current)
          .toList(growable: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const PageStorageKey<String>('resources-tab-content-v2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: _ResourceTopHeader(
                title: 'Resources',
                subtitle: 'Search, filter, preview and upload from database',
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _openUploadSheet,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('Upload'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4F9EFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SearchField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          onClear: () {
            _searchController.clear();
            _refreshResources();
          },
        ),
        const SizedBox(height: 10),
        _FilterWrap(
          semesterOptions: _semesterOptions,
          selectedSemester: _selectedSemester,
          selectedCourseCode: _selectedCourseCode,
          selectedFileType: _selectedFileType,
          courses: _courseOptionsForSelectedSemester,
          onSemesterChanged: (value) {
            setState(() {
              _selectedSemester = value;
              _selectedCourseCode = null;
            });
            _refreshResources();
          },
          onCourseChanged: (value) {
            setState(() {
              _selectedCourseCode = value;
            });
            _refreshResources();
          },
          onFileTypeChanged: (value) {
            setState(() {
              _selectedFileType = value;
            });
            _refreshResources();
          },
        ),
        if (_isAdminView) ...[
          const SizedBox(height: 10),
          _AdminReviewBanner(
            pendingCount: _pendingReviewCount,
            pendingOnly: _pendingOnlyForAdmin,
            onTogglePendingOnly: (value) {
              setState(() {
                _pendingOnlyForAdmin = value;
              });
            },
          ),
        ],
        const SizedBox(height: 10),
        Expanded(
          child: _buildBody(),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading && _visibleResources.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _visibleResources.isEmpty) {
      return _RetryState(
        title: 'Unable to load resources',
        subtitle: _errorMessage!,
        onRetry: _bootstrap,
      );
    }

    if (_visibleResources.isEmpty) {
      return _EmptyResourceState(onUpload: _openUploadSheet);
    }

    return RefreshIndicator(
      onRefresh: _refreshResources,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(0, 2, 0, 118),
        itemCount: _visibleResources.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = _visibleResources[index];
          return _ResourceListCard(
            item: item,
            onTap: () => _openResourceDetail(item),
            canManage: _canManageResource(item),
            canReview: _canReviewResource(item),
            onEdit: () => _openEditSheet(item),
            onDelete: () => _deleteResource(item),
            onApprove: () => _approveResource(item),
            onReject: () => _rejectResource(item),
          );
        },
      ),
    );
  }
}

Future<ResourceItem?> showResourceUploadSheet(
  BuildContext context, {
  List<CourseOption>? preloadedCourses,
  ResourceItem? existingResource,
}) {
  return showModalBottomSheet<ResourceItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ResourceUploadSheet(
      preloadedCourses: preloadedCourses,
      existingResource: existingResource,
    ),
  );
}

class _ResourceTopHeader extends StatelessWidget {
  const _ResourceTopHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AdminReviewBanner extends StatelessWidget {
  const _AdminReviewBanner({
    required this.pendingCount,
    required this.pendingOnly,
    required this.onTogglePendingOnly,
  });

  final int pendingCount;
  final bool pendingOnly;
  final ValueChanged<bool> onTogglePendingOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.admin_panel_settings_rounded,
            color: Color(0xFF1D4ED8),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Pending Reviews: $pendingCount',
              style: const TextStyle(
                color: Color(0xFF1E3A8A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Switch.adaptive(
            value: pendingOnly,
            onChanged: onTogglePendingOnly,
            activeThumbColor: const Color(0xFF2563EB),
          ),
          const Text(
            'Only pending',
            style: TextStyle(
              color: Color(0xFF1E3A8A),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'Search by title, description or course',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: controller.text.trim().isEmpty
                ? null
                : IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.83),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.94)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.94)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: Color(0xFF4F9EFF), width: 1.2),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterWrap extends StatelessWidget {
  const _FilterWrap({
    required this.semesterOptions,
    required this.selectedSemester,
    required this.selectedCourseCode,
    required this.selectedFileType,
    required this.courses,
    required this.onSemesterChanged,
    required this.onCourseChanged,
    required this.onFileTypeChanged,
  });

  final List<int> semesterOptions;
  final int? selectedSemester;
  final String? selectedCourseCode;
  final ResourceFileType? selectedFileType;
  final List<CourseOption> courses;

  final ValueChanged<int?> onSemesterChanged;
  final ValueChanged<String?> onCourseChanged;
  final ValueChanged<ResourceFileType?> onFileTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        SizedBox(
          width: 150,
          child: _DropdownContainer<int>(
            value: selectedSemester,
            hint: 'Semester',
            items: [
              const DropdownMenuItem<int>(
                value: null,
                child: Text('All Semesters'),
              ),
              ...semesterOptions.map(
                (sem) => DropdownMenuItem<int>(
                  value: sem,
                  child: Text('Semester $sem'),
                ),
              ),
            ],
            onChanged: onSemesterChanged,
          ),
        ),
        SizedBox(
          width: 190,
          child: _DropdownContainer<String>(
            value: selectedCourseCode,
            hint: 'Course',
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('All Courses'),
              ),
              ...courses.map(
                (course) => DropdownMenuItem<String>(
                  value: course.courseCode,
                  child: Text(
                    '${course.courseCode} - ${course.courseTitle}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: onCourseChanged,
          ),
        ),
        SizedBox(
          width: 132,
          child: _DropdownContainer<ResourceFileType>(
            value: selectedFileType,
            hint: 'File',
            items: [
              const DropdownMenuItem<ResourceFileType>(
                value: null,
                child: Text('All Files'),
              ),
              ...ResourceFileType.values.map(
                (fileType) => DropdownMenuItem<ResourceFileType>(
                  value: fileType,
                  child: Text(fileType.label),
                ),
              ),
            ],
            onChanged: onFileTypeChanged,
          ),
        ),
      ],
    );
  }
}

class _DropdownContainer<T> extends StatelessWidget {
  const _DropdownContainer({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final T? value;
  final String hint;
  final List<DropdownMenuItem<T?>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T?>(
              value: value,
              hint: Text(hint),
              isExpanded: true,
              borderRadius: BorderRadius.circular(12),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResourceListCard extends StatelessWidget {
  const _ResourceListCard({
    required this.item,
    required this.onTap,
    required this.canManage,
    required this.canReview,
    required this.onEdit,
    required this.onDelete,
    required this.onApprove,
    required this.onReject,
  });

  final ResourceItem item;
  final VoidCallback onTap;
  final bool canManage;
  final bool canReview;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.84),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F9EFF).withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _fileColor(item.fileType).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _fileIcon(item.fileType),
                  color: _fileColor(item.fileType),
                ),
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
                    const SizedBox(height: 4),
                    Text(
                      '${item.courseCode} • ${item.semesterLabel} • ${item.resourceType.label}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _UploaderIdentityRow(item: item),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(item.approvalStatus)
                                .withOpacity(0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            item.approvalStatus.label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _statusColor(item.approvalStatus),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.download_rounded,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${item.totalDownloads}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (canReview) ...[
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
                                side: const BorderSide(
                                  color: Color(0xFFFCA5A5),
                                ),
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
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (canManage)
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Color(0xFF64748B),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('Edit Resource'),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete Resource'),
                    ),
                  ],
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _fileColor(ResourceFileType type) {
    switch (type) {
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

  IconData _fileIcon(ResourceFileType type) {
    switch (type) {
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

  Color _statusColor(ResourceApprovalStatus status) {
    switch (status) {
      case ResourceApprovalStatus.pending:
        return const Color(0xFFD97706);
      case ResourceApprovalStatus.approved:
        return const Color(0xFF059669);
      case ResourceApprovalStatus.rejected:
        return const Color(0xFFDC2626);
    }
  }
}

class _UploaderIdentityRow extends StatelessWidget {
  const _UploaderIdentityRow({required this.item});

  final ResourceItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: const Color(0xFFDCEBFF),
          backgroundImage: (item.uploaderAvatarUrl ?? '').trim().isNotEmpty
              ? NetworkImage(item.uploaderAvatarUrl!.trim())
              : null,
          child: (item.uploaderAvatarUrl ?? '').trim().isNotEmpty
              ? null
              : Text(
                  item.uploaderName.isEmpty
                      ? 'U'
                      : item.uploaderName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            '${item.uploaderName} • ${item.uploaderRole.displayName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyResourceState extends StatelessWidget {
  const _EmptyResourceState({required this.onUpload});

  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.82),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.95)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.menu_book_rounded,
                    size: 36,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No resources found',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try changing filters or upload your first resource.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onUpload,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Upload Resource'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RetryState extends StatelessWidget {
  const _RetryState({
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  final String title;
  final String subtitle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 34,
              color: Color(0xFF64748B),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceUploadSheet extends StatefulWidget {
  const _ResourceUploadSheet({
    this.preloadedCourses,
    this.existingResource,
  });

  final List<CourseOption>? preloadedCourses;
  final ResourceItem? existingResource;

  @override
  State<_ResourceUploadSheet> createState() => _ResourceUploadSheetState();
}

class _ResourceUploadSheetState extends State<_ResourceUploadSheet> {
  final ResourceService _resourceService = ResourceService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _driveUrlController = TextEditingController();
  final TextEditingController _fileNameController = TextEditingController();

  bool _isLoadingCourses = true;
  bool _isSubmitting = false;
  List<CourseOption> _courses = const <CourseOption>[];

  int? _selectedSemester;
  String? _selectedCourseCode;
  ResourceKind _selectedResourceType = ResourceKind.notes;
  ResourceFileType _selectedFileType = ResourceFileType.pdf;

  bool get _isEditMode => widget.existingResource != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existingResource;
    if (existing != null) {
      _titleController.text = existing.title;
      _descriptionController.text = existing.description ?? '';
      _driveUrlController.text = existing.driveUrl;
      _fileNameController.text = existing.originalFileName ?? '';
      _selectedSemester = existing.semesterNo;
      _selectedCourseCode = existing.courseCode;
      _selectedResourceType = existing.resourceType;
      _selectedFileType = existing.fileType;
    }

    _loadCourses();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _driveUrlController.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    if ((widget.preloadedCourses ?? const <CourseOption>[]).isNotEmpty) {
      setState(() {
        _courses = widget.preloadedCourses!;
        _isLoadingCourses = false;
      });
      return;
    }

    try {
      final options = await _resourceService.fetchCourseOptions();
      if (!mounted) {
        return;
      }

      setState(() {
        _courses = options;
        _isLoadingCourses = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingCourses = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load course options: $error')),
      );
    }
  }

  List<int> get _semesterOptions {
    final set = _courses.map((course) => course.semesterNo).toSet().toList();
    set.sort();
    return set;
  }

  List<CourseOption> get _filteredCourses {
    if (_selectedSemester == null) {
      return const <CourseOption>[];
    }

    return _courses
        .where((course) => course.semesterNo == _selectedSemester)
        .toList(growable: false);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_selectedSemester == null) {
      _showMessage('Semester is required.');
      return;
    }

    if ((_selectedCourseCode ?? '').trim().isEmpty) {
      _showMessage('Course is required.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_isEditMode) {
        await _resourceService.updateResource(
          resourceId: widget.existingResource!.id,
          title: _titleController.text,
          description: _descriptionController.text,
          originalFileName: _fileNameController.text,
          driveUrl: _driveUrlController.text,
          courseCode: _selectedCourseCode,
          semesterNo: _selectedSemester,
          resourceType: _selectedResourceType,
          fileType: _selectedFileType,
        );

        if (!mounted) {
          return;
        }

        Navigator.of(context).pop(
          widget.existingResource!.copyWith(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            originalFileName: _fileNameController.text.trim().isEmpty
                ? null
                : _fileNameController.text.trim(),
            driveUrl: _driveUrlController.text.trim(),
          ),
        );
        return;
      }

      final created = await _resourceService.uploadResource(
        title: _titleController.text,
        description: _descriptionController.text,
        originalFileName: _fileNameController.text,
        courseCode: _selectedCourseCode!,
        semesterNo: _selectedSemester!,
        resourceType: _selectedResourceType,
        fileType: _selectedFileType,
        driveUrl: _driveUrlController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(created);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('${_isEditMode ? 'Update' : 'Upload'} failed: $error');
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, keyboardInset + 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.97)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _isEditMode ? 'Edit Resource' : 'Upload Resource',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _LabeledInput(
                        label: 'Title *',
                        controller: _titleController,
                        hint: 'e.g. Machine Learning Final Exam Prep',
                        validator: (value) {
                          if ((value ?? '').trim().length < 3) {
                            return 'Title must be at least 3 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _LabeledInput(
                        label: 'Description',
                        controller: _descriptionController,
                        hint: 'Optional short description',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      if (_isLoadingCourses)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        _LabeledDropdown<int>(
                          label: 'Semester *',
                          value: _selectedSemester,
                          items: _semesterOptions
                              .map(
                                (semester) => DropdownMenuItem<int>(
                                  value: semester,
                                  child: Text('Semester $semester'),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            setState(() {
                              _selectedSemester = value;
                              _selectedCourseCode = null;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _LabeledDropdown<String>(
                          label: 'Course Name *',
                          value: _selectedCourseCode,
                          items: _filteredCourses
                              .map(
                                (course) => DropdownMenuItem<String>(
                                  value: course.courseCode,
                                  child: Text(
                                    '${course.courseCode} - ${course.courseTitle}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            setState(() {
                              _selectedCourseCode = value;
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      _LabeledDropdown<ResourceKind>(
                        label: 'Resource Type *',
                        value: _selectedResourceType,
                        items: ResourceKind.values
                            .map(
                              (kind) => DropdownMenuItem<ResourceKind>(
                                value: kind,
                                child: Text(kind.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            _selectedResourceType = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _LabeledDropdown<ResourceFileType>(
                        label: 'File Type *',
                        value: _selectedFileType,
                        items: ResourceFileType.values
                            .map(
                              (fileType) => DropdownMenuItem<ResourceFileType>(
                                value: fileType,
                                child: Text(fileType.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            _selectedFileType = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _LabeledInput(
                        label: 'File Link * (Google Drive)',
                        controller: _driveUrlController,
                        hint: 'https://drive.google.com/file/d/...',
                        validator: (value) {
                          final normalized = (value ?? '').trim();
                          if (normalized.isEmpty) {
                            return 'Google Drive link is required';
                          }

                          final allowedHost = RegExp(
                            r'^https?://(drive\.google\.com|docs\.google\.com)/',
                            caseSensitive: false,
                          );

                          if (!allowedHost.hasMatch(normalized)) {
                            return 'Only Google Drive links are allowed';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF5FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFC8DEFF)),
                        ),
                        child: const Text(
                          'How to share:\n1. Upload your file to Google Drive\n2. Share -> Anyone with the link\n3. Paste that link above',
                          style: TextStyle(
                            color: Color(0xFF1D4ED8),
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _LabeledInput(
                        label: 'File Name (optional)',
                        controller: _fileNameController,
                        hint: 'e.g. Chapter1-Notes.pdf',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: _isSubmitting ? null : _submit,
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(_isEditMode ? 'Update' : 'Upload'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LabeledInput extends StatelessWidget {
  const _LabeledInput({
    required this.label,
    required this.controller,
    required this.hint,
    this.validator,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF334155),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blueGrey.shade100),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFF4F9EFF), width: 1.2),
            ),
            fillColor: Colors.white,
            filled: true,
          ),
        ),
      ],
    );
  }
}

class _LabeledDropdown<T> extends StatelessWidget {
  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF334155),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          key: ValueKey<T?>(value),
          initialValue: value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blueGrey.shade100),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFF4F9EFF), width: 1.2),
            ),
            fillColor: Colors.white,
            filled: true,
          ),
        ),
      ],
    );
  }
}

class ResourceDetailScreen extends StatefulWidget {
  const ResourceDetailScreen({
    super.key,
    required this.resource,
  });

  final ResourceItem resource;

  @override
  State<ResourceDetailScreen> createState() => _ResourceDetailScreenState();
}

class _ResourceDetailScreenState extends State<ResourceDetailScreen> {
  final ResourceService _resourceService = ResourceService();

  late ResourceItem _resource;
  bool _isRecordingDownload = false;

  @override
  void initState() {
    super.initState();
    _resource = widget.resource;
  }

  Future<void> _recordDownloadAndOpen() async {
    if (_isRecordingDownload) {
      return;
    }

    setState(() {
      _isRecordingDownload = true;
    });

    try {
      final newCount = await _resourceService.recordDownload(
        resourceId: _resource.id,
        clientPlatform: 'mobile_app',
      );

      if (!mounted) {
        return;
      }

      final updated = _resource.copyWith(totalDownloads: newCount);
      setState(() {
        _resource = updated;
      });

      if (!mounted) {
        return;
      }

      await _openResourceLink(
        title: 'Download Resource',
        url: _resource.driveUrl,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(updated);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to record download: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRecordingDownload = false;
        });
      }
    }
  }

  Future<void> _openPreview() async {
    final url = (_resource.previewUrl ?? _resource.driveUrl).trim();
    if (url.isEmpty) {
      return;
    }

    await _openResourceLink(
      title: 'Resource Preview',
      url: url,
    );
  }

  Future<void> _openResourceLink({
    required String title,
    required String url,
  }) async {
    await _openUrlWithFallback(
      context,
      title: title,
      url: url,
    );
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _resource.driveUrl));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Resource link copied to clipboard.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Resource Details'),
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
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
            children: [
              _HeroResourceCard(resource: _resource),
              const SizedBox(height: 12),
              _UploaderProfileCard(resource: _resource),
              const SizedBox(height: 12),
              _MetaGrid(resource: _resource),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Description',
                child: Text(
                  (_resource.description ?? '').trim().isEmpty
                      ? 'No description provided.'
                      : _resource.description!,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Document Preview',
                trailing: _resource.supportsPreview
                    ? TextButton.icon(
                        onPressed: _openPreview,
                        icon: const Icon(Icons.visibility_rounded),
                        label: const Text('Open Preview'),
                      )
                    : null,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFFF0F5FF),
                    border: Border.all(color: const Color(0xFFD5E3FA)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _resource.fileType == ResourceFileType.image
                            ? Icons.image_rounded
                            : Icons.picture_as_pdf_rounded,
                        size: 46,
                        color: const Color(0xFF4F9EFF),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _resource.supportsPreview
                            ? 'Preview available in-app'
                            : 'Preview not available for this file type',
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _resource.fileType.label,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyLink,
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Copy Link'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed:
                      _isRecordingDownload ? null : _recordDownloadAndOpen,
                  icon: _isRecordingDownload
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded),
                  label: Text(
                    _isRecordingDownload ? 'Processing...' : 'Download',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4F9EFF),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroResourceCard extends StatelessWidget {
  const _HeroResourceCard({required this.resource});

  final ResourceItem resource;

  @override
  Widget build(BuildContext context) {
    final colors = switch (resource.fileType) {
      ResourceFileType.pdf => const [Color(0xFFF87171), Color(0xFFDC2626)],
      ResourceFileType.docx => const [Color(0xFF60A5FA), Color(0xFF2563EB)],
      ResourceFileType.ppt => const [Color(0xFFF97316), Color(0xFFEA580C)],
      ResourceFileType.image => const [Color(0xFF34D399), Color(0xFF0F766E)],
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.24),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              switch (resource.fileType) {
                ResourceFileType.pdf => Icons.picture_as_pdf_rounded,
                ResourceFileType.docx => Icons.description_rounded,
                ResourceFileType.ppt => Icons.slideshow_rounded,
                ResourceFileType.image => Icons.image_rounded,
              },
              color: colors.last,
              size: 36,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resource.fileType.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  resource.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Added ${_formatDate(resource.createdAt)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}

class _UploaderProfileCard extends StatelessWidget {
  const _UploaderProfileCard({required this.resource});

  final ResourceItem resource;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Uploaded By',
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFDCEBFF),
            backgroundImage:
                (resource.uploaderAvatarUrl ?? '').trim().isNotEmpty
                    ? NetworkImage(resource.uploaderAvatarUrl!.trim())
                    : null,
            child: (resource.uploaderAvatarUrl ?? '').trim().isNotEmpty
                ? null
                : Text(
                    resource.uploaderName.isEmpty
                        ? 'U'
                        : resource.uploaderName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF1D4ED8),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resource.uploaderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  resource.uploaderRole.displayName,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaGrid extends StatelessWidget {
  const _MetaGrid({required this.resource});

  final ResourceItem resource;

  @override
  Widget build(BuildContext context) {
    final items = <_MetaItemData>[
      _MetaItemData(
        icon: Icons.school_rounded,
        label: 'Course',
        value: resource.courseCode,
      ),
      _MetaItemData(
        icon: Icons.layers_rounded,
        label: 'Semester',
        value: resource.semesterLabel,
      ),
      _MetaItemData(
        icon: Icons.category_rounded,
        label: 'Type',
        value: resource.resourceType.label,
      ),
      _MetaItemData(
        icon: Icons.download_rounded,
        label: 'Downloads',
        value: '${resource.totalDownloads}',
      ),
      _MetaItemData(
        icon: Icons.verified_rounded,
        label: 'Status',
        value: resource.approvalStatus.label,
      ),
      _MetaItemData(
        icon: Icons.person_outline_rounded,
        label: 'Uploader',
        value: resource.uploaderName,
      ),
    ];

    return _SectionCard(
      title: 'Metadata',
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2.2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE1EAF8)),
            ),
            child: Row(
              children: [
                Icon(item.icon, color: const Color(0xFF4F9EFF), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.label,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetaItemData {
  const _MetaItemData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.86),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openUrlWithFallback(
  BuildContext context, {
  required String title,
  required String url,
}) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invalid resource URL.')),
    );
    return;
  }

  final supportsWebView = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  if (supportsWebView) {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ResourceWebViewScreen(
          title: title,
          url: uri.toString(),
        ),
      ),
    );
    return;
  }

  final launched = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );

  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unable to open link on this platform.'),
      ),
    );
  }
}

class _ResourceWebViewScreen extends StatefulWidget {
  const _ResourceWebViewScreen({
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  @override
  State<_ResourceWebViewScreen> createState() => _ResourceWebViewScreenState();
}

class _ResourceWebViewScreenState extends State<_ResourceWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
