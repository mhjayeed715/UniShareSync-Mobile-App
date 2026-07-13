import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/data/models/project_model.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';
import 'package:unisharesync_mobile_app/providers/project_hub_providers.dart';
import 'package:unisharesync_mobile_app/features/projects/project_create_screen.dart';
import 'package:unisharesync_mobile_app/features/projects/supervisor_assignment_screen.dart';
import 'package:unisharesync_mobile_app/features/projects/project_join_requests_screen.dart';
import 'package:unisharesync_mobile_app/features/projects/project_members_screen.dart';

class ProjectSettingsScreen extends ConsumerStatefulWidget {
  const ProjectSettingsScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<ProjectSettingsScreen> createState() => _ProjectSettingsScreenState();
}

class _ProjectSettingsScreenState extends ConsumerState<ProjectSettingsScreen> {
  bool _isUpdatingStatus = false;

  Future<void> _updateStatus(ProjectStatus newStatus) async {
    setState(() => _isUpdatingStatus = true);
    try {
      await ref.read(projectsServiceProvider).updateProjectStatus(
            projectId: widget.projectId,
            status: newStatus,
          );
      ref.invalidate(singleProjectProvider(widget.projectId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Project status updated to ${newStatus.displayName}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, ProjectModel project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${project.title}"? This action is permanent and cannot be undone.'),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(projectsServiceProvider).deleteProject(widget.projectId);
        ref.invalidate(discoverProjectsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project deleted successfully.')),
          );
          // Pop settings screen and details screen to return to projects hub
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete project: $e')),
          );
        }
      }
    }
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
        title: const Text(
          'Project Settings',
          style: TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          // Light gradient background
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

              final isOwner = project.ownerId == currentUserId;
              final isAdmin = roleAsync.valueOrNull == UserRole.admin;
              final hasControl = isOwner || isAdmin;

              if (!hasControl) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'You do not have permission to manage this project settings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
                    ),
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Section
                    _buildSectionHeader('Project Status'),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.88),
                            border: Border.all(color: Colors.white.withOpacity(0.95)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Update the current lifecycle state of your project. This affects visibility and collaboration.',
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              _isUpdatingStatus
                                  ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                                  : Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<ProjectStatus>(
                                          value: project.status,
                                          items: ProjectStatus.values.map((status) {
                                            return DropdownMenuItem(
                                              value: status,
                                              child: Text(
                                                status.displayName,
                                                style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (status) {
                                            if (status != null) _updateStatus(status);
                                          },
                                          isExpanded: true,
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Actions Section
                    _buildSectionHeader('Actions'),
                    _buildSettingsOption(
                      icon: Icons.edit_outlined,
                      title: 'Edit Project Details',
                      subtitle: 'Change title, description, skills, category, or visibility',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProjectCreateScreen(existingProject: project),
                          ),
                        ).then((_) => ref.invalidate(singleProjectProvider(widget.projectId)));
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSettingsOption(
                      icon: Icons.person_add_alt_1_outlined,
                      title: 'Manage Faculty Supervisors',
                      subtitle: 'Send and manage invitations to faculty supervisors',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SupervisorAssignmentScreen(projectId: widget.projectId),
                          ),
                        ).then((_) => ref.invalidate(singleProjectProvider(widget.projectId)));
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSettingsOption(
                      icon: Icons.group_outlined,
                      title: 'Manage Team Members',
                      subtitle: 'View, monitor, and remove project members',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProjectMembersScreen(projectId: widget.projectId),
                          ),
                        ).then((_) => ref.invalidate(singleProjectProvider(widget.projectId)));
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSettingsOption(
                      icon: Icons.mail_outline_rounded,
                      title: 'Review Join Requests',
                      subtitle: 'Approve or decline requests from students to join your project',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProjectJoinRequestsScreen(projectId: widget.projectId),
                          ),
                        ).then((_) => ref.invalidate(singleProjectProvider(widget.projectId)));
                      },
                    ),

                    const SizedBox(height: 32),

                    // Danger Zone
                    _buildSectionHeader('Danger Zone', isDanger: true),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.04),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.15)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: const CircleAvatar(
                            backgroundColor: Colors.redAccent,
                            child: Icon(Icons.delete_forever, color: Colors.white),
                          ),
                          title: const Text(
                            'Delete Project',
                            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            'Permanently remove this project, tasks, whiteboard, and history.',
                            style: TextStyle(color: Colors.black54, fontSize: 12),
                          ),
                          onTap: () => _confirmDelete(context, project),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent))),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool isDanger = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: isDanger ? Colors.redAccent : const Color(0xFF0F172A),
          fontFamily: 'Outfit',
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildSettingsOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF2563EB).withOpacity(0.12),
              child: Icon(icon, color: const Color(0xFF2563EB)),
            ),
            title: Text(title, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
            subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF64748B)),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}
