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

    final withStatus = await _applyJoinRequestStatus(projects);
    return _applyMemberNames(withStatus);
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

    final projects = (response as List<dynamic>)
        .map((row) => ProjectModel.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);

    return _applyMemberNames(projects);
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
      
      // 1. Fetch project owner and title BEFORE RPC call
      final project = await _client
          .from('projects')
          .select('owner_id, title')
          .eq('id', projectId)
          .single();
      final ownerId = project['owner_id'] as String;
      final projectTitle = project['title'] as String;

      // 2. Perform the RPC join request
      await _client.rpc('request_project_join', params: {
        'p_project_id': projectId,
      });
      print('DEBUG: Join request successful');

      // 3. Fetch current user's profile to get their name
      final profile = await _profileService.getCurrentProfile();
      final senderName = profile?.fullName ?? 'A student';

      // 4. Send push notification to project owner
      await _sendPushNotification(
        userId: ownerId,
        title: 'New Join Request',
        body: '$senderName wants to join your project "$projectTitle"',
        type: 'project_request',
        data: {'project_id': projectId},
        skipInApp: false,
      );
    } catch (e) {
      print('DEBUG: Join request error: $e');
      rethrow;
    }
  }

  Future<void> reviewJoinRequest({
    required String requestId,
    required bool approve,
  }) async {
    try {
      // 1. Fetch request details first (requester_id, project_id, and project title)
      final request = await _client
          .from('project_join_requests')
          .select('requester_id, project_id, projects(title)')
          .eq('id', requestId)
          .single();
      
      final requesterId = request['requester_id'] as String;
      final projectId = request['project_id'] as String;
      final projectMap = request['projects'] as Map<String, dynamic>;
      final projectTitle = projectMap['title'] as String;
      
      // Get owner's profile to get owner's name
      final ownerProfile = await _profileService.getCurrentProfile();
      final ownerName = ownerProfile?.fullName ?? 'Project Owner';

      // 2. Perform the review action via RPC
      await _client.rpc('review_project_join_request', params: {
        'p_request_id': requestId,
        'p_action': approve ? 'approve' : 'reject',
      });

      // 3. Send push notification to requester
      final String title = approve ? 'Join Request Approved' : 'Join Request Declined';
      final String body = approve
          ? '$ownerName approved your request to join "$projectTitle"'
          : 'Your request to join "$projectTitle" was declined';

      await _sendPushNotification(
        userId: requesterId,
        title: title,
        body: body,
        type: 'project_request',
        data: {
          'project_id': projectId,
          'status': approve ? 'approved' : 'rejected',
        },
        skipInApp: false,
      );
    } catch (e) {
      print('DEBUG: Review join request error: $e');
      rethrow;
    }
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

  Future<List<ProjectModel>> _applyMemberNames(
    List<ProjectModel> projects,
  ) async {
    if (projects.isEmpty) return projects;

    final projectIds = projects.map((p) => p.id).toList();
    print('DEBUG: Fetching members for ${projectIds.length} projects');
    
    try {
      // Fetch project members
      final membersResponse = await _client
          .from('project_members')
          .select('project_id, user_id')
          .inFilter('project_id', projectIds);

      print('DEBUG: project_members response: $membersResponse');
      
      if ((membersResponse as List).isEmpty) {
        print('DEBUG: No members found for any project');
        return projects;
      }
      
      final userIds = <String>{};
      final memberProjectMap = <String, List<String>>{};
      
      for (final row in membersResponse as List<dynamic>) {
        final data = Map<String, dynamic>.from(row);
        final projectId = data['project_id']?.toString();
        final userId = data['user_id']?.toString();
        
        if (projectId != null && userId != null) {
          userIds.add(userId);
          memberProjectMap.putIfAbsent(userId, () => []).add(projectId);
        }
      }

      print('DEBUG: Found ${userIds.length} unique user IDs');
      if (userIds.isEmpty) return projects;

      // Fetch profiles - use select with specific columns to avoid RLS issues
      final profilesResponse = await _client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', userIds.toList());

      print('DEBUG: profiles response: $profilesResponse');
      
      final namesByUserId = <String, String>{};
      for (final row in profilesResponse as List<dynamic>) {
        final data = Map<String, dynamic>.from(row);
        final userId = data['id']?.toString();
        final name = data['full_name']?.toString();
        if (userId != null && name != null) {
          namesByUserId[userId] = name;
        }
      }

      print('DEBUG: Found ${namesByUserId.length} profile names');
      
      // Map members to projects
      final membersByProject = <String, List<String>>{};
      memberProjectMap.forEach((userId, projectIds) {
        final name = namesByUserId[userId];
        if (name != null) {
          for (final projectId in projectIds) {
            membersByProject.putIfAbsent(projectId, () => []).add(name);
          }
        }
      });

      print('DEBUG: membersByProject: $membersByProject');
      
      return projects
          .map((project) {
            final members = membersByProject[project.id] ?? [];
            print('DEBUG: Project ${project.title} has ${members.length} members: $members');
            return project.copyWith(memberNames: members);
          })
          .toList(growable: false);
    } catch (e, stackTrace) {
      print('DEBUG: Error fetching member names: $e');
      print('DEBUG: Stack trace: $stackTrace');
      return projects;
    }
  }

  Future<void> _sendPushNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
    bool skipInApp = false,
  }) async {
    try {
      await _client.functions.invoke(
        'send-push-notification',
        body: {
          'type': type,
          'title': title,
          'body': body,
          'userId': userId,
          'skipInApp': skipInApp,
          if (data != null) 'data': data,
        },
      );
    } catch (e) {
      print('ERROR [Push] Failed to send project notification: $e');
    }
  }
}
