import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:unisharesync_mobile_app/data/models/event_model.dart';
import 'package:unisharesync_mobile_app/services/events_service.dart';
import 'package:unisharesync_mobile_app/features/events_clubs/create_event_dialog.dart';
import 'package:unisharesync_mobile_app/features/events_clubs/event_participants_screen.dart';

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen> {
  final EventsService _eventsService = EventsService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  List<EventModel> _events = [];
  EventStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final events = await _eventsService.searchEvents(
        query: _searchController.text.trim().isEmpty ? null : _searchController.text,
      );

      if (!mounted) return;

      // Apply status filter
      final filtered = _selectedStatus == null
          ? events
          : events.where((e) => e.status == _selectedStatus).toList();

      setState(() {
        _events = filtered;
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
      await _loadEvents();
      _showSnackBar('Event created successfully');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Failed to create event: $error');
    }
  }

  Future<void> _editEvent(EventModel event) async {
    final draft = await showDialog<EventDraft>(
      context: context,
      builder: (_) => CreateEventDialog(existingEvent: event),
    );

    if (draft == null) return;

    try {
      await _eventsService.updateEvent(
        eventId: event.id,
        title: draft.title,
        description: draft.description,
        date: draft.date,
        time: draft.time,
        venue: draft.venue,
        organizerClub: draft.organizerClub,
        seatCapacity: draft.seatCapacity,
      );
      if (!mounted) return;
      await _loadEvents();
      _showSnackBar('Event updated successfully');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Failed to update event: $error');
    }
  }

  Future<void> _updateEventStatus(EventModel event, EventStatus newStatus) async {
    try {
      await _eventsService.updateEventStatus(
        eventId: event.id,
        status: newStatus,
      );
      if (!mounted) return;
      await _loadEvents();
      _showSnackBar('Event status updated to ${newStatus.displayName}');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Failed to update status: $error');
    }
  }

  Future<void> _deleteEvent(EventModel event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _eventsService.deleteEvent(event.id);
      if (!mounted) return;
      await _loadEvents();
      _showSnackBar('Event deleted successfully');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Failed to delete event: $error');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
          'Manage Events',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
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
                  colors: [
                    Color(0xFFF8FBFF),
                    Color(0xFFEAF6FF),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _SearchField(
                        controller: _searchController,
                        onChanged: (_) => _loadEvents(),
                        onClear: () {
                          _searchController.clear();
                          _loadEvents();
                        },
                      ),
                      const SizedBox(height: 12),
                      _StatusFilter(
                        selectedStatus: _selectedStatus,
                        onChanged: (status) {
                          setState(() => _selectedStatus = status);
                          _loadEvents();
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                          ? _buildErrorState()
                          : _events.isEmpty
                              ? _buildEmptyState()
                              : _buildEventsList(),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createEvent,
        backgroundColor: const Color(0xFFFF6B9D),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildEventsList() {
    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        itemCount: _events.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final event = _events[index];
          return _EventCard(
            event: event,
            onEdit: () => _editEvent(event),
            onDelete: () => _deleteEvent(event),
            onStatusChange: (status) => _updateEventStatus(event, status),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
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
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.event_outlined, size: 48, color: Color(0xFF94A3B8)),
                const SizedBox(height: 12),
                const Text(
                  'No events found',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Create your first event',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
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
          const Icon(Icons.warning_amber_rounded, size: 46, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          const Text(
            'Unable to load events',
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
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loadEvents,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B9D),
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
            hintText: 'Search events',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: controller.text.isEmpty
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

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({
    required this.selectedStatus,
    required this.onChanged,
  });

  final EventStatus? selectedStatus;
  final ValueChanged<EventStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<EventStatus?>(
        value: selectedStatus,
        isExpanded: true,
        underline: const SizedBox(),
        hint: const Text('All statuses'),
        onChanged: onChanged,
        items: [
          const DropdownMenuItem(value: null, child: Text('All statuses')),
          ...EventStatus.values.map(
            (status) => DropdownMenuItem(
              value: status,
              child: Text(status.displayName),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
  });

  final EventModel event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<EventStatus> onStatusChange;

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
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'participants') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EventParticipantsScreen(event: event),
                            ),
                          );
                        } else if (value == 'edit') {
                          onEdit();
                        } else if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'participants',
                          child: Row(
                            children: [
                              Icon(Icons.people_outline, size: 18),
                              SizedBox(width: 8),
                              Text('Participants'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_rounded, size: 18, color: Color(0xFFEF4444)),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  event.organizerClub,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFFF6B9D),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${event.date.day}/${event.date.month}/${event.date.year}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      event.time,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.people_rounded, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${event.registeredCount}/${event.seatCapacity} registered',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'Status:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButton<EventStatus>(
                          value: event.status,
                          isExpanded: true,
                          underline: const SizedBox(),
                          isDense: true,
                          onChanged: (status) {
                            if (status != null) onStatusChange(status);
                          },
                          items: EventStatus.values.map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Text(
                                status.displayName,
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }).toList(),
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
    );
  }
}
