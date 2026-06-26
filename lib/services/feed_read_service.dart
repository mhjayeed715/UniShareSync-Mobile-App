import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/dashboard_feed_item.dart';

/// Service responsible for persisting and streaming the *read* state of
/// dashboard feed items. It uses the Supabase RPC `mark_feed_item_read`
/// defined in the database migrations.
class FeedReadService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Marks a feed item as read for the currently authenticated user.
  /// Returns `true` on success, otherwise `false`.
  Future<bool> markAsRead(String feedItemId) async {
    final response = await _client
        .rpc('mark_feed_item_read', params: {'feed_item_id': feedItemId});

    if (response.error != null) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('❌ markAsRead error: ${response.error?.message}');
      }
      return false;
    }
    return true;
  }

  /// Streams the list of feed items together with the `isRead` flag.
  /// The view `dashboard_feed_items_with_read` already adds the flag
  /// for the current user, so we simply select from it.
  Stream<List<DashboardFeedItem>> watchFeedItems() {
    final stream = _client
        .from('dashboard_feed_items_with_read')
        .stream(primaryKey: const ['id'])
        .order('created_at', ascending: false);

    return stream.map((list) => (list as List).map<DashboardFeedItem>((e) => _fromJson(e as Map<String, dynamic>)).toList());
  }

  /// Convert a Supabase row (Map) into the client‑side model.
  DashboardFeedItem _fromJson(Map<String, dynamic> json) {
    return DashboardFeedItem(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      category: json['category'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      isRead: (json['is_read'] as bool?) ?? false,
    );
  }
}
