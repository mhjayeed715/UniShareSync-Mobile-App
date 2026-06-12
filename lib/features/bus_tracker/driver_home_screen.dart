import 'package:flutter/material.dart';
import 'package:unisharesync_mobile_app/features/auth/login_screen.dart';
import 'package:unisharesync_mobile_app/features/bus_tracker/bus_tracker_screen.dart';
import 'package:unisharesync_mobile_app/services/auth_service.dart';

class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({
    super.key,
    required this.driverName,
    required this.assignedRouteId,
  });

  final String driverName;
  final String assignedRouteId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14B8A6),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Driver Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            Text(
              driverName,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Sign Out',
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SignInScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: BusTrackerScreen(
        currentUserName: driverName,
        initialRouteId: assignedRouteId,
        isDriver: true,
      ),
    );
  }
}
