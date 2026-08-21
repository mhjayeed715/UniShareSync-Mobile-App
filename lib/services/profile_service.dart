import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/data/models/profile_model.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';
import 'package:unisharesync_mobile_app/services/local_session_store.dart';

class ProfileService {
  ProfileService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final LocalSessionStore _localSessionStore = LocalSessionStore();

  Future<ProfileModel?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }

    try {
      final results = await Connectivity().checkConnectivity();
      final isOffline = results.every((r) => r == ConnectivityResult.none);
      if (isOffline) {
        return _localSessionStore.getCachedProfile(user.id);
      }
    } catch (_) {}

    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) {
        return _localSessionStore.getCachedProfile(user.id);
      }

      final profile = ProfileModel.fromMap(response);
      await _localSessionStore.cacheProfile(profile);
      return profile;
    } catch (_) {
      return _localSessionStore.getCachedProfile(user.id);
    }
  }

  Future<void> ensureProfileForCurrentUser({
    required String email,
    required String fullName,
    required UserRole role,
    String? department,
    String? studentId,
    String? semester,
    String? designation,
    String? avatarUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return;
    }

    final profile = ProfileModel(
      id: user.id,
      email: email,
      fullName: fullName,
      role: role,
      department: department,
      studentId: studentId,
      semester: semester,
      designation: designation,
      avatarUrl: avatarUrl,
    );

    await _client.from('profiles').upsert(profile.toUpsertMap());
    await _localSessionStore.cacheProfile(profile);
  }

  Future<void> updateCurrentProfile(ProfileModel profile) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No active user session found.');
    }

    final updated = profile.copyWith(id: user.id);
    await _client.from('profiles').upsert(updated.toUpsertMap());
    await _localSessionStore.cacheProfile(updated);
  }

  Future<String> uploadProfilePhoto({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('You must sign in to upload a profile photo.');
    }

    final normalizedExtension = fileExtension.toLowerCase().replaceAll('.', '');
    final objectPath = '${user.id}/avatar.$normalizedExtension';

    await _client.storage.from('profile-photos').uploadBinary(
      objectPath,
      bytes,
      fileOptions: FileOptions(
        upsert: true,
        contentType: _contentType(normalizedExtension),
      ),
    );

    final publicUrl = _client.storage.from('profile-photos').getPublicUrl(objectPath);

    await _client.from('profiles').update({
      'id': user.id,
      'avatar_url': publicUrl,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);

    final cachedProfile = await getCurrentProfile();
    if (cachedProfile != null) {
      await _localSessionStore.cacheProfile(cachedProfile.copyWith(avatarUrl: publicUrl));
    }

    return publicUrl;
  }

  String _contentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
