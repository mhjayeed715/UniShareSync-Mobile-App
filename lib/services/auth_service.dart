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
      'is_approved': role != UserRole.faculty,
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

  LocalSessionStore get localSessionStore => _localSessionStore;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<void> signUp(SignUpPayload payload) async {
    final normalizedEmail = payload.email.trim().toLowerCase();
    // Block signup if a deactivated profile exists for this email
    final existing = await _client
        .from('profiles')
        .select('is_active')
        .eq('email', normalizedEmail)
        .maybeSingle();
    if (existing != null && existing['is_active'] == false) {
      throw StateError('This email is associated with a deactivated account. Please contact an administrator.');
    }
    await _client.auth.signUp(
      email: normalizedEmail,
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

    if (profile != null && !profile.isActive) {
      await _client.auth.signOut();
      throw StateError('This account has been deactivated. Please contact an administrator.');
    }

    if (profile != null && profile.role == UserRole.faculty && !profile.isApproved) {
      await _client.auth.signOut();
      throw StateError('Your Faculty account has been registered and is pending administrator verification. You will be able to log in once approved by the SMUCT administration.');
    }

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
    final isFixedStudent =
        normalizedEmail == AppSecrets.fixedStudentEmail.toLowerCase() &&
            normalizedPassword == AppSecrets.fixedStudentPassword;

    if (isFixedAdmin) {
      try {
        final authResponse = await _client.auth.signInWithPassword(
          email: normalizedEmail,
          password: normalizedPassword,
        );
        await _localSessionStore.setLocalAdminSignedIn(false);
        await _localSessionStore.setSupabaseSessionActive(true);
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
        await _localSessionStore.setSupabaseSessionActive(true);
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
      } catch (_) {
        // Offline fallback: allow demo faculty without a Supabase account.
        await _localSessionStore.setDemoSession(
          ProfileModel(
            id: 'demo-faculty-local',
            email: normalizedEmail,
            fullName: 'Demo Faculty',
            role: UserRole.faculty,
            designation: 'Lecturer',
            avatarUrl: null,
            department: null,
            studentId: null,
            semester: null,
          ),
        );
        return const AuthSessionInfo(
          role: UserRole.faculty,
          isLocalAdmin: false,
        );
      }
    }

    if (isFixedStudent) {
      try {
        final authResponse = await _client.auth.signInWithPassword(
          email: normalizedEmail,
          password: normalizedPassword,
        );
        await _localSessionStore.setLocalAdminSignedIn(false);
        await _localSessionStore.setSupabaseSessionActive(true);
        await _profileService.ensureProfileForCurrentUser(
          email: normalizedEmail,
          fullName: 'Demo Student',
          role: UserRole.student,
          studentId: '223071000',
          semester: '9',
          department: 'Computer Science & Engineering',
        );
        final studentProfile = await _profileService.getCurrentProfile();
        return AuthSessionInfo(
          role: UserRole.student,
          isLocalAdmin: false,
          profile: studentProfile,
          user: authResponse.user,
        );
      } catch (_) {
        // Offline fallback: allow demo student without a Supabase account.
        await _localSessionStore.setDemoSession(
          ProfileModel(
            id: 'demo-student-local',
            email: normalizedEmail,
            fullName: 'Demo Student',
            role: UserRole.student,
            studentId: '223071000',
            semester: '9',
            department: 'Computer Science & Engineering',
            designation: null,
            avatarUrl: null,
          ),
        );
        return const AuthSessionInfo(
          role: UserRole.student,
          isLocalAdmin: false,
        );
      }
    }

    // ── Predefined driver accounts (local credential, no Supabase auth) ──────
    final driverMatch = AppSecrets.driverAccounts.where(
      (d) => d[0] == normalizedEmail && d[1] == normalizedPassword,
    );
    if (driverMatch.isNotEmpty) {
      final driver = driverMatch.first;
      await _localSessionStore.setLocalAdminSignedIn(false);
      await _localSessionStore.setDriverSession(
        email: driver[0],
        name: driver[2],
        routeId: driver[3],
      );
      return AuthSessionInfo(
        role: UserRole.driver,
        isLocalAdmin: false,
        profile: ProfileModel(
          id: driver[4],
          email: driver[0],
          fullName: driver[2],
          role: UserRole.driver,
          designation: 'Bus Driver',
          avatarUrl: null,
          department: null,
          studentId: null,
          semester: null,
        ),
      );
    }

    final authResponse = await _client.auth.signInWithPassword(
      email: normalizedEmail,
      password: normalizedPassword,
    );

    await _localSessionStore.setLocalAdminSignedIn(false);

    final profile = await _profileService.getCurrentProfile();

    if (profile != null && !profile.isActive) {
      await _client.auth.signOut();
      throw StateError('Your account has been deactivated. Please contact an administrator.');
    }

    if (profile != null && profile.role == UserRole.faculty && !profile.isApproved) {
      await _client.auth.signOut();
      throw StateError('Your Faculty account is currently pending administrative verification. An administrator must approve your account before you can log in.');
    }

    await _localSessionStore.setSupabaseSessionActive(true);

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
    // Live Supabase session (online)
    if (_client.auth.currentSession != null) return true;
    // Local-only sessions
    if (await _localSessionStore.isLocalAdminSignedIn()) return true;
    if (await _localSessionStore.isDriverSignedIn()) return true;
    if (await _localSessionStore.hasDemoSession()) return true;
    // Offline fallback: user had a valid Supabase session last time they were online
    return _localSessionStore.wasSupabaseSessionActive();
  }

  Future<UserRole?> getCurrentRole() async {
    final hasLocalAdmin = await _localSessionStore.isLocalAdminSignedIn();
    if (hasLocalAdmin && _client.auth.currentSession == null) {
      return UserRole.admin;
    }

    final isDriver = await _localSessionStore.isDriverSignedIn();
    if (isDriver && _client.auth.currentSession == null) {
      return UserRole.driver;
    }

    if (_client.auth.currentSession == null) {
      final demoProfile = await _localSessionStore.getDemoSessionProfile();
      if (demoProfile != null) return demoProfile.role;

      // Offline: Supabase session exists on-device but couldn't refresh.
      // Try to resolve role from the cached profile.
      if (await _localSessionStore.wasSupabaseSessionActive()) {
        final user = _client.auth.currentUser; // may still be populated
        if (user != null) {
          final cached = await _localSessionStore.getCachedProfile(user.id);
          if (cached != null) return cached.role;
          // Fall back to email-based role resolution
          final email = user.email?.toLowerCase();
          if (email == AppSecrets.fixedAdminEmail.toLowerCase()) return UserRole.admin;
          if (email == AppSecrets.fixedFacultyEmail.toLowerCase()) return UserRole.faculty;
          if (email == AppSecrets.fixedStudentEmail.toLowerCase()) return UserRole.student;
          return UserRole.fromString(user.userMetadata?['role']?.toString());
        }
      }
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

    if (user.email?.toLowerCase() ==
        AppSecrets.fixedStudentEmail.toLowerCase()) {
      return UserRole.student;
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
    await _localSessionStore.clearDriverSession();
    await _localSessionStore.clearDemoSession();
    await _localSessionStore.setSupabaseSessionActive(false);

    if (_client.auth.currentSession != null) {
      await _client.auth.signOut();
    }
  }
}
