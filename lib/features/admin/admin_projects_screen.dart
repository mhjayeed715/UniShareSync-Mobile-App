import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:unisharesync_mobile_app/data/models/project_model.dart';
import 'package:unisharesync_mobile_app/services/projects_service.dart';
import 'package:unisharesync_mobile_app/features/projects/create_project_dialog.dart';
import 'package:unisharesync_mobile_app/features/projects/project_detail_screen.dart';

class AdminProjectsScreen extends StatefulWidget {
  const AdminProjectsScreen({super.key});

  @override
  State<AdminProjectsScreen> createState() => _AdminProjectsScreenState();
}

class _AdminProjectsScreenState extends State<AdminProjectsScreen> {
  final ProjectsService _projectsService = ProjectsService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  List<ProjectModel> _projects = [];
  int? _selectedSemester;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final projects = await _projectsService.searchProjects(
        query: _searchController.text,
        semesterNo: _selectedSemester,
      );

      if (!mounted) return;

      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '$error';
        _isLoading = false;
      });
    }
  }

  Future<void> _createProject() async {
    final draft = await showDialog<ProjectDraft>(
      context: context,
      builder: (_) => const CreateProjectDialog(),
    );

    if (draft == null) return;

    try {
      await _projectsService.createProject(draft);
      if (!mounted) return;
      await _loadProjects();
      _showSnackBar('Project created successfully');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Failed to create project: $error');
    }
  }

  Future<void> _editProject(ProjectModel project) async {
    final draft = await showDialog<ProjectDraft>(
      context: context,
      builder: (_) => CreateProjectDialog(existingProject: project),
    );

    if (draft == null) return;

    try {
      await _projectsService.updateProject(
        projectId: project.id,
        draft: draft,
      );
      if (!mounted) return;
      await _loadProjects();
      _showSnackBar('Project updated successfully');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Failed to update project: $error');
    }
  }

  Future<void> _deleteProject(ProjectModel project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to delete "${project.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _projectsService.deleteProject(project.id);
      if (!mounted) return;
      await _loadProjects();
      _showSnackBar('Project deleted successfully');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Failed to delete project: $error');
    }
  }

  Future<void> _updateStatus(ProjectModel project, ProjectStatus newStatus) async {
    try {
      await _projectsService.updateProjectStatus(
        projectId: project.id,
        status: newStatus,
      );
      if (!mounted) return;
      await _loadProjects();
      _showSnackBar('Status updated to ${newStatus.displayName}');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Failed to update status: $error');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
          'Manage Projects',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 24,
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
                  colors: [
                    Color(0xFFF8FBFF),
                    Color(0xFFEAF6FF),
                  ],
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
                color: const Color(0xFF8B5CF6).withOpacity(0.12),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _SearchField(
                        controller: _searchController,
                        onChanged: (_) => _loadProjects(),
                        onClear: () {
                          _searchController.clear();
                          _loadProjects();
                        },
                      ),
                      const SizedBox(height: 10),
                      _SemesterFilter(
                        selectedSemester: _selectedSemester,
                        onChanged: (value) {
                          setState(() => _selectedSemester = value);
                          _loadProjects();
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildProjectsList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProjects,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_projects.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No projects found', style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProjects,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        itemCount: _projects.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final project = _projects[index];
          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProjectDetailScreen(projectId: project.id),
                ),
              ).then((_) => _loadProjects());
            },
            borderRadius: BorderRadius.circular(18),
            child: _AdminProjectCard(
              project: project,
              onEdit: () => _editProject(project),
              onDelete: () => _deleteProject(project),
              onStatusChange: (status) => _updateStatus(project, status),
            ),
          );
        },
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
            hintText: 'Search projects',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: controller.text.isEmpty
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
              borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.2),
            ),
          ),
        ),
      ),
    );
  }
}

class _SemesterFilter extends StatelessWidget {
  const _SemesterFilter({
    required this.selectedSemester,
    required this.onChanged,
  });

  final int? selectedSemester;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.94)),
      ),
      child: DropdownButton<int?>(
        value: selectedSemester,
        isExpanded: true,
        underline: const SizedBox(),
        hint: const Text('All Semesters'),
        items: [
          const DropdownMenuItem(value: null, child: Text('All Semesters')),
          ...List.generate(12, (i) => i + 1).map(
            (sem) => DropdownMenuItem(
              value: sem,
              child: Text('Semester $sem'),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _AdminProjectCard extends StatelessWidget {
  const _AdminProjectCard({
    required this.project,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
  });

  final ProjectModel project;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<ProjectStatus> onStatusChange;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'By ${project.ownerName}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (value) {
                        if (value == 'edit') {
                          onEdit();
                        } else if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_rounded, size: 20),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_rounded, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  project.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: Icons.people_rounded,
                      label: '${project.currentMembers}/${project.maxMembers}',
                    ),
                    _InfoChip(
                      icon: Icons.school_rounded,
                      label: project.semesterLabel,
                    ),
                    _InfoChip(
                      icon: Icons.category_rounded,
                      label: project.category.displayName,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text(
                      'Status:',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<ProjectStatus>(
                        value: project.status,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: ProjectStatus.values.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(
                              status.displayName,
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        }).toList(),
                        onChanged: (status) {
                          if (status != null) onStatusChange(status);
                        },
                      ),
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
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF8B5CF6)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8B5CF6),
            ),
          ),
        ],
      ),
    );
  }
}
