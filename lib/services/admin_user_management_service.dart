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
    final res = await _client.functions.invoke(
      'admin-create-user',
      body: {
        'email': email,
        'password': password,
        'fullName': fullName,
        'role': role.value,
        'department': department,
        'studentId': studentId,
        'semester': semester,
        'designation': designation,
      },
    );
    if (res.status != 200) {
      final msg = (res.data as Map?)?['error'] ?? 'User creation failed.';
      throw StateError(msg.toString());
    }
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
    // Ban/unban in auth.users via a SECURITY DEFINER RPC (admin API requires service role key)
    await _client.rpc('set_user_active', params: {
      'target_user_id': userId,
      'is_active': active,
    });
  }

  Future<void> changeRole(String userId, UserRole newRole) async {
    await _client
        .from('profiles')
        .update({'role': newRole.value, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', userId);
  }
}
