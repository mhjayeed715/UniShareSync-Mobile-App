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
    ProjectType? projectType,
    ProjectCategory? category,
    List<String>? skills,
  }) async {
    var request = _client.from('projects').select('*, project_supervisors(*, profiles!faculty_id(full_name, avatar_url))');

    if (semesterNo != null) {
      request = request.eq('semester_no', semesterNo);
    }

    if (status != null) {
      request = request.eq('status', status.storageValue);
    }

    if (projectType != null) {
      request = request.eq('project_type', projectType.value);
    }

    if (category != null) {
      request = request.eq('category', category.value);
    }

    final trimmedQuery = (query ?? '').trim();
    if (trimmedQuery.isNotEmpty) {
      final escaped = trimmedQuery.replaceAll('%', r'\%');
      request = request.or(
        'title.ilike.%$escaped%,description.ilike.%$escaped%,course_code.ilike.%$escaped%',
      );
    }

    final response = await request.order('created_at', ascending: false);

    var projects = (response as List<dynamic>)
        .map((row) => ProjectModel.fromMap(Map<String, dynamic>.from(row)))
        .toList();

    // Filter skills in memory if specified
    if (skills != null && skills.isNotEmpty) {
      projects = projects.where((p) {
        return skills.any((skill) =>
            p.requiredSkills.any((s) => s.toLowerCase() == skill.toLowerCase()));
      }).toList();
    }

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

    var request = _client.from('projects').select('*, project_supervisors(*, profiles!faculty_id(full_name, avatar_url))');

    if (role != UserRole.admin) {
      // For student/faculty, filter if they are a member or supervisor
      request = request.or(
        'owner_id.eq.$userId,id.in.(select project_id from project_members where user_id = \'$userId\'),id.in.(select project_id from project_supervisors where faculty_id = \'$userId\' and status = \'accepted\')',
      );
    }

    if (semesterNo != null) {
      request = request.eq('semester_no', semesterNo);
    }

    final trimmedQuery = (query ?? '').trim();
    if (trimmedQuery.isNotEmpty) {
      final escaped = trimmedQuery.replaceAll('%', r'\%');
      request = request.or(
        'title.ilike.%$escaped%,description.ilike.%$escaped%',
      );
    }

    final response = await request.order('created_at', ascending: false);

    final projects = (response as List<dynamic>)
        .map((row) => ProjectModel.fromMap(Map<String, dynamic>.from(row)))
        .toList();

    return _applyMemberNames(projects);
  }

  Future<ProjectModel?> fetchProjectById(String projectId) async {
    try {
      final response = await _client
          .from('projects')
          .select('*, project_supervisors(*, profiles!faculty_id(full_name, avatar_url))')
          .eq('id', projectId)
          .single();

      final project = ProjectModel.fromMap(Map<String, dynamic>.from(response));
      final wrapped = await _applyJoinRequestStatus([project]);
      final withNames = await _applyMemberNames(wrapped);
      return withNames.isNotEmpty ? withNames.first : null;
    } catch (_) {
      return null;
    }
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
      'category': draft.category.value,
      'semester_no': draft.semesterNo,
      'max_members': draft.maxMembers,
      'current_members': 1,
      'required_skills': draft.requiredSkills,
      'deadline': draft.deadline.toIso8601String(),
      'status': ProjectStatus.recruiting.storageValue,
      'owner_id': user.id,
      'owner_name': profile.fullName,
      'owner_avatar_url': profile.avatarUrl,
      'project_type': draft.projectType.value,
      'visibility': draft.visibility.value,
      'course_code': draft.courseCode?.trim(),
      'course_name': draft.courseName?.trim(),
      'banner_url': draft.bannerUrl,
    };

    final inserted = await _client
        .from('projects')
        .insert(payload)
        .select('*, project_supervisors(*, profiles!faculty_id(full_name, avatar_url))')
        .single();

    await _client.from('project_members').insert({
      'project_id': inserted['id'],
      'user_id': user.id,
      'role': 'owner',
    });

    final defaultCols = [
      {'title': 'Backlog', 'position': 1},
      {'title': 'To Do', 'position': 2},
      {'title': 'In Progress', 'position': 3},
      {'title': 'Review', 'position': 4},
      {'title': 'Done', 'position': 5},
    ];

    for (final col in defaultCols) {
      await _client.from('kanban_columns').insert({
        'project_id': inserted['id'],
        'title': col['title'],
        'position': col['position'],
        'created_by': user.id,
      });
    }

    return ProjectModel.fromMap(Map<String, dynamic>.from(inserted));
  }

  Future<ProjectModel> updateProject({
    required String projectId,
    required ProjectDraft draft,
  }) async {
    final payload = {
      'title': draft.title.trim(),
      'description': draft.description.trim(),
      'category': draft.category.value,
      'semester_no': draft.semesterNo,
      'max_members': draft.maxMembers,
      'required_skills': draft.requiredSkills,
      'deadline': draft.deadline.toIso8601String(),
      'project_type': draft.projectType.value,
      'visibility': draft.visibility.value,
      'course_code': draft.courseCode?.trim(),
      'course_name': draft.courseName?.trim(),
      'banner_url': draft.bannerUrl,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final updated = await _client
        .from('projects')
        .update(payload)
        .eq('id', projectId)
        .select('*, project_supervisors(*, profiles!faculty_id(full_name, avatar_url))')
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

  // --- Supervisor Operations ---

  Future<void> inviteSupervisor(String projectId, String facultyId) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('Not authenticated');

    // Check if there is an existing supervisor record
    final existing = await _client
        .from('project_supervisors')
        .select()
        .eq('project_id', projectId)
        .eq('faculty_id', facultyId);

    if (existing.isNotEmpty) {
      // Find if there's any pending or accepted invitation
      final hasActive = existing.any((row) => row['status'] == 'pending' || row['status'] == 'accepted');
      if (hasActive) {
        throw StateError('This faculty member is already invited or assigned as a supervisor for this project.');
      }

      // If they declined or resigned, delete the old records first to avoid constraint conflicts
      await _client
          .from('project_supervisors')
          .delete()
          .eq('project_id', projectId)
          .eq('faculty_id', facultyId);
    }

    await _client.from('project_supervisors').insert({
      'project_id': projectId,
      'faculty_id': facultyId,
      'status': 'pending',
      'invited_by': userId,
    });

    final project = await _client.from('projects').select('title').eq('id', projectId).single();
    final profile = await _profileService.getCurrentProfile();

    await _sendPushNotification(
      userId: facultyId,
      title: 'Supervisor Invitation',
      body: '${profile?.fullName ?? "A student"} invited you to supervise "${project["title"]}"',
      type: 'supervisor_invite',
      data: {'project_id': projectId},
    );
  }

  Future<void> respondToSupervision(String projectId, bool accept) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('Not authenticated');

    final status = accept ? 'accepted' : 'declined';
    await _client
        .from('project_supervisors')
        .update({
          'status': status,
          'responded_at': DateTime.now().toIso8601String(),
        })
        .eq('project_id', projectId)
        .eq('faculty_id', userId);

    final project = await _client.from('projects').select('title, owner_id').eq('id', projectId).single();
    final facultyProfile = await _profileService.getCurrentProfile();

    await _sendPushNotification(
      userId: project['owner_id'] as String,
      title: accept ? 'Supervision Accepted' : 'Supervision Declined',
      body: '${facultyProfile?.fullName ?? "Faculty"} has $status the supervision for "${project["title"]}"',
      type: 'supervisor_response',
      data: {'project_id': projectId, 'status': status},
    );
  }

  Future<void> resignSupervision(String projectId) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('Not authenticated');

    await _client
        .from('project_supervisors')
        .update({
          'status': 'resigned',
          'responded_at': DateTime.now().toIso8601String(),
        })
        .eq('project_id', projectId)
        .eq('faculty_id', userId);

    final project = await _client.from('projects').select('title, owner_id').eq('id', projectId).single();
    final facultyProfile = await _profileService.getCurrentProfile();

    await _sendPushNotification(
      userId: project['owner_id'] as String,
      title: 'Supervisor Resigned',
      body: '${facultyProfile?.fullName ?? "Faculty"} has resigned from supervising "${project["title"]}"',
      type: 'supervisor_resigned',
      data: {'project_id': projectId},
    );
  }

  Future<void> updateSupervisorFeedback({
    required String projectId,
    required String feedback,
    required String reviewStatus, // 'reviewed', 'needs_revision'
  }) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('Not authenticated');

    final existingFeedback = await _client
        .from('project_supervisors')
        .select('feedback_note')
        .eq('project_id', projectId)
        .eq('faculty_id', userId)
        .maybeSingle();
    final String? oldFeedback = existingFeedback?['feedback_note'] as String?;
    
    final now = DateTime.now();
    final timestamp = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final String newFeedbackWithTime = "[$timestamp] $feedback";
    
    final String updatedFeedback;
    if (oldFeedback == null || oldFeedback.trim().isEmpty) {
      updatedFeedback = newFeedbackWithTime;
    } else {
      updatedFeedback = "$oldFeedback\n$newFeedbackWithTime";
    }

    await _client
        .from('project_supervisors')
        .update({
          'feedback_note': updatedFeedback,
          'last_review_status': reviewStatus,
        })
        .eq('project_id', projectId)
        .eq('faculty_id', userId);

    final project = await _client.from('projects').select('title, owner_id').eq('id', projectId).single();
    final facultyProfile = await _profileService.getCurrentProfile();

    // Notify project owner
    await _sendPushNotification(
      userId: project['owner_id'] as String,
      title: 'New Supervisor Feedback',
      body: '${facultyProfile?.fullName ?? "Faculty"} posted a feedback review for "${project["title"]}"',
      type: 'supervisor_feedback',
      data: {'project_id': projectId},
    );
  }

  Future<void> requestProgressUpdate(String projectId) async {
    final project = await _client.from('projects').select('title, owner_id').eq('id', projectId).single();
    final members = await _client.from('project_members').select('user_id').eq('project_id', projectId);

    for (final row in members as List) {
      final memberId = row['user_id'] as String;
      await _sendPushNotification(
        userId: memberId,
        title: 'Progress Update Requested',
        body: 'Your supervisor requested a progress update on "${project["title"]}"',
        type: 'progress_request',
        data: {'project_id': projectId},
      );
    }
  }

  // --- Faculty course monitor fetching ---

  Future<List<Map<String, dynamic>>> fetchFacultyCourses() async {
    final userId = currentUserId;
    if (userId == null) return const [];

    final response = await _client
        .from('faculty_courses')
        .select()
        .eq('faculty_id', userId)
        .eq('is_active', true);

    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<List<ProjectModel>> fetchFacultyMonitoredProjects() async {
    final userId = currentUserId;
    if (userId == null) return const [];

    final courses = await fetchFacultyCourses();
    if (courses.isEmpty) return const [];

    // Filter projects where course_code matches any taught courses AND semester matches
    final orFilters = courses.map((c) => 'and(course_code.eq.${c["course_code"]},semester_no.eq.${c["semester"]})').join(',');

    final response = await _client
        .from('projects')
        .select('*, project_supervisors(*, profiles:faculty_id(full_name, avatar_url))')
        .or(orFilters)
        .order('created_at', ascending: false);

    final projects = (response as List)
        .map((row) => ProjectModel.fromMap(Map<String, dynamic>.from(row)))
        .toList();

    return _applyMemberNames(projects);
  }

  // --- Join Requests ---

  Future<void> requestJoinProject(String projectId) async {
    try {
      final project = await _client
          .from('projects')
          .select('owner_id, title')
          .eq('id', projectId)
          .single();
      final ownerId = project['owner_id'] as String;
      final projectTitle = project['title'] as String;

      await _client.rpc('request_project_join', params: {
        'p_project_id': projectId,
      });

      final profile = await _profileService.getCurrentProfile();
      final senderName = profile?.fullName ?? 'A student';

      await _sendPushNotification(
        userId: ownerId,
        title: 'New Join Request',
        body: '$senderName wants to join your project "$projectTitle"',
        type: 'project_request',
        data: {'project_id': projectId},
      );
    } catch (_) {
      rethrow;
    }
  }

  Future<void> reviewJoinRequest({
    required String requestId,
    required bool approve,
  }) async {
    try {
      final request = await _client
          .from('project_join_requests')
          .select('requester_id, project_id, projects(title)')
          .eq('id', requestId)
          .single();
      
      final requesterId = request['requester_id'] as String;
      final projectId = request['project_id'] as String;
      final projectMap = request['projects'] as Map<String, dynamic>;
      final projectTitle = projectMap['title'] as String;
      
      final ownerProfile = await _profileService.getCurrentProfile();
      final ownerName = ownerProfile?.fullName ?? 'Project Owner';

      await _client.rpc('review_project_join_request', params: {
        'p_request_id': requestId,
        'p_action': approve ? 'approve' : 'reject',
      });

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
      );
    } catch (_) {
      rethrow;
    }
  }

  Future<List<ProjectJoinRequest>> fetchJoinRequests(String projectId) async {
    final response = await _client
        .from('project_join_requests')
        .select()
        .eq('project_id', projectId)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((row) => ProjectJoinRequest.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> fetchProjectMembersWithProfiles(String projectId) async {
    final membersResponse = await _client
        .from('project_members')
        .select('user_id, role')
        .eq('project_id', projectId);
    
    final members = (membersResponse as List<dynamic>).map((row) => Map<String, dynamic>.from(row)).toList();
    if (members.isEmpty) return [];

    final userIds = members.map((m) => m['user_id'] as String).toList();
    final profilesResponse = await _client
        .from('profiles')
        .select('id, full_name, avatar_url, email')
        .inFilter('id', userIds);

    final profilesMap = {
      for (final p in profilesResponse as List<dynamic>)
        p['id'] as String: Map<String, dynamic>.from(p)
    };

    for (final m in members) {
      m['profiles'] = profilesMap[m['user_id']];
    }

    return members;
  }

  Future<void> removeMember(String projectId, String userId) async {
    await _client
        .from('project_members')
        .delete()
        .eq('project_id', projectId)
        .eq('user_id', userId);

    final project = await _client.from('projects').select('current_members').eq('id', projectId).single();
    final currentMembers = project['current_members'] as int;

    await _client.from('projects').update({
      'current_members': currentMembers - 1,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', projectId);
  }

  // --- Utility functions ---

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
    
    try {
      final membersResponse = await _client
          .from('project_members')
          .select('project_id, user_id')
          .inFilter('project_id', projectIds);

      if ((membersResponse as List).isEmpty) return projects;
      
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

      if (userIds.isEmpty) return projects;

      final profilesResponse = await _client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', userIds.toList());

      final namesByUserId = <String, String>{};
      for (final row in profilesResponse as List<dynamic>) {
        final data = Map<String, dynamic>.from(row);
        final userId = data['id']?.toString();
        final name = data['full_name']?.toString();
        if (userId != null && name != null) {
          namesByUserId[userId] = name;
        }
      }

      final membersByProject = <String, List<String>>{};
      memberProjectMap.forEach((userId, projectIds) {
        final name = namesByUserId[userId];
        if (name != null) {
          for (final projectId in projectIds) {
            membersByProject.putIfAbsent(projectId, () => []).add(name);
          }
        }
      });

      return projects
          .map((project) {
            final members = membersByProject[project.id] ?? [];
            return project.copyWith(memberNames: members);
          })
          .toList(growable: false);
    } catch (_) {
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
    } catch (_) {
      // Suppress network notifications fails in offline test logs
    }
  }
}
