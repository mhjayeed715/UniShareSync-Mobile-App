import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/data/models/project_model.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';
import 'package:unisharesync_mobile_app/features/projects/components/project_filter_sheet.dart';
import 'package:unisharesync_mobile_app/features/projects/project_create_screen.dart';
import 'package:unisharesync_mobile_app/features/projects/project_detail_screen.dart';
import 'package:unisharesync_mobile_app/features/faculty/faculty_monitoring_screen.dart';
import 'package:unisharesync_mobile_app/providers/project_hub_providers.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(projectHubFiltersProvider);
    final projectsAsync = ref.watch(discoverProjectsProvider);
    final roleAsync = ref.watch(currentUserRoleProvider);

    return roleAsync.when(
      data: (role) {
        final isFaculty = role == UserRole.faculty;
        final isAdmin = role == UserRole.admin;

        // If admin, we don't need any tabs. They just get a single list.
        if (isAdmin) {
          return Scaffold(
            backgroundColor: const Color(0xFFF4F8FF),
            appBar: _buildAppBar(context),
            body: Stack(
              children: [
                _buildBackgroundGlows(),
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: _buildSearchBar(ref, filters),
                    ),
                    _buildSemesterFilterRow(ref, filters),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _buildProjectGrid(projectsAsync, mode: 'discover'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        final tabCount = isFaculty ? 3 : 2;

        return DefaultTabController(
          key: ValueKey('projects_tab_${role?.name}'),
          length: tabCount,
          child: Scaffold(
            backgroundColor: const Color(0xFFF4F8FF),
            appBar: _buildAppBar(context),
            body: Stack(
              children: [
                _buildBackgroundGlows(),
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: _buildSearchBar(ref, filters),
                    ),
                    _buildSemesterFilterRow(ref, filters),
                    const SizedBox(height: 12),
                    _buildTabBarContainer(isFaculty),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TabBarView(
                        children: isFaculty
                            ? [
                                _buildProjectGrid(projectsAsync, mode: 'supervisor_requests'),
                                _buildProjectGrid(projectsAsync, mode: 'discover'),
                                const FacultyMonitoringScreen(),
                              ]
                            : [
                                _buildProjectGrid(projectsAsync, mode: 'discover'),
                                _buildProjectGrid(projectsAsync, mode: 'my_projects'),
                              ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            floatingActionButton: (role == UserRole.admin || role == UserRole.faculty)
                ? null
                : FloatingActionButton(
                    backgroundColor: const Color(0xFF2563EB),
                    child: const Icon(Icons.add, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProjectCreateScreen()),
                      ).then((_) => ref.refresh(discoverProjectsProvider));
                    },
                  ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent)))),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      title: const Text(
        'Projects',
        style: TextStyle(
          color: Color(0xFF0F172A),
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w800,
          fontSize: 26,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_list, color: Color(0xFF0F172A)),
          onPressed: () => _showFilterSheet(context),
        ),
      ],
    );
  }

  Widget _buildBackgroundGlows() {
    return Stack(
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
          top: -100,
          right: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2563EB).withOpacity(0.06),
            ),
          ),
        ),
        Positioned(
          bottom: -80,
          left: -100,
          child: Container(
            width: 350,
            height: 350,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF06B6D4).withOpacity(0.05),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(WidgetRef ref, ProjectHubFilters filters) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Color(0xFF0F172A)),
            onChanged: (val) {
              ref.read(projectHubFiltersProvider.notifier).state =
                  filters.copyWith(query: val);
            },
            decoration: InputDecoration(
              hintText: 'Search course code, skills, or titles...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF2563EB)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSemesterFilterRow(WidgetRef ref, ProjectHubFilters filters) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 13, // Semester 1-12 + "All"
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final semNo = index;
          final isSelected = isAll ? filters.semesterNo == null : filters.semesterNo == semNo;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                isAll ? 'All Semesters' : 'Sem $semNo',
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                  fontWeight: FontWeight.bold,
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF2563EB),
              backgroundColor: Colors.white.withOpacity(0.88),
              side: BorderSide(
                color: isSelected ? const Color(0xFF2563EB) : Colors.white.withOpacity(0.95),
              ),
              onSelected: (selected) {
                if (selected) {
                  ref.read(projectHubFiltersProvider.notifier).state =
                      filters.copyWith(
                        semesterNo: isAll ? null : semNo,
                        clearSemester: isAll,
                      );
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabBarContainer(bool isFaculty) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.95)),
      ),
      child: TabBar(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: const Color(0xFF2563EB).withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3)),
        ),
        labelColor: const Color(0xFF2563EB),
        unselectedLabelColor: const Color(0xFF64748B),
        tabs: isFaculty
            ? const [
                Tab(text: 'Supervisor Requests'),
                Tab(text: 'All Projects'),
                Tab(text: 'Course Monitoring'),
              ]
            : const [
                Tab(text: 'Discover'),
                Tab(text: 'My Projects'),
              ],
      ),
    );
  }

  Widget _buildProjectGrid(AsyncValue<List<ProjectModel>> projectsAsync, {required String mode}) {
    return projectsAsync.when(
      data: (projects) {
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        final List<ProjectModel> list;
        if (mode == 'my_projects') {
          list = projects.where((p) => p.hasUserJoined || p.ownerId == currentUserId).toList();
        } else if (mode == 'supervisor_requests') {
          list = projects.where((p) => p.supervisors.any((sv) => sv.facultyId == currentUserId)).toList();
        } else {
          list = projects;
        }

        if (list.isEmpty) {
          return const Center(
            child: Text(
              'No projects found matching current tags.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            mainAxisSpacing: 16,
            childAspectRatio: 2.1,
          ),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final project = list[index];
            return _buildProjectCard(project);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text(
          'Error: $err',
          style: const TextStyle(color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _buildProjectCard(ProjectModel project) {
    final hasRisk = project.isAtRisk;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasRisk
                  ? Colors.redAccent.withOpacity(0.8)
                  : Colors.white.withOpacity(0.95),
              width: hasRisk ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProjectDetailScreen(projectId: project.id),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            project.title,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Sem ${project.semesterNo}',
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      project.description,
                      style: const TextStyle(color: Color(0xFF475569), fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.people_outline, color: Color(0xFF64748B), size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${project.currentMembers}/${project.maxMembers}',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                            ),
                            if (project.courseCode != null) ...[
                              const SizedBox(width: 12),
                              const Icon(Icons.assignment_outlined, color: Color(0xFF64748B), size: 16),
                              const SizedBox(width: 4),
                              Text(
                                project.courseCode!,
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                              ),
                            ]
                          ],
                        ),
                        // Progress ring overlay
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                value: project.progressPct / 100,
                                strokeWidth: 3.5,
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                              ),
                            ),
                            Text(
                              '${project.progressPct}%',
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ProjectFilterSheet(),
    ).then((_) => ref.refresh(discoverProjectsProvider));
  }
}
