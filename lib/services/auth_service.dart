import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/core/config/app_secrets.dart';
import 'package:unisharesync_mobile_app/data/models/profile_model.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';
import 'package:unisharesync_mobile_app/services/local_session_store.dart';
import 'package:unisharesync_mobile_app/services/profile_service.dart';

class SignUpPayload {
  const SignUpPayload({
    required this.email,
    required this.password,
    required this.fullName,
    required this.role,
    this.department,
    this.studentId,
    this.semester,
    this.designation,
  });

  final String email;
  final String password;
  final String fullName;
  final UserRole role;
  final String? department;
  final String? studentId;
  final String? semester;
  final String? designation;

  Map<String, dynamic> toMetadata() {
    return {
      'role': role.value,
      'full_name': fullName,
      'department': department,
      'student_id': studentId,
      'semester': semester,
      'designation': designation,
    };
  }
}

class AuthSessionInfo {
  const AuthSessionInfo({
    required this.role,
    required this.isLocalAdmin,
    this.profile,
    this.user,
  });

  final UserRole role;
  final bool isLocalAdmin;
  final ProfileModel? profile;
  final User? user;
}

class AuthService {
  AuthService({
    SupabaseClient? client,
    LocalSessionStore? localSessionStore,
    ProfileService? profileService,
  })  : _client = client ?? Supabase.instance.client,
        _localSessionStore = localSessionStore ?? LocalSessionStore(),
        _profileService = profileService ?? ProfileService(client: client);

  final SupabaseClient _client;
  final LocalSessionStore _localSessionStore;
  final ProfileService _profileService;

  Future<void> signUp(SignUpPayload payload) async {
    await _client.auth.signUp(
      email: payload.email.trim().toLowerCase(),
      password: payload.password,
      data: payload.toMetadata(),
    );
  }

  Future<AuthSessionInfo> verifySignupOtp({
    required String email,
    required String otp,
  }) async {
    final response = await _client.auth.verifyOTP(
      email: email.trim().toLowerCase(),
      token: otp.trim(),
      type: OtpType.signup,
    );

    final user = response.user ?? _client.auth.currentUser;
    if (user == null) {
      throw StateError('Unable to verify OTP. Try again.');
    }

    await _localSessionStore.setLocalAdminSignedIn(false);

    final profile = await _profileService.getCurrentProfile();
    final role = profile?.role ??
        UserRole.fromString(user.userMetadata?['role']?.toString());

    return AuthSessionInfo(
        role: role, isLocalAdmin: false, profile: profile, user: user);
  }

  Future<AuthSessionInfo> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.trim();

    final isFixedAdmin =
        normalizedEmail == AppSecrets.fixedAdminEmail.toLowerCase() &&
            normalizedPassword == AppSecrets.fixedAdminPassword;
    final isFixedFaculty =
        normalizedEmail == AppSecrets.fixedFacultyEmail.toLowerCase() &&
            normalizedPassword == AppSecrets.fixedFacultyPassword;

    if (isFixedAdmin) {
      try {
        final authResponse = await _client.auth.signInWithPassword(
          email: normalizedEmail,
          password: normalizedPassword,
        );

        await _localSessionStore.setLocalAdminSignedIn(false);

        await _profileService.ensureProfileForCurrentUser(
          email: normalizedEmail,
          fullName: 'UniShareSync Administrator',
          role: UserRole.admin,
          designation: 'System Admin',
        );

        final adminProfile = await _profileService.getCurrentProfile();

        return AuthSessionInfo(
          role: UserRole.admin,
          isLocalAdmin: false,
          profile: adminProfile,
          user: authResponse.user,
        );
      } catch (_) {
        // Allow fixed admin credentials to access admin flow even without a backend account.
        await _localSessionStore.setLocalAdminSignedIn(true);
        return const AuthSessionInfo(role: UserRole.admin, isLocalAdmin: true);
      }
    }

    if (isFixedFaculty) {
      try {
        final authResponse = await _client.auth.signInWithPassword(
          email: normalizedEmail,
          password: normalizedPassword,
        );

        await _localSessionStore.setLocalAdminSignedIn(false);

        await _profileService.ensureProfileForCurrentUser(
          email: normalizedEmail,
          fullName: 'Demo Faculty',
          role: UserRole.faculty,
          designation: 'Lecturer',
        );

        final facultyProfile = await _profileService.getCurrentProfile();

        return AuthSessionInfo(
          role: UserRole.faculty,
          isLocalAdmin: false,
          profile: facultyProfile,
          user: authResponse.user,
        );
      } catch (error) {
        throw StateError(
          'Demo faculty sign-in failed. Ensure this account exists in Supabase Auth with confirmed email. ($error)',
        );
      }
    }

    final authResponse = await _client.auth.signInWithPassword(
      email: normalizedEmail,
      password: normalizedPassword,
    );

    await _localSessionStore.setLocalAdminSignedIn(false);

    final profile = await _profileService.getCurrentProfile();
    final resolvedRole = profile?.role ??
        UserRole.fromString(
            authResponse.user?.userMetadata?['role']?.toString());

    return AuthSessionInfo(
      role: resolvedRole,
      isLocalAdmin: false,
      profile: profile,
      user: authResponse.user,
    );
  }

  Future<void> sendPasswordResetOtp(String email) async {
    await _client.auth.resetPasswordForEmail(
      email.trim().toLowerCase(),
      redirectTo: AppSecrets.passwordRecoveryRedirectTo,
    );
  }

  Future<void> resendPasswordResetOtp(String email) async {
    await _client.auth.resend(
      type: OtpType.recovery,
      email: email.trim().toLowerCase(),
      emailRedirectTo: AppSecrets.passwordRecoveryRedirectTo,
    );
  }

  Future<void> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {
    await _client.auth.verifyOTP(
      email: email.trim().toLowerCase(),
      token: otp.trim(),
      type: OtpType.recovery,
    );
  }

  Future<void> updatePassword(String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  Future<bool> hasActiveSession() async {
    return _client.auth.currentSession != null ||
        await _localSessionStore.isLocalAdminSignedIn();
  }

  Future<UserRole?> getCurrentRole() async {
    final hasLocalAdmin = await _localSessionStore.isLocalAdminSignedIn();
    if (hasLocalAdmin && _client.auth.currentSession == null) {
      return UserRole.admin;
    }

    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }

    final profile = await _profileService.getCurrentProfile();
    if (profile != null) {
      return profile.role;
    }

    if (user.email?.toLowerCase() == AppSecrets.fixedAdminEmail.toLowerCase()) {
      return UserRole.admin;
    }

    if (user.email?.toLowerCase() ==
        AppSecrets.fixedFacultyEmail.toLowerCase()) {
      return UserRole.faculty;
    }

    return UserRole.fromString(user.userMetadata?['role']?.toString());
  }

  Future<ProfileModel?> getCurrentProfile() {
    return _profileService.getCurrentProfile();
  }

  Future<bool> isLocalAdminSession() {
    return _localSessionStore.isLocalAdminSignedIn();
  }

  Future<void> signOut() async {
    await _localSessionStore.setLocalAdminSignedIn(false);

    if (_client.auth.currentSession != null) {
      await _client.auth.signOut();
    }
  }
}
