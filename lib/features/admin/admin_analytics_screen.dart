import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:unisharesync_mobile_app/services/admin_analytics_service.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _Palette {
  static const scaffold = Color(0xFFF4F8FF);
  static const gradientStart = Color(0xFFF8FBFF);
  static const gradientEnd = Color(0xFFEAF6FF);
  static const primary = Color(0xFF4F9EFF);
  static const teal = Color(0xFF14B8A6);
  static const emerald = Color(0xFF10B981);
  static const amber = Color(0xFFF59E0B);
  static const purple = Color(0xFF8B5CF6);
  static const indigo = Color(0xFF6366F1);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF334155);
  static const textMuted = Color(0xFF64748B);
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  final AdminAnalyticsService _service = AdminAnalyticsService();

  late AnimationController _entrance;
  AdminAnalyticsSnapshot _snapshot = AdminAnalyticsSnapshot.empty;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _load();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      setState(() => _refreshing = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final snapshot = await _service.fetchSnapshot();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _refreshing = false;
      });
      _entrance.forward(from: 0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = 'Could not load analytics. Pull to retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Palette.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'UniShareSync Analytics',
          style: TextStyle(
            color: _Palette.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : () => _load(refresh: true),
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
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
                  colors: [_Palette.gradientStart, _Palette.gradientEnd],
                ),
              ),
            ),
          ),
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorView(message: _error!, onRetry: _load)
                    : RefreshIndicator(
                        color: _Palette.primary,
                        onRefresh: () => _load(refresh: true),
                        child: FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _entrance,
                            curve: Curves.easeOut,
                          ),
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                            children: [
                              _HeroCard(snapshot: _snapshot),
                              const SizedBox(height: 14),
                              _SummaryRow(snapshot: _snapshot),
                              const SizedBox(height: 18),
                              _ChartCard(
                                title: 'Most Downloaded Courses',
                                subtitle: 'Top courses by resource downloads',
                                icon: Icons.menu_book_rounded,
                                iconColor: _Palette.primary,
                                child: _CourseDownloadsChart(
                                  courses: _snapshot.topCourses,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _ChartCard(
                                title: 'Weekly Active Users',
                                subtitle:
                                    'Unique users across logins, uploads & events',
                                icon: Icons.people_rounded,
                                iconColor: _Palette.indigo,
                                child: _WeeklyUsersChart(
                                  points: _snapshot.weeklyActiveUsers,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _ChartCard(
                                title: 'Portal Feature Statistics',
                                subtitle:
                                    'Activity across Notices, Communities & Lost-Found',
                                icon: Icons.dashboard_customize_rounded,
                                iconColor: _Palette.teal,
                                child: _FeaturesBarChart(
                                  notices: _snapshot.totalNotices,
                                  communities: _snapshot.totalCommunities,
                                  lostFound: _snapshot.totalLostFound,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _EventRegistrationsCard(
                                events: _snapshot.topEvents,
                                total: _snapshot.totalRegistrations,
                              ),
                              const SizedBox(height: 10),
                              Center(
                                child: Text(
                                  'Updated ${_formatTime(_snapshot.fetchedAt)}',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.snapshot});

  final AdminAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_Palette.primary, _Palette.indigo],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.insights_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'UniShareSync Insights',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: _Palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Live usage across resources, users, and transport',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.snapshot});

  final AdminAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            label: 'Users',
            value: snapshot.totalUsers,
            color: _Palette.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStat(
            label: 'Resources',
            value: snapshot.totalResources,
            color: _Palette.purple,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStat(
            label: 'Downloads',
            value: snapshot.totalDownloads,
            color: _Palette.emerald,
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        children: [
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: value),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Text(
              '$v',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: _Palette.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _Palette.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _CourseDownloadsChart extends StatelessWidget {
  const _CourseDownloadsChart({required this.courses});

  final List<CourseDownloadStat> courses;

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return const _EmptyChart(message: 'No download data yet');
    }

    final maxY = courses
            .map((c) => c.totalDownloads)
            .reduce((a, b) => a > b ? a : b)
            .toDouble() *
        1.2;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY < 4 ? 4 : maxY,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final course = courses[group.x];
                return BarTooltipItem(
                  '${course.courseCode}\n${course.totalDownloads} downloads',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, _) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10, color: _Palette.textMuted),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= courses.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      courses[i].courseCode,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _Palette.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: _Palette.primary.withOpacity(0.08),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var i = 0; i < courses.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: courses[i].totalDownloads.toDouble(),
                    width: 20,
                    gradient: const LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [_Palette.primary, Color(0xFF93C5FD)],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                  ),
                ],
              ),
          ],
        ),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

class _WeeklyUsersChart extends StatelessWidget {
  const _WeeklyUsersChart({required this.points});

  final List<WeeklyActiveUsersPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _EmptyChart(message: 'No user activity data yet');
    }

    final maxY = points
            .map((p) => p.activeUsers)
            .reduce((a, b) => a > b ? a : b)
            .toDouble() *
        1.25;

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY < 4 ? 4 : maxY,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map(
                    (s) => LineTooltipItem(
                      '${points[s.x.toInt()].weekLabel}\n${s.y.toInt()} users',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, _) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10, color: _Palette.textMuted),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, _) {
                  final i = value.toInt();
                  if (i < 0 || i >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    points[i].weekLabel,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: _Palette.textMuted,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: _Palette.indigo.withOpacity(0.08),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < points.length; i++)
                  FlSpot(i.toDouble(), points[i].activeUsers.toDouble()),
              ],
              isCurved: true,
              curveSmoothness: 0.28,
              color: _Palette.indigo,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2.5,
                  strokeColor: _Palette.indigo,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _Palette.indigo.withOpacity(0.22),
                    _Palette.indigo.withOpacity(0.02),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

class _FeaturesBarChart extends StatelessWidget {
  const _FeaturesBarChart({
    required this.notices,
    required this.communities,
    required this.lostFound,
  });

  final int notices;
  final int communities;
  final int lostFound;

  @override
  Widget build(BuildContext context) {
    final values = [notices.toDouble(), communities.toDouble(), lostFound.toDouble()];
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final maxY = maxVal < 4 ? 4.0 : maxVal * 1.25;

    final labels = ['Notices', 'Communities', 'Lost & Found'];
    final colors = [_Palette.amber, _Palette.purple, _Palette.teal];

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${labels[group.x]}\n${rod.toY.toInt()} items',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, _) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10, color: _Palette.textMuted),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      labels[i],
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: _Palette.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: _Palette.teal.withOpacity(0.08),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var i = 0; i < 3; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i],
                    color: colors[i],
                    width: 28,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxY,
                      color: colors[i].withOpacity(0.05),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _EventRegistrationsCard extends StatelessWidget {
  const _EventRegistrationsCard({
    required this.events,
    required this.total,
  });

  final List<EventRegistrationStat> events;
  final int total;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Event Registrations',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _Palette.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _Palette.emerald.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$total total',
                  style: const TextStyle(
                    color: _Palette.emerald,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          if (events.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'No event registrations yet',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            ...events.map((event) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          '${event.registeredCount}/${event.seatCapacity}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _Palette.emerald,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: event.fillRate,
                        minHeight: 6,
                        backgroundColor: _Palette.emerald.withOpacity(0.12),
                        color: _Palette.emerald,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.84),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
