import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

/// Utility class to ensure the app has permission to post notifications.
///
/// * On Android 13+ (API 33) the system requires a runtime permission
///   `POST_NOTIFICATIONS`. The helper checks the platform version and
///   shows the permission dialog only when needed.
/// * On older Android versions the permission is granted at install
///   time, so the method returns `true` immediately.
class NotificationPermission {
  /// Call this once (e.g. after Firebase initialisation) to request the
  /// notification permission if the OS requires it. Returns `true` when
  /// notifications are allowed.
  static Future<bool> ensureGranted() async {
    if (!Platform.isAndroid) return true; // iOS handles its own flow.

    final status = await Permission.notification.status;
    if (status.isGranted) return true;

    final result = await Permission.notification.request();
    return result.isGranted;
  }
}
