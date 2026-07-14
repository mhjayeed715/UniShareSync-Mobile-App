import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/events_provider.dart';
import '../../data/models/event_model.dart';
import 'event_detail_screen.dart';
import 'event_create_screen.dart';
import 'package:unisharesync_mobile_app/services/auth_service.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';

class EventsBrowseScreen extends ConsumerStatefulWidget {
  const EventsBrowseScreen({super.key});

  @override
  ConsumerState<EventsBrowseScreen> createState() => _EventsBrowseScreenState();
}

class _EventsBrowseScreenState extends ConsumerState<EventsBrowseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  EventFilters _currentFilters = const EventFilters();

  UserRole? _userRole;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadUserRole();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(eventsProvider.notifier).fetchEvents(filters: _currentFilters, isRefresh: true);
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        ref.read(eventsProvider.notifier).fetchEvents(filters: _currentFilters);
      }
    });
  }

  void _loadUserRole() async {
    final role = await AuthService().getCurrentRole();
    if (mounted) {
      setState(() {
        _userRole = role;
      });
    }
  }

  void _onSearchChanged(String val) {
    _currentFilters = _currentFilters.copyWith(searchQuery: val);
    ref.read(eventsProvider.notifier).fetchEvents(filters: _currentFilters, isRefresh: true);
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Events',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('All Events'),
              onTap: () {
                _currentFilters = const EventFilters();
                ref.read(eventsProvider.notifier).fetchEvents(filters: _currentFilters, isRefresh: true);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Free Events Only'),
              onTap: () {
                _currentFilters = _currentFilters.copyWith(isPaid: false);
                ref.read(eventsProvider.notifier).fetchEvents(filters: _currentFilters, isRefresh: true);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Paid Events Only'),
              onTap: () {
                _currentFilters = _currentFilters.copyWith(isPaid: true);
                ref.read(eventsProvider.notifier).fetchEvents(filters: _currentFilters, isRefresh: true);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventsProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FBFF), Color(0xFFEAF6FF)],
          ),
        ),
        child: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              floating: false,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: innerBoxIsScrolled
                  ? const Text(
                      'Events & Seminars',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    )
                  : null,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Events & Seminars',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              decoration: const InputDecoration(
                                hintText: 'Search workshops, seminars...',
                                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          onPressed: _showFilterSheet,
                          icon: const Icon(Icons.tune_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.all(12),
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF4F9EFF),
                  labelColor: const Color(0xFF0F172A),
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                  tabs: const [
                    Tab(text: 'All'),
                    Tab(text: 'Workshops'),
                    Tab(text: 'Seminars'),
                    Tab(text: 'Hackathons'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: List.generate(4, (index) {
              return state.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
                data: (events) {
                  final filteredList = index == 0
                      ? events
                      : events.where((e) {
                          if (index == 1) return e.eventType == 'workshop';
                          if (index == 2) return e.eventType == 'seminar';
                          if (index == 3) return e.eventType == 'hackathon';
                          return true;
                        }).toList();

                  if (filteredList.isEmpty) {
                    return const Center(child: Text('No events found.'));
                  }

                  return RefreshIndicator(
                    onRefresh: () => ref.read(eventsProvider.notifier).fetchEvents(filters: _currentFilters, isRefresh: true),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredList.length,
                      itemBuilder: (context, idx) {
                        final event = filteredList[idx];
                        return _buildEventCard(context, event);
                      },
                    ),
                  );
                },
              );
            }),
          ),
        ),
      ),
      floatingActionButton: (_userRole == UserRole.faculty || _userRole == UserRole.admin)
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const EventCreateScreen(),
                ));
              },
              backgroundColor: const Color(0xFF4F9EFF),
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildEventCard(BuildContext context, EventModel event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.9)),
            ),
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => EventDetailScreen(eventId: event.id),
                ));
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Image.network(
                        event.bannerUrl ?? 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800',
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 160,
                          color: Colors.grey.shade300,
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_not_supported_rounded, size: 40, color: Colors.grey),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            event.isPaid ? '৳ ${event.entryFee}' : 'FREE',
                            style: TextStyle(
                              color: event.isPaid ? const Color(0xFF4F9EFF) : Colors.green,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            event.eventType.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat('EEE, dd MMM yyyy · hh:mm a').format(event.eventDate),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              event.isOnline ? 'Online Webinar' : event.venue,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${event.registeredCount} / ${event.seatCapacity} seats filled',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: event.registeredCount >= event.seatCapacity ? Colors.red : Colors.grey,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(event.status).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                event.status.replaceAll('_', ' ').toUpperCase(),
                                style: TextStyle(
                                  color: _getStatusColor(event.status),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'upcoming':
        return const Color(0xFF4F9EFF);
      case 'registration_open':
        return Colors.green;
      case 'registration_closed':
        return Colors.red;
      case 'ongoing':
        return Colors.amber;
      case 'completed':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFFF8FBFF),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
