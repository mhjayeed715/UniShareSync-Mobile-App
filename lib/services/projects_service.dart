import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/data/models/project_join_request.dart';
import 'package:unisharesync_mobile_app/data/models/project_model.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';
import 'package:unisharesync_mobile_app/services/profile_service.dart';

class ProjectsService {
  ProjectsService({SupabaseClient? client, ProfileService? profileService})
      : _client = client ?? Supabase.instance.client,
        _profileService = profileService ?? ProfileService(client: client);

  final SupabaseClient _client;
  final ProfileService _profileService;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<ProjectModel>> searchProjects({
    String? query,
    int? semesterNo,
    ProjectStatus? status,
  }) async {
    var request = _client.from('projects').select();

    if (semesterNo != null) {
      request = request.eq('semester_no', semesterNo);
    }

    if (status != null) {
      request = request.eq('status', status.storageValue);
    }

    final trimmedQuery = (query ?? '').trim();
    if (trimmedQuery.isNotEmpty) {
      final escaped = trimmedQuery.replaceAll('%', r'\%');
      request = request.or(
        'title.ilike.%$escaped%,description.ilike.%$escaped%,category.ilike.%$escaped%',
      );
    }

    final response = await request.order('created_at', ascending: false);

    final projects = (response as List<dynamic>)
        .map((row) => ProjectModel.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);

    return _applyJoinRequestStatus(projects);
  }

  Future<List<ProjectModel>> fetchManagedProjects({
    required UserRole role,
    String? query,
    int? semesterNo,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      return const <ProjectModel>[];
    }

    var request = _client.from('projects').select();

    if (role != UserRole.admin) {
      request = request.eq('owner_id', userId);
    }

    if (semesterNo != null) {
      request = request.eq('semester_no', semesterNo);
    }

    final trimmedQuery = (query ?? '').trim();
    if (trimmedQuery.isNotEmpty) {
      final escaped = trimmedQuery.replaceAll('%', r'\%');
      request = request.or(
        'title.ilike.%$escaped%,description.ilike.%$escaped%,category.ilike.%$escaped%',
      );
    }

    final response = await request.order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((row) => ProjectModel.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<ProjectModel> createProject(ProjectDraft draft) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to create a project.');
    }

    final profile = await _profileService.getCurrentProfile();
    if (profile == null) {
      throw StateError('Profile not found for current user.');
    }

    if (profile.role == UserRole.faculty) {
      throw StateError('Faculty members cannot create projects.');
    }

    final payload = {
      'title': draft.title.trim(),
      'description': draft.description.trim(),
      'category': draft.category.trim(),
      'semester_no': draft.semesterNo,
      'max_members': draft.maxMembers,
      'current_members': 1,
      'required_skills': draft.requiredSkills,
      'deadline': draft.deadline.toIso8601String(),
      'status': ProjectStatus.recruiting.storageValue,
      'owner_id': user.id,
      'owner_name': profile.fullName,
      'owner_avatar_url': profile.avatarUrl,
    };

    final inserted = await _client
        .from('projects')
        .insert(payload)
        .select()
        .single();

    await _client.from('project_members').insert({
      'project_id': inserted['id'],
      'user_id': user.id,
      'role': 'owner',
    });

    return ProjectModel.fromMap(Map<String, dynamic>.from(inserted));
  }

  Future<ProjectModel> updateProject({
    required String projectId,
    required ProjectDraft draft,
  }) async {
    final payload = {
      'title': draft.title.trim(),
      'description': draft.description.trim(),
      'category': draft.category.trim(),
      'semester_no': draft.semesterNo,
      'max_members': draft.maxMembers,
      'required_skills': draft.requiredSkills,
      'deadline': draft.deadline.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final updated = await _client
        .from('projects')
        .update(payload)
        .eq('id', projectId)
        .select()
        .single();

    return ProjectModel.fromMap(Map<String, dynamic>.from(updated));
  }

  Future<void> updateProjectStatus({
    required String projectId,
    required ProjectStatus status,
  }) async {
    await _client.from('projects').update({
      'status': status.storageValue,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', projectId);
  }

  Future<void> deleteProject(String projectId) async {
    await _client.from('projects').delete().eq('id', projectId);
  }

  Future<void> requestJoinProject(String projectId) async {
    try {
      print('DEBUG: Requesting to join project: $projectId');
      await _client.rpc('request_project_join', params: {
        'p_project_id': projectId,
      });
      print('DEBUG: Join request successful');
    } catch (e) {
      print('DEBUG: Join request error: $e');
      rethrow;
    }
  }

  Future<void> reviewJoinRequest({
    required String requestId,
    required bool approve,
  }) async {
    await _client.rpc('review_project_join_request', params: {
      'p_request_id': requestId,
      'p_action': approve ? 'approve' : 'reject',
    });
  }

  Future<List<ProjectJoinRequest>> fetchJoinRequests(String projectId) async {
    try {
      print('DEBUG: Fetching join requests for project: $projectId');
      final response = await _client
          .from('project_join_requests')
          .select()
          .eq('project_id', projectId)
          .order('created_at', ascending: false);

      print('DEBUG: Join requests response: $response');
      final requests = (response as List<dynamic>)
          .map((row) =>
              ProjectJoinRequest.fromMap(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      print('DEBUG: Parsed ${requests.length} join requests');
      return requests;
    } catch (e) {
      print('DEBUG: Fetch join requests error: $e');
      rethrow;
    }
  }

  Future<List<ProjectModel>> _applyJoinRequestStatus(
    List<ProjectModel> projects,
  ) async {
    final userId = currentUserId;
    if (userId == null || projects.isEmpty) {
      return projects;
    }

    final response = await _client
        .from('project_join_requests')
        .select('project_id, status')
        .eq('requester_id', userId);

    final statusByProjectId = <String, String>{};
    for (final row in response as List<dynamic>) {
      final data = Map<String, dynamic>.from(row);
      final projectId = data['project_id']?.toString();
      final status = data['status']?.toString();
      if (projectId != null && status != null) {
        statusByProjectId[projectId] = status;
      }
    }

    return projects
        .map((project) {
          final status = statusByProjectId[project.id];
          if (status == null) {
            return project;
          }
          final isApproved = status == 'approved';
          final isPending = status == 'pending';
          return project.copyWith(
            hasUserJoined: isApproved,
            joinRequestPending: isPending,
          );
        })
        .toList(growable: false);
  }

}
