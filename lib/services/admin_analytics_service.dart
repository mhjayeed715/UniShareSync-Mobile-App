import 'package:supabase_flutter/supabase_flutter.dart';

class CourseDownloadStat {
  const CourseDownloadStat({
    required this.courseCode,
    required this.courseTitle,
    required this.totalDownloads,
    required this.resourceCount,
  });

  final String courseCode;
  final String courseTitle;
  final int totalDownloads;
  final int resourceCount;
}

class WeeklyActiveUsersPoint {
  const WeeklyActiveUsersPoint({
    required this.weekLabel,
    required this.activeUsers,
  });

  final String weekLabel;
  final int activeUsers;
}

class BusRouteTrafficStat {
  const BusRouteTrafficStat({
    required this.routeId,
    required this.routeName,
    required this.scheduledTrips,
    required this.liveSessions,
    required this.activityScore,
  });

  final String routeId;
  final String routeName;
  final int scheduledTrips;
  final int liveSessions;
  final int activityScore;
}

class EventRegistrationStat {
  const EventRegistrationStat({
    required this.eventId,
    required this.title,
    required this.registeredCount,
    required this.seatCapacity,
    required this.status,
  });

  final String eventId;
  final String title;
  final int registeredCount;
  final int seatCapacity;
  final String status;

  double get fillRate =>
      seatCapacity > 0 ? registeredCount / seatCapacity : 0;
}

class AdminAnalyticsSnapshot {
  const AdminAnalyticsSnapshot({
    required this.totalUsers,
    required this.activeUsers,
    required this.totalResources,
    required this.totalDownloads,
    required this.totalRegistrations,
    required this.topCourses,
    required this.weeklyActiveUsers,
    required this.busRouteTraffic,
    required this.topEvents,
    required this.fetchedAt,
    required this.totalCommunities,
    required this.totalNotices,
    required this.totalLostFound,
  });

  final int totalUsers;
  final int activeUsers;
  final int totalResources;
  final int totalDownloads;
  final int totalRegistrations;
  final List<CourseDownloadStat> topCourses;
  final List<WeeklyActiveUsersPoint> weeklyActiveUsers;
  final List<BusRouteTrafficStat> busRouteTraffic;
  final List<EventRegistrationStat> topEvents;
  final DateTime fetchedAt;
  final int totalCommunities;
  final int totalNotices;
  final int totalLostFound;

  static AdminAnalyticsSnapshot get empty => AdminAnalyticsSnapshot(
        totalUsers: 0,
        activeUsers: 0,
        totalResources: 0,
        totalDownloads: 0,
        totalRegistrations: 0,
        topCourses: const [],
        weeklyActiveUsers: const [],
        busRouteTraffic: const [],
        topEvents: const [],
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
        totalCommunities: 0,
        totalNotices: 0,
        totalLostFound: 0,
      );
}

class AdminAnalyticsService {
  AdminAnalyticsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const Map<String, String> _routeNames = {
    'route-azimpur': 'Azimpur',
    'route-savar': 'Savar',
    'route-gazipur': 'Gazipur',
    'route-mirpur': 'Mirpur-10',
    'route-rampura': 'Rampura',
  };

  static const Map<String, int> _routeScheduledTrips = {
    'route-azimpur': 2,
    'route-savar': 2,
    'route-gazipur': 6,
    'route-mirpur': 8,
    'route-rampura': 2,
  };

  Future<AdminAnalyticsSnapshot> fetchSnapshot() async {
    final results = await Future.wait([
      _fetchUserStats(),
      _fetchTopCourses(),
      _fetchWeeklyActiveUsers(),
      _fetchBusRouteTraffic(),
      _fetchEventStats(),
      _fetchResourceSummary(),
      _fetchTotalCommunities(),
      _fetchTotalNotices(),
      _fetchTotalLostFound(),
    ]);

    final userStats = results[0] as _UserStats;
    final topCourses = results[1] as List<CourseDownloadStat>;
    final weeklyActiveUsers = results[2] as List<WeeklyActiveUsersPoint>;
    final busRouteTraffic = results[3] as List<BusRouteTrafficStat>;
    final eventStats = results[4] as _EventStats;
    final resourceSummary = results[5] as _ResourceSummary;
    final totalCommunities = results[6] as int;
    final totalNotices = results[7] as int;
    final totalLostFound = results[8] as int;

    return AdminAnalyticsSnapshot(
      totalUsers: userStats.total,
      activeUsers: userStats.active,
      totalResources: resourceSummary.total,
      totalDownloads: resourceSummary.totalDownloads,
      totalRegistrations: eventStats.totalRegistrations,
      topCourses: topCourses,
      weeklyActiveUsers: weeklyActiveUsers,
      busRouteTraffic: busRouteTraffic,
      topEvents: eventStats.topEvents,
      fetchedAt: DateTime.now(),
      totalCommunities: totalCommunities,
      totalNotices: totalNotices,
      totalLostFound: totalLostFound,
    );
  }

  Future<_UserStats> _fetchUserStats() async {
    try {
      final rows = await _client
          .from('profiles')
          .select('is_active')
          .timeout(const Duration(seconds: 10));

      var active = 0;
      for (final row in rows) {
        if (row['is_active'] != false) active++;
      }

      return _UserStats(total: rows.length, active: active);
    } catch (_) {
      return const _UserStats();
    }
  }

  Future<_ResourceSummary> _fetchResourceSummary() async {
    try {
      final rows = await _client
          .from('resources')
          .select('total_downloads')
          .timeout(const Duration(seconds: 10));

      var totalDownloads = 0;
      for (final row in rows) {
        totalDownloads += _toInt(row['total_downloads']);
      }

      return _ResourceSummary(total: rows.length, totalDownloads: totalDownloads);
    } catch (_) {
      return const _ResourceSummary();
    }
  }

  Future<List<CourseDownloadStat>> _fetchTopCourses() async {
    try {
      final rows = await _client
          .from('resources')
          .select('course_code, total_downloads, approval_status')
          .timeout(const Duration(seconds: 10));

      final courseTitles = await _fetchCourseTitles();
      final aggregates = <String, _CourseAggregate>{};

      for (final row in rows) {
        final status =
            (row['approval_status']?.toString() ?? '').toLowerCase();
        if (status == 'rejected') continue;

        final code = (row['course_code']?.toString() ?? '').trim();
        if (code.isEmpty) continue;

        final downloads = _toInt(row['total_downloads']);
        final current = aggregates[code];
        aggregates[code] = _CourseAggregate(
          downloads: (current?.downloads ?? 0) + downloads,
          resourceCount: (current?.resourceCount ?? 0) + 1,
        );
      }

      final stats = aggregates.entries
          .map(
            (entry) => CourseDownloadStat(
              courseCode: entry.key,
              courseTitle: courseTitles[entry.key] ?? entry.key,
              totalDownloads: entry.value.downloads,
              resourceCount: entry.value.resourceCount,
            ),
          )
          .toList()
        ..sort((a, b) => b.totalDownloads.compareTo(a.totalDownloads));

      return stats.take(6).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, String>> _fetchCourseTitles() async {
    try {
      final rows = await _client
          .from('courses')
          .select('course_code, course_title')
          .timeout(const Duration(seconds: 8));

      return {
        for (final row in rows)
          (row['course_code']?.toString() ?? ''):
              (row['course_title']?.toString() ?? '').trim(),
      };
    } catch (_) {
      return const {};
    }
  }

  Future<int> _fetchTotalCommunities() async {
    try {
      final rows = await _client.from('communities').select('id').timeout(const Duration(seconds: 8));
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _fetchTotalNotices() async {
    try {
      final rows = await _client.from('notices').select('id').timeout(const Duration(seconds: 8));
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _fetchTotalLostFound() async {
    try {
      final rows = await _client.from('lost_found_reports').select('id').timeout(const Duration(seconds: 8));
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  Future<List<WeeklyActiveUsersPoint>> _fetchWeeklyActiveUsers() async {
    try {
      final now = DateTime.now();
      final weekLabels = <String>[];
      final weekRanges = <_WeekRange>[];

      for (var i = 6; i >= 0; i--) {
        final weekEnd = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: i * 7));
        final weekBegin = weekEnd.subtract(const Duration(days: 7));
        weekLabels.add(_formatWeekLabel(weekBegin));
        weekRanges.add(_WeekRange(start: weekBegin, end: weekEnd));
      }

      final profiles = await _client
          .from('profiles')
          .select('id, updated_at')
          .timeout(const Duration(seconds: 10));

      List<dynamic> registrations = const [];
      List<dynamic> resources = const [];

      try {
        registrations = await _client
            .from('event_registrations')
            .select('user_id, registered_at')
            .gte(
              'registered_at',
              weekRanges.first.start.toIso8601String(),
            )
            .timeout(const Duration(seconds: 10));
      } catch (_) {}

      try {
        resources = await _client
            .from('resources')
            .select('uploader_id, created_at')
            .gte('created_at', weekRanges.first.start.toIso8601String())
            .timeout(const Duration(seconds: 10));
      } catch (_) {}

      final points = <WeeklyActiveUsersPoint>[];

      for (var i = 0; i < weekRanges.length; i++) {
        final range = weekRanges[i];
        final activeIds = <String>{};

        for (final row in profiles) {
          final updatedAt = _parseDate(row['updated_at']);
          final id = row['id']?.toString();
          if (id != null &&
              updatedAt != null &&
              _isInRange(updatedAt, range)) {
            activeIds.add(id);
          }
        }

        for (final row in registrations) {
          final registeredAt = _parseDate(row['registered_at']);
          final userId = row['user_id']?.toString();
          if (userId != null &&
              registeredAt != null &&
              _isInRange(registeredAt, range)) {
            activeIds.add(userId);
          }
        }

        for (final row in resources) {
          final createdAt = _parseDate(row['created_at']);
          final uploaderId = row['uploader_id']?.toString();
          if (uploaderId != null &&
              createdAt != null &&
              _isInRange(createdAt, range)) {
            activeIds.add(uploaderId);
          }
        }

        points.add(
          WeeklyActiveUsersPoint(
            weekLabel: weekLabels[i],
            activeUsers: activeIds.length,
          ),
        );
      }

      return points;
    } catch (_) {
      return const [];
    }
  }

  Future<List<BusRouteTrafficStat>> _fetchBusRouteTraffic() async {
    final liveCounts = <String, int>{};

    try {
      final rows = await _client
          .from('bus_locations')
          .select('bus_id, updated_at')
          .timeout(const Duration(seconds: 8));

      for (final row in rows) {
        final busId = row['bus_id']?.toString() ?? '';
        if (busId.isEmpty) continue;
        liveCounts[busId] = (liveCounts[busId] ?? 0) + 1;
      }
    } catch (_) {}

    final stats = _routeNames.entries
        .map((entry) {
          final scheduled = _routeScheduledTrips[entry.key] ?? 0;
          final live = liveCounts[entry.key] ?? 0;
          return BusRouteTrafficStat(
            routeId: entry.key,
            routeName: entry.value,
            scheduledTrips: scheduled,
            liveSessions: live,
            activityScore: scheduled + (live * 4),
          );
        })
        .toList()
      ..sort((a, b) => b.activityScore.compareTo(a.activityScore));

    return stats;
  }

  Future<_EventStats> _fetchEventStats() async {
    try {
      final eventRows = await _client
          .from('events')
          .select('id, title, registered_count, seat_capacity, status')
          .timeout(const Duration(seconds: 10));

      var totalRegistrations = 0;
      final stats = <EventRegistrationStat>[];

      for (final row in eventRows) {
        final registered = _toInt(row['registered_count']);
        totalRegistrations += registered;

        stats.add(
          EventRegistrationStat(
            eventId: row['id']?.toString() ?? '',
            title: row['title']?.toString() ?? 'Untitled',
            registeredCount: registered,
            seatCapacity: _toInt(row['seat_capacity']),
            status: (row['status']?.toString() ?? 'upcoming').toLowerCase(),
          ),
        );
      }

      stats.sort((a, b) => b.registeredCount.compareTo(a.registeredCount));

      return _EventStats(
        totalRegistrations: totalRegistrations,
        topEvents: stats.take(4).toList(growable: false),
      );
    } catch (_) {
      return const _EventStats();
    }
  }

  bool _isInRange(DateTime value, _WeekRange range) {
    return value.isAfter(range.start) && !value.isAfter(range.end);
  }

  String _formatWeekLabel(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {}
    }
    return null;
  }
}

class _WeekRange {
  const _WeekRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

class _UserStats {
  const _UserStats({this.total = 0, this.active = 0});

  final int total;
  final int active;
}

class _ResourceSummary {
  const _ResourceSummary({this.total = 0, this.totalDownloads = 0});

  final int total;
  final int totalDownloads;
}

class _CourseAggregate {
  const _CourseAggregate({
    required this.downloads,
    required this.resourceCount,
  });

  final int downloads;
  final int resourceCount;
}

class _EventStats {
  const _EventStats({
    this.totalRegistrations = 0,
    this.topEvents = const [],
  });

  final int totalRegistrations;
  final List<EventRegistrationStat> topEvents;
}
