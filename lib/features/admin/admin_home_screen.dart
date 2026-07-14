import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unisharesync_mobile_app/data/models/profile_model.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';
import 'package:unisharesync_mobile_app/features/auth/login_screen.dart';
import 'package:unisharesync_mobile_app/features/notice_board/admin_notice_board_screen.dart';
import 'package:unisharesync_mobile_app/features/admin/admin_projects_screen.dart';
import 'package:unisharesync_mobile_app/features/admin/admin_events_screen.dart';
import 'package:unisharesync_mobile_app/features/admin/admin_communities_screen.dart';
import 'package:unisharesync_mobile_app/features/admin/admin_class_scheduler_screen.dart';
import 'package:unisharesync_mobile_app/features/admin/admin_user_management_screen.dart';
import 'package:unisharesync_mobile_app/features/feedback/feedback_screen.dart';
import 'package:unisharesync_mobile_app/features/lost_found/lost_found_screen.dart';
import 'package:unisharesync_mobile_app/features/profile/profile_management_screen.dart';
import 'package:unisharesync_mobile_app/features/admin/admin_analytics_screen.dart';
import 'package:unisharesync_mobile_app/features/admin/admin_resources_screen.dart';
import 'package:unisharesync_mobile_app/features/admin/admin_campus_share_screen.dart';
import 'package:unisharesync_mobile_app/features/admin/admin_settings_screen.dart';
import 'package:unisharesync_mobile_app/features/ai_chat/ai_chat_screen.dart';
import 'package:unisharesync_mobile_app/features/bus_tracker/bus_tracker_screen.dart';
import 'package:unisharesync_mobile_app/features/notification_center/notification_center_screen.dart';
import 'package:unisharesync_mobile_app/services/auth_service.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({
    super.key,
    this.isLocalAdmin,
    this.initialProfile,
  });

  final bool? isLocalAdmin;
  final ProfileModel? initialProfile;

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
  static const Color analyticsRose = Color(0xFFEC4899);
  static const Color roleControlCyan = Color(0xFF06B6D4);
}

class _AdminPanelOption {
  const _AdminPanelOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String id;
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

  static const List<_AdminPanelOption> _overviewOptions = [
    _AdminPanelOption(
      id: 'analytics',
      title: 'Analytics',
      subtitle: 'Downloads, users & bus routes.',
      icon: Icons.insights_rounded,
      color: _AdminPalette.analyticsRose,
    ),
    _AdminPanelOption(
      id: 'role_control',
      title: 'Role Control',
      subtitle: 'Assign and audit permissions.',
      icon: Icons.admin_panel_settings_rounded,
      color: _AdminPalette.roleControlCyan,
    ),
    _AdminPanelOption(
      id: 'profile',
      title: 'Profile',
      subtitle: 'Manage admin profile details.',
      icon: Icons.person_outline_rounded,
      color: _AdminPalette.authBlue,
    ),
  ];

  static const List<_AdminPanelOption> _contentOptions = [
    _AdminPanelOption(
      id: 'resources',
      title: 'Resources',
      subtitle: 'Review and manage uploads.',
      icon: Icons.menu_book_rounded,
      color: _AdminPalette.resourcesBlue,
    ),
    _AdminPanelOption(
      id: 'notices',
      title: 'Notice Board',
      subtitle: 'Publish and moderate notices.',
      icon: Icons.campaign_rounded,
      color: _AdminPalette.noticesAmber,
    ),
    _AdminPanelOption(
      id: 'projects',
      title: 'Projects',
      subtitle: 'Monitor project spaces.',
      icon: Icons.account_tree_rounded,
      color: _AdminPalette.projectsPurple,
    ),
    _AdminPanelOption(
      id: 'events',
      title: 'Events & Seminars',
      subtitle: 'Manage campus events & seminars.',
      icon: Icons.celebration_rounded,
      color: _AdminPalette.eventsEmerald,
    ),
    _AdminPanelOption(
      id: 'communities',
      title: 'Communities',
      subtitle: 'Manage campus communities.',
      icon: Icons.groups_rounded,
      color: _AdminPalette.projectsPurple,
    ),
    _AdminPanelOption(
      id: 'scheduler',
      title: 'Class Scheduler',
      subtitle: 'Configure academic schedules.',
      icon: Icons.calendar_view_week_rounded,
      color: _AdminPalette.authTeal,
    ),
    _AdminPanelOption(
      id: 'lost_found',
      title: 'Lost & Found',
      subtitle: 'Handle item reports.',
      icon: Icons.search_rounded,
      color: _AdminPalette.lostFoundSoftRed,
    ),
    _AdminPanelOption(
      id: 'campus_share',
      title: 'Campus Share',
      subtitle: 'Moderate listings and disputes.',
      icon: Icons.swap_horizontal_circle_rounded,
      color: _AdminPalette.projectsPurple,
    ),
    _AdminPanelOption(
      id: 'feedback',
      title: 'Feedback',
      subtitle: 'Review user suggestions.',
      icon: Icons.rate_review_outlined,
      color: _AdminPalette.feedbackIndigo,
    ),
  ];

  static const List<_AdminPanelOption> _systemOptions = [
    _AdminPanelOption(
      id: 'notifications',
      title: 'Notifications',
      subtitle: 'Campus alerts and broadcasts.',
      icon: Icons.notifications_active_outlined,
      color: _AdminPalette.notificationSky,
    ),
    _AdminPanelOption(
      id: 'ai_assistant',
      title: 'AI Assistant',
      subtitle: 'Campus assistant for admins.',
      icon: Icons.smart_toy_outlined,
      color: _AdminPalette.aiAssistantViolet,
    ),
    _AdminPanelOption(
      id: 'bus_tracker',
      title: 'Bus Tracker',
      subtitle: 'Live routes and transport.',
      icon: Icons.directions_bus_rounded,
      color: _AdminPalette.busTrackerTeal,
    ),
    _AdminPanelOption(
      id: 'settings',
      title: 'Settings',
      subtitle: 'UniShareSync admin preferences.',
      icon: Icons.settings_outlined,
      color: _AdminPalette.settingsSlate,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadAdminContext();
  }

  Future<void> _loadAdminContext() async {
    // If splash pre-loaded the profile, skip network calls.
    if (widget.initialProfile != null) {
      final isLocalAdmin = widget.isLocalAdmin ?? false;
      if (!mounted) return;
      setState(() {
        _profile = widget.initialProfile;
        _isLocalAdmin = isLocalAdmin;
        _isLoading = false;
      });
      return;
    }

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

  Future<void> _handleSystemBack() async {
    final shouldExit = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Exit app?'),
            content: const Text(
              'You are on the admin dashboard. Do you want to close the app?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Stay'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Exit'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldExit) {
      SystemNavigator.pop();
    }
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
    switch (option.id) {
      case 'profile':
        await _openProfile();
        break;
      case 'analytics':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminAnalyticsScreen()),
        );
        break;
      case 'role_control':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminUserManagementScreen()),
        );
        break;
      case 'resources':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminResourcesScreen()),
        );
        break;
      case 'notices':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminNoticeBoardScreen()),
        );
        break;
      case 'projects':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminProjectsScreen()),
        );
        break;
      case 'events':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminEventsScreen()),
        );
        break;
      case 'communities':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminCommunitiesScreen()),
        );
        break;
      case 'scheduler':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminClassSchedulerScreen()),
        );
        break;
      case 'lost_found':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LostFoundScreen()),
        );
        break;
      case 'campus_share':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminCampusShareScreen()),
        );
        break;
      case 'feedback':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FeedbackScreen()),
        );
        break;
      case 'notifications':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
        );
        break;
      case 'ai_assistant':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AiChatScreen()),
        );
        break;
      case 'bus_tracker':
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BusTrackerScreen(
              currentUserName: _profile?.fullName ?? 'UniShareSync Admin',
            ),
          ),
        );
        break;
      case 'settings':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminSettingsScreen()),
        );
        break;
    }
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
          'UniShareSync Admin',
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
                      const SizedBox(height: 16),
                      const _AdminSectionLabel(title: 'Overview'),
                      const SizedBox(height: 8),
                      _AdminOptionsGrid(
                        options: _overviewOptions,
                        onTap: _openAdminModule,
                      ),
                      const SizedBox(height: 16),
                      const _AdminSectionLabel(title: 'Content & Campus'),
                      const SizedBox(height: 8),
                      _AdminOptionsGrid(
                        options: _contentOptions,
                        onTap: _openAdminModule,
                      ),
                      const SizedBox(height: 16),
                      const _AdminSectionLabel(title: 'System'),
                      const SizedBox(height: 8),
                      _AdminOptionsGrid(
                        options: _systemOptions,
                        onTap: _openAdminModule,
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
                      'UniShareSync Admin',
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

class _AdminSectionLabel extends StatelessWidget {
  const _AdminSectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF334155),
        fontWeight: FontWeight.w800,
        fontSize: 14,
      ),
    );
  }
}

class _AdminOptionsGrid extends StatelessWidget {
  const _AdminOptionsGrid({
    required this.options,
    required this.onTap,
  });

  final List<_AdminPanelOption> options;
  final Future<void> Function(_AdminPanelOption option) onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.08,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final option = options[index];
        return _AdminOptionCard(
          option: option,
          onTap: () => onTap(option),
        );
      },
    );
  }
}

class _AdminOptionCard extends StatefulWidget {
  const _AdminOptionCard({
    required this.option,
    required this.onTap,
  });

  final _AdminPanelOption option;
  final VoidCallback onTap;

  @override
  State<_AdminOptionCard> createState() => _AdminOptionCardState();
}

class _AdminOptionCardState extends State<_AdminOptionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Material(
              color: Colors.white.withOpacity(0.82),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.95)),
                  boxShadow: _pressed
                      ? [
                          BoxShadow(
                            color: widget.option.color.withOpacity(0.18),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: widget.option.color
                            .withOpacity(_pressed ? 0.22 : 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        widget.option.icon,
                        size: 19,
                        color: widget.option.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.option.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.option.subtitle,
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
      ),
    );
  }
}

