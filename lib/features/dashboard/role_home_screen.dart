import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:flutter/foundation.dart';
import 'package:native_glass_navbar/native_glass_navbar.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/data/models/dashboard_feed_item.dart';
import 'package:unisharesync_mobile_app/data/models/profile_model.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';
import 'package:unisharesync_mobile_app/features/admin/admin_home_screen.dart';
import 'package:unisharesync_mobile_app/features/auth/login_screen.dart';
import 'package:unisharesync_mobile_app/features/notice_board/notice_board_screen.dart';
import 'package:unisharesync_mobile_app/features/notification_center/notification_center_screen.dart';
import 'package:unisharesync_mobile_app/features/profile/profile_management_screen.dart';
import 'package:unisharesync_mobile_app/features/projects/projects_screen.dart';
import 'package:unisharesync_mobile_app/features/resources/resources_tab_view.dart';
import 'package:unisharesync_mobile_app/features/scheduler/class_scheduler_screen.dart';
import 'package:unisharesync_mobile_app/features/events/presentation/screens/events_browse_screen.dart';
import 'package:unisharesync_mobile_app/features/communities/presentation/screens/communities_browse_screen.dart';
import 'package:unisharesync_mobile_app/features/lost_found/lost_found_screen.dart';
import 'package:unisharesync_mobile_app/features/alumni/presentation/screens/alumni_browse_screen.dart';
import 'package:unisharesync_mobile_app/features/feedback/feedback_screen.dart';
import 'package:unisharesync_mobile_app/features/ai_chat/ai_chat_screen.dart';
import 'package:unisharesync_mobile_app/features/bus_tracker/bus_tracker_screen.dart';
import 'package:unisharesync_mobile_app/features/item_share/campus_share_home_screen.dart';
import 'package:unisharesync_mobile_app/services/auth_service.dart';
import 'package:unisharesync_mobile_app/services/dashboard_feed_service.dart';

enum _DashboardTab { home, resources, routine, profile }

enum _MenuDestination {
  profile,
  settings,
  resources,
  noticeBoard,
  projects,
  events,
  communities,
  lostAndFound,
  feedback,
  notificationCenter,
  classScheduler,
  aiCampusAssistant,
  busTracker,
  campusShare,
  alumniConnect,
  signOut,
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
  static const Color campusShareOrange = Color(0xFFF97316);
  static const Color alumniBlue = Color(0xFF2563EB);
}

class RoleHomeScreen extends StatefulWidget {
  const RoleHomeScreen({
    super.key,
    this.initialRole,
    this.initialProfile,
    this.isLocalAdmin,
  });

  final UserRole? initialRole;
  final ProfileModel? initialProfile;
  final bool? isLocalAdmin;

  @override
  State<RoleHomeScreen> createState() => _RoleHomeScreenState();
}

class _RoleHomeScreenState extends State<RoleHomeScreen> {
  final AuthService _authService = AuthService();
  final DashboardFeedService _dashboardFeedService = DashboardFeedService();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSigningOut = false;
  bool _isLocalAdmin = false;
  UserRole _role = UserRole.student;
  ProfileModel? _profile;
  _DashboardTab _activeTab = _DashboardTab.home;
  int _resourcesRefreshTick = 0;

  DateTime _now = DateTime.now();
  bool _isOnline = true;
  StreamSubscription? _connectivitySub;
  Timer? _clockTicker;

  late final Stream<List<DashboardFeedItem>> _resourceStream;

  // Track notifications and notices unread status
  List<Map<String, dynamic>> _notices = [];
  List<Map<String, dynamic>> _noticeReads = [];
  List<Map<String, dynamic>> _dismissedNotices = [];
  List<Map<String, dynamic>> _systemNotifications = [];
  bool _hasUnreadNotifications = false;

  StreamSubscription? _noticesSubscription;
  StreamSubscription? _noticeReadsSubscription;
  StreamSubscription? _dismissedNoticesSubscription;
  StreamSubscription? _systemNotificationsSubscription;

  @override
  void initState() {
    super.initState();

    _resourceStream =
        _dashboardFeedService.watchResources(limit: 30).asBroadcastStream();

    _startClockTicker();
    _resolveSession();
    _watchConnectivity();
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    _cancelNotificationStreams();
    _connectivitySub?.cancel();
    super.dispose();
  }

  void _watchConnectivity() {
    Connectivity().checkConnectivity().then((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (mounted && _isOnline != online) {
        setState(() {
          _isOnline = online;
        });
      }
    });

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (mounted && _isOnline != online) {
        setState(() {
          _isOnline = online;
        });
      }
    });
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
    // If splash pre-loaded everything, skip the network round-trip.
    if (widget.initialProfile != null && widget.initialRole != null) {
      final role = widget.initialRole!;
      final profile = widget.initialProfile;
      final isLocalAdmin = widget.isLocalAdmin ?? false;

      if ((role == UserRole.admin || isLocalAdmin) && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AdminHomeScreen(
              isLocalAdmin: isLocalAdmin,
              initialProfile: profile,
            ),
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _role = role;
        _isLocalAdmin = isLocalAdmin;
        _profile = profile;
        _isLoading = false;
      });

      final userId = _supabase.auth.currentUser?.id;
      if (userId != null && !_isLocalAdmin) {
        _initNotificationStreams(userId);
      }
      return;
    }

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

      final userId = _supabase.auth.currentUser?.id;
      if (userId != null && !_isLocalAdmin) {
        _initNotificationStreams(userId);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSystemBack() async {
    if (_activeTab != _DashboardTab.home) {
      setState(() {
        _activeTab = _DashboardTab.home;
      });
      return;
    }

    final shouldExit = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Exit app?'),
            content: const Text(
              'You are on the dashboard. Do you want to close the app?'
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

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
    });

    _cancelNotificationStreams();

    await _authService.signOut();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  }

  void _initNotificationStreams(String userId) {
    _cancelNotificationStreams();

    _noticesSubscription = _supabase
        .from('notices')
        .stream(primaryKey: const ['id'])
        .order('created_at', ascending: false)
        .limit(100)
        .listen((data) {
          _notices = data.cast<Map<String, dynamic>>();
          _updateUnreadStatus();
        });

    _noticeReadsSubscription = _supabase
        .from('notice_reads')
        .stream(primaryKey: const ['id'])
        .eq('user_id', userId)
        .listen((data) {
          _noticeReads = data.cast<Map<String, dynamic>>();
          _updateUnreadStatus();
        });

    _dismissedNoticesSubscription = _supabase
        .from('dismissed_notices')
        .stream(primaryKey: const ['id'])
        .eq('user_id', userId)
        .listen((data) {
          _dismissedNotices = data.cast<Map<String, dynamic>>();
          _updateUnreadStatus();
        });

    _systemNotificationsSubscription = _supabase
        .from('notifications')
        .stream(primaryKey: const ['id'])
        .eq('user_id', userId)
        .listen((data) {
          _systemNotifications = data.cast<Map<String, dynamic>>();
          _updateUnreadStatus();
        });
  }

  void _cancelNotificationStreams() {
    _noticesSubscription?.cancel();
    _noticeReadsSubscription?.cancel();
    _dismissedNoticesSubscription?.cancel();
    _systemNotificationsSubscription?.cancel();
  }

  bool _shouldShowNotice(Map<String, dynamic> notice, String userRole, int? userSemester) {
    final targetRoles = (notice['target_roles'] as List?)?.cast<String>() ?? ['student', 'faculty', 'admin'];
    final targetSemesters = (notice['target_semesters'] as List?)?.cast<int>() ?? [];

    if (!targetRoles.contains(userRole)) {
      return false;
    }

    if (targetSemesters.isEmpty) {
      return true;
    }

    if (userSemester != null) {
      return targetSemesters.contains(userSemester);
    }

    return userRole != 'student';
  }

  void _updateUnreadStatus() {
    if (!mounted) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _hasUnreadNotifications = false;
      });
      return;
    }

    final hasUnreadSystem = _systemNotifications.any((n) => n['is_read'] == false);

    final readNoticeIds = _noticeReads.map((r) => r['notice_id'].toString()).toSet();
    final dismissedNoticeIds = _dismissedNotices.map((d) => d['notice_id'].toString()).toSet();

    final userRole = _profile?.role.value ?? _role.value;
    final userSemester = _profile?.semester != null
        ? int.tryParse(_profile!.semester!.toString())
        : null;

    final hasUnreadNotice = _notices.any((notice) {
      final noticeId = notice['id'].toString();

      if (readNoticeIds.contains(noticeId)) return false;
      if (dismissedNoticeIds.contains(noticeId)) return false;

      return _shouldShowNotice(notice, userRole, userSemester);
    });

    setState(() {
      _hasUnreadNotifications = hasUnreadSystem || hasUnreadNotice;
    });
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
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.97),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.95)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F9EFF).withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
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
                            Navigator.of(this.context).push(
                              MaterialPageRoute(
                                builder: (_) => const AiChatScreen(),
                              ),
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
        _openProfileEditor();
        break;
      case _MenuDestination.settings:
        _openProfileEditor();
        break;
      case _MenuDestination.signOut:
        _signOut();
        break;
      case _MenuDestination.resources:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ResourcesStandaloneScreen(
              currentRole: _role,
              isLocalAdmin: _isLocalAdmin,
            ),
          ),
        );
        break;
      case _MenuDestination.noticeBoard:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NoticeBoardScreen()),
        );
        break;
      case _MenuDestination.projects:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProjectsScreen()),
        );
        break;
      case _MenuDestination.events:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EventsBrowseScreen()),
        );
        break;
      case _MenuDestination.communities:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CommunitiesBrowseScreen()),
        );
        break;
      case _MenuDestination.lostAndFound:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LostFoundScreen(
              initialRole: _role,
              isLocalAdmin: _isLocalAdmin,
            ),
          ),
        );
        break;
      case _MenuDestination.feedback:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FeedbackScreen(
              initialRole: _role,
              isLocalAdmin: _isLocalAdmin,
            ),
          ),
        );
        break;
      case _MenuDestination.notificationCenter:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
        );
        break;
      case _MenuDestination.classScheduler:
        setState(() {
          _activeTab = _DashboardTab.routine;
        });
        break;
      case _MenuDestination.aiCampusAssistant:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AiChatScreen()),
        );
        break;
      case _MenuDestination.busTracker:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BusTrackerScreen(
              currentUserName: _profile?.fullName ?? 'Campus User',
            ),
          ),
        );
        break;
      case _MenuDestination.campusShare:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CampusShareHomeScreen(),
          ),
        );
        break;
      case _MenuDestination.alumniConnect:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AlumniBrowseScreen(),
          ),
        );
        break;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // Mark all notices as read
  Future<void> _markAllNoticesAsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      // Fetch all notice IDs
      final data = await _supabase.from('notices').select('id');
      final ids = (data as List).map((e) => e['id'].toString()).toList();
      // Upsert read records for each notice
      await _supabase.from('notice_reads').upsert(
        ids.map((id) => {
          'notice_id': id,
          'user_id': userId,
          'read_at': DateTime.now().toIso8601String(),
        }).toList(),
        onConflict: 'notice_id,user_id',
      );
    } catch (_) {}
  }

  // Mark all system notifications as read
  Future<void> _markAllSystemNotificationsAsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId);
    } catch (_) {}
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
          onAvatarTap: _openProfileEditor,
          hasUnread: _hasUnreadNotifications,
          onNotificationTap: () async {
            // Open notification center and mark all notices/system notifications as read on return
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationCenterScreen(),
              ),
            );
            // Mark all unread notices and system notifications as read when returning to home
            await _markAllNoticesAsRead();
            await _markAllSystemNotificationsAsRead();
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
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const NoticeBoardScreen()),
            ),
            child: const Text('View All Notices →',
                style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontWeight: FontWeight.w700)),
          ),
        ),
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
    return const ClassSchedulerScreen(key: PageStorageKey<String>('routine-tab'));
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
        const SizedBox(height: 20),
        // ── Account section ───────────────────────────────────────────────
        const _SettingsSectionLabel(label: 'Account'),
        const SizedBox(height: 6),
        _GlassSettingsGroup(
          children: [
            _SettingsRow(
              icon: Icons.person_outline_rounded,
              iconColor: _DashboardPalette.authBlue,
              label: 'Edit Profile',
              onTap: _openProfileEditor,
            ),
            _SettingsRow(
              icon: Icons.notifications_none_rounded,
              iconColor: _DashboardPalette.notificationSky,
              label: 'Notifications',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const NotificationCenterScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // ── Campus section ────────────────────────────────────────────────
        const _SettingsSectionLabel(label: 'Campus'),
        const SizedBox(height: 6),
        _GlassSettingsGroup(
          children: [
            _SettingsRow(
              icon: Icons.campaign_rounded,
              iconColor: _DashboardPalette.noticesAmber,
              label: 'Notice Board',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NoticeBoardScreen())),
            ),
            _SettingsRow(
              icon: Icons.directions_bus_rounded,
              iconColor: _DashboardPalette.busTrackerTeal,
              label: 'Bus Tracker',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BusTrackerScreen(
                      currentUserName: _profile?.fullName ?? 'Campus User'),
                ),
              ),
            ),
            _SettingsRow(
              icon: Icons.smart_toy_outlined,
              iconColor: _DashboardPalette.aiAssistantViolet,
              label: 'AI Campus Assistant',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AiChatScreen())),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // ── Support section ───────────────────────────────────────────────
        const _SettingsSectionLabel(label: 'Support'),
        const SizedBox(height: 6),
        _GlassSettingsGroup(
          children: [
            _SettingsRow(
              icon: Icons.rate_review_outlined,
              iconColor: _DashboardPalette.feedbackIndigo,
              label: 'Send Feedback',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FeedbackScreen(
                      initialRole: _role, isLocalAdmin: _isLocalAdmin),
                ),
              ),
            ),
          ],
        ),
        if (_isLocalAdmin) ...[
          const SizedBox(height: 14),
          const _LocalAdminNoticeCard(),
        ],
        const SizedBox(height: 28),
        // ── Sign out — always last, always red ────────────────────────────
        _SignOutButton(
          isLoading: _isSigningOut,
          onTap: _isSigningOut ? null : _signOut,
        ),
      ],
    );
  }

  Widget _buildActivityOverviewCard() {
    return FutureBuilder<int>(
      future: _dashboardFeedService.getTotalResourceCount(),
      builder: (context, totalCountSnapshot) {
        return StreamBuilder<List<DashboardFeedItem>>(
          stream: _resourceStream.timeout(
            const Duration(seconds: 5),
            onTimeout: (sink) {
              sink.add(const <DashboardFeedItem>[]);
            },
          ),
          builder: (context, snapshot) {
            final items = snapshot.data ?? const <DashboardFeedItem>[];
            final weekStart = DateTime.now().subtract(const Duration(days: 7));

            final weeklyItems = items
                .where(
                  (item) =>
                      item.createdAt != null && item.createdAt!.isAfter(weekStart),
                )
                .length;

            final totalResources = totalCountSnapshot.data ?? 0;

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
                    'Resources available now: $totalResources',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            );
          },
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
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NoticeBoardScreen()),
                  );
                },
              ),
              _QuickAccessTile(
                icon: Icons.account_tree_rounded,
                label: 'Projects',
                color: _DashboardPalette.projectsPurple,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProjectsScreen()),
                  );
                },
              ),
              _QuickAccessTile(
                icon: Icons.celebration_rounded,
                label: 'Events',
                color: _DashboardPalette.eventsEmerald,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EventsBrowseScreen()),
                  );
                },
              ),
              _QuickAccessTile(
                icon: Icons.groups_rounded,
                label: 'Communities',
                color: const Color(0xFF8B5CF6),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CommunitiesBrowseScreen()),
                  );
                },
              ),
              _QuickAccessTile(
                icon: Icons.search_rounded,
                label: 'Lost & Found',
                color: _DashboardPalette.lostFoundSoftRed,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LostFoundScreen(
                        initialRole: _role,
                        isLocalAdmin: _isLocalAdmin,
                      ),
                    ),
                  );
                },
              ),
              _QuickAccessTile(
                icon: Icons.directions_bus_rounded,
                label: 'Bus Tracker',
                color: _DashboardPalette.busTrackerTeal,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BusTrackerScreen(
                        currentUserName: _profile?.fullName ?? 'Campus User',
                      ),
                    ),
                  );
                },
              ),
              _QuickAccessTile(
                icon: Icons.swap_horiz_rounded,
                label: 'CampusShare',
                color: _DashboardPalette.campusShareOrange,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CampusShareHomeScreen(),
                    ),
                  );
                },
              ),
              _QuickAccessTile(
                icon: Icons.school_rounded,
                label: 'AlumniConnect',
                color: _DashboardPalette.alumniBlue,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AlumniBrowseScreen(),
                    ),
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
    return const NoticeDashboardStrip();
  }

  Widget _buildResourcePreviewList() {
    return FutureBuilder<List<DashboardFeedItem>>(
      future: _dashboardFeedService.watchResources(limit: 30).first,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _ResourcePreviewSkeletonList(itemCount: 4);
        }

        if (snapshot.hasError) {
          return _GlassCard(
            child: _CompactMessageWithAction(
              title: 'Unable to load resources',
              subtitle: 'Check your connection and try again.',
              actionLabel: 'Retry',
              onAction: () {
                if (!mounted) {
                  return;
                }

                setState(() {
                  _resourcesRefreshTick++;
                });
              },
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleSystemBack();
      },
      child: Scaffold(
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
                      child: _buildCurrentTab(),
                    ),
                  ),
                  if (!_isOnline)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 10,
                      left: 16,
                      right: 16,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2).withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFCA5A5).withOpacity(0.5)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.wifi_off_rounded, color: Color(0xFFB91C1C), size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'No Connection. Working offline.',
                                    style: TextStyle(
                                      color: Color(0xFFB91C1C),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
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
        bottomNavigationBar: _isLoading
            ? null
            : (!kIsWeb && Platform.isIOS)
                ? NativeGlassNavBar(
                    currentIndex: _currentIndex,
                    onTap: _onBottomNavTapped,
                    actionButton: TabBarActionButton(
                      symbol: 'sparkles',
                      onTap: _openQuickActionSheet,
                    ),
                    tabs: const [
                      NativeGlassNavBarItem(label: 'Home', symbol: 'house'),
                      NativeGlassNavBarItem(label: 'Resources', symbol: 'book'),
                      NativeGlassNavBarItem(label: 'Routine', symbol: 'calendar'),
                      NativeGlassNavBarItem(label: 'Menu', symbol: 'line.3.horizontal'),
                    ],
                    fallback: _buildFallbackBottomNav(),
                  )
                : _buildFallbackBottomNav(),
      ),
    );
  }

  int get _currentIndex {
    switch (_activeTab) {
      case _DashboardTab.home:
        return 0;
      case _DashboardTab.resources:
        return 1;
      case _DashboardTab.routine:
        return 2;
      case _DashboardTab.profile:
        return 0;
    }
  }

  void _onBottomNavTapped(int index) {
    if (index == 3) {
      _openHamburgerMenu();
      return;
    }
    setState(() {
      if (index == 0) _activeTab = _DashboardTab.home;
      if (index == 1) _activeTab = _DashboardTab.resources;
      if (index == 2) _activeTab = _DashboardTab.routine;
    });
  }

  Widget _buildFallbackBottomNav() {
    return Padding(
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
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.greeting,
    required this.subtitle,
    required this.avatarUrl,
    required this.onNotificationTap,
    required this.onAvatarTap,
    required this.hasUnread,
  });

  final String greeting;
  final String subtitle;
  final String? avatarUrl;
  final VoidCallback onNotificationTap;
  final VoidCallback onAvatarTap;
  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          child: CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFDCEBFF),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? const Icon(Icons.person, color: Color(0xFF2B5B94), size: 22)
                : null,
          ),
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
                  if (hasUnread)
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
    // Lightweight card — no BackdropFilter to keep 60fps on mid-range devices.
    // The subtle white fill + border preserves the glassmorphism aesthetic.
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.95)),
        boxShadow: [
          BoxShadow(
            color: _DashboardPalette.authBlue.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
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
      UserRole.driver => const Color(0xFF14B8A6),
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

class _CompactMessageWithAction extends StatelessWidget {
  const _CompactMessageWithAction({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

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
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(actionLabel),
          ),
        ),
      ],
    );
  }
}

class _ResourcePreviewSkeletonList extends StatelessWidget {
  const _ResourcePreviewSkeletonList({required this.itemCount});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index == itemCount - 1 ? 0 : 10),
          child: const _ResourcePreviewSkeletonCard(),
        ),
      ),
    );
  }
}

class _ResourcePreviewSkeletonCard extends StatelessWidget {
  const _ResourcePreviewSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBox(width: 36, height: 36, radius: 10),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: double.infinity, height: 14, radius: 8),
                SizedBox(height: 8),
                _SkeletonBox(width: 180, height: 12, radius: 8),
                SizedBox(height: 8),
                _SkeletonBox(width: 74, height: 18, radius: 999),
              ],
            ),
          ),
          SizedBox(width: 8),
          _SkeletonBox(width: 38, height: 12, radius: 8),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE2E8F0),
            Color(0xFFF1F5F9),
            Color(0xFFE2E8F0),
          ],
        ),
      ),
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

class _HamburgerMenuScreen extends StatelessWidget {
  const _HamburgerMenuScreen({
    required this.profile,
    required this.role,
    required this.isLocalAdmin,
  });

  final ProfileModel? profile;
  final UserRole role;
  final bool isLocalAdmin;

  void _go(BuildContext context, _MenuDestination d) =>
      Navigator.of(context).pop(d);

  @override
  Widget build(BuildContext context) {
    final displayName = profile?.fullName ??
        (isLocalAdmin ? 'Fixed Credential Admin' : 'Campus User');
    final email = profile?.email ?? (isLocalAdmin ? 'Local admin mode' : '');
    final roleLabel = isLocalAdmin ? 'Admin' : role.displayName;

    final roleColor = switch (role) {
      UserRole.student => const Color(0xFF2563EB),
      UserRole.faculty => const Color(0xFF0F766E),
      UserRole.admin => const Color(0xFFEA580C),
      UserRole.driver => const Color(0xFF14B8A6),
    };

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
            top: -90, right: -60,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _DashboardPalette.authBlue.withOpacity(0.1),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                _GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: roleColor.withOpacity(0.15),
                        backgroundImage: profile?.avatarUrl != null
                            ? NetworkImage(profile!.avatarUrl!)
                            : null,
                        child: profile?.avatarUrl == null
                            ? Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                  color: roleColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
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
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: roleColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                roleLabel,
                                style: TextStyle(
                                  color: roleColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _go(context, _MenuDestination.profile),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: _DashboardPalette.authBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Edit',
                            style: TextStyle(
                              color: _DashboardPalette.authBlue,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // ── Campus Features ──────────────────────────────────────
                const _SettingsSectionLabel(label: 'Campus'),
                const SizedBox(height: 6),
                _GlassSettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.menu_book_rounded,
                      iconColor: _DashboardPalette.resourcesBlue,
                      label: 'Resources',
                      onTap: () => _go(context, _MenuDestination.resources),
                    ),
                    _SettingsRow(
                      icon: Icons.campaign_rounded,
                      iconColor: _DashboardPalette.noticesAmber,
                      label: 'Notice Board',
                      onTap: () => _go(context, _MenuDestination.noticeBoard),
                    ),
                    _SettingsRow(
                      icon: Icons.account_tree_rounded,
                      iconColor: _DashboardPalette.projectsPurple,
                      label: 'Projects',
                      onTap: () => _go(context, _MenuDestination.projects),
                    ),
                    _SettingsRow(
                      icon: Icons.celebration_rounded,
                      iconColor: _DashboardPalette.eventsEmerald,
                      label: 'Events & Seminars',
                      onTap: () =>
                          _go(context, _MenuDestination.events),
                    ),
                    _SettingsRow(
                      icon: Icons.groups_rounded,
                      iconColor: const Color(0xFF8B5CF6),
                      label: 'Communities',
                      onTap: () =>
                          _go(context, _MenuDestination.communities),
                    ),
                    _SettingsRow(
                      icon: Icons.search_rounded,
                      iconColor: _DashboardPalette.lostFoundSoftRed,
                      label: 'Lost & Found',
                      onTap: () => _go(context, _MenuDestination.lostAndFound),
                    ),
                    _SettingsRow(
                      icon: Icons.directions_bus_rounded,
                      iconColor: _DashboardPalette.busTrackerTeal,
                      label: 'Bus Tracker',
                      onTap: () => _go(context, _MenuDestination.busTracker),
                    ),
                    _SettingsRow(
                      icon: Icons.calendar_view_week_rounded,
                      iconColor: _DashboardPalette.authTeal,
                      label: 'Class Scheduler',
                      onTap: () =>
                          _go(context, _MenuDestination.classScheduler),
                    ),
                    _SettingsRow(
                      icon: Icons.smart_toy_outlined,
                      iconColor: _DashboardPalette.aiAssistantViolet,
                      label: 'AI Campus Assistant',
                      onTap: () =>
                          _go(context, _MenuDestination.aiCampusAssistant),
                    ),
                    _SettingsRow(
                      icon: Icons.swap_horiz_rounded,
                      iconColor: _DashboardPalette.campusShareOrange,
                      label: 'CampusShare',
                      onTap: () => _go(context, _MenuDestination.campusShare),
                    ),
                    _SettingsRow(
                      icon: Icons.school_rounded,
                      iconColor: _DashboardPalette.alumniBlue,
                      label: 'AlumniConnect',
                      onTap: () => _go(context, _MenuDestination.alumniConnect),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // ── Account ──────────────────────────────────────────────
                const _SettingsSectionLabel(label: 'Account'),
                const SizedBox(height: 6),
                _GlassSettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.notifications_active_outlined,
                      iconColor: _DashboardPalette.notificationSky,
                      label: 'Notifications',
                      onTap: () =>
                          _go(context, _MenuDestination.notificationCenter),
                    ),
                    _SettingsRow(
                      icon: Icons.rate_review_outlined,
                      iconColor: _DashboardPalette.feedbackIndigo,
                      label: 'Feedback',
                      onTap: () => _go(context, _MenuDestination.feedback),
                    ),
                    _SettingsRow(
                      icon: Icons.settings_outlined,
                      iconColor: _DashboardPalette.settingsSlate,
                      label: 'Profile Settings',
                      onTap: () => _go(context, _MenuDestination.profile),
                    ),
                    _SettingsRow(
                      icon: Icons.logout_rounded,
                      iconColor: const Color(0xFFDC2626),
                      label: 'Sign Out',
                      isDestructive: true,
                      onTap: () => _go(context, _MenuDestination.signOut),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Settings section label ────────────────────────────────────────────────────

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF94A3B8),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Grouped glass settings card ───────────────────────────────────────────────

class _GlassSettingsGroup extends StatelessWidget {
  const _GlassSettingsGroup({required this.children});
  final List<_SettingsRow> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.95)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F9EFF).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 1,
                indent: 54,
                endIndent: 0,
                color: const Color(0xFFE2E8F0).withOpacity(0.8),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Single settings row ───────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final labelColor =
        isDestructive ? const Color(0xFFDC2626) : const Color(0xFF0F172A);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: labelColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isDestructive
                        ? const Color(0xFFDC2626).withOpacity(0.4)
                        : const Color(0xFFCBD5E1),
                    size: 20,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sign Out button ───────────────────────────────────────────────────────────

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.isLoading, required this.onTap});
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.95)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(Color(0xFFDC2626)),
                          ),
                        )
                      : const Icon(
                          Icons.logout_rounded,
                          color: Color(0xFFDC2626),
                          size: 18,
                        ),
                ),
                const SizedBox(width: 12),
                Text(
                  isLoading ? 'Signing out...' : 'Sign Out',
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
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
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.12),
                        const Color(0xFFE0F2FE).withOpacity(0.22),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.42),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withOpacity(0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _BottomNavItem(
                        icon: const Icon(Icons.home_rounded),
                        label: 'Home',
                        isActive: activeTab == _DashboardTab.home,
                        onTap: () => onTabSelected(_DashboardTab.home),
                      ),
                      _BottomNavItem(
                        icon: const Icon(Icons.import_contacts_rounded),
                        label: 'Resources',
                        isActive: activeTab == _DashboardTab.resources,
                        onTap: () => onTabSelected(_DashboardTab.resources),
                      ),
                      const SizedBox(width: 56),
                      _BottomNavItem(
                        icon: const Icon(Icons.calendar_view_week_rounded),
                        label: 'Routine',
                        isActive: activeTab == _DashboardTab.routine,
                        onTap: () => onTabSelected(_DashboardTab.routine),
                      ),
                      _BottomNavItem(
                        icon: const Icon(Icons.menu_rounded),
                        label: 'Menu',
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
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final Widget icon;
  final String label;
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
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconTheme(
              data: IconThemeData(color: iconColor, size: 22),
              child: icon,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: iconColor,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
