import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/community_activity_post_model.dart';
import '../../data/repositories/community_activity_repository.dart';

class CommunityActivityNotifier extends StateNotifier<AsyncValue<List<CommunityActivityPostModel>>> {
  CommunityActivityNotifier(this._client) : super(const AsyncValue.loading()) {
    _repository = CommunityActivityRepository(_client);
  }

  final SupabaseClient _client;
  late final CommunityActivityRepository _repository;

  Future<void> fetchActivityPosts(String communityId) async {
    state = const AsyncValue.loading();
    try {
      final posts = await _repository.getActivityPosts(communityId);
      state = AsyncValue.data(posts);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> createActivityPost(Map<String, dynamic> postData, {List<Uint8List> photoBytesList = const [], List<String> photoNamesList = const []}) async {
    try {
      final payload = Map<String, dynamic>.from(postData);
      payload['posted_by'] = _client.auth.currentUser!.id;

      // 1. Insert post first
      final response = await _client.from('community_activity_posts').insert(payload).select('id').single();
      final postId = response['id'].toString();

      // 2. Upload photos if any
      final communityId = postData['community_id'].toString();
      for (int i = 0; i < photoBytesList.length; i++) {
        final bytes = photoBytesList[i];
        final name = photoNamesList[i];
        final url = await _uploadActivityPhoto(communityId, postId, bytes, name, i);
        
        await _repository.addActivityPhoto({
          'activity_post_id': postId,
          'photo_url': url,
          'display_order': i,
        });
      }

      await fetchActivityPosts(communityId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteActivityPost(String postId, String communityId) async {
    try {
      await _repository.deleteActivityPost(postId);
      await fetchActivityPosts(communityId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addReaction(String postId, String emoji, String communityId) async {
    try {
      await _repository.addReaction(postId, emoji);
      await fetchActivityPosts(communityId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeReaction(String postId, String emoji, String communityId) async {
    try {
      await _repository.removeReaction(postId, emoji);
      await fetchActivityPosts(communityId);
    } catch (e) {
      rethrow;
    }
  }

  Future<String> _uploadActivityPhoto(String communityId, String postId, Uint8List bytes, String fileName, int index) async {
    final name = '${postId}_photo_${index}_$fileName';
    final path = 'activity/$communityId/$name';
    await _client.storage.from('community-assets').uploadBinary(path, bytes);
    return _client.storage.from('community-assets').getPublicUrl(path);
  }
}

final communityActivityProvider = StateNotifierProvider<CommunityActivityNotifier, AsyncValue<List<CommunityActivityPostModel>>>((ref) {
  return CommunityActivityNotifier(Supabase.instance.client);
});
