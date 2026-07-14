import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_registration_model.dart';

class EventRegistrationRepository {
  final SupabaseClient _client;

  EventRegistrationRepository(this._client);

  Future<void> registerForEvent(Map<String, dynamic> regData) async {
    await _client.from('event_registrations').upsert(
          regData,
          onConflict: 'event_id,user_id',
        );
  }

  Future<void> updateRegistrationStatus(String regId, String status) async {
    await _client.from('event_registrations').update({
      'registration_status': status,
    }).eq('id', regId);
  }

  Future<void> verifyPayment(String regId, String paymentStatus) async {
    await _client.from('event_registrations').update({
      'payment_status': paymentStatus,
      'registration_status': paymentStatus == 'verified' ? 'confirmed' : 'pending',
    }).eq('id', regId);
  }

  Future<void> checkInAttendee(String regId, String checkedInBy) async {
    await _client.from('event_registrations').update({
      'checked_in_at': DateTime.now().toIso8601String(),
      'checked_in_by': checkedInBy,
      'registration_status': 'attended',
    }).eq('id', regId);
  }

  Future<List<EventRegistrationModel>> getMyRegistrations(String userId) async {
    final response = await _client.from('event_registrations').select('''
      *,
      event:event_id(*)
    ''').eq('user_id', userId);

    final data = response as List<dynamic>;
    return data.map((json) => EventRegistrationModel.fromMap(json)).toList();
  }

  Future<List<EventRegistrationModel>> getEventRegistrants(
    String eventId, {
    String? search,
    int? semester,
    String? paymentStatus,
  }) async {
    var query = _client.from('event_registrations').select().eq('event_id', eventId);

    if (search != null && search.isNotEmpty) {
      query = query.ilike('full_name', '%$search%');
    }
    if (semester != null) {
      query = query.eq('semester', semester);
    }
    if (paymentStatus != null) {
      query = query.eq('payment_status', paymentStatus);
    }

    final response = await query.order('registered_at', ascending: false);
    final data = response as List<dynamic>;
    return data.map((json) => EventRegistrationModel.fromMap(json)).toList();
  }
}
