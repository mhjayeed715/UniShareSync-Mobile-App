import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/data/models/dashboard_feed_item.dart';
import 'package:unisharesync_mobile_app/services/offline_cache_service.dart';

class DashboardFeedService {
  DashboardFeedService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final OfflineCacheService _cache = OfflineCacheService.instance;

  String _cacheKey(String suffix) => 'dashboard_feed_$suffix';

  Stream<List<DashboardFeedItem>> watchResources({int limit = 25}) async* {
    final cached = await _cache.readJsonList(_cacheKey('resources_$limit'));
    if (cached.isNotEmpty) {
      yield cached
          .map(DashboardFeedItem.fromResourceMap)
          .toList(growable: false);
    }

    try {
      await for (final rows in _client
        .from('resources')
        .stream(primaryKey: const ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
      ) {
        await _cache.saveJsonList(_cacheKey('resources_$limit'), rows);
        yield rows
            .map(DashboardFeedItem.fromResourceMap)
            .toList(growable: false);
      }
    } catch (_) {
      if (cached.isEmpty) {
        yield const <DashboardFeedItem>[];
      }
    }
  }

  Future<int> getTotalResourceCount() async {
    try {
      final response = await _client
          .from('resources')
          .select('id')
          .then((data) => data as List);
      return response.length;
    } catch (_) {
      return (await _cache.readJsonList(_cacheKey('resources_30'))).length;
    }
  }

  Stream<List<DashboardFeedItem>> watchNotices({int limit = 15}) async* {
    final cached = await _cache.readJsonList(_cacheKey('notices_$limit'));
    if (cached.isNotEmpty) {
      yield cached
          .map(DashboardFeedItem.fromNoticeMap)
          .toList(growable: false);
    }

    try {
      await for (final rows in _client
        .from('notices')
        .stream(primaryKey: const ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
      ) {
        await _cache.saveJsonList(_cacheKey('notices_$limit'), rows);
        yield rows
            .map(DashboardFeedItem.fromNoticeMap)
            .toList(growable: false);
      }
    } catch (_) {
      if (cached.isEmpty) {
        yield const <DashboardFeedItem>[];
      }
    }
  }

  Stream<List<DashboardFeedItem>> watchRoutines({int limit = 20}) async* {
    final cached = await _cache.readJsonList(_cacheKey('routines_$limit'));
    if (cached.isNotEmpty) {
      yield cached
          .map(DashboardFeedItem.fromRoutineMap)
          .toList(growable: false);
    }

    try {
      await for (final rows in _client
        .from('routines')
        .stream(primaryKey: const ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
      ) {
        await _cache.saveJsonList(_cacheKey('routines_$limit'), rows);
        yield rows
            .map(DashboardFeedItem.fromRoutineMap)
            .toList(growable: false);
      }
    } catch (_) {
      if (cached.isEmpty) {
        yield const <DashboardFeedItem>[];
      }
    }
  }
}
