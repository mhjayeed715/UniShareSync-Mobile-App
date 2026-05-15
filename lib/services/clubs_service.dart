import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/data/models/club_model.dart';

class EventParticipant {
  final String userId;
  final String name;
  final String? avatarUrl;
  final DateTime registeredAt;

  EventParticipant({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.registeredAt,
  });
}

class ClubMember {
  final String userId;
  final String name;
  final String? avatarUrl;
  final String role;
  final DateTime joinedAt;

  ClubMember({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.role,
    required this.joinedAt,
  });
}

class ClubsService {
  ClubsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  // Fetch all clubs
  Future<List<ClubModel>> fetchClubs() async {
    final response = await _client
        .from('clubs')
        .select()
        .order('created_at', ascending: false);

    final clubs = (response as List<dynamic>)
        .map((row) => ClubModel.fromMap(Map<String, dynamic>.from(row)))
        .toList();

    return _applyMembershipStatus(clubs);
  }

  // Search clubs
  Future<List<ClubModel>> searchClubs({String? query}) async {
    var request = _client.from('clubs').select();

    if (query != null && query.trim().isNotEmpty) {
      final escaped = query.trim().replaceAll('%', r'\%');
      request = request.or(
        'name.ilike.%$escaped%,description.ilike.%$escaped%,category.ilike.%$escaped%',
      );
    }

    final response = await request.order('created_at', ascending: false);

    final clubs = (response as List<dynamic>)
        .map((row) => ClubModel.fromMap(Map<String, dynamic>.from(row)))
        .toList();

    return _applyMembershipStatus(clubs);
  }

  // Watch clubs with realtime
  Stream<List<ClubModel>> watchClubs() {
    return _client
        .from('clubs')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data
            .map((row) => ClubModel.fromMap(Map<String, dynamic>.from(row)))
            .toList());
  }

  // Request to join club
  Future<void> requestJoinClub(String clubId) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final isMember = await isUserMember(clubId);
    if (isMember) throw Exception('You are already a member of this club');

    // Check for existing request
    final existing = await _client
        .from('club_join_requests')
        .select('id, status')
        .eq('club_id', clubId)
        .eq('requester_id', userId)
        .maybeSingle();

    if (existing != null) {
      final status = existing['status']?.toString();
      if (status == 'pending') {
        throw Exception('You have already requested to join this club');
      }
      // Update existing rejected request back to pending instead of delete+insert
      await _client
          .from('club_join_requests')
          .update({'status': 'pending'})
          .eq('club_id', clubId)
          .eq('requester_id', userId);
      return;
    }

    final profile = await _client
        .from('profiles')
        .select('full_name, avatar_url')
        .eq('id', userId)
        .single();

    await _client.from('club_join_requests').insert({
      'club_id': clubId,
      'requester_id': userId,
      'requester_name': profile['full_name'] ?? 'Student',
      'requester_avatar': profile['avatar_url'],
      'status': 'pending',
    });
  }

  // Leave club
  Future<void> leaveClub(String clubId) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final club = await _client
        .from('clubs')
        .select('owner_id, member_count')
        .eq('id', clubId)
        .single();

    if (club['owner_id'] == userId) {
      throw Exception('Club owner cannot leave the club');
    }

    // Delete join requests for this user
    await _client
        .from('club_join_requests')
        .delete()
        .eq('club_id', clubId)
        .eq('requester_id', userId);

    // Remove from club_members
    await _client
        .from('club_members')
        .delete()
        .eq('club_id', clubId)
        .eq('user_id', userId);

    // Verify the delete worked
    final stillMember = await _client
        .from('club_members')
        .select('id')
        .eq('club_id', clubId)
        .eq('user_id', userId)
        .maybeSingle();

    if (stillMember != null) {
      throw Exception('Failed to leave club - permission denied');
    }

    final newCount = (club['member_count'] as int) - 1;
    await _client
        .from('clubs')
        .update({'member_count': newCount >= 1 ? newCount : 1})
        .eq('id', clubId);
  }

  // Check if user has requested to join
  Future<bool> hasUserRequested(String clubId) async {
    final userId = currentUserId;
    if (userId == null) return false;

    final response = await _client
        .from('club_join_requests')
        .select('id')
        .eq('club_id', clubId)
        .eq('requester_id', userId)
        .eq('status', 'pending')
        .maybeSingle();

    return response != null;
  }

  // Check if user is member
  Future<bool> isUserMember(String clubId) async {
    final userId = currentUserId;
    if (userId == null) return false;

    final response = await _client
        .from('club_members')
        .select('id')
        .eq('club_id', clubId)
        .eq('user_id', userId)
        .maybeSingle();

    return response != null;
  }

  // Create club (Faculty/Admin only)
  Future<ClubModel> createClub({
    required String name,
    required String description,
    required String category,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final profile = await _client
        .from('profiles')
        .select('full_name, avatar_url')
        .eq('id', user.id)
        .single();

    final payload = {
      'name': name.trim(),
      'description': description.trim(),
      'category': category.trim(),
      'owner_id': user.id,
      'owner_name': profile['full_name'] ?? 'Owner',
      'owner_avatar': profile['avatar_url'],
    };

    final inserted = await _client
        .from('clubs')
        .insert(payload)
        .select()
        .single();

    // Add owner as member
    await _client.from('club_members').insert({
      'club_id': inserted['id'],
      'user_id': user.id,
      'role': 'owner',
    });

    return ClubModel.fromMap(Map<String, dynamic>.from(inserted));
  }

  // Update club
  Future<ClubModel> updateClub({
    required String clubId,
    required String name,
    required String description,
    required String category,
  }) async {
    final payload = {
      'name': name.trim(),
      'description': description.trim(),
      'category': category.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final updated = await _client
        .from('clubs')
        .update(payload)
        .eq('id', clubId)
        .select()
        .single();

    return ClubModel.fromMap(Map<String, dynamic>.from(updated));
  }

  // Delete club
  Future<void> deleteClub(String clubId) async {
    await _client.from('clubs').delete().eq('id', clubId);
  }

  // Fetch join requests for a club
  Future<List<ClubJoinRequest>> fetchJoinRequests(String clubId) async {
    final response = await _client
        .from('club_join_requests')
        .select()
        .eq('club_id', clubId)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((row) => ClubJoinRequest.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  // Review join request
  Future<void> reviewJoinRequest({
    required String requestId,
    required bool approve,
  }) async {
    await _client.rpc('review_club_join_request', params: {
      'p_request_id': requestId,
      'p_action': approve ? 'approve' : 'reject',
    });
  }

  // Fetch club members
  Future<List<ClubMember>> fetchClubMembers(String clubId) async {
    final response = await _client
        .from('club_members')
        .select('user_id, role, joined_at')
        .eq('club_id', clubId)
        .order('joined_at', ascending: false);

    final members = response as List<dynamic>;
    if (members.isEmpty) return [];

    final userIds = members.map((m) => m['user_id'].toString()).toList();
    final profiles = await _client
        .from('profiles')
        .select('id, full_name, avatar_url')
        .inFilter('id', userIds);

    final profileMap = <String, Map<String, dynamic>>{};
    for (final profile in profiles as List<dynamic>) {
      profileMap[profile['id'].toString()] = profile;
    }

    return members.map((mem) {
      final userId = mem['user_id'].toString();
      final profile = profileMap[userId];
      return ClubMember(
        userId: userId,
        name: profile?['full_name'] ?? 'Unknown',
        avatarUrl: profile?['avatar_url'],
        role: mem['role'] ?? 'member',
        joinedAt: DateTime.parse(mem['joined_at']),
      );
    }).toList();
  }

  // Remove member from club
  Future<void> removeMember(String clubId, String userId) async {
    // Delete any existing join requests first
    await _client
        .from('club_join_requests')
        .delete()
        .eq('club_id', clubId)
        .eq('requester_id', userId);

    // Remove from club_members
    await _client
        .from('club_members')
        .delete()
        .eq('club_id', clubId)
        .eq('user_id', userId);

    // Manually decrement member count (minimum 1 for owner)
    final currentClub = await _client
        .from('clubs')
        .select('member_count')
        .eq('id', clubId)
        .single();

    final newCount = (currentClub['member_count'] as int) - 1;
    await _client
        .from('clubs')
        .update({'member_count': newCount >= 1 ? newCount : 1})
        .eq('id', clubId);
  }

  // Apply membership status to clubs
  Future<List<ClubModel>> _applyMembershipStatus(List<ClubModel> clubs) async {
    final userId = currentUserId;
    if (userId == null || clubs.isEmpty) return clubs;

    final clubIds = clubs.map((c) => c.id).toList();

    final memberResponse = await _client
        .from('club_members')
        .select('club_id')
        .eq('user_id', userId)
        .inFilter('club_id', clubIds);

    final memberClubIds = <String>{};
    for (final row in memberResponse as List<dynamic>) {
      final id = row['club_id']?.toString();
      if (id != null) memberClubIds.add(id);
    }

    final requestResponse = await _client
        .from('club_join_requests')
        .select('club_id, status')
        .eq('requester_id', userId)
        .inFilter('club_id', clubIds)
        .order('created_at', ascending: false);

    final requestStatusByClubId = <String, String>{};
    for (final row in requestResponse as List<dynamic>) {
      final id = row['club_id']?.toString();
      final status = row['status']?.toString();
      if (id != null && status != null && !requestStatusByClubId.containsKey(id)) {
        requestStatusByClubId[id] = status;
      }
    }

    return clubs.map((club) {
      final isMember = memberClubIds.contains(club.id);
      final requestStatus = requestStatusByClubId[club.id]; // null if no request
      return ClubModel(
        id: club.id,
        name: club.name,
        description: club.description,
        category: club.category,
        memberCount: club.memberCount,
        ownerId: club.ownerId,
        ownerName: club.ownerName,
        ownerAvatar: club.ownerAvatar,
        logoUrl: club.logoUrl,
        createdAt: club.createdAt,
        isUserMember: isMember,
        joinRequestStatus: requestStatus,
      );
    }).toList();
  }
}
