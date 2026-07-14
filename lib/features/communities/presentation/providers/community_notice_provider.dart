import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/community_notice_model.dart';
import '../../data/repositories/community_notice_repository.dart';

class CommunityNoticeNotifier extends StateNotifier<AsyncValue<List<CommunityNoticeModel>>> {
  CommunityNoticeNotifier(this._client) : super(const AsyncValue.loading()) {
    _repository = CommunityNoticeRepository(_client);
  }

  final SupabaseClient _client;
  late final CommunityNoticeRepository _repository;
  StreamSubscription? _newNoticeSubscription;
  final List<CommunityNoticeModel> _notices = [];

  Future<void> fetchNotices(String communityId) async {
    state = const AsyncValue.loading();
    try {
      final list = await _repository.getNotices(communityId);
      _notices.clear();
      _notices.addAll(list);
      state = AsyncValue.data(List.from(_notices));
      
      subscribeToNewNotices(communityId);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> createNotice(Map<String, dynamic> noticeData, {String? imagePath, String? docPath}) async {
    try {
      final payload = Map<String, dynamic>.from(noticeData);
      payload['posted_by'] = _client.auth.currentUser!.id;
      
      if (imagePath != null && payload['community_id'] != null) {
        final imgUrl = await _uploadNoticeFile(payload['community_id'].toString(), imagePath, 'image');
        payload['image_url'] = imgUrl;
      }
      if (docPath != null && payload['community_id'] != null) {
        final docUrl = await _uploadNoticeFile(payload['community_id'].toString(), docPath, 'pdf');
        payload['attachment_url'] = docUrl;
        payload['attachment_name'] = docPath.split('/').last;
      }

      await _repository.createNotice(payload);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> pinNotice(String noticeId, bool isPinned) async {
    try {
      await _repository.pinNotice(noticeId, isPinned);
      // Local updates
      if (state is AsyncData<List<CommunityNoticeModel>>) {
        final current = state.value!;
        final idx = current.indexWhere((n) => n.id == noticeId);
        if (idx != -1) {
          final updated = List<CommunityNoticeModel>.from(current);
          updated[idx] = updated[idx].toMap() as dynamic; // Dummy cast or mapping logic
          // Fetch notices again to preserve exact sort
          fetchNotices(current.first.communityId);
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteNotice(String noticeId) async {
    try {
      await _repository.deleteNotice(noticeId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addReaction(String noticeId, String emoji) async {
    try {
      await _repository.addReaction(noticeId, emoji);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeReaction(String noticeId, String emoji) async {
    try {
      await _repository.removeReaction(noticeId, emoji);
    } catch (e) {
      rethrow;
    }
  }

  void subscribeToNewNotices(String communityId) {
    _newNoticeSubscription?.cancel();
    _newNoticeSubscription = _client
        .from('community_notices:community_id=eq.$communityId')
        .stream(primaryKey: ['id'])
        .listen((data) async {
          if (data.isNotEmpty) {
            await fetchNotices(communityId);
          }
        });
  }

  Future<String> _uploadNoticeFile(String communityId, String localPath, String type) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.${type == 'pdf' ? 'pdf' : 'jpg'}';
    final fileBytes = await _client.storage.from('community-assets').upload(
      'notices/$communityId/$fileName',
      _client.auth.currentUser!.id as dynamic
    );
    return _client.storage.from('community-assets').getPublicUrl(fileBytes);
  }

  @override
  void dispose() {
    _newNoticeSubscription?.cancel();
    super.dispose();
  }
}

final communityNoticeProvider = StateNotifierProvider<CommunityNoticeNotifier, AsyncValue<List<CommunityNoticeModel>>>((ref) {
  return CommunityNoticeNotifier(Supabase.instance.client);
});
