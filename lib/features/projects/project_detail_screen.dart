import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/data/models/project_model.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';
import 'package:unisharesync_mobile_app/features/projects/kanban_board_screen.dart';
import 'package:unisharesync_mobile_app/features/projects/project_whiteboard_screen.dart';
import 'package:unisharesync_mobile_app/features/projects/project_settings_screen.dart';
import 'package:unisharesync_mobile_app/features/faculty/faculty_project_monitor_screen.dart';
import 'package:unisharesync_mobile_app/providers/project_hub_providers.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(singleProjectProvider(widget.projectId));
    final roleAsync = ref.watch(currentUserRoleProvider);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text('Projects', style: TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        actions: [
          projectAsync.when(
            data: (project) {
              final isOwner = project != null && project.ownerId == currentUserId;
              final isAdmin = roleAsync.valueOrNull == UserRole.admin;
              if (project == null || !(isOwner || isAdmin)) return const SizedBox();

              return IconButton(
                icon: const Icon(Icons.settings, color: Color(0xFF0F172A)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProjectSettingsScreen(projectId: widget.projectId)),
                  ).then((_) => ref.invalidate(singleProjectProvider(widget.projectId)));
                },
              );
            },
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          )
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
          projectAsync.when(
            data: (project) {
              if (project == null) {
                return const Center(child: Text('Project not found.', style: TextStyle(color: Color(0xFF0F172A))));
              }

              final isSupervisor = project.supervisors.any(
                (sv) => sv.facultyId == currentUserId && sv.status == SupervisorInviteStatus.accepted,
              );
              final isMember = project.hasUserJoined || project.ownerId == currentUserId || isSupervisor;

              return Column(
            children: [
              // Banner & Core Info
              _buildProjectHeader(project),
              const SizedBox(height: 12),

              // Quick action buttons for Kanban & Whiteboard if a member
              if (isMember) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          label: 'Kanban Board',
                          icon: Icons.dashboard_outlined,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => KanbanBoardScreen(projectId: project.id)),
                            ).then((_) {
                              ref.invalidate(singleProjectProvider(widget.projectId));
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          label: 'Whiteboard',
                          icon: Icons.gesture_outlined,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ProjectWhiteboardScreen(projectId: project.id)),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (isSupervisor) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.analytics_outlined),
                      label: const Text('Access Supervisor Panel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => FacultyProjectMonitorScreen(projectId: project.id)),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Details Tabs
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TabBar(
                  controller: _tabController,
                  dividerColor: Colors.transparent,
                  indicatorColor: const Color(0xFF2563EB),
                  labelColor: const Color(0xFF2563EB),
                  unselectedLabelColor: const Color(0xFF64748B),
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Members'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(project, isMember, currentUserId, roleAsync.valueOrNull),
                    _buildMembersTab(project),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent))),
      ),
    ],
  ),
);
}

  Widget _buildProjectHeader(ProjectModel project) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.88),
              border: Border.all(color: Colors.white.withOpacity(0.95)),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      project.projectCode,
                      style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    if (project.isAtRisk)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: const Text('AT RISK', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  project.title,
                  style: const TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  project.description,
                  style: const TextStyle(color: Color(0xFF475569), fontSize: 14),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Progress:', style: TextStyle(color: Color(0xFF475569), fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: project.progressPct / 100,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${project.progressPct}%',
                      style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({required String label, required IconData icon, required VoidCallback onPressed}) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(ProjectModel project, bool isMember, String? currentUserId, UserRole? currentUserRole) {
    // Check if the current user is faculty and has a pending supervision invitation
    ProjectSupervisorModel? pendingSv;
    for (final sv in project.supervisors) {
      if (sv.facultyId == currentUserId && sv.status == SupervisorInviteStatus.pending) {
        pendingSv = sv;
        break;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // If current user is faculty and has a pending supervision invitation, show accept/decline actions
          if (currentUserRole == UserRole.faculty && pendingSv != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Supervision Invitation',
                    style: TextStyle(
                      color: Color(0xFF1E40AF),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'You have been invited to supervise this project.',
                    style: TextStyle(color: Color(0xFF1E3A8A), fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () async {
                            try {
                              await ref.read(projectsServiceProvider).respondToSupervision(project.id, true);
                              ref.invalidate(singleProjectProvider(widget.projectId));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Accepted supervision invitation')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to accept: $e')),
                                );
                              }
                            }
                          },
                          child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () async {
                            try {
                              await ref.read(projectsServiceProvider).respondToSupervision(project.id, false);
                              ref.invalidate(singleProjectProvider(widget.projectId));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Declined supervision invitation')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to decline: $e')),
                                );
                              }
                            }
                          },
                          child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // If not member and user is student, show Join Request Button
          if (!isMember && currentUserRole == UserRole.student) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: project.joinRequestPending
                    ? null
                    : () async {
                        try {
                          await ref.read(projectsServiceProvider).requestJoinProject(project.id);
                          ref.invalidate(singleProjectProvider(widget.projectId));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Join request sent successfully!')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to send join request: $e')),
                            );
                          }
                        }
                      },
                child: Text(
                  project.joinRequestPending ? 'Join Request Pending' : 'Send Join Request',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          _buildSectionHeader('Details'),
          _buildDetailRow('Project Type', project.projectType.displayName),
          _buildDetailRow('Category', project.category.displayName),
          _buildDetailRow('Status', project.status.displayName),
          if (project.courseCode != null) ...[
            _buildDetailRow('Course Code', project.courseCode!),
            _buildDetailRow('Course Name', project.courseName ?? ''),
          ],
          _buildDetailRow('Team Size limit', '${project.maxMembers} members'),
          _buildDetailRow('Progress Measure', '${project.progressPct}% (completed Kanban tasks)'),

          const SizedBox(height: 18),

          _buildSectionHeader('Required Skills'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: project.requiredSkills.map((skill) {
              return Chip(
                label: Text(skill, style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                backgroundColor: const Color(0xFF2563EB).withOpacity(0.12),
                side: BorderSide(color: const Color(0xFF2563EB).withOpacity(0.2)),
              );
            }).toList(),
          ),

          const SizedBox(height: 18),

          // Supervisors feedback deck
          _buildSectionHeader('Faculty Supervisors'),
          if (project.supervisors.isEmpty)
            const Text('No faculty supervisor assigned yet.', style: TextStyle(color: Color(0xFF64748B)))
          else
            ...project.supervisors.map((sv) {
              return Card(
                color: Colors.white.withOpacity(0.88),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withOpacity(0.95)),
                ),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF2563EB),
                        child: Text(sv.facultyName[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sv.facultyName, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                              'Invite Status: ${sv.status.name.toUpperCase()}',
                              style: TextStyle(
                                color: sv.status == SupervisorInviteStatus.accepted ? Colors.green.shade700 : Colors.amber.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (sv.feedbackNote != null) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Feedback History:',
                                style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                sv.feedbackNote!,
                                style: const TextStyle(color: Color(0xFF475569), fontStyle: FontStyle.italic, fontSize: 13),
                              )
                            ]
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMembersTab(ProjectModel project) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: project.memberNames.length,
      itemBuilder: (context, index) {
        final memberName = project.memberNames[index];
        final isOwner = index == 0; // Owner is usually first in our members name query mapping
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.88),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.95)),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isOwner ? const Color(0xFF06B6D4) : const Color(0xFF2563EB),
                  child: Text(memberName[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                ),
                title: Text(memberName, style: const TextStyle(color: Color(0xFF0F172A))),
                trailing: isOwner
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('OWNER', style: TextStyle(color: Color(0xFF0284C7), fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontFamily: 'Outfit',
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
