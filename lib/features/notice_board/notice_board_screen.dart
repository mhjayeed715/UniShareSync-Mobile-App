import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'notice_model.dart';
import 'notice_service.dart';

// ── Public entry point ────────────────────────────────────────────────────────

class NoticeBoardScreen extends StatelessWidget {
  const NoticeBoardScreen({super.key});

  static const _amber = Color(0xFFF59E0B);
  static const _bg = Color(0xFFF4F8FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Notice Board',
          style: TextStyle(
              color: Color(0xFF0F172A), fontWeight: FontWeight.w800),
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
                  colors: [Color(0xFFF8FBFF), Color(0xFFEAF6FF)],
                ),
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _amber.withOpacity(0.1),
              ),
            ),
          ),
          SafeArea(
            child: StreamBuilder<List<NoticeModel>>(
              stream: NoticeService().watchNotices(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final notices = snapshot.data ?? [];
                if (notices.isEmpty) {
                  return const Center(
                    child: Text('No notices available.',
                        style: TextStyle(color: Color(0xFF64748B))),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: notices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final notice = notices[index];
                    return _NoticeListCard(
                      notice: notice,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NoticeDetailScreen(notice: notice),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dashboard horizontal preview strip ───────────────────────────────────────

class NoticeDashboardStrip extends StatelessWidget {
  const NoticeDashboardStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 152,
      child: StreamBuilder<List<NoticeModel>>(
        stream: NoticeService().watchNotices(limit: 10),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final notices = snapshot.data ?? [];
          if (notices.isEmpty) {
            return const _GlassCard(
              child: Center(
                child: Text('No notices yet.',
                    style: TextStyle(color: Color(0xFF64748B))),
              ),
            );
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: notices.length > 10 ? 10 : notices.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final notice = notices[index];
              return _NoticeDashboardCard(
                notice: notice,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NoticeDetailScreen(notice: notice),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Detail screen ─────────────────────────────────────────────────────────────

class NoticeDetailScreen extends StatelessWidget {
  const NoticeDetailScreen({super.key, required this.notice});

  final NoticeModel notice;

  static const _amber = Color(0xFFF59E0B);
  static const _bg = Color(0xFFF4F8FF);

  Color _priorityColor(NoticePriority p) => switch (p) {
        NoticePriority.urgent => const Color(0xFFEF4444),
        NoticePriority.important => _amber,
        NoticePriority.normal => const Color(0xFF64748B),
      };

  @override
  Widget build(BuildContext context) {
    final pColor = _priorityColor(notice.priority);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Notice Detail',
          style: TextStyle(
              color: Color(0xFF0F172A), fontWeight: FontWeight.w800),
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
                  colors: [Color(0xFFF8FBFF), Color(0xFFEAF6FF)],
                ),
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pColor.withOpacity(0.12),
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Priority badge
                      if (notice.priority != NoticePriority.normal)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: pColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            notice.priority.label,
                            style: TextStyle(
                                color: pColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 10),
                      // Title
                      Text(
                        notice.title,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 6),
                      // Date
                      Text(
                        _formatDate(notice.createdAt),
                        style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                      const Divider(height: 24),
                      // Content
                      Text(
                        notice.content,
                        style: const TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 15,
                            height: 1.6),
                      ),
                      // Attachment
                      if (notice.attachmentUrl != null) ...[
                        const SizedBox(height: 20),
                        _buildAttachment(notice),
                      ],
                      if (notice.postedBy != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Posted by: ${notice.postedBy}',
                          style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachment(NoticeModel notice) {
    final isPdf = notice.attachmentType == 'pdf';
    final isImage = notice.attachmentType == 'image';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attachment',
          style: TextStyle(
              fontWeight: FontWeight.w700, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 8),
        if (isImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              notice.attachmentUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Text('Image unavailable'),
            ),
          ),
        if (isPdf)
          GestureDetector(
            onTap: () => launchUrl(Uri.parse(notice.attachmentUrl!),
                mode: LaunchMode.externalApplication),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.picture_as_pdf,
                      color: Color(0xFFEF4444), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Open PDF',
                    style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ── Private widgets ───────────────────────────────────────────────────────────

class _NoticeListCard extends StatelessWidget {
  const _NoticeListCard({required this.notice, required this.onTap});

  final NoticeModel notice;
  final VoidCallback onTap;

  static const _amber = Color(0xFFF59E0B);

  Color _priorityColor(NoticePriority p) => switch (p) {
        NoticePriority.urgent => const Color(0xFFEF4444),
        NoticePriority.important => _amber,
        NoticePriority.normal => const Color(0xFF64748B),
      };

  @override
  Widget build(BuildContext context) {
    final pColor = _priorityColor(notice.priority);

    return _GlassCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: pColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.campaign_rounded, color: pColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    notice.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A)),
                  ),
                ),
                if (notice.priority != NoticePriority.normal)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: pColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      notice.priority.label,
                      style: TextStyle(
                          color: pColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              notice.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            if (notice.attachmentUrl != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    notice.attachmentType == 'pdf'
                        ? Icons.picture_as_pdf
                        : Icons.image_outlined,
                    size: 15,
                    color: notice.attachmentType == 'pdf'
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF4F9EFF),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    notice.attachmentType == 'pdf'
                        ? 'PDF attached'
                        : 'Image attached',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _relativeTime(notice.createdAt),
                  style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600),
                ),
                const Text(
                  'View Details →',
                  style: TextStyle(
                      color: Color(0xFF4F9EFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final delta = DateTime.now().difference(dt);
    if (delta.inMinutes < 1) return 'Just now';
    if (delta.inHours < 1) return '${delta.inMinutes}m ago';
    if (delta.inDays < 1) return '${delta.inHours}h ago';
    if (delta.inDays < 7) return '${delta.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _NoticeDashboardCard extends StatelessWidget {
  const _NoticeDashboardCard({required this.notice, required this.onTap});

  final NoticeModel notice;
  final VoidCallback onTap;

  static const _amber = Color(0xFFF59E0B);

  Color _priorityColor(NoticePriority p) => switch (p) {
        NoticePriority.urgent => const Color(0xFFEF4444),
        NoticePriority.important => _amber,
        NoticePriority.normal => const Color(0xFF64748B),
      };

  @override
  Widget build(BuildContext context) {
    final pColor = _priorityColor(notice.priority);

    return SizedBox(
      width: 240,
      child: _GlassCard(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (notice.priority != NoticePriority.normal)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: pColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    notice.priority.label,
                    style: TextStyle(
                        color: pColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                notice.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  notice.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5, color: Colors.grey.shade700),
                ),
              ),
              Text(
                _relativeTime(notice.createdAt),
                style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final delta = DateTime.now().difference(dt);
    if (delta.inMinutes < 1) return 'Just now';
    if (delta.inHours < 1) return '${delta.inMinutes}m ago';
    if (delta.inDays < 1) return '${delta.inHours}h ago';
    if (delta.inDays < 7) return '${delta.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.82),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
