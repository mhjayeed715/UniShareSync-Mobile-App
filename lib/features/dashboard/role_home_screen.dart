import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:unisharesync_mobile_app/data/models/profile_model.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';
import 'package:unisharesync_mobile_app/features/auth/login_screen.dart';
import 'package:unisharesync_mobile_app/features/profile/profile_management_screen.dart';
import 'package:unisharesync_mobile_app/services/auth_service.dart';

class RoleHomeScreen extends StatefulWidget {
  const RoleHomeScreen({
    super.key,
    this.initialRole,
    this.isLocalAdmin,
  });

  final UserRole? initialRole;
  final bool? isLocalAdmin;

  @override
  State<RoleHomeScreen> createState() => _RoleHomeScreenState();
}

class _RoleHomeScreenState extends State<RoleHomeScreen> {
  final AuthService _authService = AuthService();

  bool _isLoading = true;
  bool _isSigningOut = false;
  bool _isLocalAdmin = false;
  UserRole _role = UserRole.student;
  ProfileModel? _profile;

  @override
  void initState() {
    super.initState();
    _resolveSession();
  }

  Future<void> _resolveSession() async {
    try {
      final role = widget.initialRole ?? await _authService.getCurrentRole();
      final isLocalAdmin = widget.isLocalAdmin ?? await _authService.isLocalAdminSession();

      if (role == null && !isLocalAdmin) {
        if (!mounted) {
          return;
        }

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SignInScreen()),
          (route) => false,
        );
        return;
      }

      final profile = await _authService.getCurrentProfile();

      if (!mounted) {
        return;
      }

      setState(() {
        _role = role ?? UserRole.admin;
        _isLocalAdmin = isLocalAdmin;
        _profile = profile;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    final title = _isLocalAdmin ? 'Admin Control Center' : '${_role.displayName} Dashboard';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton.icon(
            onPressed: _isSigningOut ? null : _signOut,
            icon: _isSigningOut
                ? const SizedBox(
                    width: 16,
                    height: 16,
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
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFF8FBFF),
                          _role == UserRole.admin
                              ? const Color(0xFFFFF4ED)
                              : const Color(0xFFEAF6FF),
                        ],
                      ),
                    ),
                  ),
                ),
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    _HeroProfileCard(
                      role: _role,
                      profile: _profile,
                      isLocalAdmin: _isLocalAdmin,
                    ),
                    const SizedBox(height: 16),
                    _QuickActions(
                      role: _role,
                      isLocalAdmin: _isLocalAdmin,
                      onManageProfile: _isLocalAdmin
                          ? null
                          : () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ProfileManagementScreen(),
                                ),
                              );

                              if (mounted) {
                                _resolveSession();
                              }
                            },
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Role-Based Modules',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                    ),
                    const SizedBox(height: 10),
                    ..._roleModules(_role).map(
                      (item) => _ModuleTile(
                        icon: item.icon,
                        title: item.title,
                        subtitle: item.subtitle,
                      ),
                    ),
                    if (_isLocalAdmin) ...[
                      const SizedBox(height: 16),
                      _LocalAdminNoticeCard(),
                    ],
                  ],
                ),
              ],
            ),
    );
  }
}

class _HeroProfileCard extends StatelessWidget {
  const _HeroProfileCard({
    required this.role,
    required this.profile,
    required this.isLocalAdmin,
  });

  final UserRole role;
  final ProfileModel? profile;
  final bool isLocalAdmin;

  @override
  Widget build(BuildContext context) {
    final roleColor = switch (role) {
      UserRole.student => const Color(0xFF4F9EFF),
      UserRole.faculty => const Color(0xFF2DD4BF),
      UserRole.admin => const Color(0xFFFF884B),
    };

    final displayName = profile?.fullName ??
        (isLocalAdmin ? 'Fixed Credential Admin' : 'Campus User');

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.72),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.9)),
            boxShadow: [
              BoxShadow(
                color: roleColor.withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: roleColor.withOpacity(0.15),
                backgroundImage: profile?.avatarUrl != null
                    ? NetworkImage(profile!.avatarUrl!)
                    : null,
                child: profile?.avatarUrl == null
                    ? Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                        style: TextStyle(
                          color: roleColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF10223D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      role.displayName,
                      style: TextStyle(
                        color: roleColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile?.email ?? (isLocalAdmin ? 'Local fixed-admin mode' : 'No profile found'),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
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

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.role,
    required this.isLocalAdmin,
    required this.onManageProfile,
  });

  final UserRole role;
  final bool isLocalAdmin;
  final VoidCallback? onManageProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.person_rounded,
            label: 'Manage Profile',
            onTap: onManageProfile,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            icon: Icons.security_rounded,
            label: role == UserRole.admin ? 'Admin Rules' : 'Access Rules',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isLocalAdmin
                        ? 'Local admin mode active: profile write operations are disabled.'
                        : 'RLS policies and role checks are active in Supabase.',
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.78),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.9)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: const Color(0xFF2B5B94)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF10223D),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModuleItem {
  const _ModuleItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

List<_ModuleItem> _roleModules(UserRole role) {
  switch (role) {
    case UserRole.student:
      return const [
        _ModuleItem(
          icon: Icons.library_books_rounded,
          title: 'Academic Resources',
          subtitle: 'Browse notes, past papers, and shared class materials.',
        ),
        _ModuleItem(
          icon: Icons.event_note_rounded,
          title: 'Semester Planner',
          subtitle: 'Track classes, assignments, and exam deadlines.',
        ),
      ];
    case UserRole.faculty:
      return const [
        _ModuleItem(
          icon: Icons.assignment_rounded,
          title: 'Course Publishing',
          subtitle: 'Upload lectures, assignments, and faculty resources.',
        ),
        _ModuleItem(
          icon: Icons.rate_review_rounded,
          title: 'Student Feedback',
          subtitle: 'Review submissions and monitor classroom updates.',
        ),
      ];
    case UserRole.admin:
      return const [
        _ModuleItem(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Platform Governance',
          subtitle: 'Control user roles, moderation, and high-level settings.',
        ),
        _ModuleItem(
          icon: Icons.analytics_rounded,
          title: 'Analytics and Reports',
          subtitle: 'Track engagement, resources, and campus activity trends.',
        ),
      ];
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF4F9EFF).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF2B5B94), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalAdminNoticeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD6B7)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFFB85D16)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'You are signed in with fixed admin credentials in local mode. Supabase profile actions are disabled until this admin account exists in Auth + profiles table.',
              style: TextStyle(
                color: Color(0xFF8D4B1A),
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
