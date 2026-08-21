import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'notice_model.dart';
import 'notice_service.dart';

// ── Public entry point ────────────────────────────────────────────────────────

class NoticeBoardScreen extends StatefulWidget {
  const NoticeBoardScreen({super.key});

  @override
  State<NoticeBoardScreen> createState() => _NoticeBoardScreenState();
}

class _NoticeBoardScreenState extends State<NoticeBoardScreen> {
  int _retryTick = 0;

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
        centerTitle: false,
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
              key: ValueKey(_retryTick),
              stream: NoticeService().watchNotices(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const _NoticeBoardLoadingState();
                }
                if (snapshot.hasError) {
                  return _NoticeBoardErrorState(
                    message: 'Unable to load notices.',
                    onRetry: () => setState(() => _retryTick++),
                  );
                }
                final notices = snapshot.data ?? [];
                if (notices.isEmpty) {
                  return const _NoticeBoardEmptyState(
                    title: 'No notices available',
                    subtitle: 'New notices will appear here when published.',
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

class NoticeDashboardStrip extends StatefulWidget {
  const NoticeDashboardStrip({super.key});

  @override
  State<NoticeDashboardStrip> createState() => _NoticeDashboardStripState();
}

class _NoticeDashboardStripState extends State<NoticeDashboardStrip> {
  int _retryTick = 0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 152,
      child: StreamBuilder<List<NoticeModel>>(
        key: ValueKey(_retryTick),
        stream: NoticeService().watchNotices(limit: 10),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const _NoticeStripLoadingState();
          }
          if (snapshot.hasError) {
            return _NoticeStripErrorState(
              onRetry: () => setState(() => _retryTick++),
            );
          }
          final notices = snapshot.data ?? [];
          if (notices.isEmpty) {
            return const _GlassCard(
              child: _NoticeBoardEmptyState(
                title: 'No notices yet',
                subtitle: 'This preview updates when notices are published.',
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

class _NoticeBoardLoadingState extends StatelessWidget {
  const _NoticeBoardLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const _NoticeSkeletonCard(),
    );
  }
}

class _NoticeStripLoadingState extends StatelessWidget {
  const _NoticeStripLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (_, __) => const SizedBox(
        width: 220,
        child: _NoticeSkeletonCard(compact: true),
      ),
    );
  }
}

class _NoticeBoardErrorState extends StatelessWidget {
  const _NoticeBoardErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 34, color: Color(0xFF64748B)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeStripErrorState extends StatelessWidget {
  const _NoticeStripErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Text(
              'Unable to load notices',
              style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _NoticeBoardEmptyState extends StatelessWidget {
  const _NoticeBoardEmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}

class _NoticeSkeletonCard extends StatelessWidget {
  const _NoticeSkeletonCard({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 124.0 : 118.0;
    return _GlassCard(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 72, height: 18, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 10),
            Container(width: double.infinity, height: 14, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 8),
            Container(width: 180, height: 12, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(8))),
            const Spacer(),
            Container(width: 90, height: 12, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(8))),
          ],
        ),
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
            if (notice.attachmentUrl != null && notice.attachmentUrl!.trim().isNotEmpty) ...[
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.95)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}
