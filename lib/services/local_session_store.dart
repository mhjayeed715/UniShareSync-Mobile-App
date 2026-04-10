import 'package:shared_preferences/shared_preferences.dart';

class LocalSessionStore {
  static const _localAdminKey = 'local_admin_signed_in';

  Future<bool> isLocalAdminSignedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_localAdminKey) ?? false;
  }

  Future<void> setLocalAdminSignedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_localAdminKey, value);
  }
}
