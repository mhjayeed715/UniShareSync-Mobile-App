import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/core/utils/image_compression.dart';
import 'package:unisharesync_mobile_app/services/offline_cache_service.dart';
import 'notice_model.dart';




class NoticeService {
  NoticeService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final OfflineCacheService _cache = OfflineCacheService.instance;

  String _cacheKey(String suffix) => 'notice_board_$suffix';

  Future<Map<String, dynamic>> _getCurrentUserRoleAndSemester() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return {'role': 'student', 'semester': null};
      }

      final profile = await _client
          .from('profiles')
          .select('role, semester')
          .eq('id', userId)
          .maybeSingle();

      if (profile != null) {
        final role = profile['role']?.toString() ?? 'student';
        final semester = profile['semester'] != null
            ? int.tryParse(profile['semester'].toString())
            : null;
        return {'role': role, 'semester': semester};
      }

      return {'role': 'student', 'semester': null};
    } catch (_) {
      return {'role': 'student', 'semester': null};
    }
  }

  Stream<List<NoticeModel>> watchNotices({int limit = 50}) async* {
    final userId = _client.auth.currentUser?.id ?? 'guest';
    final cacheKey = _cacheKey('notices_${userId}_$limit');
    final cached = await _cache.readJsonList(cacheKey);

    if (cached.isNotEmpty) {
      yield await _filterNoticesByUserRole(
        cached.map(NoticeModel.fromMap).toList(growable: false),
      );
    }

    try {
      await for (final rows in _client
          .from('notices')
          .stream(primaryKey: const ['id'])
          .order('created_at', ascending: false)
          .limit(limit)) {
        await _cache.saveJsonList(cacheKey, rows);
        final notices = rows.map(NoticeModel.fromMap).toList(growable: false);
        final filtered = await _filterNoticesByUserRole(notices);
        filtered.sort((a, b) {
          final priorityCmp = _priorityValue(b.priority) - _priorityValue(a.priority);
          if (priorityCmp != 0) return priorityCmp;
          return b.createdAt.compareTo(a.createdAt);
        });
        yield filtered;
      }
    } catch (_) {
      if (cached.isEmpty) {
        yield const <NoticeModel>[];
      }
    }
  }

  Stream<List<NoticeModel>> watchAllNotices({int limit = 50}) async* {
    final cacheKey = _cacheKey('all_notices_$limit');
    final cached = await _cache.readJsonList(cacheKey);

    if (cached.isNotEmpty) {
      yield cached.map(NoticeModel.fromMap).toList(growable: false);
    }

    try {
      await for (final rows in _client
          .from('notices')
          .stream(primaryKey: const ['id'])
          .order('created_at', ascending: false)
          .limit(limit)) {
        await _cache.saveJsonList(cacheKey, rows);
        final notices = rows.map(NoticeModel.fromMap).toList(growable: false);
        notices.sort((a, b) {
          final priorityCmp = _priorityValue(b.priority) - _priorityValue(a.priority);
          if (priorityCmp != 0) return priorityCmp;
          return b.createdAt.compareTo(a.createdAt);
        });
        yield notices;
      }
    } catch (_) {
      if (cached.isEmpty) {
        yield const <NoticeModel>[];
      }
    }
  }

  int _priorityValue(NoticePriority p) => switch (p) {
        NoticePriority.urgent => 3,
        NoticePriority.important => 2,
        NoticePriority.normal => 1,
      };

  Future<List<NoticeModel>> fetchNotices({int limit = 50}) async {
    final cacheKey = _cacheKey('notices_${_client.auth.currentUser?.id ?? 'guest'}_$limit');
    try {
      final rows = await _client
          .from('notices')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      final rawRows = (rows as List).cast<Map<String, dynamic>>();
      await _cache.saveJsonList(cacheKey, rawRows);
      var notices = rawRows.map(NoticeModel.fromMap).toList();
      notices = await _filterNoticesByUserRole(notices);
      notices.sort((a, b) {
        final priorityCmp = _priorityValue(b.priority) - _priorityValue(a.priority);
        if (priorityCmp != 0) return priorityCmp;
        return b.createdAt.compareTo(a.createdAt);
      });
      return notices;
    } catch (_) {
      final cached = await _cache.readJsonList(cacheKey);
      if (cached.isEmpty) {
        return const <NoticeModel>[];
      }

      var notices = cached.map(NoticeModel.fromMap).toList();
      notices = await _filterNoticesByUserRole(notices);
      notices.sort((a, b) {
        final priorityCmp = _priorityValue(b.priority) - _priorityValue(a.priority);
        if (priorityCmp != 0) return priorityCmp;
        return b.createdAt.compareTo(a.createdAt);
      });
      return notices;
    }
  }

  Future<List<NoticeModel>> fetchAllNotices({int limit = 50}) async {
    final cacheKey = _cacheKey('all_notices_$limit');
    try {
      final rows = await _client
          .from('notices')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      final rawRows = (rows as List).cast<Map<String, dynamic>>();
      await _cache.saveJsonList(cacheKey, rawRows);
      return rawRows.map(NoticeModel.fromMap).toList();
    } catch (_) {
      final cached = await _cache.readJsonList(cacheKey);
      return cached.map(NoticeModel.fromMap).toList();
    }
  }

  Future<List<NoticeModel>> _filterNoticesByUserRole(List<NoticeModel> notices) async {
    final userInfo = await _getCurrentUserRoleAndSemester();
    final userRole = userInfo['role'] as String;
    final userSemester = userInfo['semester'] as int?;

    final filtered = notices.where((notice) {
      if (!notice.targetRoles.contains(userRole)) {
        return false;
      }

      if (notice.targetSemesters.isEmpty) {
        return true;
      }

      if (userSemester != null) {
        return notice.targetSemesters.contains(userSemester);
      }

      return userRole != 'student';
    }).toList();

    return filtered;
  }

  Future<NoticeModel> createNotice({
    required String title,
    required String content,
    required NoticePriority priority,
    Uint8List? attachmentBytes,
    String? attachmentFileName,
    String? postedBy,
    List<String> targetRoles = const ['student', 'faculty', 'admin'],
    List<int> targetSemesters = const [],
  }) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    String? attachmentUrl;
    String? attachmentType;

    if (attachmentBytes != null && attachmentFileName != null) {
      final ext = attachmentFileName.split('.').last.toLowerCase();
      attachmentType = ext == 'pdf' ? 'pdf' : 'image';

      if (attachmentType == 'pdf') {
        final storagePath = 'notices/${DateTime.now().millisecondsSinceEpoch}_$attachmentFileName';
        await _client.storage
            .from('notice_attachments')
            .uploadBinary(storagePath, attachmentBytes);
        attachmentUrl = _client.storage.from('notice_attachments').getPublicUrl(storagePath);
      } else {
        final compressed = await ImageCompression.toWebp(
              attachmentBytes,
              maxDimension: 1600,
              quality: 80,
            ) ??
            attachmentBytes;
        final storagePath =
            'notices/${DateTime.now().millisecondsSinceEpoch}_${attachmentFileName.split('.').first}.webp';
        await _client.storage.from('notice_attachments').uploadBinary(
              storagePath,
              compressed,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'image/webp',
              ),
            );
        attachmentUrl = _client.storage.from('notice_attachments').getPublicUrl(storagePath);
      }
    }

    final notice = NoticeModel(
      id: '',
      title: title,
      content: content,
      priority: priority,
      createdAt: DateTime.now(),
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      postedBy: currentUserId,
      targetRoles: targetRoles,
      targetSemesters: targetSemesters,
    );

    final inserted = await _client
        .from('notices')
        .insert(notice.toInsertMap())
        .select()
        .single();

    await _sendPushNotification(
      title: title,
      body: content.length > 100 ? '${content.substring(0, 100)}…' : content,
      priority: priority,
      targetRoles: targetRoles,
      targetSemesters: targetSemesters,
    );

    return NoticeModel.fromMap(Map<String, dynamic>.from(inserted));
  }

  Future<void> updateNotice({
    required String id,
    required String title,
    required String content,
    required NoticePriority priority,
    List<String> targetRoles = const ['student', 'faculty', 'admin'],
    List<int> targetSemesters = const [],
  }) async {
    await _client.from('notices').update({
      'title': title,
      'body': content,
      'content': content,
      'priority': priority.name,
      'target_roles': targetRoles,
      'target_semesters': targetSemesters,
    }).eq('id', id);
  }

  Future<void> deleteNotice(String id) async {
    try {
      await _client.from('notices').delete().eq('id', id);
    } catch (e) {
      print('Delete error: $e');
      rethrow;
    }
  }

  Future<void> _sendPushNotification({
    required String title,
    required String body,
    required NoticePriority priority,
    List<String> targetRoles = const ['student', 'faculty', 'admin'],
    List<int> targetSemesters = const [],
  }) async {
    try {
      await _client.functions.invoke(
        'send-push-notification',
        body: {
          'type': 'notice',
          'title': title,
          'body': body,
          'targetRoles': targetRoles,
          'targetSemesters': targetSemesters,
          'data': {'priority': priority.name},
        },
      );
    } catch (e) {
      print('ERROR [Push] Failed to invoke send-push-notification: $e');
    }
  }
}
