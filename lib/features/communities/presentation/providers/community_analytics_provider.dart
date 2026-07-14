import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/community_analytics_model.dart';

class CommunityAnalyticsNotifier extends StateNotifier<AsyncValue<CommunityAnalyticsModel>> {
  CommunityAnalyticsNotifier(this._client) : super(const AsyncValue.loading());

  final SupabaseClient _client;

  Future<void> fetchAnalytics(String communityId) async {
    state = const AsyncValue.loading();
    try {
      // 1. Fetch current analytics values & snapshots
      final snapshotsResponse = await _client.from('community_analytics_snapshots')
          .select()
          .eq('community_id', communityId)
          .order('recorded_at', ascending: true);

      // 2. Semester Distribution Query
      final semesterResp = await _client.from('community_members').select('''
        profiles(semester)
      ''').eq('community_id', communityId);

      // 3. Top Active Members Query (by notices/activity reactions)
      // Query reactions for posts in this community
      final reactionsResp = await _client.from('community_activity_reactions').select('''
        user_id,
        profile:profiles(id, full_name, avatar_url),
        community_activity_posts!inner(community_id)
      ''').eq('community_activity_posts.community_id', communityId);

      final snapshots = snapshotsResponse as List<dynamic>;
      final semesters = semesterResp as List<dynamic>;

      final analytics = CommunityAnalyticsModel.compile(
        snapshots: snapshots,
        semesterDistribution: semesters,
        activeReactions: reactionsResp as List<dynamic>,
      );

      state = AsyncValue.data(analytics);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final communityAnalyticsProvider = StateNotifierProvider<CommunityAnalyticsNotifier, AsyncValue<CommunityAnalyticsModel>>((ref) {
  return CommunityAnalyticsNotifier(Supabase.instance.client);
});
