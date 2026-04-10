import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/core/config/app_secrets.dart';
import 'package:unisharesync_mobile_app/features/splash/splash_screen.dart';

final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppSecrets.supabaseUrl,
    anonKey: AppSecrets.supabaseAnonKey,
  );

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
