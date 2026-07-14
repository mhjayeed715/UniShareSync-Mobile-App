import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/community_activity_post_model.dart';

class CommunityActivityRepository {
  final SupabaseClient _client;

  CommunityActivityRepository(this._client);

  Future<List<CommunityActivityPostModel>> getActivityPosts(String communityId) async {
    final response = await _client.from('community_activity_posts').select('''
      *,
      community_activity_photos(*),
      reactions:community_activity_reactions(*)
    ''').eq('community_id', communityId)
       .order('created_at', ascending: false);

    final data = response as List<dynamic>;
    return data.map((json) => CommunityActivityPostModel.fromMap(json)).toList();
  }

  Future<void> createActivityPost(Map<String, dynamic> data) async {
    await _client.from('community_activity_posts').insert(data);
  }

  Future<void> addActivityPhoto(Map<String, dynamic> photoData) async {
    await _client.from('community_activity_photos').insert(photoData);
  }

  Future<void> deleteActivityPost(String postId) async {
    await _client.from('community_activity_posts').delete().eq('id', postId);
  }

  Future<void> addReaction(String postId, String emoji) async {
    await _client.from('community_activity_reactions').upsert({
      'activity_post_id': postId,
      'user_id': _client.auth.currentUser?.id,
      'emoji': emoji,
    });
  }

  Future<void> removeReaction(String postId, String emoji) async {
    await _client.from('community_activity_reactions').delete()
        .eq('activity_post_id', postId)
        .eq('user_id', _client.auth.currentUser!.id)
        .eq('emoji', emoji);
  }
}
