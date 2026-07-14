class CommunityAnalyticsModel {
  const CommunityAnalyticsModel({
    required this.memberGrowth,
    required this.semesterDistribution,
    required this.topActiveMembers,
    required this.totalNotices,
    required this.totalEvents,
    required this.totalActivityPosts,
    required this.activityScore,
  });

  final List<AnalyticsGrowthPoint> memberGrowth;
  final Map<int, int> semesterDistribution; // semester -> memberCount
  final List<AnalyticsActiveMember> topActiveMembers;
  final int totalNotices;
  final int totalEvents;
  final int totalActivityPosts;
  final int activityScore;

  factory CommunityAnalyticsModel.compile({
    required List<dynamic> snapshots,
    required List<dynamic> semesterDistribution,
    required List<dynamic> activeReactions,
  }) {
    // 1. Parse growth snapshots
    final growthPoints = snapshots.map((s) {
      final date = DateTime.parse(s['recorded_at']?.toString() ?? DateTime.now().toIso8601String());
      final count = s['member_count'] is int ? s['member_count'] as int : 0;
      return AnalyticsGrowthPoint(date: date, count: count);
    }).toList();

    // 2. Parse semesters
    final semesterMap = <int, int>{};
    for (var sem in semesterDistribution) {
      final profile = sem['profiles'] as Map<String, dynamic>?;
      if (profile != null && profile['semester'] is int) {
        final num = profile['semester'] as int;
        semesterMap[num] = (semesterMap[num] ?? 0) + 1;
      }
    }

    // 3. Parse active members (grouped by user ID and reaction occurrences)
    final reactionCounts = <String, int>{};
    final userProfiles = <String, Map<String, String>>{};
    for (var react in activeReactions) {
      final userId = react['user_id']?.toString() ?? '';
      final profile = react['profile'] as Map<String, dynamic>?;
      if (userId.isNotEmpty) {
        reactionCounts[userId] = (reactionCounts[userId] ?? 0) + 1;
        if (profile != null) {
          userProfiles[userId] = {
            'name': profile['full_name']?.toString() ?? 'Member',
            'avatar': profile['avatar_url']?.toString() ?? '',
          };
        }
      }
    }

    final topMembers = reactionCounts.entries.map((entry) {
      final profile = userProfiles[entry.key];
      return AnalyticsActiveMember(
        userId: entry.key,
        name: profile?['name'] ?? 'Member',
        avatarUrl: profile?['avatar'],
        interactionCount: entry.value,
      );
    }).toList();
    topMembers.sort((a, b) => b.interactionCount.compareTo(a.interactionCount));

    // Get aggregated sums from latest snapshots if present
    int noticesSum = 0;
    int eventsSum = 0;
    int postsSum = 0;
    int score = 0;

    if (snapshots.isNotEmpty) {
      final latest = snapshots.last;
      noticesSum = latest['notices_posted'] is int ? latest['notices_posted'] as int : 0;
      eventsSum = latest['events_organized'] is int ? latest['events_organized'] as int : 0;
      postsSum = latest['activity_posts_count'] is int ? latest['activity_posts_count'] as int : 0;
      score = latest['activity_score'] is int ? latest['activity_score'] as int : 0;
    }

    return CommunityAnalyticsModel(
      memberGrowth: growthPoints,
      semesterDistribution: semesterMap,
      topActiveMembers: topMembers.take(5).toList(),
      totalNotices: noticesSum,
      totalEvents: eventsSum,
      totalActivityPosts: postsSum,
      activityScore: score,
    );
  }
}

class AnalyticsGrowthPoint {
  const AnalyticsGrowthPoint({required this.date, required this.count});
  final DateTime date;
  final int count;
}

class AnalyticsActiveMember {
  const AnalyticsActiveMember({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.interactionCount,
  });

  final String userId;
  final String name;
  final String? avatarUrl;
  final int interactionCount;
}
