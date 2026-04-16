import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:unisharesync_mobile_app/data/models/profile_model.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';
import 'package:unisharesync_mobile_app/features/auth/login_screen.dart';
import 'package:unisharesync_mobile_app/features/profile/profile_management_screen.dart';
import 'package:unisharesync_mobile_app/features/resources/resources_tab_view.dart';
import 'package:unisharesync_mobile_app/services/auth_service.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({
    super.key,
    this.isLocalAdmin,
  });

  final bool? isLocalAdmin;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminPalette {
  static const Color scaffold = Color(0xFFF4F8FF);
  static const Color authGradientStart = Color(0xFFF8FBFF);
  static const Color authGradientEnd = Color(0xFFEAF6FF);
  static const Color authBlue = Color(0xFF4F9EFF);
  static const Color authTeal = Color(0xFF2DD4BF);

  static const Color resourcesBlue = Color(0xFF4F9EFF);
  static const Color noticesAmber = Color(0xFFF59E0B);
  static const Color projectsPurple = Color(0xFF8B5CF6);
  static const Color eventsEmerald = Color(0xFF10B981);
  static const Color lostFoundSoftRed = Color(0xFFF87171);
  static const Color busTrackerTeal = Color(0xFF14B8A6);
  static const Color settingsSlate = Color(0xFF64748B);
  static const Color feedbackIndigo = Color(0xFF6366F1);
  static const Color notificationSky = Color(0xFF0EA5E9);
  static const Color aiAssistantViolet = Color(0xFF7C3AED);
  static const Color roleControlCyan = Color(0xFF06B6D4);
}

class _AdminPanelOption {
  const _AdminPanelOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final AuthService _authService = AuthService();

  bool _isLoading = true;
  bool _isLocalAdmin = false;
  bool _isSigningOut = false;
  ProfileModel? _profile;

  static const List<_AdminPanelOption> _options = [
    _AdminPanelOption(
      title: 'Profile',
      subtitle: 'Manage admin profile details.',
      icon: Icons.person_outline_rounded,
      color: _AdminPalette.authBlue,
    ),
    _AdminPanelOption(
      title: 'Settings',
      subtitle: 'Global app controls and preferences.',
      icon: Icons.settings_outlined,
      color: _AdminPalette.settingsSlate,
    ),
    _AdminPanelOption(
      title: 'Resource Screen',
      subtitle: 'Review and manage learning resources.',
      icon: Icons.menu_book_rounded,
      color: _AdminPalette.resourcesBlue,
    ),
    _AdminPanelOption(
      title: 'Notice Board Screen',
      subtitle: 'Publish and moderate campus notices.',
      icon: Icons.campaign_rounded,
      color: _AdminPalette.noticesAmber,
    ),
    _AdminPanelOption(
      title: 'Projects Screen',
      subtitle: 'Monitor project spaces and activity.',
      icon: Icons.account_tree_rounded,
      color: _AdminPalette.projectsPurple,
    ),
    _AdminPanelOption(
      title: 'Events and Clubs Screen',
      subtitle: 'Approve and manage events and clubs.',
      icon: Icons.celebration_rounded,
      color: _AdminPalette.eventsEmerald,
    ),
    _AdminPanelOption(
      title: 'Lost and Found Screen',
      subtitle: 'Handle item reports and status updates.',
      icon: Icons.search_rounded,
      color: _AdminPalette.lostFoundSoftRed,
    ),
    _AdminPanelOption(
      title: 'Feedback Screen',
      subtitle: 'Review user feedback and reports.',
      icon: Icons.rate_review_outlined,
      color: _AdminPalette.feedbackIndigo,
    ),
    _AdminPanelOption(
      title: 'Notification Center',
      subtitle: 'Broadcast and track notifications.',
      icon: Icons.notifications_active_outlined,
      color: _AdminPalette.notificationSky,
    ),
    _AdminPanelOption(
      title: 'Class Scheduler',
      subtitle: 'Configure schedules and academic slots.',
      icon: Icons.calendar_view_week_rounded,
      color: _AdminPalette.authTeal,
    ),
    _AdminPanelOption(
      title: 'AI Campus Assistant',
      subtitle: 'Manage assistant behavior and prompts.',
      icon: Icons.smart_toy_outlined,
      color: _AdminPalette.aiAssistantViolet,
    ),
    _AdminPanelOption(
      title: 'Bus Tracker',
      subtitle: 'Oversee routes and transport updates.',
      icon: Icons.directions_bus_rounded,
      color: _AdminPalette.busTrackerTeal,
    ),
    _AdminPanelOption(
      title: 'Role Control',
      subtitle: 'Assign and audit user permissions.',
      icon: Icons.admin_panel_settings_rounded,
      color: _AdminPalette.roleControlCyan,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadAdminContext();
  }

  Future<void> _loadAdminContext() async {
    final isLocalAdmin =
        widget.isLocalAdmin ?? await _authService.isLocalAdminSession();

    if (!isLocalAdmin) {
      final role = await _authService.getCurrentRole();
      if (role != UserRole.admin) {
        if (!mounted) {
          return;
        }

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SignInScreen()),
          (route) => false,
        );
        return;
      }
    }

    final profile = await _authService.getCurrentProfile();

    if (!mounted) {
      return;
    }

    setState(() {
      _profile = profile;
      _isLocalAdmin = isLocalAdmin;
      _isLoading = false;
    });
  }

  Future<void> _openProfile() async {
    if (_isLocalAdmin) {
      _showSnackBar('Local admin mode does not support profile updates yet.');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileManagementScreen()),
    );

    if (!mounted) {
      return;
    }

    await _loadAdminContext();
  }

  Future<void> _openAdminModule(_AdminPanelOption option) async {
    if (option.title == 'Profile') {
      await _openProfile();
      return;
    }

    if (option.title == 'Resource Screen') {
      if (_isLocalAdmin) {
        _showSnackBar(
          'Local admin mode has no backend session. Use a Supabase admin account to manage resources.',
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResourcesStandaloneScreen(
            currentRole: UserRole.admin,
            isLocalAdmin: _isLocalAdmin,
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AdminModuleScreen(option: option),
      ),
    );
  }

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
    });

    await _authService.signOut();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AdminPalette.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Admin Control Center',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isSigningOut ? null : _signOut,
            icon: _isSigningOut
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
            label: const Text('Sign Out'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _AdminPalette.authGradientStart,
                          _AdminPalette.authGradientEnd,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -100,
                  right: -60,
                  child: Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _AdminPalette.authBlue.withOpacity(0.12),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -120,
                  left: -60,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _AdminPalette.authTeal.withOpacity(0.1),
                    ),
                  ),
                ),
                SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 22),
                    children: [
                      _AdminHeroCard(
                        profile: _profile,
                        isLocalAdmin: _isLocalAdmin,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Complete Admin Panel Options',
                        style: TextStyle(
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.06,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _options.length,
                        itemBuilder: (context, index) {
                          final option = _options[index];
                          return _AdminOptionCard(
                            option: option,
                            onTap: () => _openAdminModule(option),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _AdminHeroCard extends StatelessWidget {
  const _AdminHeroCard({
    required this.profile,
    required this.isLocalAdmin,
  });

  final ProfileModel? profile;
  final bool isLocalAdmin;

  @override
  Widget build(BuildContext context) {
    final name = profile?.fullName ??
        (isLocalAdmin ? 'Fixed Credential Admin' : 'Administrator');
    final email = profile?.email ??
        (isLocalAdmin ? 'Local fixed-admin mode' : 'No profile available');

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
            boxShadow: [
              BoxShadow(
                color: _AdminPalette.authBlue.withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: _AdminPalette.authBlue.withOpacity(0.14),
                backgroundImage: profile?.avatarUrl != null
                    ? NetworkImage(profile!.avatarUrl!)
                    : null,
                child: profile?.avatarUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'A',
                        style: const TextStyle(
                          color: _AdminPalette.authBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Admin',
                      style: TextStyle(
                        color: _AdminPalette.authBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminOptionCard extends StatelessWidget {
  const _AdminOptionCard({
    required this.option,
    required this.onTap,
  });

  final _AdminPanelOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withOpacity(0.82),
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.95)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: option.color.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(option.icon, size: 19, color: option.color),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    option.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    option.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminModuleScreen extends StatelessWidget {
  const _AdminModuleScreen({required this.option});

  final _AdminPanelOption option;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AdminPalette.scaffold,
      appBar: AppBar(
        title: Text(option.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _AdminPalette.authGradientStart,
                    _AdminPalette.authGradientEnd,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -70,
            right: -50,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: option.color.withOpacity(0.14),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.82),
                        borderRadius: BorderRadius.circular(18),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.95)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: option.color.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(option.icon,
                                size: 32, color: option.color),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            option.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            option.subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'This admin module is ready for detailed feature integration.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
