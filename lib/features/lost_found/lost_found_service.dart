import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';
import 'package:unisharesync_mobile_app/core/utils/image_compression.dart';
import 'package:unisharesync_mobile_app/features/lost_found/lost_found_model.dart';
import 'package:unisharesync_mobile_app/services/profile_service.dart';
import 'package:unisharesync_mobile_app/services/offline_cache_service.dart';

class LostFoundService {
  LostFoundService({SupabaseClient? client, ProfileService? profileService})
      : _client = client ?? Supabase.instance.client,
        _profileService = profileService ?? ProfileService(client: client);

  final SupabaseClient _client;
  final ProfileService _profileService;
  final OfflineCacheService _cache = OfflineCacheService.instance;

  String? get currentUserId => _client.auth.currentUser?.id;

  String _cacheKey(String suffix) => 'lost_found_$suffix';

  Stream<List<LostFoundReport>> watchReports({int limit = 200}) async* {
    final userId = currentUserId ?? 'guest';
    final cacheKey = _cacheKey('reports_${userId}_$limit');
    final cached = await _cache.readJsonList(cacheKey);
    if (cached.isNotEmpty) {
      yield cached.map(LostFoundReport.fromMap).toList(growable: false);
    }

    try {
      await for (final rows in _client
        .from('lost_found_reports')
        .stream(primaryKey: const ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
      ) {
        await _cache.saveJsonList(cacheKey, rows);
        yield rows
            .map((row) => LostFoundReport.fromMap(Map<String, dynamic>.from(row)))
            .toList(growable: false);
      }
    } catch (_) {
      if (cached.isEmpty) {
        yield const <LostFoundReport>[];
      }
    }
  }

  Future<List<LostFoundReport>> fetchReports({int limit = 200}) async {
    final cacheKey = _cacheKey('reports_${currentUserId ?? 'guest'}_$limit');
    try {
      final response = await _client
          .from('lost_found_reports')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      final rows = (response as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      await _cache.saveJsonList(cacheKey, rows);
      return rows.map(LostFoundReport.fromMap).toList(growable: false);
    } catch (_) {
      final cached = await _cache.readJsonList(cacheKey);
      return cached.map(LostFoundReport.fromMap).toList(growable: false);
    }
  }

  Future<LostFoundReport> createReport({
    required LostFoundReportDraft draft,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to report an item.');
    }

    final profile = await _resolveProfile();
    final now = DateTime.now();
    final uploadUrls = await _uploadReportPhotos(
      userId: user.id,
      photoBytes: draft.photoBytes,
      photoFileNames: draft.photoFileNames,
    );

    final inserted = await _client
        .from('lost_found_reports')
        .insert({
          'report_type': draft.reportType.storageValue,
          'title': draft.title.trim(),
          'category': draft.category.trim(),
          'description': draft.description.trim(),
          'location': draft.location.trim(),
          'contact_info': draft.contactInfo.trim(),
          'report_date': _dateOnlyIso(draft.reportDate),
          'status': LostFoundStatus.open.storageValue,
          'photo_urls': uploadUrls,
          'reporter_id': user.id,
          'reporter_name': profile.fullName,
          'reporter_avatar_url': profile.avatarUrl,
          'reporter_role': profile.role.value,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        })
        .select()
        .single();

    return LostFoundReport.fromMap(Map<String, dynamic>.from(inserted));
  }

  Future<void> updateReportStatus({
    required String reportId,
    required LostFoundStatus status,
  }) async {
    await _client.from('lost_found_reports').update({
      'status': status.storageValue,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', reportId);
  }

  Future<void> deleteReport(String reportId) async {
    await _client.from('lost_found_reports').delete().eq('id', reportId);
  }

  Future<_ReporterProfile> _resolveProfile() async {
    final profile = await _profileService.getCurrentProfile();
    if (profile != null) {
      return _ReporterProfile(
        fullName: profile.fullName,
        avatarUrl: profile.avatarUrl,
        role: profile.role,
      );
    }

    final user = _client.auth.currentUser;
    final email = user?.email?.trim();
    final name = user?.userMetadata?['full_name']?.toString().trim();

    return _ReporterProfile(
      fullName: (name == null || name.isEmpty)
          ? ((email == null || email.isEmpty)
              ? 'Campus User'
              : email.split('@').first)
          : name,
      avatarUrl: null,
      role: UserRole.fromString(user?.userMetadata?['role']?.toString()),
    );
  }

  Future<List<String>> _uploadReportPhotos({
    required String userId,
    required List<Uint8List> photoBytes,
    required List<String> photoFileNames,
  }) async {
    if (photoBytes.isEmpty) {
      return const <String>[];
    }

    final urls = <String>[];
    final limitedCount = photoBytes.length > 3 ? 3 : photoBytes.length;

    for (var index = 0; index < limitedCount; index++) {
      final bytes = photoBytes[index];
      final compressed = await ImageCompression.toWebp(
            bytes,
            maxDimension: 1600,
            quality: 80,
          ) ??
          bytes;
      final objectPath =
          'reports/$userId/${DateTime.now().microsecondsSinceEpoch}_$index.webp';

      await _client.storage.from('lost-found-photos').uploadBinary(
            objectPath,
            compressed,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/webp',
            ),
          );

      urls.add(_client.storage.from('lost-found-photos').getPublicUrl(objectPath));
    }

    return urls;
  }

  String _dateOnlyIso(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day).toIso8601String();
  }

}

class _ReporterProfile {
  const _ReporterProfile({
    required this.fullName,
    required this.avatarUrl,
    required this.role,
  });

  final String fullName;
  final String? avatarUrl;
  final UserRole role;
}
