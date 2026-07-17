import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/alumni_profile_model.dart';
import '../../data/models/alumni_connect_request_model.dart';
import '../providers/alumni_admin_provider.dart';
import '../widgets/alumni_pending_approval_tile.dart';
import '../widgets/alumni_analytics_card.dart';
import '../widgets/batch_chart_widget.dart';
import '../widgets/industry_pie_chart_widget.dart';
import 'alumni_add_edit_screen.dart';

class AlumniAdminScreen extends ConsumerStatefulWidget {
  const AlumniAdminScreen({super.key});

  @override
  ConsumerState<AlumniAdminScreen> createState() => _AlumniAdminScreenState();
}

class _AlumniAdminScreenState extends ConsumerState<AlumniAdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(alumniAdminProvider.notifier).fetchPendingApprovals();
      ref.read(alumniAdminProvider.notifier).fetchAllAlumni();
      ref.read(alumniAdminProvider.notifier).fetchAnalytics();
      ref.read(alumniAdminProvider.notifier).fetchConnectRequestsLog();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }


  void _exportCSV() async {
    try {
      final filepath = await ref.read(alumniAdminProvider.notifier).exportAlumniCSV();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV report exported and saved to: $filepath'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export CSV: $e'), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  void _deleteConfirm(String id, String name) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        title: const Text('Confirm Deletion', style: TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to unpublish and delete $name from the directory?',
          style: const TextStyle(color: Color(0xFF475569), fontFamily: 'Outfit'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit')),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await ref.read(alumniAdminProvider.notifier).softDeleteAlumni(id);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile deleted successfully.'),
                    backgroundColor: Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (_) {}
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDismissSingleLog(String id) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        title: const Text('Dismiss Log', style: TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to dismiss and delete this connection log entry?',
          style: TextStyle(color: Color(0xFF475569), fontFamily: 'Outfit'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit')),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(alumniAdminProvider.notifier).deleteConnectRequest(id);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Log entry dismissed.'),
                  backgroundColor: Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Dismiss', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmClearAllLogs() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        title: const Text('Clear All Logs', style: TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to clear all connection logs? This action cannot be undone.',
          style: TextStyle(color: Color(0xFF475569), fontFamily: 'Outfit'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit')),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(alumniAdminProvider.notifier).clearAllConnectRequests();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All connection logs cleared.'),
                  backgroundColor: Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Clear All', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(alumniAdminProvider);
    final pendingCount = adminState.pendingApprovals.length;

    ref.listen<AlumniAdminState>(alumniAdminProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Alumni Connect Admin',
          style: TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Color(0xFF0F172A)),
            onPressed: _exportCSV,
            tooltip: 'Export CSV Report',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF2563EB),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Pending', style: TextStyle(fontFamily: 'Outfit')),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(child: Text('All Alumni', style: TextStyle(fontFamily: 'Outfit'))),
            const Tab(child: Text('Analytics', style: TextStyle(fontFamily: 'Outfit'))),
            const Tab(child: Text('Connect Log', style: TextStyle(fontFamily: 'Outfit'))),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FBFF), Color(0xFFEAF6FF)],
          ),
        ),
        child: adminState.isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
            : TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Pending approvals
                  _buildPendingTab(adminState.pendingApprovals),
                  // Tab 2: All Alumni (CRUD management)
                  _buildAllAlumniTab(adminState.allAlumni),
                  // Tab 3: Analytics
                  _buildAnalyticsTab(adminState.analytics),
                  // Tab 4: Connection requests audit log
                  _buildConnectLogTab(adminState.connectRequests),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AlumniAddEditScreen()),
          );
        },
        backgroundColor: const Color(0xFF2563EB),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  // ─── TAB 1: PENDING ──────────────────────────────────────
  Widget _buildPendingTab(List<AlumniProfile> pending) {
    if (pending.isEmpty) {
      return const Center(
        child: Text(
          'No pending profile approvals.',
          style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pending.length,
      itemBuilder: (context, index) {
        final profile = pending[index];
        return AlumniPendingApprovalTile(
          profile: profile,
          onApprove: () => ref.read(alumniAdminProvider.notifier).approveAlumni(profile),
          onReject: (note) => ref.read(alumniAdminProvider.notifier).rejectAlumni(profile, note),
        );
      },
    );
  }

  // ─── TAB 2: ALL ALUMNI ───────────────────────────────────
  Widget _buildAllAlumniTab(List<AlumniProfile> all) {
    if (all.isEmpty) {
      return const Center(
        child: Text(
          'No alumni profiles stored in database.',
          style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: all.length,
      itemBuilder: (context, index) {
        final profile = all[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          profile.fullName,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          profile.isVerified ? Icons.verified_rounded : Icons.pending_actions_rounded,
                          size: 14,
                          color: profile.isVerified ? const Color(0xFF10B981) : const Color(0xFFFBBF24),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Batch ${profile.batchYear.toString().padLeft(2, '0')} · ${profile.currentJobTitle ?? 'No job title'}',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontFamily: 'Outfit'),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF2563EB)),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AlumniAddEditScreen(profile: profile),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                onPressed: () => _deleteConfirm(profile.id, profile.fullName),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── TAB 3: ANALYTICS ────────────────────────────────────
  Widget _buildAnalyticsTab(Map<String, dynamic> analytics) {
    if (analytics.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final total = analytics['total']?.toString() ?? '0';
    final pending = analytics['pending']?.toString() ?? '0';
    final mentors = analytics['mentors']?.toString() ?? '0';
    final requests = analytics['requests_this_month']?.toString() ?? '0';

    final batchMap = Map<int, int>.from(analytics['batches'] ?? {});
    final industryMap = Map<String, int>.from(analytics['industries'] ?? {});
    final locationMap = Map<String, int>.from(analytics['locations'] ?? {});

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Analytics Cards Grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: [
            AlumniAnalyticsCard(
              title: 'Total Alumni',
              value: total,
              subtitle: 'Active verified members',
              icon: Icons.groups_rounded,
              color: const Color(0xFF2563EB),
            ),
            AlumniAnalyticsCard(
              title: 'Pending Approvals',
              value: pending,
              subtitle: 'Awaiting verification',
              icon: Icons.pending_actions_rounded,
              color: const Color(0xFFF59E0B),
            ),
            AlumniAnalyticsCard(
              title: 'Mentors',
              value: mentors,
              subtitle: 'Available to guide',
              icon: Icons.star_rounded,
              color: const Color(0xFF10B981),
            ),
            AlumniAnalyticsCard(
              title: 'Connects (Month)',
              value: requests,
              subtitle: 'Outgoing student asks',
              icon: Icons.chat_bubble_rounded,
              color: const Color(0xFFEC4899),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Batch Distribution Bar Chart
        _buildGraphHeader('Batch Distribution (Year)'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _glassDecoration(),
          child: BatchChartWidget(data: batchMap),
        ),
        const SizedBox(height: 24),

        // Industry Pie Chart
        _buildGraphHeader('Alumni by Industry Sector'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _glassDecoration(),
          child: IndustryPieChartWidget(data: industryMap),
        ),
        const SizedBox(height: 24),

        // Location Breakdown
        _buildGraphHeader('Location Breakdown'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _glassDecoration(),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: locationMap.length,
            itemBuilder: (context, index) {
              final entry = locationMap.entries.toList()[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key, style: const TextStyle(color: Color(0xFF475569), fontFamily: 'Outfit')),
                    Text('${entry.value}', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ─── TAB 4: CONNECT REQUESTS LOG ─────────────────────────
  Widget _buildConnectLogTab(List<AlumniConnectRequest> logs) {
    if (logs.isEmpty) {
      return const Center(
        child: Text(
          'No connection requests logged.',
          style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${logs.length} Log Entries',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton.icon(
                  onPressed: _confirmClearAllLogs,
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: Color(0xFFEF4444)),
                  label: const Text(
                    'Clear All Logs',
                    style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
          );
        }

        final req = logs[index - 1];
        final formattedDate = DateFormat('yMMMd').add_jm().format(req.sentAt);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Student: ${req.senderName}',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: req.deliveryStatus == 'sent'
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : const Color(0xFFEF4444).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      req.deliveryStatus.toUpperCase(),
                      style: TextStyle(
                        color: req.deliveryStatus == 'sent' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFF64748B)),
                    onPressed: () => _confirmDismissSingleLog(req.id),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    splashRadius: 18,
                    tooltip: 'Dismiss Log',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Sent at: $formattedDate',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontFamily: 'Outfit'),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"${req.message}"',
                  style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontFamily: 'Outfit', fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGraphHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 15,
        fontWeight: FontWeight.bold,
        fontFamily: 'Outfit',
      ),
    );
  }

  BoxDecoration _glassDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}
