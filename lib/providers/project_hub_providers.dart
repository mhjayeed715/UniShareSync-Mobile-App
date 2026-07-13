import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/data/models/project_model.dart';
import 'package:unisharesync_mobile_app/data/models/profile_model.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';
import 'package:unisharesync_mobile_app/services/profile_service.dart';
import 'package:unisharesync_mobile_app/services/auth_service.dart';
import 'package:unisharesync_mobile_app/services/projects_service.dart';

final projectsServiceProvider = Provider<ProjectsService>((ref) {
  return ProjectsService();
});

class ProjectHubFilters {
  const ProjectHubFilters({
    this.query,
    this.semesterNo,
    this.status,
    this.projectType,
    this.category,
    this.skills,
  });

  final String? query;
  final int? semesterNo;
  final ProjectStatus? status;
  final ProjectType? projectType;
  final ProjectCategory? category;
  final List<String>? skills;

  ProjectHubFilters copyWith({
    String? query,
    int? semesterNo,
    ProjectStatus? status,
    ProjectType? projectType,
    ProjectCategory? category,
    List<String>? skills,
    bool clearSemester = false,
  }) {
    return ProjectHubFilters(
      query: query ?? this.query,
      semesterNo: clearSemester ? null : (semesterNo ?? this.semesterNo),
      status: status ?? this.status,
      projectType: projectType ?? this.projectType,
      category: category ?? this.category,
      skills: skills ?? this.skills,
    );
  }
}

final projectHubFiltersProvider = StateProvider<ProjectHubFilters>((ref) {
  return const ProjectHubFilters();
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final discoverProjectsProvider = FutureProvider<List<ProjectModel>>((ref) async {
  ref.watch(authStateProvider);
  final service = ref.watch(projectsServiceProvider);
  final filters = ref.watch(projectHubFiltersProvider);

  return service.searchProjects(
    query: filters.query,
    semesterNo: filters.semesterNo,
    status: filters.status,
    projectType: filters.projectType,
    category: filters.category,
    skills: filters.skills,
  );
});

final facultyMonitoredProjectsProvider = FutureProvider<List<ProjectModel>>((ref) async {
  ref.watch(authStateProvider);
  final service = ref.watch(projectsServiceProvider);
  return service.fetchFacultyMonitoredProjects();
});

final singleProjectProvider = FutureProvider.family<ProjectModel?, String>((ref, projectId) async {
  ref.watch(authStateProvider);
  final service = ref.watch(projectsServiceProvider);
  return service.fetchProjectById(projectId);
});

final currentUserProfileProvider = FutureProvider<ProfileModel?>((ref) async {
  ref.watch(authStateProvider);
  return ProfileService().getCurrentProfile();
});

final currentUserRoleProvider = FutureProvider<UserRole?>((ref) async {
  final profile = await ref.watch(currentUserProfileProvider.future);
  if (profile != null) return profile.role;
  return AuthService().getCurrentRole();
});
