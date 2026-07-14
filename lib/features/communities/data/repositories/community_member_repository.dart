import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/community_member_model.dart';

class CommunityMemberRepository {
  final SupabaseClient _client;

  CommunityMemberRepository(this._client);

  Future<List<CommunityMemberModel>> getCommunityMembers(String communityId) async {
    final response = await _client.from('community_members').select('''
      *,
      profile:profiles(id, full_name, avatar_url, semester, department)
    ''').eq('community_id', communityId).order('joined_at', ascending: true);

    final data = response as List<dynamic>;
    return data.map((json) => CommunityMemberModel.fromMap(json)).toList();
  }

  Future<void> addMember(String communityId, String userId, String role) async {
    await _client.from('community_members').insert({
      'community_id': communityId,
      'user_id': userId,
      'role': role,
    });
  }

  Future<void> removeMember(String memberId) async {
    await _client.from('community_members').delete().eq('id', memberId);
  }

  Future<void> updateMemberRole(String memberId, String role, String assignedBy) async {
    await _client.from('community_members').update({
      'role': role,
      'assigned_role_at': DateTime.now().toIso8601String(),
      'assigned_role_by': assignedBy,
    }).eq('id', memberId);
  }
}
