import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/data/models/profile_model.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';

class AdminUserManagementService {
  AdminUserManagementService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<ProfileModel>> getAllUsers() async {
    final rows = await _client
        .from('profiles')
        .select()
        .order('full_name')
        .timeout(const Duration(seconds: 10));
    return rows.map<ProfileModel>((r) => ProfileModel.fromMap(r)).toList();
  }

  Future<void> createUser({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? department,
    String? studentId,
    String? semester,
    String? designation,
  }) async {
    final res = await _client.auth.admin.createUser(
      AdminUserAttributes(
        email: email.trim().toLowerCase(),
        password: password,
        emailConfirm: true,
        userMetadata: {
          'role': role.value,
          'full_name': fullName,
        },
      ),
    );
    final uid = res.user?.id;
    if (uid == null) throw StateError('User creation failed.');

    await _client.from('profiles').upsert({
      'id': uid,
      'email': email.trim().toLowerCase(),
      'full_name': fullName,
      'role': role.value,
      'department': department,
      'student_id': studentId,
      'semester': semester,
      'designation': designation,
      'is_active': true,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateUser(ProfileModel profile) async {
    await _client.from('profiles').update({
      'full_name': profile.fullName,
      'role': profile.role.value,
      'department': profile.department,
      'student_id': profile.studentId,
      'semester': profile.semester,
      'designation': profile.designation,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', profile.id);
  }

  Future<void> setActiveStatus(String userId, {required bool active}) async {
    await _client
        .from('profiles')
        .update({'is_active': active, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', userId);
  }

  Future<void> changeRole(String userId, UserRole newRole) async {
    await _client
        .from('profiles')
        .update({'role': newRole.value, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', userId);
  }
}
