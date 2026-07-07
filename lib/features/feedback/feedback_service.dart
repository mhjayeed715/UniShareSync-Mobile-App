import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';
import 'package:unisharesync_mobile_app/features/feedback/feedback_model.dart';
import 'package:unisharesync_mobile_app/services/profile_service.dart';
import 'package:unisharesync_mobile_app/services/offline_cache_service.dart';

class FeedbackService {
  FeedbackService({SupabaseClient? client, ProfileService? profileService})
      : _client = client ?? Supabase.instance.client,
        _profileService = profileService ?? ProfileService(client: client);

  final SupabaseClient _client;
  final ProfileService _profileService;
  final OfflineCacheService _cache = OfflineCacheService.instance;

  String? get currentUserId => _client.auth.currentUser?.id;

  String _cacheKey(String suffix) => 'feedback_$suffix';

  Stream<List<FeedbackEntry>> watchFeedback({int limit = 200}) async* {
    final userId = currentUserId ?? 'guest';
    final cacheKey = _cacheKey('entries_${userId}_$limit');
    final cached = await _cache.readJsonList(cacheKey);
    if (cached.isNotEmpty) {
      yield cached.map(FeedbackEntry.fromMap).toList(growable: false);
    }

    try {
      await for (final rows in _client
        .from('feedback_entries')
        .stream(primaryKey: const ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
      ) {
        await _cache.saveJsonList(cacheKey, rows);
        yield rows
            .map((row) => FeedbackEntry.fromMap(Map<String, dynamic>.from(row)))
            .toList(growable: false);
      }
    } catch (_) {
      if (cached.isEmpty) {
        yield const <FeedbackEntry>[];
      }
    }
  }

  Future<List<FeedbackEntry>> fetchFeedback({int limit = 200}) async {
    final cacheKey = _cacheKey('entries_${currentUserId ?? 'guest'}_$limit');
    try {
      final response = await _client
          .from('feedback_entries')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      final rows = (response as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      await _cache.saveJsonList(cacheKey, rows);
      return rows.map(FeedbackEntry.fromMap).toList(growable: false);
    } catch (_) {
      final cached = await _cache.readJsonList(cacheKey);
      return cached.map(FeedbackEntry.fromMap).toList(growable: false);
    }
  }

  Future<FeedbackEntry> createFeedback({required FeedbackDraft draft}) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to submit feedback.');
    }

    final profile = await _resolveProfile();
    final now = DateTime.now().toIso8601String();

    final inserted = await _client
        .from('feedback_entries')
        .insert({
          'category': draft.category.storageValue,
          'title': draft.title.trim(),
          'content': draft.content.trim(),
          'rating': draft.rating,
          'is_anonymous': draft.isAnonymous,
          'status': FeedbackStatus.pending.storageValue,
          'submitter_id': user.id,
          'submitter_name': profile.fullName,
          'submitter_avatar_url': profile.avatarUrl,
          'submitter_role': profile.role.value,
          'created_at': now,
          'updated_at': now,
        })
        .select()
        .single();

    return FeedbackEntry.fromMap(Map<String, dynamic>.from(inserted));
  }

  Future<void> deleteFeedback({required String feedbackId}) async {
    await _client.from('feedback_entries').delete().eq('id', feedbackId);
  }

  Future<void> respondToFeedback({
    required String feedbackId,
    required String response,
    required FeedbackStatus status,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to respond to feedback.');
    }

    final now = DateTime.now().toIso8601String();
    await _client.from('feedback_entries').update({
      'admin_response': response.trim(),
      'status': status.storageValue,
      'responded_by': user.id,
      'responded_at': now,
      'updated_at': now,
    }).eq('id', feedbackId);
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
