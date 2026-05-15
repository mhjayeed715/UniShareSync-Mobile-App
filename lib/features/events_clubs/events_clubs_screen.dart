import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:unisharesync_mobile_app/data/models/event_model.dart';
import 'package:unisharesync_mobile_app/data/models/club_model.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';
import 'package:unisharesync_mobile_app/services/auth_service.dart';
import 'package:unisharesync_mobile_app/services/events_service.dart';
import 'package:unisharesync_mobile_app/services/clubs_service.dart';
import 'package:unisharesync_mobile_app/features/events_clubs/create_event_dialog.dart';
import 'package:unisharesync_mobile_app/features/events_clubs/create_club_dialog.dart';
import 'package:unisharesync_mobile_app/features/events_clubs/event_detail_screen.dart';
import 'package:unisharesync_mobile_app/features/events_clubs/club_detail_screen.dart';
import 'package:unisharesync_mobile_app/features/events_clubs/club_management_screen.dart';
import 'package:unisharesync_mobile_app/features/events_clubs/faculty_events_management_screen.dart';

class EventsClubsScreen extends StatefulWidget {
  const EventsClubsScreen({super.key});

  @override
  State<EventsClubsScreen> createState() => _EventsClubsScreenState();
}

class _EventsClubsScreenState extends State<EventsClubsScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final EventsService _eventsService = EventsService();
  final ClubsService _clubsService = ClubsService();
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  UserRole? _role;
  String? _currentUserId;
  bool _isLoading = true;
  String? _errorMessage;

  List<EventModel> _events = [];
  List<ClubModel> _clubs = [];

  int _currentTabIndex = 0;

  bool get _canCreateEvent => _role == UserRole.faculty || _role == UserRole.admin;
  bool get _canCreateClub => _role == UserRole.faculty || _role == UserRole.admin;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentTabIndex = _tabController.index);
      }
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final role = await _authService.getCurrentRole();
      final userId = _authService.currentUserId;
      if (!mounted) return;

      setState(() {
        _role = role ?? UserRole.student;
        _currentUserId = userId;
      });

      await _loadData();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '$error';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final events = await _eventsService.fetchEvents();
      final clubs = await _clubsService.fetchClubs();

      if (!mounted) return;

      setState(() {
        _events = events;
        _clubs = clubs;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '$error';
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    // TODO: Implement debounced search
  }

  Future<void> _createEvent() async {
    final draft = await showDialog<EventDraft>(
      context: context,
      builder: (_) => const CreateEventDialog(),
    );

    if (draft == null) return;

    try {
      await _eventsService.createEvent(
        title: draft.title,
        description: draft.description,
        date: draft.date,
        time: draft.time,
        venue: draft.venue,
        organizerClub: draft.organizerClub,
        seatCapacity: draft.seatCapacity,
      );
      if (!mounted) return;
      await _loadData();
      _showSnackBar('Event created successfully');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Failed to create event: $error');
    }
  }

  Future<void> _createClub() async {
    final draft = await showDialog<ClubDraft>(
      context: context,
      builder: (_) => const CreateClubDialog(),
    );

    if (draft == null) return;

    try {
      await _clubsService.createClub(
        name: draft.name,
        description: draft.description,
        category: draft.category,
      );
      if (!mounted) return;
      await _loadData();
      _showSnackBar('Club created successfully');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Failed to create club: $error');
    }
  }

  Future<void> _registerForEvent(EventModel event) async {
    try {
      await _eventsService.registerForEvent(event.id);
      if (!mounted) return;
      await _loadData();
      _showSnackBar('Successfully registered for ${event.title}');
    } catch (error) {
      if (!mounted) return;
      final errorMsg = error.toString();
      if (errorMsg.contains('already registered')) {
        _showSnackBar('You are already registered for this event');
      } else {
        _showSnackBar('Failed to register: $error');
      }
    }
  }

  Future<void> _requestJoinClub(ClubModel club) async {
    try {
      await _clubsService.requestJoinClub(club.id);
      if (!mounted) return;
      
      // Force reload to update status
      setState(() {
        _isLoading = true;
      });
      await _loadData();
      
      _showSnackBar('Join request sent for ${club.name}');
    } catch (error) {
      if (!mounted) return;
      final errorMsg = error.toString();
      if (errorMsg.contains('already requested')) {
        _showSnackBar('You have already requested to join this club');
      } else if (errorMsg.contains('already a member')) {
        _showSnackBar('You are already a member of this club');
      } else {
        _showSnackBar('Failed to send request: $error');
      }
    }
  }

  Future<void> _leaveClub(ClubModel club) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Club'),
        content: Text('Are you sure you want to leave ${club.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Leave',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _clubsService.leaveClub(club.id);
      if (!mounted) return;
      
      // Force reload to update status
      setState(() {
        _isLoading = true;
      });
      await _loadData();
      
      _showSnackBar('You have left ${club.name}');
    } catch (error) {
      if (!mounted) return;
      final errorMsg = error.toString();
      if (errorMsg.contains('owner cannot leave')) {
        _showSnackBar('Club owner cannot leave the club');
      } else {
        _showSnackBar('Failed to leave club: $error');
      }
    }
  }

  void _onCreatePressed() {
    if (_currentTabIndex == 0 && _canCreateEvent) {
      _createEvent();
    } else if (_currentTabIndex == 1 && _canCreateClub) {
      _createClub();
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _events.isEmpty && _clubs.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F8FF),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Events & Clubs',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
        ),
        centerTitle: false,
        actions: [
          if (_canCreateClub)
            PopupMenuButton<String>(
              icon: const Icon(Icons.manage_accounts_rounded),
              tooltip: 'Manage',
              onSelected: (value) {
                if (value == 'events') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FacultyEventsManagementScreen(),
                    ),
                  ).then((_) => _loadData());
                } else if (value == 'clubs') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ClubManagementScreen(),
                    ),
                  ).then((_) => _loadData());
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'events',
                  child: Row(
                    children: [
                      Icon(Icons.event_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('My Events'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clubs',
                  child: Row(
                    children: [
                      Icon(Icons.groups_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('My Clubs'),
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
                  colors: [
                    Color(0xFFF8FBFF),
                    Color(0xFFEAF6FF),
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
                color: const Color(0xFFFF6B9D).withOpacity(0.12),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: _buildDescriptionCard(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _SearchField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onClear: () {
                      _searchController.clear();
                      _loadData();
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Material(
                          color: Colors.transparent,
                          child: TabBar(
                            controller: _tabController,
                            indicatorColor: const Color(0xFFFF6B9D),
                            unselectedLabelColor: const Color(0xFF94A3B8),
                            labelColor: const Color(0xFF0F172A),
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            tabs: const [
                              Tab(text: 'Events'),
                              Tab(text: 'Clubs'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildEventsTab(),
                            _buildClubsTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: (_canCreateEvent || _canCreateClub)
          ? FloatingActionButton(
              onPressed: _onCreatePressed,
              backgroundColor: const Color(0xFFFF6B9D),
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            )
          : null,
    );
  }

  Widget _buildDescriptionCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Campus Events & Clubs',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Discover events, join clubs, and connect with your campus community.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventsTab() {
    if (_isLoading && _events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _events.isEmpty) {
      return _buildErrorState();
    }

    if (_events.isEmpty) {
      return _buildEmptyState(
        title: 'No events available',
        subtitle: 'Check back later for upcoming campus events.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _events.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final event = _events[index];
          final isCreator = event.createdBy == _currentUserId;
          final canRegister = _role == UserRole.student && event.canRegister;
          return _EventCard(
            event: event,
            isCreator: isCreator,
            canRegister: canRegister,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EventDetailScreen(event: event),
                ),
              );
            },
            onRegister: () => _registerForEvent(event),
          );
        },
      ),
    );
  }

  Widget _buildClubsTab() {
    if (_isLoading && _clubs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _clubs.isEmpty) {
      return _buildErrorState();
    }

    if (_clubs.isEmpty) {
      return _buildEmptyState(
        title: 'No clubs available',
        subtitle: 'Be the first to create a club!',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _clubs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final club = _clubs[index];
          final isOwner = club.ownerId == _currentUserId;
          final canJoin = _role == UserRole.student;
          return _ClubCard(
            club: club,
            isOwner: isOwner,
            canJoin: canJoin,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClubDetailScreen(club: club),
                ),
              );
            },
            onJoin: () => _requestJoinClub(club),
            onLeave: () => _leaveClub(club),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({required String title, required String subtitle}) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.78),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.95)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.event_outlined,
                  size: 48,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 46,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 12),
          const Text(
            'Unable to load data',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? 'An error occurred',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loadData,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B9D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'Search events or clubs',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: controller.text.trim().isEmpty
                ? null
                : IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.83),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.94)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.94)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFFF6B9D), width: 1.2),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.isCreator,
    required this.canRegister,
    required this.onTap,
    required this.onRegister,
  });

  final EventModel event;
  final bool isCreator;
  final bool canRegister;
  final VoidCallback onTap;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                event.organizerClub,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFFF6B9D),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(status: event.status),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      event.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${event.date.day}/${event.date.month}/${event.date.year}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          event.time,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.venue,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${event.availableSeats} / ${event.seatCapacity} seats available',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: event.registeredCount / event.seatCapacity,
                                  minHeight: 4,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFFFF6B9D),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isCreator)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFF10B981).withOpacity(0.35),
                              ),
                            ),
                            child: const Text(
                              'Organizer',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          )
                        else if (event.isUserRegistered)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFF10B981).withOpacity(0.35),
                              ),
                            ),
                            child: const Text(
                              'Registered',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          )
                        else if (canRegister)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onRegister,
                              borderRadius: BorderRadius.circular(8),
                              child: Ink(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B9D),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Register',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else if (event.isFull)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withOpacity(0.35),
                              ),
                            ),
                            child: const Text(
                              'Full',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClubCard extends StatelessWidget {
  const _ClubCard({
    required this.club,
    required this.isOwner,
    required this.canJoin,
    required this.onTap,
    required this.onJoin,
    required this.onLeave,
  });

  final ClubModel club;
  final bool isOwner;
  final bool canJoin;
  final VoidCallback onTap;
  final VoidCallback onJoin;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B9D).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: club.logoUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    club.logoUrl!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    club.name.isNotEmpty ? club.name[0].toUpperCase() : 'C',
                                    style: const TextStyle(
                                      color: Color(0xFFFF6B9D),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                club.name,
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
                                club.category,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFFF6B9D),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isOwner)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFF10B981).withOpacity(0.35),
                              ),
                            ),
                            child: const Text(
                              'Owner',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          )
                        else if (club.isUserMember)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0xFF10B981).withOpacity(0.35),
                                  ),
                                ),
                                child: const Text(
                                  'Joined',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: onLeave,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Ink(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFEF4444).withOpacity(0.35),
                                      ),
                                    ),
                                    child: const Text(
                                      'Leave',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFEF4444),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else if (club.hasRequestPending)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withOpacity(0.35),
                              ),
                            ),
                            child: const Text(
                              'Pending',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                          )
                        else if (club.wasRequestRejected)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onJoin,
                              borderRadius: BorderRadius.circular(8),
                              child: Ink(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFEF4444).withOpacity(0.35),
                                  ),
                                ),
                                child: const Text(
                                  'Rejected · Retry',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else if (canJoin)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onJoin,
                              borderRadius: BorderRadius.circular(8),
                              child: Ink(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B9D),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Join',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      club.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.people_rounded, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${club.memberCount} members',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: const Color(0xFFFF6B9D).withOpacity(0.15),
                          backgroundImage: club.ownerAvatar != null
                              ? NetworkImage(club.ownerAvatar!)
                              : null,
                          child: club.ownerAvatar == null
                              ? Text(
                                  club.ownerName.isNotEmpty
                                      ? club.ownerName[0].toUpperCase()
                                      : 'O',
                                  style: const TextStyle(
                                    color: Color(0xFFFF6B9D),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          club.ownerName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final EventStatus status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case EventStatus.upcoming:
        color = const Color(0xFF10B981);
        break;
      case EventStatus.ongoing:
        color = const Color(0xFF4F9EFF);
        break;
      case EventStatus.completed:
        color = const Color(0xFF94A3B8);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
