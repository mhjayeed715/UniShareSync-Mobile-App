import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/data/models/dashboard_feed_item.dart';

class DashboardFeedService {
  DashboardFeedService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Stream<List<DashboardFeedItem>> watchResources({int limit = 25}) {
    return _client
        .from('resources')
        .stream(primaryKey: const ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
        .map(
          (rows) => rows
              .map(DashboardFeedItem.fromResourceMap)
              .toList(growable: false),
        );
  }

  Stream<List<DashboardFeedItem>> watchNotices({int limit = 15}) {
    return _client
        .from('notices')
        .stream(primaryKey: const ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
        .map(
          (rows) =>
              rows.map(DashboardFeedItem.fromNoticeMap).toList(growable: false),
        );
  }

  Stream<List<DashboardFeedItem>> watchRoutines({int limit = 20}) {
    return _client
        .from('routines')
        .stream(primaryKey: const ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
        .map(
          (rows) => rows
              .map(DashboardFeedItem.fromRoutineMap)
              .toList(growable: false),
        );
  }
}
