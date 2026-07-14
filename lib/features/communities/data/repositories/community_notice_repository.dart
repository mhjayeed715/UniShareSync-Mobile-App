import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/community_notice_model.dart';

class CommunityNoticeRepository {
  final SupabaseClient _client;

  CommunityNoticeRepository(this._client);

  Future<List<CommunityNoticeModel>> getNotices(String communityId) async {
    final response = await _client.from('community_notices').select('''
      *,
      reactions:community_notice_reactions(*)
    ''').eq('community_id', communityId)
       .order('is_pinned', ascending: false)
       .order('created_at', ascending: false);

    final data = response as List<dynamic>;
    return data.map((json) => CommunityNoticeModel.fromMap(json)).toList();
  }

  Future<void> createNotice(Map<String, dynamic> data) async {
    await _client.from('community_notices').insert(data);
  }

  Future<void> pinNotice(String id, bool isPinned) async {
    await _client.from('community_notices').update({
      'is_pinned': isPinned,
    }).eq('id', id);
  }

  Future<void> deleteNotice(String id) async {
    await _client.from('community_notices').delete().eq('id', id);
  }

  Future<void> addReaction(String noticeId, String emoji) async {
    await _client.from('community_notice_reactions').upsert({
      'notice_id': noticeId,
      'user_id': _client.auth.currentUser?.id,
      'emoji': emoji,
    });
  }

  Future<void> removeReaction(String noticeId, String emoji) async {
    await _client.from('community_notice_reactions').delete()
        .eq('notice_id', noticeId)
        .eq('user_id', _client.auth.currentUser!.id)
        .eq('emoji', emoji);
  }
}
