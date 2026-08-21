import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/community_model.dart';

class CommunitiesRepository {
  final SupabaseClient _client;

  CommunitiesRepository(this._client);

  Future<List<CommunityModel>> getCommunities({
    String? search,
    String? type,
    String? joinType,
    int? activityScoreMin,
  }) async {
    var query = _client.from('communities').select();

    if (search != null && search.isNotEmpty) {
      query = query.ilike('name', '%$search%');
    }
    if (type != null) {
      query = query.eq('type', type);
    }
    if (joinType != null) {
      query = query.eq('join_type', joinType);
    }
    if (activityScoreMin != null) {
      query = query.gte('activity_score', activityScoreMin);
    }

    final response = await query.order('name', ascending: true);
    final data = response as List<dynamic>;
    
    final communities = data.map((json) => CommunityModel.fromMap(json)).toList();
    return _applyMembershipStatus(communities);
  }

  Future<CommunityModel> getCommunityDetail(String communityId) async {
    final response = await _client.from('communities').select('''
      *,
      community_members!left(*, profiles(id, full_name, avatar_url))
    ''').eq('id', communityId).single();

    final community = CommunityModel.fromMap(response);
    return _applySingleMembershipStatus(community);
  }

  Future<void> createCommunity(Map<String, dynamic> data) async {
    final facultyHeadId = data.remove('faculty_head_id')?.toString();

    final inserted = await _client.from('communities').insert(data).select('id, created_by').single();
    final communityId = inserted['id'].toString();
    final createdBy = inserted['created_by'].toString();

    final targetHead = facultyHeadId ?? createdBy;

    await _client.from('community_members').insert({
      'community_id': communityId,
      'user_id': targetHead,
      'role': 'faculty_head',
    });

    if (createdBy != targetHead) {
      try {
        await _client.from('community_members').insert({
          'community_id': communityId,
          'user_id': createdBy,
          'role': 'president',
        });
      } catch (_) {}
    }
  }

  Future<void> updateCommunity(String id, Map<String, dynamic> data) async {
    final facultyHeadId = data.remove('faculty_head_id')?.toString();
    
    await _client.from('communities').update(data).eq('id', id);

    if (facultyHeadId != null) {
      // Remove any existing faculty heads to prevent duplicates
      await _client.from('community_members')
          .delete()
          .eq('community_id', id)
          .eq('role', 'faculty_head');

      // Add the new faculty head
      await _client.from('community_members').upsert({
        'community_id': id,
        'user_id': facultyHeadId,
        'role': 'faculty_head',
      });
    }
  }

  Future<void> deleteCommunity(String id) async {
    await _client.from('communities').delete().eq('id', id);
  }

  Future<List<CommunityModel>> _applyMembershipStatus(List<CommunityModel> list) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || list.isEmpty) return list;

    final ids = list.map((c) => c.id).toList();
    final membersResponse = await _client.from('community_members')
        .select('community_id, role')
        .eq('user_id', uid)
        .inFilter('community_id', ids);

    final memberRoleMap = {
      for (var row in membersResponse as List)
        row['community_id'].toString(): row['role'].toString()
    };

    final requestsResponse = await _client.from('community_join_requests')
        .select('community_id, status')
        .eq('requester_id', uid)
        .inFilter('community_id', ids);

    final requestMap = {
      for (var r in requestsResponse as List)
        r['community_id'].toString(): r['status'].toString()
    };

    return list.map((c) {
      final role = memberRoleMap[c.id];
      return c.copyWith(
        isUserMember: role != null,
        userMemberRole: role,
        joinRequestStatus: requestMap[c.id],
      );
    }).toList();
  }

  Future<CommunityModel> _applySingleMembershipStatus(CommunityModel community) async {
    final list = await _applyMembershipStatus([community]);
    return list.first;
  }
}
