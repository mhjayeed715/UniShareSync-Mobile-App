import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/data/models/profile_model.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';

class ProfileService {
  ProfileService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<ProfileModel?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }

    final response = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return ProfileModel.fromMap(response);
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
  }

  Future<void> updateCurrentProfile(ProfileModel profile) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No active user session found.');
    }

    await _client.from('profiles').upsert(profile.copyWith(id: user.id).toUpsertMap());
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
