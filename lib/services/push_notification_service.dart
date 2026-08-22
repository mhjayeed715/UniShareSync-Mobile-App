import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/features/notice_board/notice_board_screen.dart';
import 'package:unisharesync_mobile_app/main.dart';

const String _channelId = 'campus_notices_channel';
const String _channelName = 'Campus Notices';
const String _notifIcon = 'ic_notification';
const _largeIcon =
    DrawableResourceAndroidBitmap('@mipmap/ic_unisharesync_logo');

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // notification block = Android shows it automatically. Only handle data-only.
  if (message.notification == null) {
    final title = message.data['title']?.toString();
    final body = message.data['body']?.toString();
    if (title == null || body == null || body.isEmpty) return;
    final payloadJson = jsonEncode(message.data);
    await _showLocalNotification(
        title, body, payloadJson, message.hashCode);
  }
}

Future<void> _showLocalNotification(
  String title,
  String body,
  String? payload,
  int id,
) async {
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(const AndroidNotificationChannel(
        _channelId,
        _channelName,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ));
  await plugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings(_notifIcon),
  ));
  await plugin.show(
    id,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.max,
        priority: Priority.high,
        icon: _notifIcon,
        largeIcon: _largeIcon,
        playSound: true,
        enableVibration: true,
      ),
    ),
    payload: payload,
  );
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;

  Future<void> init({String? userId}) async {
    if (_initialised) {
      if (userId != null) await _saveToken(userId);
      return;
    }
    _initialised = true;

    if (kIsWeb) {
      try {
        final settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('[FCM Web] Notification permission: ${settings.authorizationStatus}');

        final targetUid = userId ?? Supabase.instance.client.auth.currentUser?.id;
        if (targetUid != null) {
          final token = await _messaging.getToken();
          if (token != null) await _persistToken(targetUid, token);
        }

        _messaging.onTokenRefresh.listen((token) async {
          final uid = Supabase.instance.client.auth.currentUser?.id;
          if (uid != null) await _persistToken(uid, token);
        });

        Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
          final uid = data.session?.user.id;
          if (uid != null) {
            final token = await _messaging.getToken();
            if (token != null) await _persistToken(uid, token);
          }
        });

        FirebaseMessaging.onMessage.listen(_handleForeground);
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          _handleNotificationRouting(message.data);
        });
      } catch (e) {
        debugPrint('[FCM Web] init error: $e');
      }
      return;
    }

    if (!kIsWeb && Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) await Permission.notification.request();
    }

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Campus notices and app updates',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ));

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings(_notifIcon),
      ),
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null && details.payload!.isNotEmpty) {
          try {
            final parsed = jsonDecode(details.payload!);
            if (parsed is Map<String, dynamic>) {
              _handleNotificationRouting(parsed);
              return;
            }
          } catch (_) {}
          _handleNotificationRouting({'type': details.payload});
        }
      },
    );

    // Save token for passed userId
    if (userId != null) {
      final token = await _messaging.getToken();
      if (token != null) await _persistToken(userId, token);
    }

    // Save token for already-logged-in users on fresh reinstall
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    if (currentUid != null && userId == null) {
      final token = await _messaging.getToken();
      if (token != null) await _persistToken(currentUid, token);
    }

    _messaging.onTokenRefresh.listen((token) async {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) await _persistToken(uid, token);
    });

    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final uid = data.session?.user.id;
      if (uid != null) {
        final token = await _messaging.getToken();
        if (token != null) await _persistToken(uid, token);
      }
    });

    FirebaseMessaging.onMessage.listen(_handleForeground);

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationRouting(message.data);
    });

    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        Future.delayed(const Duration(milliseconds: 700), () {
          _handleNotificationRouting(message.data);
        });
      }
    });
  }

  void _handleNotificationRouting(Map<String, dynamic> data) {
    final type = data['type']?.toString().toLowerCase();
    final noticeId = data['notice_id']?.toString() ?? data['id']?.toString();

    final navState = appNavigatorKey.currentState;
    if (navState == null) return;

    if (type == 'notice' || noticeId != null) {
      if (noticeId != null && noticeId.isNotEmpty && noticeId != 'notice') {
        navState.push(
          MaterialPageRoute(
            builder: (_) => NoticeDetailScreen(noticeId: noticeId),
          ),
        );
      } else {
        navState.push(
          MaterialPageRoute(
            builder: (_) => const NoticeBoardScreen(),
          ),
        );
      }
    }
  }

  Future<void> _saveToken(String userId) async {
    final token = await _messaging.getToken();
    if (token != null) await _persistToken(userId, token);
  }

  Future<void> _persistToken(String userId, String token) async {
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', userId)
          .select('id')
          .maybeSingle();
      if (res == null) {
        debugPrint('[FCM] WARNING: token save returned null for $userId');
      } else {
        debugPrint('[FCM] token saved OK for $userId');
      }
    } catch (e) {
      debugPrint('[FCM] token save error: $e');
    }
  }

  void _handleForeground(RemoteMessage message) {
    final title = message.notification?.title ??
        message.data['title']?.toString() ??
        'UniShareSync';
    final body =
        message.notification?.body ?? message.data['body']?.toString() ?? '';
    if (body.isEmpty) return;

    if (kIsWeb) {
      debugPrint('[FCM Web] Foreground message: $title - $body');
      return;
    }

    final payload = jsonEncode(message.data);

    _localNotifications.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.max,
          priority: Priority.high,
          icon: _notifIcon,
          largeIcon: _largeIcon,
          playSound: true,
          enableVibration: true,
        ),
      ),
      payload: payload,
    );
  }
}
