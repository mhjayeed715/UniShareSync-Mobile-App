import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/community_analytics_provider.dart';

class CommunityAnalyticsScreen extends ConsumerStatefulWidget {
  final String communityId;

  const CommunityAnalyticsScreen({super.key, required this.communityId});

  @override
  ConsumerState<CommunityAnalyticsScreen> createState() => _CommunityAnalyticsScreenState();
}

class _CommunityAnalyticsScreenState extends ConsumerState<CommunityAnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(communityAnalyticsProvider.notifier).fetchAnalytics(widget.communityId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communityAnalyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Analytics'),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading stats: $err')),
        data: (analytics) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Activity Score Card
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Activity Score', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                            const SizedBox(height: 6),
                            Text('${analytics.activityScore} / 100', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green)),
                            const SizedBox(height: 4),
                            const Text('Calculated based on notices, posts, events & growth', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        const Spacer(),
                        const Icon(Icons.flash_on_rounded, size: 48, color: Colors.green),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text('Summary Metrics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildMetricCard('Events Organized', '${analytics.totalEvents}', Icons.event_available_rounded)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildMetricCard('Notices Posted', '${analytics.totalNotices}', Icons.campaign_rounded)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildMetricCard('Activity Feed Posts', '${analytics.totalActivityPosts}', Icons.rss_feed_rounded)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildMetricCard('Active Members Ratio', 'High', Icons.people_outline_rounded)),
                  ],
                ),
                const SizedBox(height: 24),

                const Text('Top Active Contributors', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (analytics.topActiveMembers.isEmpty)
                  const Text('No interactions recorded yet.', style: TextStyle(color: Colors.grey))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: analytics.topActiveMembers.length,
                    itemBuilder: (context, idx) {
                      final contributor = analytics.topActiveMembers[idx];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: contributor.avatarUrl != null ? NetworkImage(contributor.avatarUrl!) : null,
                        ),
                        title: Text(contributor.name),
                        trailing: Chip(
                          label: Text('${contributor.interactionCount} reactions'),
                        ),
                      );
                    },
                  )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(String title, String val, IconData icon) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF4F9EFF)),
            const SizedBox(height: 12),
            Text(val, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
