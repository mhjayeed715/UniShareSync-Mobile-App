import 'package:shared_preferences/shared_preferences.dart';
import 'package:unisharesync_mobile_app/data/models/profile_model.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';

class LocalSessionStore {
  static const _localAdminKey = 'local_admin_signed_in';
  static const _driverEmailKey = 'driver_email';
  static const _driverNameKey = 'driver_name';
  static const _driverRouteKey = 'driver_route_id';
  static const _cachedProfilePrefix = 'cached_profile_';
  static const _demoSessionActiveKey = 'demo_session_active';
  static const _demoSessionUserIdKey = 'demo_session_user_id';
  static const _supabaseSessionActiveKey = 'supabase_session_was_active';

  static String? _demoUserIdInMemory;

  /// Returns the raw SharedPreferences instance so callers can batch-read
  /// multiple keys in a single async call (avoids repeated getInstance() overhead).
  Future<SharedPreferences> getPrefs() => SharedPreferences.getInstance();

  Future<bool> isLocalAdminSignedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_localAdminKey) ?? false;
  }

  Future<void> setLocalAdminSignedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_localAdminKey, value);
  }

  /// Persisted flag: a real Supabase session was active at last sign-in.
  /// Used as offline fallback so the user isn't kicked to onboarding.
  Future<void> setSupabaseSessionActive(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      await prefs.setBool(_supabaseSessionActiveKey, true);
    } else {
      await prefs.remove(_supabaseSessionActiveKey);
    }
  }

  Future<bool> wasSupabaseSessionActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_supabaseSessionActiveKey) ?? false;
  }

  // ── Driver session ─────────────────────────────────────────────────────────

  Future<void> setDriverSession({
    required String email,
    required String name,
    required String routeId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_driverEmailKey, email);
    await prefs.setString(_driverNameKey, name);
    await prefs.setString(_driverRouteKey, routeId);
  }

  Future<Map<String, String>?> getDriverSession() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_driverEmailKey);
    if (email == null) return null;
    return {
      'email': email,
      'name': prefs.getString(_driverNameKey) ?? 'Driver',
      'routeId': prefs.getString(_driverRouteKey) ?? '',
    };
  }

  Future<void> clearDriverSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_driverEmailKey);
    await prefs.remove(_driverNameKey);
    await prefs.remove(_driverRouteKey);
  }

  Future<bool> isDriverSignedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_driverEmailKey) != null;
  }

  Future<void> cacheProfile(ProfileModel profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_cachedProfilePrefix${profile.id}', _encodeProfile(profile));
  }

  Future<ProfileModel?> getCachedProfile(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = prefs.getString('$_cachedProfilePrefix$userId');
    if (payload == null || payload.isEmpty) {
      return null;
    }

    return _decodeProfile(payload);
  }

  Future<void> clearCachedProfile(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_cachedProfilePrefix$userId');
  }

  String? get demoUserId => _demoUserIdInMemory;

  Future<void> setDemoSession(ProfileModel profile) async {
    final prefs = await SharedPreferences.getInstance();
    _demoUserIdInMemory = profile.id;
    await prefs.setBool(_demoSessionActiveKey, true);
    await prefs.setString(_demoSessionUserIdKey, profile.id);
    await cacheProfile(profile);
  }

  Future<bool> hasDemoSession() async {
    if (_demoUserIdInMemory != null) {
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getBool(_demoSessionActiveKey) ?? false;
    final userId = prefs.getString(_demoSessionUserIdKey);
    if (active && userId != null && userId.isNotEmpty) {
      _demoUserIdInMemory = userId;
      return true;
    }

    return false;
  }

  Future<ProfileModel?> getDemoSessionProfile() async {
    if (!await hasDemoSession()) {
      return null;
    }

    final userId = _demoUserIdInMemory;
    if (userId == null || userId.isEmpty) {
      return null;
    }

    return getCachedProfile(userId);
  }

  Future<void> clearDemoSession() async {
    final prefs = await SharedPreferences.getInstance();
    _demoUserIdInMemory = null;
    await prefs.remove(_demoSessionActiveKey);
    await prefs.remove(_demoSessionUserIdKey);
  }

  String _encodeProfile(ProfileModel profile) {
    String value(String? input) => input ?? '';

    return [
      profile.id,
      profile.email,
      profile.fullName,
      profile.role.value,
      value(profile.department),
      value(profile.studentId),
      value(profile.semester),
      value(profile.designation),
      value(profile.avatarUrl),
      profile.isActive ? '1' : '0',
    ].join('||');
  }

  ProfileModel _decodeProfile(String payload) {
    final parts = payload.split('||');
    String? optional(int index) {
      if (index >= parts.length) {
        return null;
      }

      final text = parts[index].trim();
      return text.isEmpty ? null : text;
    }

    return ProfileModel(
      id: parts.isNotEmpty ? parts[0] : '',
      email: parts.length > 1 ? parts[1] : '',
      fullName: parts.length > 2 ? parts[2] : '',
      role: UserRole.fromString(parts.length > 3 ? parts[3] : null),
      department: optional(4),
      studentId: optional(5),
      semester: optional(6),
      designation: optional(7),
      avatarUrl: optional(8),
      isActive: (parts.length > 9 ? parts[9] : '1') == '1',
    );
  }
}
