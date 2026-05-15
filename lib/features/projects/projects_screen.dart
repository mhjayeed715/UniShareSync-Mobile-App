import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:unisharesync_mobile_app/data/models/project_join_request.dart';
import 'package:unisharesync_mobile_app/data/models/project_model.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';
import 'package:unisharesync_mobile_app/features/projects/create_project_dialog.dart';
import 'package:unisharesync_mobile_app/services/auth_service.dart';
import 'package:unisharesync_mobile_app/services/projects_service.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final AuthService _authService = AuthService();
  final ProjectsService _projectsService = ProjectsService();
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;
  UserRole? _role;
  bool _isLocalAdmin = false;
  bool _isProfileLoading = true;
  bool _isLoading = true;
  String? _errorMessage;

  List<ProjectModel> _browseProjects = const <ProjectModel>[];
  List<ProjectModel> _managedProjects = const <ProjectModel>[];

  int? _selectedSemester;

  List<int> get _semesterOptions =>
      List<int>.generate(10, (index) => index + 1);

  bool get _isFacultyView => _role == UserRole.faculty;
  bool get _isAdminView => _role == UserRole.admin;
  bool get _canCreate => _role == UserRole.student || _isAdminView;
  bool get _canJoin => _role == UserRole.student;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _isProfileLoading = true;
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final role = await _authService.getCurrentRole();
      final isLocalAdmin = await _authService.isLocalAdminSession();

      if (!mounted) {
        return;
      }

      setState(() {
        _role = role ?? UserRole.student;
        _isLocalAdmin = isLocalAdmin;
        _isProfileLoading = false;
      });

      await _refreshProjects(showLoader: false);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = '$error';
        _isProfileLoading = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshProjects({bool showLoader = true}) async {
    if (_isLocalAdmin && _projectsService.currentUserId == null) {
      setState(() {
        _errorMessage =
            'Local admin mode cannot load projects without a backend session.';
        _isLoading = false;
      });
      return;
    }

    if (showLoader) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final browse = await _projectsService.searchProjects(
        query: _searchController.text,
        semesterNo: _selectedSemester,
      );

      final managed = _isFacultyView
          ? const <ProjectModel>[]
          : await _projectsService.fetchManagedProjects(
              role: _role ?? UserRole.student,
              query: _searchController.text,
              semesterNo: _selectedSemester,
            );

      if (!mounted) {
        return;
      }

      setState(() {
        _browseProjects = browse;
        _managedProjects = managed;
        _isLoading = false;
        _errorMessage = null;
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
    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      _refreshProjects(showLoader: false);
    });
  }

  Future<void> _showCreateProjectDialog() async {
    if (!_canCreate) {
      _showSnackBar('Only students or admins can create projects.');
      return;
    }

    if (_isLocalAdmin && _projectsService.currentUserId == null) {
      _showSnackBar(
        'Local admin mode cannot create projects without a backend session.',
      );
      return;
    }

    final draft = await showDialog<ProjectDraft>(
      context: context,
      builder: (_) => const CreateProjectDialog(),
    );

    if (draft == null) {
      return;
    }

    try {
      await _projectsService.createProject(draft);
      if (!mounted) {
        return;
      }
      await _refreshProjects(showLoader: false);
      _showSnackBar('Project created successfully.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Unable to create project: $error');
    }
  }

  Future<void> _showEditProjectDialog(ProjectModel project) async {
    final draft = await showDialog<ProjectDraft>(
      context: context,
      builder: (_) => CreateProjectDialog(existingProject: project),
    );

    if (draft == null) {
      return;
    }

    try {
      await _projectsService.updateProject(projectId: project.id, draft: draft);
      if (!mounted) {
        return;
      }
      await _refreshProjects(showLoader: false);
      _showSnackBar('Project updated successfully.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Unable to update project: $error');
    }
  }

  Future<void> _handleJoinRequest(ProjectModel project) async {
    try {
      await _projectsService.requestJoinProject(project.id);
      if (!mounted) {
        return;
      }
      await _refreshProjects(showLoader: false);
      _showSnackBar('Join request sent. The owner will review it.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Unable to send join request: $error');
    }
  }

  void _showProjectDetailSheet(ProjectModel project) {
    final joinState = _resolveJoinState(project);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProjectDetailSheet(
        project: project,
        joinState: joinState,
        onJoinTap: () {
          Navigator.pop(context);
          _handleJoinRequest(project);
        },
      ),
    );
  }

  void _showManageProjectSheet(ProjectModel project) {
    final canManage = _canManageProject(project);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManageProjectSheet(
        project: project,
        projectsService: _projectsService,
        canEdit: canManage,
        canDelete: canManage,
        canReviewRequests: canManage,
        onEdit: () {
          Navigator.pop(context);
          _showEditProjectDialog(project);
        },
        onProjectUpdated: () => _refreshProjects(showLoader: false),
        onProjectDeleted: () => _refreshProjects(showLoader: false),
      ),
    );
  }

  bool _canManageProject(ProjectModel project) {
    final currentUserId = _projectsService.currentUserId;
    if (currentUserId == null) {
      return false;
    }
    return _isAdminView || project.ownerId == currentUserId;
  }

  _JoinActionState _resolveJoinState(ProjectModel project) {
    final currentUserId = _projectsService.currentUserId;
    
    // Hide join button if user is the owner
    if (currentUserId != null && project.ownerId == currentUserId) {
      return _JoinActionState.hidden;
    }
    
    if (!_canJoin) {
      return _JoinActionState.hidden;
    }
    if (project.hasUserJoined) {
      return _JoinActionState.joined;
    }
    if (project.joinRequestPending) {
      return _JoinActionState.pending;
    }
    if (project.isRecruiting && !project.isDeadlinePassed && !project.isFull) {
      return _JoinActionState.join;
    }
    return _JoinActionState.hidden;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isProfileLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F8FF),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final tabs = <_ProjectTab>[
      _ProjectTab(label: 'Browse Projects', builder: _buildBrowseProjectsTab),
      if (!_isFacultyView)
        _ProjectTab(
          label: _isAdminView ? 'Manage Projects' : 'My Projects',
          builder: _buildManagedProjectsTab,
        ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Project Collaboration',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
        ),
        centerTitle: false,
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
                color: const Color(0xFF4F9EFF).withOpacity(0.12),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: _buildDescriptionCard(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _SearchField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onClear: () {
                      _searchController.clear();
                      _refreshProjects(showLoader: false);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _SemesterFilter(
                    selectedSemester: _selectedSemester,
                    semesterOptions: _semesterOptions,
                    onSemesterChanged: (value) {
                      setState(() {
                        _selectedSemester = value;
                      });
                      _refreshProjects(showLoader: false);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: DefaultTabController(
                    length: tabs.length,
                    child: Column(
                      children: [
                        if (tabs.length > 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Material(
                              color: Colors.transparent,
                              child: TabBar(
                                indicatorColor: const Color(0xFF4F9EFF),
                                unselectedLabelColor: const Color(0xFF94A3B8),
                                labelColor: const Color(0xFF0F172A),
                                labelStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                                tabs: tabs
                                    .map((tab) => Tab(text: tab.label))
                                    .toList(growable: false),
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: tabs.length > 1
                              ? TabBarView(
                                  children: tabs
                                      .map((tab) => tab.builder())
                                      .toList(growable: false),
                                )
                              : tabs.first.builder(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _canCreate
          ? FloatingActionButton(
              onPressed: _showCreateProjectDialog,
              backgroundColor: const Color(0xFF4F9EFF),
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add_rounded,
                  color: Colors.white, size: 28),
            )
          : null,
    );
  }

  Widget _buildDescriptionCard() {
    final headline = _isFacultyView
        ? 'Browse project groups'
        : 'Join collaborative projects';
    final subtitle = _isFacultyView
        ? 'Explore student projects and track collaboration progress.'
        : 'Create or join campus projects, manage team members, and build together.';

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrowseProjectsTab() {
    if (_isLoading && _browseProjects.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _browseProjects.isEmpty) {
      return _RetryState(
        title: 'Unable to load projects',
        subtitle: _errorMessage!,
        onRetry: _refreshProjects,
      );
    }

    if (_browseProjects.isEmpty) {
      return Center(
        child: _buildEmptyState(
          title: 'No projects available',
          subtitle: 'Check back later for new project opportunities.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshProjects,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _browseProjects.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final project = _browseProjects[index];
          final joinState = _resolveJoinState(project);
          return _ProjectBrowseCard(
            project: project,
            joinState: joinState,
            onTap: () => _showProjectDetailSheet(project),
            onJoinTap: () => _handleJoinRequest(project),
          );
        },
      ),
    );
  }

  Widget _buildManagedProjectsTab() {
    if (_isLoading && _managedProjects.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _managedProjects.isEmpty) {
      return _RetryState(
        title: 'Unable to load projects',
        subtitle: _errorMessage!,
        onRetry: _refreshProjects,
      );
    }

    if (_managedProjects.isEmpty) {
      return Center(
        child: _buildEmptyState(
          title: _isAdminView ? 'No projects found' : 'No projects yet',
          subtitle: _isAdminView
              ? 'Create or wait for students to add projects.'
              : 'Create a project to get started with collaboration.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshProjects,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _managedProjects.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final project = _managedProjects[index];
          return _ProjectMyProjectCard(
            project: project,
            onTap: () => _showProjectDetailSheet(project),
            onManageTap: () => _showManageProjectSheet(project),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.assignment_outlined,
                size: 48,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _ProjectTab {
  const _ProjectTab({required this.label, required this.builder});

  final String label;
  final Widget Function() builder;
}

class _ProjectBrowseCard extends StatelessWidget {
  const _ProjectBrowseCard({
    required this.project,
    required this.joinState,
    required this.onTap,
    required this.onJoinTap,
  });

  final ProjectModel project;
  final _JoinActionState joinState;
  final VoidCallback onTap;
  final VoidCallback onJoinTap;

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
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(14),
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
                              Text(
                                project.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: const Color(0xFF4F9EFF)
                                        .withOpacity(0.15),
                                    backgroundImage: project.ownerAvatarUrl != null
                                        ? NetworkImage(project.ownerAvatarUrl!)
                                        : null,
                                    child: project.ownerAvatarUrl == null
                                        ? Text(
                                            project.ownerName.isNotEmpty
                                                ? project.ownerName[0].toUpperCase()
                                                : 'U',
                                            style: const TextStyle(
                                              color: Color(0xFF4F9EFF),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 10,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'By ${project.ownerName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: project.status == ProjectStatus.recruiting
                                ? const Color(0xFFECFDF5)
                                : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: project.status == ProjectStatus.recruiting
                                  ? const Color(0xFF10B981).withOpacity(0.3)
                                  : const Color(0xFF4F9EFF).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            project.status.displayName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: project.status == ProjectStatus.recruiting
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF2563EB),
                            ),
                          ),
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
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: project.requiredSkills.take(3).map((skill) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            skill,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${project.currentMembers}/${project.maxMembers} Members',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              if (project.memberNames.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: project.memberNames.take(3).map((name) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF475569),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                if (project.memberNames.length > 3)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '+${project.memberNames.length - 3} more',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: project.currentMembers /
                                      project.maxMembers,
                                  minHeight: 4,
                                  backgroundColor:
                                      const Color(0xFFE2E8F0),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                    Color(0xFF4F9EFF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _JoinActionPill(
                          state: joinState,
                          onJoinTap: onJoinTap,
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
    );
  }
}

class _ProjectMyProjectCard extends StatelessWidget {
  const _ProjectMyProjectCard({
    required this.project,
    required this.onTap,
    required this.onManageTap,
  });

  final ProjectModel project;
  final VoidCallback onTap;
  final VoidCallback onManageTap;

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
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(14),
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
                              Text(
                                project.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                project.category,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF7C3AED),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: project.status == ProjectStatus.recruiting
                                ? const Color(0xFFECFDF5)
                                : project.status == ProjectStatus.active
                                    ? const Color(0xFFEFF6FF)
                                    : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            project.status.displayName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: project.status == ProjectStatus.recruiting
                                  ? const Color(0xFF059669)
                                  : project.status == ProjectStatus.active
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${project.currentMembers}/${project.maxMembers} Members',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              if (project.memberNames.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: project.memberNames.take(3).map((name) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3E8FF),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: const Color(0xFFE9D5FF),
                                        ),
                                      ),
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF7C3AED),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                if (project.memberNames.length > 3)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '+${project.memberNames.length - 3} more',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: project.currentMembers /
                                      project.maxMembers,
                                  minHeight: 4,
                                  backgroundColor:
                                      const Color(0xFFE2E8F0),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                    Color(0xFF7C3AED),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onManageTap,
                            borderRadius: BorderRadius.circular(8),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.settings_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
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
    );
  }
}

class _ProjectDetailSheet extends StatelessWidget {
  const _ProjectDetailSheet({
    required this.project,
    required this.joinState,
    required this.onJoinTap,
  });

  final ProjectModel project;
  final _JoinActionState joinState;
  final VoidCallback onJoinTap;

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.88),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white.withOpacity(0.95)),
            ),
            child: DraggableScrollableSheet(
              expand: false,
              maxChildSize: 0.9,
              initialChildSize: 0.7,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          project.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFF4F9EFF)
                                  .withOpacity(0.15),
                              backgroundImage: project.ownerAvatarUrl != null
                                  ? NetworkImage(project.ownerAvatarUrl!)
                                  : null,
                              child: project.ownerAvatarUrl == null
                                  ? Text(
                                      project.ownerName.isNotEmpty
                                          ? project.ownerName[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        color: Color(0xFF4F9EFF),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              project.ownerName,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _DetailRow(
                          label: 'Status',
                          value: project.status.displayName,
                          color: project.status == ProjectStatus.recruiting
                              ? const Color(0xFF10B981)
                              : const Color(0xFF4F9EFF),
                        ),
                        const SizedBox(height: 10),
                        _DetailRow(
                          label: 'Semester',
                          value: project.semesterLabel,
                        ),
                        const SizedBox(height: 10),
                        _DetailRow(
                          label: 'Category',
                          value: project.category,
                        ),
                        const SizedBox(height: 10),
                        _DetailRow(
                          label: 'Members',
                          value:
                              '${project.currentMembers}/${project.maxMembers}',
                        ),
                        const SizedBox(height: 10),
                        _DetailRow(
                          label: 'Deadline',
                          value:
                              '${project.deadline.day}/${project.deadline.month}/${project.deadline.year}',
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          project.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Required Skills',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: project.requiredSkills.map((skill) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                skill,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        if (project.memberNames.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Team Members',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: project.memberNames.map((name) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.person,
                                      size: 14,
                                      color: Color(0xFF6B7280),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF374151),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (joinState == _JoinActionState.join)
                          SizedBox(
                            width: double.infinity,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  onJoinTap();
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Ink(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4F9EFF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Send Join Request',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (joinState == _JoinActionState.pending)
                          _StatusNotice(
                            label: 'Join request pending approval',
                            color: const Color(0xFFF59E0B),
                          ),
                        if (joinState == _JoinActionState.joined)
                          _StatusNotice(
                            label: 'You are part of this project',
                            color: const Color(0xFF10B981),
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ManageProjectSheet extends StatefulWidget {
  const _ManageProjectSheet({
    required this.project,
    required this.projectsService,
    required this.canEdit,
    required this.canDelete,
    required this.canReviewRequests,
    required this.onEdit,
    required this.onProjectUpdated,
    required this.onProjectDeleted,
  });

  final ProjectModel project;
  final ProjectsService projectsService;
  final bool canEdit;
  final bool canDelete;
  final bool canReviewRequests;
  final VoidCallback onEdit;
  final VoidCallback onProjectUpdated;
  final VoidCallback onProjectDeleted;

  @override
  State<_ManageProjectSheet> createState() => _ManageProjectSheetState();
}

class _ManageProjectSheetState extends State<_ManageProjectSheet> {
  late ProjectStatus _selectedStatus;
  late Future<List<ProjectJoinRequest>> _requestsFuture;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.project.status;
    _requestsFuture = widget.projectsService.fetchJoinRequests(widget.project.id);
  }

  void _refreshRequests() {
    setState(() {
      _requestsFuture =
          widget.projectsService.fetchJoinRequests(widget.project.id);
    });
  }

  Future<void> _updateStatus() async {
    if (_selectedStatus == widget.project.status) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _isUpdating = true;
    });
    try {
      await widget.projectsService.updateProjectStatus(
        projectId: widget.project.id,
        status: _selectedStatus,
      );
      if (!mounted) {
        return;
      }
      widget.onProjectUpdated();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Project status updated to ${_selectedStatus.displayName}',
          ),
          backgroundColor: const Color(0xFF7C3AED),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isUpdating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update status: $error'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _reviewRequest(ProjectJoinRequest request, bool approve) async {
    try {
      await widget.projectsService.reviewJoinRequest(
        requestId: request.id,
        approve: approve,
      );
      if (!mounted) {
        return;
      }
      _refreshRequests();
      widget.onProjectUpdated();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Request approved.'
                : 'Request rejected.',
          ),
          backgroundColor:
              approve ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to review request: $error'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _deleteProject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: const Text('This will remove the project permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
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
      await widget.projectsService.deleteProject(widget.project.id);
      if (!mounted) {
        return;
      }
      widget.onProjectDeleted();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project deleted.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete project: $error'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.88),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white.withOpacity(0.95)),
            ),
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Manage Project',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (widget.canEdit) ...[
                          const Text(
                            'Update Project Status',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...ProjectStatus.values.map((status) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedStatus = status;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Ink(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 10),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: _selectedStatus == status
                                                  ? const Color(0xFF7C3AED)
                                                  : const Color(0xFFCBD5E1),
                                              width: 2,
                                            ),
                                          ),
                                          child: _selectedStatus == status
                                              ? Padding(
                                                  padding:
                                                      const EdgeInsets.all(2),
                                                  child: Container(
                                                    decoration:
                                                        const BoxDecoration(
                                                      color:
                                                          Color(0xFF7C3AED),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          status.displayName,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: _selectedStatus == status
                                                ? const Color(0xFF7C3AED)
                                                : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _isUpdating ? null : _updateStatus,
                                borderRadius: BorderRadius.circular(12),
                                child: Ink(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C3AED),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _isUpdating
                                          ? 'Updating...'
                                          : 'Update Status',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (widget.canReviewRequests) ...[
                          const Text(
                            'Join Requests',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 10),
                          FutureBuilder<List<ProjectJoinRequest>>(
                            future: _requestsFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  !snapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              final requests =
                                  snapshot.data ?? const <ProjectJoinRequest>[];
                              final pending = requests
                                  .where((request) => request.isPending)
                                  .toList(growable: false);

                              if (pending.isEmpty) {
                                return Text(
                                  'No pending requests.',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              }

                              return Column(
                                children: pending
                                    .map(
                                      (request) => _JoinRequestTile(
                                        request: request,
                                        onApprove: () =>
                                            _reviewRequest(request, true),
                                        onReject: () =>
                                            _reviewRequest(request, false),
                                      ),
                                    )
                                    .toList(growable: false),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                        Row(
                          children: [
                            if (widget.canEdit) ...[
                              Expanded(
                                child: _SecondaryActionButton(
                                  label: 'Edit Details',
                                  onTap: widget.onEdit,
                                ),
                              ),
                            ],
                            if (widget.canEdit && widget.canDelete)
                              const SizedBox(width: 12),
                            if (widget.canDelete)
                              Expanded(
                                child: _DangerActionButton(
                                  label: 'Delete Project',
                                  onTap: _deleteProject,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: (color ?? const Color(0xFF4F9EFF)).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color ?? const Color(0xFF4F9EFF),
            ),
          ),
        ),
      ],
    );
  }
}

enum _JoinActionState { hidden, join, pending, joined }

class _JoinActionPill extends StatelessWidget {
  const _JoinActionPill({
    required this.state,
    required this.onJoinTap,
  });

  final _JoinActionState state;
  final VoidCallback onJoinTap;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _JoinActionState.hidden:
        return const SizedBox.shrink();
      case _JoinActionState.join:
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onJoinTap,
            borderRadius: BorderRadius.circular(8),
            child: Ink(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF4F9EFF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Join',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      case _JoinActionState.pending:
        return _StatusChip(
          label: 'Pending',
          color: const Color(0xFFF59E0B),
        );
      case _JoinActionState.joined:
        return _StatusChip(
          label: 'Joined',
          color: const Color(0xFF10B981),
        );
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _StatusNotice extends StatelessWidget {
  const _StatusNotice({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
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
            hintText: 'Search by title, description or category',
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

class _SemesterFilter extends StatelessWidget {
  const _SemesterFilter({
    required this.selectedSemester,
    required this.semesterOptions,
    required this.onSemesterChanged,
  });

  final int? selectedSemester;
  final List<int> semesterOptions;
  final ValueChanged<int?> onSemesterChanged;

  @override
  Widget build(BuildContext context) {
    final semesterItems = <int?>[null, ...semesterOptions];

    return _FilterDropdown<int?>(
      value: selectedSemester,
      items: semesterItems,
      labelBuilder: (value) =>
          value == null ? 'All semesters' : 'Semester $value',
      onChanged: onSemesterChanged,
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.labelBuilder,
  });

  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T value) labelBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.94)),
      ),
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
        onChanged: onChanged,
        items: items
            .map(
              (item) => DropdownMenuItem<T>(
                value: item,
                child: Text(
                  labelBuilder(item),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            )
            .toList(growable: false),
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
  final Future<void> Function({bool showLoader}) onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 46,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => onRetry(showLoader: true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4F9EFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _JoinRequestTile extends StatelessWidget {
  const _JoinRequestTile({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final ProjectJoinRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.86),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.95)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF4F9EFF).withOpacity(0.15),
              backgroundImage: request.requesterAvatarUrl != null
                  ? NetworkImage(request.requesterAvatarUrl!)
                  : null,
              child: request.requesterAvatarUrl == null
                  ? Text(
                      request.requesterName.isNotEmpty
                          ? request.requesterName[0].toUpperCase()
                          : 'S',
                      style: const TextStyle(
                        color: Color(0xFF4F9EFF),
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.requesterName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Requested ${_relativeTime(request.requestedAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _MiniActionButton(
              label: 'Approve',
              color: const Color(0xFF10B981),
              onTap: onApprove,
            ),
            const SizedBox(width: 6),
            _MiniActionButton(
              label: 'Reject',
              color: const Color(0xFFF59E0B),
              onTap: onReject,
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime value) {
    final delta = DateTime.now().difference(value);
    if (delta.inMinutes < 1) return 'just now';
    if (delta.inHours < 1) return '${delta.inMinutes}m ago';
    if (delta.inDays < 1) return '${delta.inHours}h ago';
    if (delta.inDays < 7) return '${delta.inDays}d ago';
    return '${value.day}/${value.month}/${value.year}';
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DangerActionButton extends StatelessWidget {
  const _DangerActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB91C1C),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
