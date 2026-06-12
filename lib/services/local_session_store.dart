import 'package:shared_preferences/shared_preferences.dart';

class LocalSessionStore {
  static const _localAdminKey = 'local_admin_signed_in';
  static const _driverEmailKey = 'driver_email';
  static const _driverNameKey = 'driver_name';
  static const _driverRouteKey = 'driver_route_id';

  Future<bool> isLocalAdminSignedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_localAdminKey) ?? false;
  }

  Future<void> setLocalAdminSignedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_localAdminKey, value);
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
}
