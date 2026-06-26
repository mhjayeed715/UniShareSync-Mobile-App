import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io';
import 'package:unisharesync_mobile_app/core/utils/notification_permission.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/config/app_secrets.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/bus_tracker/bus_tracker_service.dart';

Future<void> main() async {
  // Ensure Flutter bindings are initialized before any async operations
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Firebase
  // On Android, google-services.json + the Gradle plugin provide config
  // automatically. On Web, explicit options are required.
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

  // Request runtime notification permission on Android
  if (!kIsWeb && Platform.isAndroid) {
    await NotificationPermission.ensureGranted();
  }

  // Initialize Hive
  await Hive.initFlutter();

  // Initialize Supabase
  await Supabase.initialize(
    url: AppSecrets.supabaseUrl,
    anonKey: AppSecrets.supabaseAnonKey,
  );

  // Init bus timetable cache — non-fatal if it fails
  try {
    await BusTrackerService.instance.initTimetable();
  } catch (_) {}

  runApp(const UniShareSyncApp());
}

class UniShareSyncApp extends StatelessWidget {
  const UniShareSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniShareSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F9EFF)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}