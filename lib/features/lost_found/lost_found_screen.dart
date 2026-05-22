import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';
import 'package:unisharesync_mobile_app/features/lost_found/lost_found_model.dart';
import 'package:unisharesync_mobile_app/features/lost_found/lost_found_service.dart';
import 'package:unisharesync_mobile_app/services/auth_service.dart';

class LostFoundScreen extends StatefulWidget {
  const LostFoundScreen({
    super.key,
    this.initialRole,
    this.isLocalAdmin,
  });

  final UserRole? initialRole;
  final bool? isLocalAdmin;

  @override
  State<LostFoundScreen> createState() => _LostFoundScreenState();
}

class _LostFoundScreenState extends State<LostFoundScreen> {
  final AuthService _authService = AuthService();
  final LostFoundService _service = LostFoundService();
  final TextEditingController _searchController = TextEditingController();

  UserRole _role = UserRole.student;
  bool _isLocalAdmin = false;
  bool _isLoading = true;
  bool _isSubmitting = false;

  LostFoundReportType? _selectedTypeFilter;
  String _selectedCategoryFilter = 'All Categories';
  LostFoundStatus? _selectedStatusFilter;

  String? _currentUserId;

  static const _bg = Color(0xFFF4F8FF);
  static const _blue = Color(0xFF4F9EFF);
  static const _teal = Color(0xFF2DD4BF);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFF87171);

  static const List<String> _categories = [
    'All Categories',
    'Personal Items',
    'Electronics',
    'Documents',
    'Books',
    'Accessories',
    'Keys',
    'Wallets',
    'Clothing',
    'ID Cards',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final role = widget.initialRole ?? await _authService.getCurrentRole();
      final isLocalAdmin =
          widget.isLocalAdmin ?? await _authService.isLocalAdminSession();

      if (!mounted) {
        return;
      }

      setState(() {
        _role = role ?? UserRole.student;
        _isLocalAdmin = isLocalAdmin;
        _currentUserId = _service.currentUserId;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _currentUserId = _service.currentUserId;
        _isLoading = false;
      });
    }
  }

  bool get _canManageAnyReport => _role == UserRole.admin && !_isLocalAdmin;

  bool get _canCreateReport => _currentUserId != null && !_isLocalAdmin;

  bool _canManageReport(LostFoundReport report) {
    if (_isLocalAdmin) {
      return false;
    }

    return _canManageAnyReport || report.reporterId == _currentUserId;
  }

  bool _canDeleteReport(LostFoundReport report) => _canManageReport(report);

  Future<void> _openReportForm() async {
    if (!_canCreateReport) {
      _showSnackBar(
        _isLocalAdmin
            ? 'Lost & Found needs a Supabase-backed session to submit reports.'
            : 'Please sign in before submitting a report.',
      );
      return;
    }

    final draft = await Navigator.of(context).push<LostFoundReportDraft>(
      MaterialPageRoute(
        builder: (_) => _LostFoundReportFormScreen(
          initialType: _selectedTypeFilter ?? LostFoundReportType.lost,
        ),
      ),
    );

    if (!mounted || draft == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _service.createReport(draft: draft);
      if (!mounted) {
        return;
      }
      _showSnackBar('Report submitted successfully.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Unable to submit report: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _updateReportStatus(
    LostFoundReport report,
    LostFoundStatus status,
  ) async {
    try {
      await _service.updateReportStatus(reportId: report.id, status: status);
      if (!mounted) {
        return;
      }
      _showSnackBar('Status updated to ${status.label}.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Unable to update status: $error');
    }
  }

  Future<void> _deleteReport(LostFoundReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text('Are you sure you want to delete this report?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _service.deleteReport(report.id);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      _showSnackBar('Report deleted.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Unable to delete report: $error');
    }
  }

  Future<void> _openReportDetails(LostFoundReport report) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReportDetailSheet(
        report: report,
        canManageStatus: _canManageReport(report),
        canDeleteReport: _canDeleteReport(report),
        onStatusChanged: (status) {
          Navigator.of(context).pop();
          _updateReportStatus(report, status);
        },
        onDelete: () => _deleteReport(report),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  List<LostFoundReport> _applyFilters(
    List<LostFoundReport> reports, {
    required bool mineOnly,
  }) {
    final query = _searchController.text.trim().toLowerCase();

    return reports.where((report) {
      if (mineOnly && report.reporterId != _currentUserId) {
        return false;
      }

      if (_selectedTypeFilter != null && report.reportType != _selectedTypeFilter) {
        return false;
      }

      if (_selectedCategoryFilter != 'All Categories' &&
          report.category.toLowerCase() != _selectedCategoryFilter.toLowerCase()) {
        return false;
      }

      if (_selectedStatusFilter != null && report.status != _selectedStatusFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final haystack = [
        report.title,
        report.description,
        report.location,
        report.category,
        report.reporterName,
        report.contactInfo,
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList(growable: false);
  }

  Map<LostFoundStatus, int> _statusCounts(List<LostFoundReport> reports) {
    return {
      LostFoundStatus.open:
          reports.where((report) => report.status == LostFoundStatus.open).length,
      LostFoundStatus.matched: reports
          .where((report) => report.status == LostFoundStatus.matched)
          .length,
      LostFoundStatus.resolved: reports
          .where((report) => report.status == LostFoundStatus.resolved)
          .length,
    };
  }

  String _formatDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  Color _statusColor(LostFoundStatus status) => switch (status) {
        LostFoundStatus.open => _blue,
        LostFoundStatus.matched => _amber,
        LostFoundStatus.resolved => const Color(0xFF10B981),
      };

  Color _typeColor(LostFoundReportType type) => switch (type) {
        LostFoundReportType.lost => _red,
        LostFoundReportType.found => const Color(0xFF0EA5E9),
      };

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.88),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.95)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: _blue.withOpacity(0.14),
      backgroundColor: Colors.white.withOpacity(0.86),
      labelStyle: TextStyle(
        color: selected ? _blue : const Color(0xFF475569),
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(color: selected ? _blue.withOpacity(0.35) : const Color(0xFFE2E8F0)),
    );
  }

  Widget _buildReportCard(LostFoundReport report) {
    final statusColor = _statusColor(report.status);
    final typeColor = _typeColor(report.reportType);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openReportDetails(report),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
            boxShadow: [
              BoxShadow(
                color: typeColor.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        report.reportType == LostFoundReportType.lost
                            ? Icons.search_rounded
                            : Icons.inventory_2_outlined,
                        color: typeColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  report.reportType.label,
                                  style: TextStyle(
                                    color: typeColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  report.status.label,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            report.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            report.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (report.hasPhotos) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 68,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: report.photoUrls.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final url = report.photoUrls[index];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            url,
                            width: 96,
                            height: 68,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 96,
                              height: 68,
                              color: const Color(0xFFF1F5F9),
                              alignment: Alignment.center,
                              child: const Icon(Icons.image_not_supported_outlined),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoPill(
                      icon: Icons.category_outlined,
                      label: report.category,
                    ),
                    _InfoPill(
                      icon: Icons.place_outlined,
                      label: report.location,
                    ),
                    _InfoPill(
                      icon: Icons.event_outlined,
                      label: _formatDate(report.reportDate),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFFDCEBFF),
                      backgroundImage: report.reporterAvatarUrl != null
                          ? NetworkImage(report.reporterAvatarUrl!)
                          : null,
                      child: report.reporterAvatarUrl == null
                          ? Text(
                              report.reporterName.isNotEmpty
                                  ? report.reporterName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: Color(0xFF2B5B94),
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        report.reporterName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _formatDate(report.createdAt),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_canManageReport(report)) ...[
                      const SizedBox(width: 10),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<LostFoundStatus>(
                          value: report.status,
                          borderRadius: BorderRadius.circular(14),
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          items: LostFoundStatus.values
                              .map(
                                (status) => DropdownMenuItem(
                                  value: status,
                                  child: Text(status.label),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (status) {
                            if (status != null) {
                              _updateReportStatus(report, status);
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportList({required List<LostFoundReport> reports}) {
    final filtered = _applyFilters(
      reports,
      mineOnly: false,
    );

    if (filtered.isEmpty) {
      return const _EmptyState(
        title: 'No reports found',
        subtitle: 'Try another type, status, category, or keyword.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 112),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildReportCard(filtered[index]),
    );
  }

  Widget _buildMyReports(List<LostFoundReport> reports) {
    if (_currentUserId == null) {
      return const _EmptyState(
        title: 'Sign in to view your reports',
        subtitle: 'Your submitted Lost & Found items will appear here.',
      );
    }

    final filtered = _applyFilters(
      reports,
      mineOnly: true,
    );

    if (filtered.isEmpty) {
      return const _EmptyState(
        title: 'No reports submitted yet',
        subtitle: 'Use Report Item to submit your first lost or found item.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 112),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildReportCard(filtered[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Lost & Found Portal',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
              ),
              onPressed: _isSubmitting ? null : _openReportForm,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add, size: 18),
              label: const Text('Report Item'),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
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
                Positioned(
                  top: -120,
                  right: -80,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _blue.withOpacity(0.12),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -140,
                  left: -80,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _teal.withOpacity(0.1),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: StreamBuilder<List<LostFoundReport>>(
                      stream: _service.watchReports(limit: 300),
                      builder: (context, snapshot) {
                        if (_isLocalAdmin && _currentUserId == null) {
                          return const Center(
                            child: _EmptyState(
                              title: 'Backend session required',
                              subtitle:
                                  'Lost & Found reporting and management uses Supabase data and photos.',
                            ),
                          );
                        }

                        if (snapshot.connectionState == ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: _GlassPanel(
                              child: Text(
                                'Unable to load lost and found reports.\n${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF334155),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }

                        final reports = snapshot.data ?? const <LostFoundReport>[];
                        final counts = _statusCounts(reports);
                        final myCount = _currentUserId == null
                            ? 0
                            : reports.where((report) => report.reporterId == _currentUserId).length;

                        return DefaultTabController(
                          length: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _buildStatCard(
                                    'Total Items',
                                    reports.length.toString(),
                                    Icons.search_rounded,
                                    _blue,
                                  ),
                                  const SizedBox(width: 10),
                                  _buildStatCard(
                                    'Open',
                                    counts[LostFoundStatus.open]!.toString(),
                                    Icons.pending_actions_rounded,
                                    _blue,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _buildStatCard(
                                    'Matched',
                                    counts[LostFoundStatus.matched]!.toString(),
                                    Icons.link_rounded,
                                    _amber,
                                  ),
                                  const SizedBox(width: 10),
                                  _buildStatCard(
                                    'Resolved',
                                    counts[LostFoundStatus.resolved]!.toString(),
                                    Icons.verified_rounded,
                                    const Color(0xFF10B981),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _searchController,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'Search items, location, or description...',
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.9),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.9)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildFilterChip(
                                    label: 'All Items',
                                    selected: _selectedTypeFilter == null,
                                    onTap: () {
                                      setState(() {
                                        _selectedTypeFilter = null;
                                      });
                                    },
                                  ),
                                  _buildFilterChip(
                                    label: 'Lost Items',
                                    selected: _selectedTypeFilter == LostFoundReportType.lost,
                                    onTap: () {
                                      setState(() {
                                        _selectedTypeFilter = LostFoundReportType.lost;
                                      });
                                    },
                                  ),
                                  _buildFilterChip(
                                    label: 'Found Items',
                                    selected: _selectedTypeFilter == LostFoundReportType.found,
                                    onTap: () {
                                      setState(() {
                                        _selectedTypeFilter = LostFoundReportType.found;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _selectedCategoryFilter,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(0.9),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      items: _categories
                                          .map(
                                            (category) => DropdownMenuItem(
                                              value: category,
                                              child: Text(category),
                                            ),
                                          )
                                          .toList(growable: false),
                                      onChanged: (value) {
                                        if (value == null) {
                                          return;
                                        }
                                        setState(() {
                                          _selectedCategoryFilter = value;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: DropdownButtonFormField<LostFoundStatus?>(
                                      initialValue: _selectedStatusFilter,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(0.9),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      items: [
                                        const DropdownMenuItem<LostFoundStatus?>(
                                          value: null,
                                          child: Text('All Status'),
                                        ),
                                        ...LostFoundStatus.values.map(
                                          (status) => DropdownMenuItem<LostFoundStatus?>(
                                            value: status,
                                            child: Text(status.label),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedStatusFilter = value;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.82),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: Colors.white.withOpacity(0.95)),
                                ),
                                child: const TabBar(
                                  labelColor: Color(0xFF0F172A),
                                  unselectedLabelColor: Color(0xFF64748B),
                                  indicatorColor: _blue,
                                  tabs: [
                                    Tab(text: 'Browse All Items'),
                                    Tab(text: 'My Reports'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: TabBarView(
                                  children: [
                                    _buildReportList(reports: reports),
                                    _buildMyReports(reports),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: null,
    );
  }
}

class _ReportDetailSheet extends StatelessWidget {
  const _ReportDetailSheet({
    required this.report,
    required this.canManageStatus,
    required this.canDeleteReport,
    required this.onStatusChanged,
    required this.onDelete,
  });

  final LostFoundReport report;
  final bool canManageStatus;
  final bool canDeleteReport;
  final ValueChanged<LostFoundStatus> onStatusChanged;
  final VoidCallback onDelete;

  Color _statusColor(LostFoundStatus status) => switch (status) {
        LostFoundStatus.open => const Color(0xFF4F9EFF),
        LostFoundStatus.matched => const Color(0xFFF59E0B),
        LostFoundStatus.resolved => const Color(0xFF10B981),
      };

  Color _typeColor(LostFoundReportType type) => switch (type) {
        LostFoundReportType.lost => const Color(0xFFF87171),
        LostFoundReportType.found => const Color(0xFF0EA5E9),
      };

  String _formatDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(report.status);
    final typeColor = _typeColor(report.reportType);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.95)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            report.reportType == LostFoundReportType.lost
                                ? Icons.search_rounded
                                : Icons.inventory_2_outlined,
                            color: typeColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                report.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _DetailBadge(
                                    label: report.reportType.label,
                                    color: typeColor,
                                  ),
                                  _DetailBadge(
                                    label: report.status.label,
                                    color: statusColor,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (report.hasPhotos) ...[
                      SizedBox(
                        height: 160,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: report.photoUrls.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final url = report.photoUrls[index];
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.network(
                                url,
                                width: 180,
                                height: 160,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 180,
                                  height: 160,
                                  color: const Color(0xFFF1F5F9),
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.image_not_supported_outlined),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _DetailRow(label: 'Category', value: report.category),
                    _DetailRow(label: 'Location', value: report.location),
                    _DetailRow(label: 'Date', value: _formatDate(report.reportDate)),
                    _DetailRow(label: 'Contact', value: report.contactInfo),
                    _DetailRow(label: 'Reported by', value: report.reporterName),
                    const SizedBox(height: 10),
                    const Text(
                      'Description',
                      style: TextStyle(
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      report.description,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                    ),
                    if (canManageStatus) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Update Status',
                        style: TextStyle(
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: LostFoundStatus.values
                            .map(
                              (status) => OutlinedButton(
                                onPressed: () => onStatusChanged(status),
                                child: Text(status.label),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    if (canDeleteReport) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                          ),
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete Report'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LostFoundReportFormScreen extends StatefulWidget {
  const _LostFoundReportFormScreen({required this.initialType});

  final LostFoundReportType initialType;

  @override
  State<_LostFoundReportFormScreen> createState() => _LostFoundReportFormScreenState();
}

class _LostFoundReportFormScreenState extends State<_LostFoundReportFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  LostFoundReportType _reportType = LostFoundReportType.lost;
  String _selectedCategory = 'Personal Items';
  DateTime _selectedDate = DateTime.now();
  final List<Uint8List> _photoBytes = <Uint8List>[];
  final List<String> _photoNames = <String>[];
  final bool _isSubmitting = false;

  static const List<String> _categories = [
    'Personal Items',
    'Electronics',
    'Documents',
    'Books',
    'Accessories',
    'Keys',
    'Wallets',
    'Clothing',
    'ID Cards',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _reportType = widget.initialType;
    _dateController.text = _formatDate(_selectedDate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _contactController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDate = picked;
      _dateController.text = _formatDate(picked);
    });
  }

  Future<void> _pickPhotos() async {
    if (_photoBytes.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can upload up to three photos.')),
      );
      return;
    }

    final picked = await _imagePicker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) {
      return;
    }

    final remainingSlots = 3 - _photoBytes.length;
    final limited = picked.take(remainingSlots).toList(growable: false);

    final bytes = <Uint8List>[];
    final names = <String>[];
    for (final file in limited) {
      bytes.add(await file.readAsBytes());
      names.add(file.name);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _photoBytes.addAll(bytes);
      _photoNames.addAll(names);
    });
  }

  void _removePhotoAt(int index) {
    setState(() {
      _photoBytes.removeAt(index);
      _photoNames.removeAt(index);
    });
  }

  void _submit() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      return;
    }

    Navigator.of(context).pop(
      LostFoundReportDraft(
        reportType: _reportType,
        title: _titleController.text.trim(),
        category: _selectedCategory,
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        contactInfo: _contactController.text.trim(),
        reportDate: _selectedDate,
        photoBytes: List<Uint8List>.from(_photoBytes),
        photoFileNames: List<String>.from(_photoNames),
      ),
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
        title: const Text(
          'Report Lost/Found Item',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Type',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<LostFoundReportType>(
                      segments: const [
                        ButtonSegment(
                          value: LostFoundReportType.lost,
                          label: Text('Lost Item'),
                          icon: Icon(Icons.search_rounded),
                        ),
                        ButtonSegment(
                          value: LostFoundReportType.found,
                          label: Text('Found Item'),
                          icon: Icon(Icons.inventory_2_outlined),
                        ),
                      ],
                      selected: {_reportType},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _reportType = selection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Item Title',
                        hintText: 'e.g., Black Laptop Bag',
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Item title is required.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Detailed description of the item...',
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Description is required.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: _categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedCategory = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        hintText: 'Where was it lost/found?',
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Location is required.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _contactController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Information',
                        hintText: 'Email or phone number',
                      ),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty) {
                          return 'Contact information is required.';
                        }

                        // If input contains '@', treat as email
                        if (text.contains('@')) {
                          final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                          if (!emailRegex.hasMatch(text)) {
                            return 'Please enter a valid email address.';
                          }
                          return null;
                        }

                        // Otherwise validate as phone number: 11 digits starting with 013-019
                        final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
                        final phoneRegex = RegExp(r'^01[3-9]\d{8}$');
                        if (!phoneRegex.hasMatch(digits)) {
                          return 'Enter an 11-digit phone starting with 013-019 or a valid email.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Provide at least one valid way to reach you.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _dateController,
                      readOnly: true,
                      onTap: _pickDate,
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        hintText: 'Select date',
                        suffixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Date is required.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Photos',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _photoBytes.length >= 3 ? null : _pickPhotos,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Choose Photos'),
                    ),
                    const SizedBox(height: 8),
                    if (_photoBytes.isEmpty)
                      Text(
                        'Up to three photos supported.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      )
                    else
                      SizedBox(
                        height: 92,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _photoBytes.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.memory(
                                    _photoBytes[index],
                                    width: 92,
                                    height: 92,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  right: 2,
                                  top: 2,
                                  child: GestureDetector(
                                    onTap: () => _removePhotoAt(index),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      child: const Icon(
                                        Icons.close,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: const Text('Submit Report'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _GlassPanel(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inbox_outlined, size: 40, color: Color(0xFF94A3B8)),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.86),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBadge extends StatelessWidget {
  const _DetailBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
