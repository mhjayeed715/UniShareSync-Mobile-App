import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/community_model.dart';
import '../../data/models/community_member_model.dart';
import '../../data/models/community_join_request_model.dart';
import '../../data/repositories/communities_repository.dart';
import '../../data/repositories/community_member_repository.dart';

class CommunityDetailNotifier extends StateNotifier<AsyncValue<CommunityModel>> {
  CommunityDetailNotifier(this._client) : super(const AsyncValue.loading()) {
    _repository = CommunitiesRepository(_client);
    _memberRepository = CommunityMemberRepository(_client);
  }

  final SupabaseClient _client;
  late final CommunitiesRepository _repository;
  late final CommunityMemberRepository _memberRepository;
  StreamSubscription? _memberCountSubscription;

  Future<void> fetchCommunityDetail(String communityId) async {
    state = const AsyncValue.loading();
    try {
      final community = await _repository.getCommunityDetail(communityId);
      state = AsyncValue.data(community);

      subscribeToMemberCount(communityId);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void subscribeToMemberCount(String communityId) {
    _memberCountSubscription?.cancel();
    _memberCountSubscription = _client
        .from('communities:id=eq.$communityId')
        .stream(primaryKey: ['id'])
        .listen((data) {
          if (data.isNotEmpty && state is AsyncData<CommunityModel>) {
            final currentData = state.value!;
            state = AsyncValue.data(currentData.copyWith(
              memberCount: data.first['member_count'] as int,
              activityScore: data.first['activity_score'] as int,
            ));
          }
        });
  }

  Future<void> joinCommunity(String communityId, {String? joinMessage}) async {
    try {
      final communityResp = await _client.from('communities').select('join_type').eq('id', communityId).single();
      final joinType = communityResp['join_type'] as String;

      if (joinType == 'open') {
        await _memberRepository.addMember(communityId, _client.auth.currentUser!.id, 'member');
        await fetchCommunityDetail(communityId);
      } else if (joinType == 'request') {
        await _client.from('community_join_requests').insert({
          'community_id': communityId,
          'requester_id': _client.auth.currentUser!.id,
          'message': joinMessage,
          'status': 'pending'
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> leaveCommunity(String communityId) async {
    try {
      final memberCheck = await _client
          .from('community_members')
          .select('role')
          .eq('community_id', communityId)
          .eq('user_id', _client.auth.currentUser!.id)
          .single();

      if (memberCheck['role'] == 'faculty_head' || memberCheck['role'] == 'president') {
        throw Exception('You cannot leave without assigning a successor first.');
      }

      await _client
          .from('community_members')
          .delete()
          .eq('community_id', communityId)
          .eq('user_id', _client.auth.currentUser!.id);

      await fetchCommunityDetail(communityId);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<CommunityMemberModel>> fetchCommunityMembers(String communityId, {String? role, int? semester, String? search}) async {
    try {
      var members = await _memberRepository.getCommunityMembers(communityId);

      if (role != null) {
        members = members.where((m) => m.role == role).toList();
      }
      if (semester != null) {
        members = members.where((m) => m.profileSemester == semester).toList();
      }
      if (search != null && search.isNotEmpty) {
        members = members.where((m) => m.fullName.toLowerCase().contains(search.toLowerCase())).toList();
      }

      return members;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateMemberRole(String memberId, String newRole) async {
    try {
      final currentUid = _client.auth.currentUser!.id;
      await _memberRepository.updateMemberRole(memberId, newRole, currentUid);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeMember(String memberId) async {
    try {
      await _memberRepository.removeMember(memberId);
    } catch (e) {
      rethrow;
    }
  }

  Future<String> generateInviteLink(String communityId) async {
    try {
      final token = _generateRandomString(16);
      final expires = DateTime.now().add(const Duration(days: 7)).toIso8601String();

      await _client.from('community_invite_links').insert({
        'community_id': communityId,
        'token': token,
        'created_by': _client.auth.currentUser!.id,
        'expires_at': expires,
        'max_uses': 200,
        'is_active': true
      });
      return 'unisharesync://communities/$communityId/invite/$token';
    } catch (e) {
      rethrow;
    }
  }

  Future<void> useInviteLink(String token) async {
    try {
      final invite = await _client.from('community_invite_links').select().eq('token', token).single();
      final expiresAt = DateTime.parse(invite['expires_at'] as String);

      if (expiresAt.isBefore(DateTime.now()) || invite['is_active'] == false) {
        throw Exception('Invite link has expired or is invalid.');
      }

      if (invite['max_uses'] != null && (invite['use_count'] as int) >= (invite['max_uses'] as int)) {
        throw Exception('Invite link has reached its maximum uses.');
      }

      final communityId = invite['community_id'].toString();

      await _memberRepository.addMember(communityId, _client.auth.currentUser!.id, 'member');

      await _client.from('community_invite_links').update({
        'use_count': (invite['use_count'] as int) + 1
      }).eq('id', invite['id']);

      await fetchCommunityDetail(communityId);
    } catch (e) {
      rethrow;
    }
  }

  String _generateRandomString(int len) {
    var r = Random();
    const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    return List.generate(len, (index) => chars[r.nextInt(chars.length)]).join();
  }

  Future<List<CommunityJoinRequestModel>> fetchJoinRequests(String communityId) async {
    try {
      final response = await _client
          .from('community_join_requests')
          .select('''
            *,
            profile:profiles(id, full_name, avatar_url)
          ''')
          .eq('community_id', communityId)
          .eq('status', 'pending');
      final data = response as List<dynamic>;
      return data.map((json) => CommunityJoinRequestModel.fromMap(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> reviewJoinRequest(String requestId, String status, String requesterId, String communityId) async {
    try {
      final currentUid = _client.auth.currentUser!.id;
      
      // Update status in community_join_requests
      await _client.from('community_join_requests').update({
        'status': status,
        'reviewed_by': currentUid,
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      // If approved, insert new row to community_members
      if (status == 'approved') {
        await _memberRepository.addMember(communityId, requesterId, 'member');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateCoverPhoto(String communityId, Uint8List bytes, String fileName) async {
    try {
      final path = 'covers/$communityId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await _client.storage.from('community-assets').uploadBinary(path, bytes);
      final publicUrl = _client.storage.from('community-assets').getPublicUrl(path);

      await _client.from('communities').update({
        'cover_photo_url': publicUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', communityId);

      await fetchCommunityDetail(communityId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateLogo(String communityId, Uint8List bytes, String fileName) async {
    try {
      final path = 'logos/$communityId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await _client.storage.from('community-assets').uploadBinary(path, bytes);
      final publicUrl = _client.storage.from('community-assets').getPublicUrl(path);

      await _client.from('communities').update({
        'logo_url': publicUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', communityId);

      await fetchCommunityDetail(communityId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  void dispose() {
    _memberCountSubscription?.cancel();
    super.dispose();
  }
}

final communityDetailProvider = StateNotifierProvider<CommunityDetailNotifier, AsyncValue<CommunityModel>>((ref) {
  return CommunityDetailNotifier(Supabase.instance.client);
});
