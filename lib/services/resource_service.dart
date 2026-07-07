import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/data/models/resource_item.dart';
import 'package:unisharesync_mobile_app/services/offline_cache_service.dart';

class ResourceService {
  ResourceService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final OfflineCacheService _cache = OfflineCacheService.instance;

  String? get currentUserId => _client.auth.currentUser?.id;

  String _cacheKey(String suffix) => 'resources_$suffix';

  Future<List<CourseOption>> fetchCourseOptions({
    int? semesterNo,
  }) async {
    final cacheKey = _cacheKey('course_options_${semesterNo ?? 'all'}');
    try {
      var query = _client.from('v_course_options_by_semester').select();

      if (semesterNo != null) {
        query = query.eq('semester_no', semesterNo);
      }

      final response = await query.order('semester_no').order('course_code');
      final rows = (response as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);

      await _cache.saveJsonList(cacheKey, rows);

      return rows
          .map(CourseOption.fromMap)
          .where((option) =>
              option.semesterNo > 0 &&
              option.courseCode.trim().isNotEmpty &&
              option.courseTitle.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      final cached = await _cache.readJsonList(cacheKey);
      return cached
          .map(CourseOption.fromMap)
          .where((option) =>
              option.semesterNo > 0 &&
              option.courseCode.trim().isNotEmpty &&
              option.courseTitle.trim().isNotEmpty)
          .toList(growable: false);
    }
  }

  Future<List<ResourceItem>> searchResources({
    String? query,
    int? semesterNo,
    String? courseCode,
    ResourceFileType? fileType,
    int limit = 40,
    int offset = 0,
  }) async {
    final cacheKey = _cacheKey(
      'search_${currentUserId ?? 'guest'}_${query ?? ''}_${semesterNo ?? 'all'}_${courseCode ?? ''}_${fileType?.value ?? 'all'}_${limit}_$offset',
    );
    final params = <String, dynamic>{
      'p_query': (query ?? '').trim().isEmpty ? null : query!.trim(),
      'p_semester_no': semesterNo,
      'p_course_code': (courseCode ?? '').trim().isEmpty ? null : courseCode,
      'p_file_type': fileType?.value,
      'p_limit': limit,
      'p_offset': offset,
    };

    try {
      final response = await _client.rpc('search_resources', params: params);
      final rows = (response as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
      await _cache.saveJsonList(cacheKey, rows);
      return rows
          .map((row) => ResourceItem.fromSearchMap(row))
          .toList(growable: false);
    } catch (_) {
      final cached = await _cache.readJsonList(cacheKey);
      return cached
          .map((row) => ResourceItem.fromSearchMap(row))
          .toList(growable: false);
    }
  }

  Future<ResourceItem> uploadResource({
    required String title,
    String? description,
    String? originalFileName,
    required String courseCode,
    required int semesterNo,
    required ResourceKind resourceType,
    required ResourceFileType fileType,
    required String driveUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('You must sign in before uploading a resource.');
    }

    final payload = {
      'title': title.trim(),
      'description': _nullIfBlank(description),
      'original_file_name': _nullIfBlank(originalFileName),
      'course_code': courseCode.trim(),
      'semester_no': semesterNo,
      'resource_type': resourceType.value,
      'file_type': fileType.value,
      'drive_url': driveUrl.trim(),
    };

    final inserted = await _client
        .from('resources')
        .insert(payload)
        .select(
          'id,title,description,original_file_name,course_code,semester_no,resource_type,file_type,drive_url,preview_url,approval_status,rejection_reason,total_downloads,uploader_id,uploader_role,created_at',
        )
        .single();

    final resolvedCourseTitle = await _resolveCourseTitle(courseCode);
    final uploader = await _resolveUploader(user.id);

    final item = ResourceItem.fromResourceTableMap(
      Map<String, dynamic>.from(inserted),
      resolvedCourseTitle: resolvedCourseTitle,
    )._withUploader(
      name: uploader.name,
      avatarUrl: uploader.avatarUrl,
    );

    if (item.approvalStatus == ResourceApprovalStatus.approved) {
      await _notifySemesterStudents(
        semesterNo: semesterNo,
        title: 'New Resource Available',
        body: 'A new resource "${item.title}" was posted for semester $semesterNo.',
        type: 'resource_update',
        data: {
          'resource_id': item.id,
          'semester_no': semesterNo.toString(),
        },
      );
    } else {
      // Pending approval — notify admins so they can review
      try {
        await _client.functions.invoke(
          'send-push-notification',
          body: {
            'type': 'resource_update',
            'title': 'New Resource Pending Review',
            'body': '"${item.title}" was submitted for semester $semesterNo and needs approval.',
            'targetRoles': ['admin'],
            'data': {'resource_id': item.id},
          },
        );
      } catch (_) {}
    }

    return item;
  }

  Future<void> updateResource({
    required String resourceId,
    required String title,
    String? description,
    String? originalFileName,
    required String driveUrl,
    String? courseCode,
    int? semesterNo,
    ResourceKind? resourceType,
    ResourceFileType? fileType,
  }) async {
    final payload = <String, dynamic>{
      'title': title.trim(),
      'description': _nullIfBlank(description),
      'original_file_name': _nullIfBlank(originalFileName),
      'drive_url': driveUrl.trim(),
    };

    if (courseCode != null && courseCode.trim().isNotEmpty) {
      payload['course_code'] = courseCode.trim();
    }

    if (semesterNo != null) {
      payload['semester_no'] = semesterNo;
    }

    if (resourceType != null) {
      payload['resource_type'] = resourceType.value;
    }

    if (fileType != null) {
      payload['file_type'] = fileType.value;
    }

    await _client.from('resources').update(payload).eq('id', resourceId);
  }

  Future<void> deleteResource({
    required String resourceId,
  }) async {
    await _client.from('resources').delete().eq('id', resourceId);
  }

  Future<void> reviewResource({
    required String resourceId,
    required bool approve,
    String? rejectionReason,
  }) async {
    try {
      // 1. Fetch resource details (uploader_id and title) BEFORE the RPC action
      final resource = await _client
          .from('resources')
          .select('uploader_id, title, semester_no')
          .eq('id', resourceId)
          .single();
      final uploaderId = resource['uploader_id'] as String;
      final resourceTitle = resource['title'] as String;

      // 2. Perform the review action via RPC
      await _client.rpc(
        'review_resource_submission',
        params: {
          'p_resource_id': resourceId,
          'p_action': approve ? 'approve' : 'reject',
          'p_rejection_reason': _nullIfBlank(rejectionReason),
        },
      );

      // 3. Send push notification to uploader
      final String title = approve ? 'Resource Approved' : 'Resource Rejected';
      final String body = approve
          ? 'Your resource "$resourceTitle" has been approved and published.'
          : 'Your resource "$resourceTitle" was rejected.${rejectionReason != null && rejectionReason.trim().isNotEmpty ? ' Reason: $rejectionReason' : ''}';

      await _sendPushNotification(
        userId: uploaderId,
        title: title,
        body: body,
        type: 'resource_update',
        data: {
          'resource_id': resourceId,
          'status': approve ? 'approved' : 'rejected',
        },
      );

      if (approve) {
        final semesterNo = resource['semester_no'];
        if (semesterNo != null) {
          await _notifySemesterStudents(
            semesterNo: int.parse(semesterNo.toString()),
            title: 'New Resource Available',
            body: 'A new resource "$resourceTitle" was published for your semester.',
            type: 'resource_update',
            data: {
              'resource_id': resourceId,
              'semester_no': semesterNo.toString(),
            },
          );
        }
      }
    } catch (e) {
      print('DEBUG: Review resource error: $e');
      rethrow;
    }
  }

  Future<int> recordDownload({
    required String resourceId,
    String? clientPlatform,
  }) async {
    final response = await _client.rpc(
      'record_resource_download',
      params: {
        'p_resource_id': resourceId,
        'p_client_platform': _nullIfBlank(clientPlatform),
      },
    );

    if (response is int) {
      return response;
    }
    return int.tryParse(response.toString()) ?? 0;
  }

  Future<String> _resolveCourseTitle(String courseCode) async {
    final row = await _client
        .from('courses')
        .select('course_title')
        .eq('course_code', courseCode)
        .maybeSingle();

    if (row == null) {
      return courseCode;
    }

    final value = row['course_title']?.toString().trim();
    if (value == null || value.isEmpty) {
      return courseCode;
    }

    return value;
  }

  Future<_UploaderInfo> _resolveUploader(String userId) async {
    try {
      final row = await _client
          .from('profiles')
          .select('full_name,email,avatar_url')
          .eq('id', userId)
          .maybeSingle();

      if (row == null) {
        return _UploaderInfo(name: 'Unknown Uploader', avatarUrl: null);
      }

      final fullName = row['full_name']?.toString().trim();
      final email = row['email']?.toString().trim();

      return _UploaderInfo(
        name: (fullName == null || fullName.isEmpty)
            ? ((email == null || email.isEmpty)
                ? 'Unknown Uploader'
                : email.split('@').first)
            : fullName,
        avatarUrl: row['avatar_url']?.toString(),
      );
    } catch (_) {
      return _UploaderInfo(name: 'Unknown Uploader', avatarUrl: null);
    }
  }

  String? _nullIfBlank(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  Future<void> _notifySemesterStudents({
    required int semesterNo,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _client.functions.invoke(
        'send-push-notification',
        body: {
          'type': type,
          'title': title,
          'body': body,
          'targetRoles': ['student'],
          'targetSemesters': [semesterNo],
          // No skipInApp — edge function handles in-app insert for semester-wide sends
          if (data != null) 'data': data,
        },
      );
    } catch (e) {
      print('ERROR [Push] Failed to send semester notification: $e');
    }
  }

  Future<void> _sendPushNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _client.functions.invoke(
        'send-push-notification',
        body: {
          'type': type,
          'title': title,
          'body': body,
          'userId': userId,
          'skipInApp': false,
          if (data != null) 'data': data,
        },
      );
    } catch (e) {
      print('ERROR [Push] Failed to send resource notification: $e');
    }
  }
}

class _UploaderInfo {
  const _UploaderInfo({
    required this.name,
    required this.avatarUrl,
  });

  final String name;
  final String? avatarUrl;
}

extension on ResourceItem {
  ResourceItem _withUploader({
    required String name,
    required String? avatarUrl,
  }) {
    return ResourceItem(
      id: id,
      title: title,
      description: description,
      originalFileName: originalFileName,
      courseCode: courseCode,
      courseTitle: courseTitle,
      semesterNo: semesterNo,
      resourceType: resourceType,
      fileType: fileType,
      driveUrl: driveUrl,
      previewUrl: previewUrl,
      rejectionReason: rejectionReason,
      approvalStatus: approvalStatus,
      totalDownloads: totalDownloads,
      uploaderId: uploaderId,
      uploaderName: name,
      uploaderAvatarUrl: avatarUrl,
      uploaderRole: uploaderRole,
      createdAt: createdAt,
    );
  }
}
