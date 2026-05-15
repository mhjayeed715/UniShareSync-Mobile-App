import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/data/models/event_model.dart';

class EventParticipant {
  final String userId;
  final String name;
  final String? avatarUrl;
  final DateTime registeredAt;

  EventParticipant({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.registeredAt,
  });
}

class EventsService {
  EventsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  // Fetch all events
  Future<List<EventModel>> fetchEvents() async {
    final response = await _client
        .from('events')
        .select()
        .order('date', ascending: true);

    final events = (response as List<dynamic>)
        .map((row) => EventModel.fromMap(Map<String, dynamic>.from(row)))
        .toList();

    return _applyRegistrationStatus(events);
  }

  // Search events
  Future<List<EventModel>> searchEvents({String? query}) async {
    var request = _client.from('events').select();

    if (query != null && query.trim().isNotEmpty) {
      final escaped = query.trim().replaceAll('%', r'\%');
      request = request.or(
        'title.ilike.%$escaped%,description.ilike.%$escaped%,organizer_club.ilike.%$escaped%',
      );
    }

    final response = await request.order('date', ascending: true);

    final events = (response as List<dynamic>)
        .map((row) => EventModel.fromMap(Map<String, dynamic>.from(row)))
        .toList();

    return _applyRegistrationStatus(events);
  }

  // Watch events with realtime
  Stream<List<EventModel>> watchEvents() {
    return _client
        .from('events')
        .stream(primaryKey: ['id'])
        .order('date', ascending: true)
        .map((data) => data
            .map((row) => EventModel.fromMap(Map<String, dynamic>.from(row)))
            .toList());
  }

  // Register for event
  Future<void> registerForEvent(String eventId) async {
    final isRegistered = await isUserRegistered(eventId);
    if (isRegistered) {
      throw Exception('You are already registered for this event');
    }
    
    await _client.rpc('register_for_event', params: {
      'p_event_id': eventId,
    });
  }

  // Unregister from event
  Future<void> unregisterFromEvent(String eventId) async {
    await _client.rpc('unregister_from_event', params: {
      'p_event_id': eventId,
    });
  }

  // Check if user is registered
  Future<bool> isUserRegistered(String eventId) async {
    final userId = currentUserId;
    if (userId == null) return false;

    final response = await _client
        .from('event_registrations')
        .select('id')
        .eq('event_id', eventId)
        .eq('user_id', userId)
        .maybeSingle();

    return response != null;
  }

  // Create event (Faculty/Admin only)
  Future<EventModel> createEvent({
    required String title,
    required String description,
    required DateTime date,
    required String time,
    required String venue,
    required String organizerClub,
    required int seatCapacity,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final profile = await _client
        .from('profiles')
        .select('full_name, avatar_url')
        .eq('id', user.id)
        .single();

    final payload = {
      'title': title.trim(),
      'description': description.trim(),
      'date': date.toIso8601String(),
      'time': time.trim(),
      'venue': venue.trim(),
      'organizer_club': organizerClub.trim(),
      'seat_capacity': seatCapacity,
      'created_by': user.id,
      'created_by_name': profile['full_name'] ?? 'Organizer',
      'created_by_avatar': profile['avatar_url'],
    };

    final inserted = await _client
        .from('events')
        .insert(payload)
        .select()
        .single();

    return EventModel.fromMap(Map<String, dynamic>.from(inserted));
  }

  // Update event
  Future<EventModel> updateEvent({
    required String eventId,
    required String title,
    required String description,
    required DateTime date,
    required String time,
    required String venue,
    required String organizerClub,
    required int seatCapacity,
  }) async {
    final payload = {
      'title': title.trim(),
      'description': description.trim(),
      'date': date.toIso8601String(),
      'time': time.trim(),
      'venue': venue.trim(),
      'organizer_club': organizerClub.trim(),
      'seat_capacity': seatCapacity,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final updated = await _client
        .from('events')
        .update(payload)
        .eq('id', eventId)
        .select()
        .single();

    return EventModel.fromMap(Map<String, dynamic>.from(updated));
  }

  // Update event status
  Future<void> updateEventStatus({
    required String eventId,
    required EventStatus status,
  }) async {
    await _client.from('events').update({
      'status': status.value,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', eventId);
  }

  // Delete event
  Future<void> deleteEvent(String eventId) async {
    await _client.from('events').delete().eq('id', eventId);
  }

  // Fetch event participants
  Future<List<EventParticipant>> fetchEventParticipants(String eventId) async {
    final response = await _client
        .from('event_registrations')
        .select('user_id, registered_at')
        .eq('event_id', eventId)
        .order('registered_at', ascending: false);

    final registrations = response as List<dynamic>;
    if (registrations.isEmpty) return [];

    final userIds = registrations.map((r) => r['user_id'].toString()).toList();
    final profiles = await _client
        .from('profiles')
        .select('id, full_name, avatar_url')
        .inFilter('id', userIds);

    final profileMap = <String, Map<String, dynamic>>{};
    for (final profile in profiles as List<dynamic>) {
      profileMap[profile['id'].toString()] = profile;
    }

    return registrations.map((reg) {
      final userId = reg['user_id'].toString();
      final profile = profileMap[userId];
      return EventParticipant(
        userId: userId,
        name: profile?['full_name'] ?? 'Unknown',
        avatarUrl: profile?['avatar_url'],
        registeredAt: DateTime.parse(reg['registered_at']),
      );
    }).toList();
  }

  // Remove participant from event
  Future<void> removeParticipant(String eventId, String userId) async {
    await _client
        .from('event_registrations')
        .delete()
        .eq('event_id', eventId)
        .eq('user_id', userId);

    await _client.rpc('decrement_event_registered_count', params: {
      'p_event_id': eventId,
    });
  }

  // Apply registration status to events
  Future<List<EventModel>> _applyRegistrationStatus(List<EventModel> events) async {
    final userId = currentUserId;
    if (userId == null || events.isEmpty) {
      return events;
    }

    final eventIds = events.map((e) => e.id).toList();
    final response = await _client
        .from('event_registrations')
        .select('event_id')
        .eq('user_id', userId)
        .inFilter('event_id', eventIds);

    final registeredEventIds = <String>{};
    for (final row in response as List<dynamic>) {
      final eventId = row['event_id']?.toString();
      if (eventId != null) {
        registeredEventIds.add(eventId);
      }
    }

    return events
        .map((event) => event.copyWith(
              isUserRegistered: registeredEventIds.contains(event.id),
            ))
        .toList();
  }
}
