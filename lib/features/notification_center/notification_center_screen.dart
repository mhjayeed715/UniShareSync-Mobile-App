import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final _supabase = Supabase.instance.client;
  late final Stream<List<Map<String, dynamic>>> _noticesStream;
  late final Stream<List<Map<String, dynamic>>> _systemNotificationsStream;
  late final Stream<List<Map<String, dynamic>>> _readStatusStream;
  late final Stream<List<Map<String, dynamic>>> _dismissedStream;

  @override
  void initState() {
    super.initState();
    final userId = _supabase.auth.currentUser?.id ?? '';

    _noticesStream = _supabase
        .from('notices')
        .stream(primaryKey: const ['id'])
        .order('created_at', ascending: false)
        .limit(100)
        .map((rows) => rows.cast<Map<String, dynamic>>());

    _systemNotificationsStream = _supabase
      .from('notifications')
      .stream(primaryKey: const ['id'])
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .limit(100)
      .map((rows) => rows.cast<Map<String, dynamic>>());
    
    _readStatusStream = _supabase
        .from('notice_reads')
        .stream(primaryKey: const ['id'])
      .eq('user_id', userId)
        .map((rows) => rows.cast<Map<String, dynamic>>());
    
    _dismissedStream = _supabase
        .from('dismissed_notices')
        .stream(primaryKey: const ['id'])
      .eq('user_id', userId)
        .map((rows) => rows.cast<Map<String, dynamic>>());
  }

  Future<Map<String, dynamic>> _getUserRoleAndSemester() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return {'role': 'student', 'semester': null};
      }

      final profile = await _supabase
          .from('profiles')
          .select('role, semester')
          .eq('id', userId)
          .maybeSingle();

      if (profile != null) {
        return {
          'role': profile['role']?.toString() ?? 'student',
          'semester': profile['semester'] != null 
              ? int.tryParse(profile['semester'].toString()) 
              : null,
        };
      }
      return {'role': 'student', 'semester': null};
    } catch (e) {
      print('Error fetching user profile: $e');
      return {'role': 'student', 'semester': null};
    }
  }

  bool _shouldShowNotice(Map<String, dynamic> notice, String userRole, int? userSemester) {
    final targetRoles = (notice['target_roles'] as List?)?.cast<String>() ?? ['student', 'faculty', 'admin'];
    final targetSemesters = (notice['target_semesters'] as List?)?.cast<int>() ?? [];

    // Check if user's role is in target roles
    if (!targetRoles.contains(userRole)) {
      return false;
    }

    // If target semesters is empty, show to all
    if (targetSemesters.isEmpty) {
      return true;
    }

    // If target semesters is specified, check if user's semester matches
    if (userSemester != null) {
      return targetSemesters.contains(userSemester);
    }

    // If user has no semester (faculty/admin), show all
    return userRole != 'student';
  }

  Future<void> _deleteNotification(String notificationId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    
    try {
      // Add to dismissed_notices to remove from notification center
      await _supabase.from('dismissed_notices').insert({
        'notice_id': notificationId,
        'user_id': userId,
      });
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification removed'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _markAsRead(String noticeId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      // Use upsert so a second tap won’t error and we can store when it was read
      await _supabase.from('notice_reads').upsert({
        'notice_id': noticeId,
        'user_id': userId,
        'read_at': DateTime.now().toIso8601String(),
      }, onConflict: 'notice_id,user_id');
    } catch (e) {
      // Silently ignore any unexpected error – the UI will stay consistent
    }
  }

  Future<void> _markAsUnread(String noticeId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase
          .from('notice_reads')
          .delete()
          .eq('notice_id', noticeId)
          .eq('user_id', userId);
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _deleteSystemNotification(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);
    } catch (_) {}
  }

  Future<void> _markSystemAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (_) {}
  }

  Future<void> _markSystemAsUnread(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': false})
          .eq('id', notificationId);
    } catch (_) {}
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Notifications',
          style: TextStyle(
              color: Color(0xFF0F172A), fontWeight: FontWeight.w800),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'mark_all') {
                // Determine which tab is active
                final tabController = DefaultTabController.of(context);
                if (tabController.index == 0) {
                  await _markAllNoticesAsRead();
                } else {
                  await _markAllSystemNotificationsAsRead();
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'mark_all',
                child: Row(
                  children: [
                    Icon(Icons.mark_email_read, size: 18, color: Color(0xFF4F9EFF)),
                    SizedBox(width: 8),
                    Text('Mark All as Read'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF8FBFF), Color(0xFFEAF6FF)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TabBar(
                      labelColor: const Color(0xFF0F172A),
                      unselectedLabelColor: const Color(0xFF94A3B8),
                      indicatorColor: const Color(0xFF4F9EFF),
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      tabs: const [
                        Tab(text: 'Notices'),
                        Tab(text: 'Updates'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildNoticesTab(),
                        _buildSystemNotificationsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticesTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _noticesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}',
                style: const TextStyle(color: Color(0xFF64748B))),
          );
        }

        final notices = snapshot.data ?? [];
        if (notices.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none_rounded,
                    size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('No notices yet',
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _readStatusStream,
          builder: (context, readSnapshot) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _dismissedStream,
              builder: (context, dismissedSnapshot) {
                return FutureBuilder<Map<String, dynamic>>(
                  future: _getUserRoleAndSemester(),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final userRole = userSnapshot.data!['role'] as String;
                    final userSemester = userSnapshot.data!['semester'] as int?;

                    final readNotices = readSnapshot.data ?? [];
                    final readNoticeIds = readNotices
                        .map((r) => r['notice_id'].toString())
                        .toSet();

                    final dismissedNotices = dismissedSnapshot.data ?? [];
                    final dismissedNoticeIds = dismissedNotices
                        .map((d) => d['notice_id'].toString())
                        .toSet();

                    final activeNotices = notices
                        .where((n) => !dismissedNoticeIds
                            .contains(n['id'].toString()))
                        .where((n) => _shouldShowNotice(
                            n, userRole, userSemester))
                        .toList();

                    if (activeNotices.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none_rounded,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('No notices',
                                style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      itemCount: activeNotices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final notice = activeNotices[index];
                        final noticeId = notice['id'].toString();
                        final isRead = readNoticeIds.contains(noticeId);
                        final title =
                            notice['title']?.toString() ?? 'Notification';
                        final body = notice['content']?.toString() ?? '';
                        final createdAt = notice['created_at'] != null
                            ? DateTime.parse(notice['created_at'].toString())
                            : DateTime.now();
                        final notifType =
                            notice['notice_type']?.toString() ?? 'info';

                        return _NotificationCard(
                          title: title,
                          body: body,
                          type: notifType,
                          createdAt: createdAt,
                          notificationId: noticeId,
                          isRead: isRead,
                          onDelete: () => _deleteNotification(noticeId),
                          onMarkAsRead: () => _markAsRead(noticeId),
                          onMarkAsUnread: () => _markAsUnread(noticeId),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSystemNotificationsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _systemNotificationsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}',
                style: const TextStyle(color: Color(0xFF64748B))),
          );
        }

        final notifications = snapshot.data ?? [];
        if (notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none_rounded,
                    size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('No updates yet',
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: notifications.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final notif = notifications[index];
            final notifId = notif['id'].toString();
            final isRead = (notif['is_read'] as bool?) ?? false;
            final title = notif['title']?.toString() ?? 'Update';
            final body = notif['body']?.toString() ?? '';
            final createdAt = notif['created_at'] != null
                ? DateTime.parse(notif['created_at'].toString())
                : DateTime.now();
            final notifType =
                notif['notification_type']?.toString() ?? 'info';

            return _NotificationCard(
              title: title,
              body: body,
              type: notifType,
              createdAt: createdAt,
              notificationId: notifId,
              isRead: isRead,
              onDelete: () => _deleteSystemNotification(notifId),
              onMarkAsRead: () => _markSystemAsRead(notifId),
              onMarkAsUnread: () => _markSystemAsUnread(notifId),
            );
          },
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    required this.notificationId,
    required this.isRead,
    required this.onDelete,
    required this.onMarkAsRead,
    required this.onMarkAsUnread,
  });

  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  final String notificationId;
  final bool isRead;
  final VoidCallback onDelete;
  final VoidCallback onMarkAsRead;
  final VoidCallback onMarkAsUnread;

  Color _getTypeColor() => switch (type) {
        'success' => const Color(0xFF10B981),
        'warning' => const Color(0xFFF59E0B),
        'error' => const Color(0xFFEF4444),
        _ => const Color(0xFF4F9EFF),
      };

  IconData _getTypeIcon() => switch (type) {
        'success' => Icons.check_circle_outline,
        'warning' => Icons.warning_outlined,
        'error' => Icons.error_outline,
        _ => Icons.info_outlined,
      };

  String _relativeTime(DateTime dt) {
    final delta = DateTime.now().difference(dt);
    if (delta.inMinutes < 1) return 'Just now';
    if (delta.inHours < 1) return '${delta.inMinutes}m ago';
    if (delta.inDays < 1) return '${delta.inHours}h ago';
    if (delta.inDays < 7) return '${delta.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.82),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
            boxShadow: [
              BoxShadow(
                color: typeColor.withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_getTypeIcon(), color: typeColor, size: 22),
                      ),
                      if (!isRead)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F9EFF),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _relativeTime(createdAt),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'read') {
                        isRead ? onMarkAsUnread() : onMarkAsRead();
                      } else if (value == 'delete') {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Remove Notification'),
                            content: const Text(
                                'Are you sure you want to remove this notification?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  onDelete();
                                },
                                child: const Text(
                                  'Remove',
                                  style: TextStyle(color: Color(0xFFEF4444)),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem<String>(
                        value: 'read',
                        child: Row(
                          children: [
                            Icon(
                              isRead ? Icons.mail_outline : Icons.mail,
                              size: 18,
                              color: const Color(0xFF4F9EFF),
                            ),
                            const SizedBox(width: 8),
                            Text(isRead ? 'Mark as Unread' : 'Mark as Read'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: const [
                            Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Color(0xFFEF4444),
                            ),
                            SizedBox(width: 8),
                            Text('Remove'),
                          ],
                        ),
                      ),
                    ],
                    child: Icon(
                      Icons.more_vert,
                      color: Colors.grey.shade600,
                      size: 20,
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
