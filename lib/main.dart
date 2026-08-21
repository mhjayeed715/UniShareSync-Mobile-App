import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:unisharesync_mobile_app/services/push_notification_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_secrets.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/bus_tracker/bus_tracker_service.dart';

Future<void> main() async {
  // Ensure Flutter bindings are initialized before any async operations
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    const FirebaseOptions webFirebaseOptions = FirebaseOptions(
      apiKey: "AIzaSyCMKXTk2EuoCqTWS6A6DTQy4FQ0LiyIT34",
      authDomain: "unisharesync-mobile-app.firebaseapp.com",
      projectId: "unisharesync-mobile-app",
      storageBucket: "unisharesync-mobile-app.firebasestorage.app",
      messagingSenderId: "940839736695",
      appId: "1:940839736695:web:ab391063b3e4448ab33d72",
      measurementId: "G-F6E1B5S6EK"
    );
    await Firebase.initializeApp(options: webFirebaseOptions);
  } else {
    // Android: google-services.json is auto-read by the Gradle plugin
    await Firebase.initializeApp();
  }

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  await Hive.initFlutter();

  await Supabase.initialize(
    url: AppSecrets.supabaseUrl,
    anonKey: AppSecrets.supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: UniShareSyncApp(),
    ),
  );

  unawaited(_bootstrapAppServices());
}

Future<void> _bootstrapAppServices() async {
  try {
    final initialUserId = Supabase.instance.client.auth.currentUser?.id;
    await PushNotificationService.instance.init(userId: initialUserId);

    await BusTrackerService.instance.initTimetable();
  } catch (_) {
    // Non-critical startup services should not block the first screen.
  }
}

class UniShareSyncApp extends StatelessWidget {
  const UniShareSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Lock to portrait and request high-refresh-rate rendering
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    return MaterialApp(
      title: 'UniShareSync',
      debugShowCheckedModeBanner: false,
      // Smooth physics that feel natural on 90/120 Hz displays
      scrollBehavior: const _SmoothScrollBehavior(),
      theme: ThemeData(
        fontFamily: 'Outfit',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F9EFF)),
        useMaterial3: true,
        // Disable the ink splash ripple delay so taps feel instant
        splashFactory: InkRipple.splashFactory,
      ),
      home: const SplashScreen(),
    );
  }
}

class _SmoothScrollBehavior extends ScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child; // remove the glow overscroll indicator
}