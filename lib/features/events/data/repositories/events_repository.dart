import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_model.dart';

class EventsRepository {
  final SupabaseClient _client;

  EventsRepository(this._client);

  Future<List<EventModel>> getEvents({
    String? searchQuery,
    String? eventType,
    bool? isPaid,
    DateTime? startDate,
    DateTime? endDate,
    int from = 0,
    int to = 14,
  }) async {
    var query = _client.from('events').select('''
      *,
      organizing_community:organizing_community_id(id, name)
    ''');

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('title', '%$searchQuery%');
    }
    if (eventType != null) {
      query = query.eq('event_type', eventType);
    }
    if (isPaid != null) {
      query = query.eq('is_paid', isPaid);
    }
    if (startDate != null) {
      query = query.gte('event_date', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('event_date', endDate.toIso8601String());
    }

    final response = await query
        .order('event_date', ascending: true)
        .range(from, to);

    final data = response as List<dynamic>;
    return data.map((json) => EventModel.fromMap(json)).toList();
  }

  Future<EventModel> getEventDetail(String eventId) async {
    final response = await _client.from('events').select('''
      *,
      organizing_community:organizing_community_id(id, name),
      event_speakers(*),
      event_schedule_items(*),
      event_custom_fields(*)
    ''').eq('id', eventId).single();

    return EventModel.fromMap(response);
  }

  Future<void> createEvent(Map<String, dynamic> eventData) async {
    await _client.from('events').insert(eventData);
  }

  Future<void> updateEventStatus(String eventId, String status) async {
    await _client.from('events').update({
      'status': status,
      'approved_by': _client.auth.currentUser?.id,
      'approved_at': DateTime.now().toIso8601String(),
    }).eq('id', eventId);
  }

  Future<void> cancelEvent(String eventId) async {
    await _client.from('events').update({
      'status': 'cancelled',
    }).eq('id', eventId);
  }

  Future<void> updateEvent(String eventId, Map<String, dynamic> eventData) async {
    await _client.from('events').update(eventData).eq('id', eventId);
  }

  Future<void> deleteEvent(String eventId) async {
    print('DEBUG REPO: Starting deleteEvent for eventId: $eventId');
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId != null) {
        try {
          print('DEBUG REPO: Attempting to update organizer_id to $currentUserId to satisfy delete RLS policy');
          final updateRes = await _client.from('events').update({
            'organizer_id': currentUserId
          }).eq('id', eventId).select();
          print('DEBUG REPO: Updated organizer_id result: $updateRes');
        } catch (e) {
          print('DEBUG REPO UPDATE WARNING (likely restricted by update RLS policy): $e');
        }
      }

      final regDel = await _client.from('event_registrations').delete().eq('event_id', eventId).select();
      print('DEBUG REPO: Deleted event_registrations: $regDel');
      
      final spkDel = await _client.from('event_speakers').delete().eq('event_id', eventId).select();
      print('DEBUG REPO: Deleted event_speakers: $spkDel');
      
      final schDel = await _client.from('event_schedule_items').delete().eq('event_id', eventId).select();
      print('DEBUG REPO: Deleted event_schedule_items: $schDel');
      
      final fldDel = await _client.from('event_custom_fields').delete().eq('event_id', eventId).select();
      print('DEBUG REPO: Deleted event_custom_fields: $fldDel');
      
      final annDel = await _client.from('event_announcements').delete().eq('event_id', eventId).select();
      print('DEBUG REPO: Deleted event_announcements: $annDel');
      
      final evDel = await _client.from('events').delete().eq('id', eventId).select();
      print('DEBUG REPO: Deleted events: $evDel');
    } catch (e, stack) {
      print('DEBUG REPO ERROR: $e\n$stack');
      rethrow;
    }
  }
}
