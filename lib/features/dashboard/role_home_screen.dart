import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:unisharesync_mobile_app/data/models/dashboard_feed_item.dart';
import 'package:unisharesync_mobile_app/data/models/profile_model.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';
import 'package:unisharesync_mobile_app/features/admin/admin_home_screen.dart';
import 'package:unisharesync_mobile_app/features/auth/login_screen.dart';
import 'package:unisharesync_mobile_app/features/profile/profile_management_screen.dart';
import 'package:unisharesync_mobile_app/features/resources/resources_tab_view.dart';
import 'package:unisharesync_mobile_app/services/auth_service.dart';
import 'package:unisharesync_mobile_app/services/dashboard_feed_service.dart';

enum _DashboardTab { home, resources, routine, profile }

enum _MenuDestination {
  profile,
  settings,
  resources,
  noticeBoard,
  projects,
  eventsAndClubs,
  lostAndFound,
  feedback,
  notificationCenter,
  classScheduler,
  aiCampusAssistant,
  busTracker,
}

class _DashboardPalette {
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
}

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
  final DashboardFeedService _dashboardFeedService = DashboardFeedService();

  bool _isLoading = true;
  bool _isSigningOut = false;
  bool _isLocalAdmin = false;
  UserRole _role = UserRole.student;
  ProfileModel? _profile;
  _DashboardTab _activeTab = _DashboardTab.home;
  int _resourcesRefreshTick = 0;

  DateTime _now = DateTime.now();
  Timer? _clockTicker;

  late final Stream<List<DashboardFeedItem>> _resourceStream;
  late final Stream<List<DashboardFeedItem>> _noticeStream;
  late final Stream<List<DashboardFeedItem>> _routineStream;

  @override
  void initState() {
    super.initState();

    _resourceStream =
        _dashboardFeedService.watchResources(limit: 30).asBroadcastStream();
    _noticeStream =
        _dashboardFeedService.watchNotices(limit: 20).asBroadcastStream();
    _routineStream =
        _dashboardFeedService.watchRoutines(limit: 25).asBroadcastStream();

    _startClockTicker();
    _resolveSession();
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    super.dispose();
  }

  void _startClockTicker() {
    _clockTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _now = DateTime.now();
      });
    });
  }

  Future<void> _resolveSession() async {
    try {
      final role = widget.initialRole ?? await _authService.getCurrentRole();
      final isLocalAdmin =
          widget.isLocalAdmin ?? await _authService.isLocalAdminSession();

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

      if ((role == UserRole.admin || isLocalAdmin) && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AdminHomeScreen(isLocalAdmin: isLocalAdmin),
          ),
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

  Future<void> _openProfileEditor() async {
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

    await _resolveSession();
  }

  Future<void> _openFeatureModule({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ModulePlaceholderScreen(
          title: title,
          subtitle: subtitle,
          icon: icon,
          accentColor: accentColor,
        ),
      ),
    );
  }

  Future<void> _openQuickActionSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.88),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.95)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Quick Action',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _SheetActionTile(
                          icon: Icons.smart_toy_outlined,
                          title: 'Open AI Chatbot',
                          subtitle:
                              'Ask about classes, notices, and campus info.',
                          onTap: () {
                            Navigator.of(context).pop();
                            _showSnackBar(
                              'AI chatbot action triggered. Connect this to your chatbot screen.',
                            );
                          },
                        ),
                        _SheetActionTile(
                          icon: Icons.upload_file_outlined,
                          title: 'Quick Upload Resource',
                          subtitle: 'Upload notes or files in one step.',
                          onTap: () async {
                            Navigator.of(context).pop();

                            if (!mounted) {
                              return;
                            }

                            if (_isLocalAdmin) {
                              _showSnackBar(
                                'Local admin mode has no backend session. Use a Supabase account to upload resources.',
                              );
                              return;
                            }

                            setState(() {
                              _activeTab = _DashboardTab.resources;
                            });

                            final uploaded = await showResourceUploadSheet(
                              context,
                            );

                            if (!mounted || uploaded == null) {
                              return;
                            }

                            setState(() {
                              _resourcesRefreshTick++;
                            });

                            _showSnackBar(
                              'Resource upload submitted successfully.',
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openHamburgerMenu() async {
    final destination = await Navigator.of(context).push<_MenuDestination>(
      MaterialPageRoute(
        builder: (_) => _HamburgerMenuScreen(
          profile: _profile,
          role: _role,
          isLocalAdmin: _isLocalAdmin,
        ),
      ),
    );

    if (!mounted || destination == null) {
      return;
    }

    switch (destination) {
      case _MenuDestination.profile:
        setState(() {
          _activeTab = _DashboardTab.profile;
        });
        break;
      case _MenuDestination.settings:
        await _openFeatureModule(
          title: 'Settings',
          subtitle: 'Preferences, privacy, and app controls.',
          icon: Icons.settings_outlined,
          accentColor: _DashboardPalette.settingsSlate,
        );
        break;
      case _MenuDestination.resources:
        setState(() {
          _activeTab = _DashboardTab.resources;
        });
        break;
      case _MenuDestination.noticeBoard:
        await _openFeatureModule(
          title: 'Notice Board',
          subtitle: 'Latest campus-wide notices and announcements.',
          icon: Icons.campaign_rounded,
          accentColor: _DashboardPalette.noticesAmber,
        );
        break;
      case _MenuDestination.projects:
        await _openFeatureModule(
          title: 'Projects',
          subtitle: 'Collaborative projects and team spaces.',
          icon: Icons.account_tree_rounded,
          accentColor: _DashboardPalette.projectsPurple,
        );
        break;
      case _MenuDestination.eventsAndClubs:
        await _openFeatureModule(
          title: 'Events and Clubs',
          subtitle: 'Discover events, clubs, and participation updates.',
          icon: Icons.celebration_rounded,
          accentColor: _DashboardPalette.eventsEmerald,
        );
        break;
      case _MenuDestination.lostAndFound:
        await _openFeatureModule(
          title: 'Lost and Found',
          subtitle: 'Report and discover lost or found items.',
          icon: Icons.search_rounded,
          accentColor: _DashboardPalette.lostFoundSoftRed,
        );
        break;
      case _MenuDestination.feedback:
        await _openFeatureModule(
          title: 'Feedback',
          subtitle: 'Share feedback and report issues for improvements.',
          icon: Icons.rate_review_outlined,
          accentColor: _DashboardPalette.feedbackIndigo,
        );
        break;
      case _MenuDestination.notificationCenter:
        await _openFeatureModule(
          title: 'Notification Center',
          subtitle: 'All important alerts and updates in one place.',
          icon: Icons.notifications_active_outlined,
          accentColor: _DashboardPalette.notificationSky,
        );
        break;
      case _MenuDestination.classScheduler:
        setState(() {
          _activeTab = _DashboardTab.routine;
        });
        break;
      case _MenuDestination.aiCampusAssistant:
        await _openFeatureModule(
          title: 'AI Campus Assistant',
          subtitle: 'Ask campus questions and get instant guided help.',
          icon: Icons.smart_toy_outlined,
          accentColor: _DashboardPalette.aiAssistantViolet,
        );
        break;
      case _MenuDestination.busTracker:
        await _openFeatureModule(
          title: 'Bus Tracker',
          subtitle: 'Track campus bus routes and live timings.',
          icon: Icons.directions_bus_rounded,
          accentColor: _DashboardPalette.busTrackerTeal,
        );
        break;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _timeGreeting() {
    final hour = _now.hour;

    if (hour >= 5 && hour < 12) {
      return 'Good Morning';
    }
    if (hour >= 12 && hour < 14) {
      return 'Good Noon';
    }
    if (hour >= 14 && hour < 18) {
      return 'Good Afternoon';
    }
    if (hour >= 18 && hour < 22) {
      return 'Good Evening';
    }
    return 'Good Night';
  }

  String _firstName() {
    final fullName = _profile?.fullName.trim();
    if (fullName == null || fullName.isEmpty) {
      return 'Campus User';
    }

    return fullName.split(RegExp(r'\s+')).first;
  }

  String _subtitleLine() {
    if (_isLocalAdmin) {
      return 'Local fixed-admin mode';
    }

    final parts = <String>[];

    if ((_profile?.department ?? '').trim().isNotEmpty) {
      parts.add(_profile!.department!.trim());
    }

    if ((_profile?.semester ?? '').trim().isNotEmpty) {
      parts.add(_profile!.semester!.trim());
    } else if ((_profile?.designation ?? '').trim().isNotEmpty) {
      parts.add(_profile!.designation!.trim());
    }

    if (parts.isEmpty) {
      parts.add(_role.displayName);
    }

    return parts.join(' | ');
  }

  String _relativeTime(DateTime? value) {
    if (value == null) {
      return 'No timestamp';
    }

    final delta = DateTime.now().difference(value);

    if (delta.inMinutes < 1) {
      return 'Just now';
    }
    if (delta.inHours < 1) {
      return '${delta.inMinutes} min ago';
    }
    if (delta.inDays < 1) {
      return '${delta.inHours} hr ago';
    }
    if (delta.inDays < 7) {
      return '${delta.inDays} day ago';
    }

    return '${value.day}/${value.month}/${value.year}';
  }

  Widget _buildCurrentTab() {
    switch (_activeTab) {
      case _DashboardTab.home:
        return _buildHomeTab();
      case _DashboardTab.resources:
        return _buildResourcesTab();
      case _DashboardTab.routine:
        return _buildRoutineTab();
      case _DashboardTab.profile:
        return _buildProfileTab();
    }
  }

  Widget _buildHomeTab() {
    return ListView(
      key: const PageStorageKey<String>('home-tab'),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 118),
      children: [
        _DashboardHeader(
          greeting: '${_timeGreeting()}, ${_firstName()}',
          subtitle: _subtitleLine(),
          avatarUrl: _profile?.avatarUrl,
          onNotificationTap: () {
            _showSnackBar('Notifications integration is ready for live data.');
          },
        ),
        const SizedBox(height: 14),
        _buildActivityOverviewCard(),
        const SizedBox(height: 16),
        _buildQuickAccessGrid(),
        const SizedBox(height: 18),
        const _SectionHeader(title: 'Recent Notices'),
        const SizedBox(height: 10),
        _buildNoticesStrip(),
        const SizedBox(height: 18),
        const _SectionHeader(title: 'Latest Resources'),
        const SizedBox(height: 10),
        _buildResourcePreviewList(),
      ],
    );
  }

  Widget _buildResourcesTab() {
    return ResourcesTabView(
      key: ValueKey<String>('resources-tab-$_resourcesRefreshTick'),
      currentRole: _role,
      isLocalAdmin: _isLocalAdmin,
      refreshTick: _resourcesRefreshTick,
    );
  }

  Widget _buildRoutineTab() {
    return Column(
      key: const PageStorageKey<String>('routine-tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const _TabHeader(
          title: 'Routine Viewer',
          subtitle: 'Live routine items from routines table',
        ),
        const SizedBox(height: 10),
        Expanded(
          child: StreamBuilder<List<DashboardFeedItem>>(
            stream: _routineStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _EmptyState(
                  title: 'Unable to load routine',
                  subtitle: '${snapshot.error}',
                );
              }

              final items = snapshot.data ?? const <DashboardFeedItem>[];
              if (items.isEmpty) {
                return const _EmptyState(
                  title: 'No routine entries yet',
                  subtitle:
                      'Add routine rows in your database and they will appear in real time.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 118),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _FeedCard(
                    icon: Icons.calendar_today_rounded,
                    iconColor: const Color(0xFF0F766E),
                    title: item.title,
                    subtitle: item.subtitle,
                    trailing: _relativeTime(item.createdAt),
                    tag: item.category,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTab() {
    return ListView(
      key: const PageStorageKey<String>('profile-tab'),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 118),
      children: [
        _ProfileHeaderCard(
          profile: _profile,
          role: _role,
          isLocalAdmin: _isLocalAdmin,
        ),
        const SizedBox(height: 14),
        _GlassButton(
          icon: Icons.person_rounded,
          label: 'Manage Profile',
          onTap: _openProfileEditor,
        ),
        const SizedBox(height: 10),
        _GlassButton(
          icon: Icons.logout_rounded,
          label: _isSigningOut ? 'Signing Out...' : 'Sign Out',
          onTap: _isSigningOut ? null : _signOut,
        ),
        if (_isLocalAdmin) ...[
          const SizedBox(height: 14),
          const _LocalAdminNoticeCard(),
        ],
      ],
    );
  }

  Widget _buildActivityOverviewCard() {
    return StreamBuilder<List<DashboardFeedItem>>(
      stream: _resourceStream,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <DashboardFeedItem>[];
        final weekStart = DateTime.now().subtract(const Duration(days: 7));

        final weeklyItems = items
            .where(
              (item) =>
                  item.createdAt != null && item.createdAt!.isAfter(weekStart),
            )
            .length;

        return _GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Activity Overview',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$weeklyItems this week',
                      style: const TextStyle(
                        color: _DashboardPalette.authBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Resources available now: ${items.length}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'This card updates from live database rows. No mock values are used.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickAccessGrid() {
    return _GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Access',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.95,
            children: [
              _QuickAccessTile(
                icon: Icons.menu_book_rounded,
                label: 'Resources',
                color: _DashboardPalette.resourcesBlue,
                onTap: () {
                  setState(() {
                    _activeTab = _DashboardTab.resources;
                  });
                },
              ),
              _QuickAccessTile(
                icon: Icons.campaign_rounded,
                label: 'Notices',
                color: _DashboardPalette.noticesAmber,
                onTap: () {
                  setState(() {
                    _activeTab = _DashboardTab.home;
                  });
                  _showSnackBar('Notices are shown in the Home section.');
                },
              ),
              _QuickAccessTile(
                icon: Icons.account_tree_rounded,
                label: 'Projects',
                color: _DashboardPalette.projectsPurple,
                onTap: () {
                  _openFeatureModule(
                    title: 'Projects',
                    subtitle: 'Collaborative projects and team spaces.',
                    icon: Icons.account_tree_rounded,
                    accentColor: _DashboardPalette.projectsPurple,
                  );
                },
              ),
              _QuickAccessTile(
                icon: Icons.celebration_rounded,
                label: 'Events',
                color: _DashboardPalette.eventsEmerald,
                onTap: () {
                  _openFeatureModule(
                    title: 'Events',
                    subtitle: 'Campus events, registration, and schedules.',
                    icon: Icons.celebration_rounded,
                    accentColor: _DashboardPalette.eventsEmerald,
                  );
                },
              ),
              _QuickAccessTile(
                icon: Icons.search_rounded,
                label: 'Lost & Found',
                color: _DashboardPalette.lostFoundSoftRed,
                onTap: () {
                  _openFeatureModule(
                    title: 'Lost & Found',
                    subtitle: 'Report and discover lost or found items.',
                    icon: Icons.search_rounded,
                    accentColor: _DashboardPalette.lostFoundSoftRed,
                  );
                },
              ),
              _QuickAccessTile(
                icon: Icons.directions_bus_rounded,
                label: 'Bus Tracker',
                color: _DashboardPalette.busTrackerTeal,
                onTap: () {
                  _openFeatureModule(
                    title: 'Bus Tracker',
                    subtitle: 'Track campus bus routes and live timings.',
                    icon: Icons.directions_bus_rounded,
                    accentColor: _DashboardPalette.busTrackerTeal,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoticesStrip() {
    return SizedBox(
      height: 150,
      child: StreamBuilder<List<DashboardFeedItem>>(
        stream: _noticeStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _GlassCard(
              child: _CompactMessage(
                title: 'Unable to load notices',
                subtitle: '${snapshot.error}',
              ),
            );
          }

          final items = snapshot.data ?? const <DashboardFeedItem>[];
          if (items.isEmpty) {
            return const _GlassCard(
              child: _CompactMessage(
                title: 'No notices yet',
                subtitle:
                    'Notices will appear here in real time when inserted.',
              ),
            );
          }

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length > 10 ? 10 : items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final notice = items[index];
              return _NoticeCard(
                title: notice.title,
                subtitle: notice.subtitle,
                category: notice.category,
                relativeTime: _relativeTime(notice.createdAt),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildResourcePreviewList() {
    return StreamBuilder<List<DashboardFeedItem>>(
      stream: _resourceStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _GlassCard(
            child: _CompactMessage(
              title: 'Unable to load resources',
              subtitle: '${snapshot.error}',
            ),
          );
        }

        final items = snapshot.data ?? const <DashboardFeedItem>[];
        if (items.isEmpty) {
          return const _GlassCard(
            child: _CompactMessage(
              title: 'No resources available',
              subtitle:
                  'When resources are added in database, they show up here.',
            ),
          );
        }

        final preview = items.take(4).toList(growable: false);

        return Column(
          children: preview
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FeedCard(
                    icon: Icons.menu_book_rounded,
                    iconColor: _DashboardPalette.resourcesBlue,
                    title: item.title,
                    subtitle: item.subtitle,
                    trailing: _relativeTime(item.createdAt),
                    tag: item.category,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: _DashboardPalette.scaffold,
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
                          _DashboardPalette.authGradientStart,
                          _DashboardPalette.authGradientEnd,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -120,
                  right: -80,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _DashboardPalette.authBlue.withOpacity(0.12),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -140,
                  left: -80,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _DashboardPalette.authTeal.withOpacity(0.1),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _buildCurrentTab(),
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _isLoading
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: _FloatingGlassBottomNav(
                activeTab: _activeTab,
                onTabSelected: (_DashboardTab tab) {
                  setState(() {
                    _activeTab = tab;
                  });
                },
                onCenterPressed: _openQuickActionSheet,
                onMenuPressed: _openHamburgerMenu,
              ),
            ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.greeting,
    required this.subtitle,
    required this.avatarUrl,
    required this.onNotificationTap,
  });

  final String greeting;
  final String subtitle;
  final String? avatarUrl;
  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFFDCEBFF),
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
          child: avatarUrl == null
              ? const Icon(Icons.person, color: Color(0xFF2B5B94), size: 22)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onNotificationTap,
            child: Ink(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.95)),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Center(
                    child: Icon(
                      Icons.notifications_none_rounded,
                      color: Color(0xFF475569),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _DashboardPalette.authBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TabHeader extends StatelessWidget {
  const _TabHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: Color(0xFF334155),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
            boxShadow: [
              BoxShadow(
                color: _DashboardPalette.authBlue.withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.w700,
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

class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.trailing,
    this.subtitle,
    this.tag,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String trailing;
  final String? subtitle;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if ((subtitle ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                ],
                if ((tag ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tag!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF1D4ED8),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            trailing,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.title,
    required this.relativeTime,
    this.subtitle,
    this.category,
  });

  final String title;
  final String relativeTime;
  final String? subtitle;
  final String? category;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 268,
      child: _GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((category ?? '').trim().isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _DashboardPalette.noticesAmber.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  category!,
                  style: const TextStyle(
                    color: Color(0xFFB45309),
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            if ((subtitle ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
            const Spacer(),
            Text(
              relativeTime,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.profile,
    required this.role,
    required this.isLocalAdmin,
  });

  final ProfileModel? profile;
  final UserRole role;
  final bool isLocalAdmin;

  @override
  Widget build(BuildContext context) {
    final roleColor = switch (role) {
      UserRole.student => const Color(0xFF2563EB),
      UserRole.faculty => const Color(0xFF0F766E),
      UserRole.admin => const Color(0xFFEA580C),
    };

    final displayName = profile?.fullName ??
        (isLocalAdmin ? 'Fixed Credential Admin' : 'Campus User');

    final line2 = profile?.email ??
        (isLocalAdmin ? 'Local fixed-admin mode' : 'No profile available');

    return _GlassCard(
      padding: const EdgeInsets.all(16),
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
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
                const SizedBox(height: 2),
                Text(
                  line2,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _GlassButton extends StatelessWidget {
  const _GlassButton({
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
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
          ),
          child: Row(
            children: [
              Icon(icon, color: _DashboardPalette.authBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactMessage extends StatelessWidget {
  const _CompactMessage({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
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
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey.shade700),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.inbox_outlined,
                size: 34,
                color: Color(0xFF64748B),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuOption {
  const _MenuOption({
    required this.destination,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final _MenuDestination destination;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _HamburgerMenuScreen extends StatelessWidget {
  const _HamburgerMenuScreen({
    required this.profile,
    required this.role,
    required this.isLocalAdmin,
  });

  final ProfileModel? profile;
  final UserRole role;
  final bool isLocalAdmin;

  @override
  Widget build(BuildContext context) {
    final displayName = profile?.fullName ??
        (isLocalAdmin ? 'Fixed Credential Admin' : 'Campus User');
    final roleLabel = isLocalAdmin ? 'Admin' : role.displayName;

    const options = <_MenuOption>[
      _MenuOption(
        destination: _MenuDestination.profile,
        title: 'Profile',
        subtitle: 'Account information and profile settings.',
        icon: Icons.person_outline_rounded,
        color: _DashboardPalette.authBlue,
      ),
      _MenuOption(
        destination: _MenuDestination.settings,
        title: 'Settings',
        subtitle: 'App controls, privacy, and preferences.',
        icon: Icons.settings_outlined,
        color: _DashboardPalette.settingsSlate,
      ),
      _MenuOption(
        destination: _MenuDestination.resources,
        title: 'Resource Screen',
        subtitle: 'Study materials and shared academic resources.',
        icon: Icons.menu_book_rounded,
        color: _DashboardPalette.resourcesBlue,
      ),
      _MenuOption(
        destination: _MenuDestination.noticeBoard,
        title: 'Notice Board Screen',
        subtitle: 'Latest official campus notices and announcements.',
        icon: Icons.campaign_rounded,
        color: _DashboardPalette.noticesAmber,
      ),
      _MenuOption(
        destination: _MenuDestination.projects,
        title: 'Projects Screen',
        subtitle: 'Team projects and collaboration spaces.',
        icon: Icons.account_tree_rounded,
        color: _DashboardPalette.projectsPurple,
      ),
      _MenuOption(
        destination: _MenuDestination.eventsAndClubs,
        title: 'Events and Clubs Screen',
        subtitle: 'Events, clubs, and participation updates.',
        icon: Icons.celebration_rounded,
        color: _DashboardPalette.eventsEmerald,
      ),
      _MenuOption(
        destination: _MenuDestination.lostAndFound,
        title: 'Lost and Found Screen',
        subtitle: 'Report and recover lost campus items.',
        icon: Icons.search_rounded,
        color: _DashboardPalette.lostFoundSoftRed,
      ),
      _MenuOption(
        destination: _MenuDestination.feedback,
        title: 'Feedback Screen',
        subtitle: 'Submit suggestions and issue reports.',
        icon: Icons.rate_review_outlined,
        color: _DashboardPalette.feedbackIndigo,
      ),
      _MenuOption(
        destination: _MenuDestination.notificationCenter,
        title: 'Notification Center',
        subtitle: 'All alerts and campus updates in one place.',
        icon: Icons.notifications_active_outlined,
        color: _DashboardPalette.notificationSky,
      ),
      _MenuOption(
        destination: _MenuDestination.classScheduler,
        title: 'Class Scheduler',
        subtitle: 'Daily class routine and academic schedule.',
        icon: Icons.calendar_view_week_rounded,
        color: _DashboardPalette.authTeal,
      ),
      _MenuOption(
        destination: _MenuDestination.aiCampusAssistant,
        title: 'AI Campus Assistant',
        subtitle: 'Get instant smart help for campus tasks.',
        icon: Icons.smart_toy_outlined,
        color: _DashboardPalette.aiAssistantViolet,
      ),
      _MenuOption(
        destination: _MenuDestination.busTracker,
        title: 'Bus Tracker',
        subtitle: 'Track routes and estimated arrival times.',
        icon: Icons.directions_bus_rounded,
        color: _DashboardPalette.busTrackerTeal,
      ),
    ];

    return Scaffold(
      backgroundColor: _DashboardPalette.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Menu',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
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
                    _DashboardPalette.authGradientStart,
                    _DashboardPalette.authGradientEnd,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -90,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _DashboardPalette.authBlue.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -70,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _DashboardPalette.authTeal.withOpacity(0.08),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 26),
              children: [
                _GlassCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            _DashboardPalette.authBlue.withOpacity(0.14),
                        backgroundImage: profile?.avatarUrl != null
                            ? NetworkImage(profile!.avatarUrl!)
                            : null,
                        child: profile?.avatarUrl == null
                            ? Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: _DashboardPalette.authBlue,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              roleLabel,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Campus Navigation',
                  style: TextStyle(
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 8),
                ...options.map(
                  (option) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MenuNavigationTile(
                      option: option,
                      onTap: () {
                        Navigator.of(context).pop(option.destination);
                      },
                    ),
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

class _MenuNavigationTile extends StatelessWidget {
  const _MenuNavigationTile({
    required this.option,
    required this.onTap,
  });

  final _MenuOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: option.color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(option.icon, color: option.color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.title,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        option.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModulePlaceholderScreen extends StatelessWidget {
  const _ModulePlaceholderScreen({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DashboardPalette.scaffold,
      appBar: AppBar(
        title: Text(title),
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
                    _DashboardPalette.authGradientStart,
                    _DashboardPalette.authGradientEnd,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withOpacity(0.14),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: _GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(icon, color: accentColor, size: 30),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'This module screen is ready for feature integration.',
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
        ],
      ),
    );
  }
}

class _LocalAdminNoticeCard extends StatelessWidget {
  const _LocalAdminNoticeCard();

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
              'You are signed in with fixed admin credentials in local mode. Profile write operations are disabled until this account exists in Auth and profiles table.',
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

class _SheetActionTile extends StatelessWidget {
  const _SheetActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _DashboardPalette.authBlue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                          color: Colors.grey.shade700, fontSize: 12.5),
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

class _FloatingGlassBottomNav extends StatelessWidget {
  const _FloatingGlassBottomNav({
    required this.activeTab,
    required this.onTabSelected,
    required this.onCenterPressed,
    required this.onMenuPressed,
  });

  final _DashboardTab activeTab;
  final ValueChanged<_DashboardTab> onTabSelected;
  final VoidCallback onCenterPressed;
  final VoidCallback onMenuPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  height: 68,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.95)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _BottomNavItem(
                        icon: const Icon(Icons.home_rounded),
                        isActive: activeTab == _DashboardTab.home,
                        onTap: () => onTabSelected(_DashboardTab.home),
                      ),
                      _BottomNavItem(
                        icon: const Icon(Icons.import_contacts_rounded),
                        isActive: activeTab == _DashboardTab.resources,
                        onTap: () => onTabSelected(_DashboardTab.resources),
                      ),
                      const SizedBox(width: 56),
                      _BottomNavItem(
                        icon: const Icon(Icons.calendar_view_week_rounded),
                        isActive: activeTab == _DashboardTab.routine,
                        onTap: () => onTabSelected(_DashboardTab.routine),
                      ),
                      _BottomNavItem(
                        icon: const Icon(Icons.menu_rounded),
                        isActive: false,
                        onTap: onMenuPressed,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -12,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                color: _DashboardPalette.authBlue,
                shape: const CircleBorder(),
                elevation: 8,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onCenterPressed,
                  child: const SizedBox(
                    width: 56,
                    height: 56,
                    child: Icon(
                      Icons.smart_toy_outlined,
                      color: Colors.white,
                      size: 28,
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

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final Widget icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        isActive ? _DashboardPalette.authBlue : const Color(0xFF64748B);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: SizedBox(
        width: 46,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconTheme(
              data: IconThemeData(color: iconColor, size: 25),
              child: icon,
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color:
                    isActive ? _DashboardPalette.authBlue : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
