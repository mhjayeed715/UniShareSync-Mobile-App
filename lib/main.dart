import 'package:flutter/material.dart';
import 'package:unisharesync_mobile_app/features/splash/splash_screen.dart';

void main() {
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
