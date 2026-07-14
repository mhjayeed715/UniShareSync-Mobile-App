import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/events/presentation/providers/events_provider.dart';
import '../events/presentation/screens/event_detail_screen.dart';
import '../events/presentation/screens/event_organizer_dashboard_screen.dart';

class AdminEventsScreen extends ConsumerStatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  ConsumerState<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends ConsumerState<AdminEventsScreen> {
  final _searchController = TextEditingController();
  EventFilters _filters = const EventFilters();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(eventsProvider.notifier).fetchEvents(filters: _filters, isRefresh: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _approveEvent(String eventId) async {
    try {
      await ref.read(eventsProvider.notifier).updateEventStatus(eventId, 'approved');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event approved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  void _rejectEvent(String eventId) async {
    try {
      await ref.read(eventsProvider.notifier).updateEventStatus(eventId, 'rejected');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event rejected')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Events'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                _filters = _filters.copyWith(searchQuery: val);
                ref.read(eventsProvider.notifier).fetchEvents(filters: _filters, isRefresh: true);
              },
              decoration: const InputDecoration(
                labelText: 'Search events...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (events) {
                if (events.isEmpty) {
                  return const Center(child: Text('No events found.'));
                }
                return ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, idx) {
                    final event = events[idx];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => EventDetailScreen(eventId: event.id),
                          ));
                        },
                        title: Text(event.title),
                        subtitle: Text('Status: ${event.status.toUpperCase()}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (event.status == 'pending_approval' || event.status == 'upcoming') ...[
                              IconButton(
                                icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.green),
                                onPressed: () => _approveEvent(event.id),
                                tooltip: 'Approve',
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                                onPressed: () => _rejectEvent(event.id),
                                tooltip: 'Reject',
                              ),
                            ],
                            IconButton(
                              icon: const Icon(Icons.dashboard_rounded, color: Color(0xFF4F9EFF)),
                              onPressed: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => EventOrganizerDashboardScreen(event: event),
                                ));
                              },
                              tooltip: 'Organizer Dashboard',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
