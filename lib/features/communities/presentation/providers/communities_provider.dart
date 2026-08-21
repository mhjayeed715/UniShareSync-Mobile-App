import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/community_model.dart';
import '../../data/repositories/communities_repository.dart';

class CommunitiesNotifier extends StateNotifier<AsyncValue<List<CommunityModel>>> {
  CommunitiesNotifier(this._client) : super(const AsyncValue.loading()) {
    _repository = CommunitiesRepository(_client);
  }

  final SupabaseClient _client;
  late final CommunitiesRepository _repository;

  Future<void> fetchCommunities({
    String? search,
    String? type,
    String? joinType,
    int? activityScoreMin,
  }) async {
    if (!state.hasValue) {
      state = const AsyncValue.loading();
    }
    try {
      final list = await _repository.getCommunities(
        search: search,
        type: type,
        joinType: joinType,
        activityScoreMin: activityScoreMin,
      );
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> createCommunity(Map<String, dynamic> data) async {
    try {
      await _repository.createCommunity(data);
      await fetchCommunities();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateCommunity(String id, Map<String, dynamic> data) async {
    try {
      await _repository.updateCommunity(id, data);
      await fetchCommunities();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteCommunity(String id) async {
    try {
      await _repository.deleteCommunity(id);
      await fetchCommunities();
    } catch (e) {
      rethrow;
    }
  }
}

final communitiesProvider = StateNotifierProvider<CommunitiesNotifier, AsyncValue<List<CommunityModel>>>((ref) {
  return CommunitiesNotifier(Supabase.instance.client);
});
