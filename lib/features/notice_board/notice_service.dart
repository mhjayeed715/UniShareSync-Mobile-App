import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/core/utils/image_compression.dart';
import 'notice_model.dart';

class NoticeService {
  NoticeService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get _currentUserRole => _client.auth.currentUser?.userMetadata?['role']?.toString();

  // ── Get current user's role and semester from profile ─────────────────────
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
        print('DEBUG: User role=$role, semester=$semester');
        return {'role': role, 'semester': semester};
      }
      return {'role': 'student', 'semester': null};
    } catch (e) {
      print('Error fetching user profile: $e');
      return {'role': 'student', 'semester': null};
    }
  }

  // ── Realtime stream with role-based filtering (for regular users) ────────
  Stream<List<NoticeModel>> watchNotices({int limit = 50}) {
    return _client
        .from('notices')
        .stream(primaryKey: const ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
        .asyncMap((rows) async {
          final notices = rows.map(NoticeModel.fromMap).toList(growable: false);
          print('DEBUG: Total notices from DB: ${notices.length}');
          for (var n in notices) {
            print('DEBUG: Notice "${n.title}" - target_roles: ${n.targetRoles}');
          }
          final filtered = await _filterNoticesByUserRole(notices);
          print('DEBUG: Filtered notices: ${filtered.length}');
          return filtered;
        });
  }

  // ── Realtime stream WITHOUT filtering (for admin) ────────────────────────
  Stream<List<NoticeModel>> watchAllNotices({int limit = 50}) {
    return _client
        .from('notices')
        .stream(primaryKey: const ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
        .map((rows) => rows.map(NoticeModel.fromMap).toList(growable: false));
  }

  // ── Read with role-based filtering ───────────────────────────────────────
  Future<List<NoticeModel>> fetchNotices({int limit = 50}) async {
    final rows = await _client
        .from('notices')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    final notices = (rows as List).map((r) => NoticeModel.fromMap(r)).toList();
    return await _filterNoticesByUserRole(notices);
  }

  // ── Read WITHOUT filtering (for admin) ──────────────────────────────────
  Future<List<NoticeModel>> fetchAllNotices({int limit = 50}) async {
    final rows = await _client
        .from('notices')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).map((r) => NoticeModel.fromMap(r)).toList();
  }

  // ── Filter notices based on user role and semester ───────────────────────
  Future<List<NoticeModel>> _filterNoticesByUserRole(List<NoticeModel> notices) async {
    final userInfo = await _getCurrentUserRoleAndSemester();
    final userRole = userInfo['role'] as String;
    final userSemester = userInfo['semester'] as int?;

    print('DEBUG: Filtering with userRole=$userRole, userSemester=$userSemester');

    final filtered = notices.where((notice) {
      print('DEBUG: Checking notice "${notice.title}"');
      print('  - targetRoles: ${notice.targetRoles}');
      print('  - targetSemesters: ${notice.targetSemesters}');
      print('  - userRole in targetRoles: ${notice.targetRoles.contains(userRole)}');

      // Check if user's role is in target roles
      if (!notice.targetRoles.contains(userRole)) {
        print('  - FILTERED OUT: role not in target');
        return false;
      }

      // If target semesters is empty, show to all
      if (notice.targetSemesters.isEmpty) {
        print('  - INCLUDED: no semester restriction');
        return true;
      }

      // If target semesters is specified, check if user's semester matches
      if (userSemester != null) {
        final included = notice.targetSemesters.contains(userSemester);
        print('  - userSemester in targetSemesters: $included');
        return included;
      }

      // If user has no semester (faculty/admin), show all
      final isNonStudent = userRole != 'student';
      print('  - isNonStudent: $isNonStudent');
      return isNonStudent;
    }).toList();

    print('DEBUG: Final filtered count: ${filtered.length}');
    return filtered;
  }

  // ── Create ───────────────────────────────────────────────────────────────
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

    print('DEBUG: Creating notice with targetRoles=$targetRoles, targetSemesters=$targetSemesters');

    String? attachmentUrl;
    String? attachmentType;

    if (attachmentBytes != null && attachmentFileName != null) {
      final ext = attachmentFileName.split('.').last.toLowerCase();
      attachmentType = ext == 'pdf' ? 'pdf' : 'image';

      if (attachmentType == 'pdf') {
        final storagePath =
            'notices/${DateTime.now().millisecondsSinceEpoch}_$attachmentFileName';
        await _client.storage
            .from('notice_attachments')
            .uploadBinary(storagePath, attachmentBytes);
        attachmentUrl = _client.storage
            .from('notice_attachments')
            .getPublicUrl(storagePath);
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
        attachmentUrl = _client.storage
            .from('notice_attachments')
            .getPublicUrl(storagePath);
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

    final insertMap = notice.toInsertMap();
    print('DEBUG: Insert map: $insertMap');

    final inserted = await _client
        .from('notices')
        .insert(insertMap)
        .select()
        .single();

    await _sendPushNotification(
      title: title,
      body: content.length > 100 ? '${content.substring(0, 100)}…' : content,
      priority: priority,
      targetRoles: targetRoles,
      targetSemesters: targetSemesters,
    );

    return NoticeModel.fromMap(inserted);
  }

  // ── Update ───────────────────────────────────────────────────────────────
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

  // ── Delete ───────────────────────────────────────────────────────────────
  Future<void> deleteNotice(String id) async {
    try {
      final result = await _client
          .from('notices')
          .delete()
          .eq('id', id);
      print('Delete result: $result');
    } catch (e) {
      print('Delete error: $e');
      rethrow;
    }
  }

  // ── FCM push via Supabase Edge Function ──────────────────────────────────
  Future<void> _sendPushNotification({
    required String title,
    required String body,
    required NoticePriority priority,
    List<String> targetRoles = const ['student', 'faculty', 'admin'],
    List<int> targetSemesters = const [],
  }) async {
    try {
      await _client.functions.invoke(
        'send-notice-push',
        body: {
          'title': title,
          'body': body,
          'priority': priority.name,
          'topic': 'campus_notices',
          'target_roles': targetRoles,
          'target_semesters': targetSemesters.isEmpty ? null : targetSemesters,
        },
      );
    } catch (_) {
      // Push failure should not block notice creation
    }
  }
}
