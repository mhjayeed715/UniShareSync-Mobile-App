import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/event_registration_model.dart';
import '../../data/repositories/event_registration_repository.dart';

class EventRegistrationNotifier extends StateNotifier<AsyncValue<void>> {
  EventRegistrationNotifier(this._client) : super(const AsyncValue.data(null)) {
    _repository = EventRegistrationRepository(_client);
  }

  final SupabaseClient _client;
  late final EventRegistrationRepository _repository;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<void> _sendPushNotification({
    required List<String> userIds,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _client.functions.invoke(
        'send-push-notification',
        body: {
          'userIds': userIds,
          'title': title,
          'body': body,
          'type': type,
          'data': data ?? {},
        },
      );
    } catch (e) {
      print('[PushNotification] Error sending push notification: $e');
    }
  }

  Future<void> registerForEvent(Map<String, dynamic> regData, {String? screenshotPath}) async {
    state = const AsyncValue.loading();
    try {
      final tempId = _generateRandomString(12);
      String? screenshotUrl;
      if (screenshotPath != null && regData['event_id'] != null) {
        screenshotUrl = await _uploadScreenshot(regData['event_id'].toString(), tempId, screenshotPath);
      }

      final payload = Map<String, dynamic>.from(regData);
      payload['user_id'] = _client.auth.currentUser!.id;
      if (screenshotUrl != null) {
        payload['payment_screenshot_url'] = screenshotUrl;
      }

      await _repository.registerForEvent(payload);
      state = const AsyncValue.data(null);

      // Async push notifications triggers
      try {
        final eventId = payload['event_id'];
        final isPaid = payload['payment_method'] != null;
        final studentId = _client.auth.currentUser!.id;
        final studentName = payload['full_name'];

        final eventResp = await _client.from('events').select('title, organizer_id').eq('id', eventId).single();
        final eventTitle = eventResp['title']?.toString() ?? 'Event';
        final organizerId = eventResp['organizer_id']?.toString();

        await _sendPushNotification(
          userIds: [studentId],
          title: isPaid ? 'Registration Pending' : 'Registration Confirmed',
          body: isPaid 
              ? 'Your registration for $eventTitle is pending payment verification.' 
              : 'You are successfully registered for $eventTitle!',
          type: 'event',
          data: {'event_id': eventId},
        );

        if (organizerId != null) {
          await _sendPushNotification(
            userIds: [organizerId],
            title: 'New Registration: $eventTitle',
            body: '$studentName has registered for your event.',
            type: 'event',
            data: {'event_id': eventId},
          );
        }
      } catch (e) {
        print('[PushNotification] Error resolving targets for registration push: $e');
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> joinWaitlist(String eventId, Map<String, dynamic> regData) async {
    state = const AsyncValue.loading();
    try {
      final waitlistCountResp = await _client.from('events').select('waitlist_count').eq('id', eventId).single();
      final waitlistPos = (waitlistCountResp['waitlist_count'] as int) + 1;

      final payload = Map<String, dynamic>.from(regData);
      payload['event_id'] = eventId;
      payload['user_id'] = _client.auth.currentUser!.id;
      payload['registration_status'] = 'waitlisted';
      payload['waitlist_position'] = waitlistPos;

      await _repository.registerForEvent(payload);
      state = const AsyncValue.data(null);

      // Async push notifications triggers
      try {
        final studentId = _client.auth.currentUser!.id;
        final studentName = payload['full_name'];

        final eventResp = await _client.from('events').select('title, organizer_id').eq('id', eventId).single();
        final eventTitle = eventResp['title']?.toString() ?? 'Event';
        final organizerId = eventResp['organizer_id']?.toString();

        await _sendPushNotification(
          userIds: [studentId],
          title: 'Waitlist Joined',
          body: 'You have joined the waitlist for $eventTitle (Position: #$waitlistPos).',
          type: 'event',
          data: {'event_id': eventId},
        );

        if (organizerId != null) {
          await _sendPushNotification(
            userIds: [organizerId],
            title: 'Waitlist Update: $eventTitle',
            body: '$studentName joined the waitlist (Position: #$waitlistPos).',
            type: 'event',
            data: {'event_id': eventId},
          );
        }
      } catch (e) {
        print('[PushNotification] Error resolving targets for waitlist push: $e');
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> cancelRegistration(String registrationId) async {
    state = const AsyncValue.loading();
    try {
      // Fetch details before cancelling
      final regData = await _client.from('event_registrations').select('user_id, event_id, full_name').eq('id', registrationId).single();
      final studentId = regData['user_id']?.toString();
      final eventId = regData['event_id']?.toString();
      final studentName = regData['full_name']?.toString() ?? 'A student';

      await _repository.updateRegistrationStatus(registrationId, 'cancelled');
      state = const AsyncValue.data(null);

      // Async push notifications triggers
      if (eventId != null && studentId != null) {
        try {
          final eventResp = await _client.from('events').select('title, organizer_id').eq('id', eventId).single();
          final eventTitle = eventResp['title']?.toString() ?? 'Event';
          final organizerId = eventResp['organizer_id']?.toString();

          await _sendPushNotification(
            userIds: [studentId],
            title: 'Registration Cancelled',
            body: 'You have cancelled your registration for $eventTitle.',
            type: 'event',
            data: {'event_id': eventId},
          );

          if (organizerId != null) {
            await _sendPushNotification(
              userIds: [organizerId],
              title: 'Registration Cancelled',
              body: '$studentName has cancelled their registration for $eventTitle.',
              type: 'event',
              data: {'event_id': eventId},
            );
          }
        } catch (e) {
          print('[PushNotification] Error resolving targets for cancel registration push: $e');
        }
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> verifyPayment(String registrationId, String paymentStatus, String? note) async {
    try {
      // Fetch details before verifying
      final regData = await _client.from('event_registrations').select('user_id, event_id').eq('id', registrationId).single();
      final studentId = regData['user_id']?.toString();
      final eventId = regData['event_id']?.toString();

      await _repository.verifyPayment(registrationId, paymentStatus);
      if (note != null && note.isNotEmpty) {
        // Optional: save note in db, if table has note field
      }

      // Async push notifications triggers
      if (eventId != null && studentId != null) {
        try {
          final eventResp = await _client.from('events').select('title').eq('id', eventId).single();
          final eventTitle = eventResp['title']?.toString() ?? 'Event';

          String notifTitle = '';
          String notifBody = '';
          if (paymentStatus == 'verified') {
            notifTitle = 'Payment Verified & Confirmed';
            notifBody = 'Your payment for $eventTitle has been verified! Registration is confirmed.';
          } else if (paymentStatus == 'rejected') {
            notifTitle = 'Payment Rejected';
            notifBody = 'Your payment for $eventTitle was rejected. Please check instructions or contact support.';
          }

          if (notifTitle.isNotEmpty) {
            await _sendPushNotification(
              userIds: [studentId],
              title: notifTitle,
              body: notifBody,
              type: 'event',
              data: {'event_id': eventId},
            );
          }
        } catch (e) {
          print('[PushNotification] Error resolving targets for verify payment push: $e');
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> checkInAttendee(String registrationId) async {
    try {
      final checkerId = _client.auth.currentUser!.id;
      await _repository.checkInAttendee(registrationId, checkerId);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<EventRegistrationModel>> fetchMyRegistrations() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    return _repository.getMyRegistrations(uid);
  }

  Future<List<EventRegistrationModel>> fetchEventRegistrants(String eventId, Map<String, dynamic> filters) async {
    return _repository.getEventRegistrants(
      eventId,
      search: filters['search']?.toString(),
      semester: filters['semester'] is int ? filters['semester'] as int : null,
      paymentStatus: filters['payment_status']?.toString(),
    );
  }

  Future<String> exportRegistrantsCSV(String eventId) async {
    final registrants = await fetchEventRegistrants(eventId, {});
    final csvData = StringBuffer();
    csvData.writeln('Full Name,Email,Phone,Semester,Student ID,Department,T-Shirt Size,Dietary,Payment Status,Registration Status');

    for (var reg in registrants) {
      csvData.writeln('${reg.fullName},${reg.email},${reg.phone},${reg.semester},${reg.studentFacultyId},${reg.department},${reg.tshirtSize ?? ""},${reg.dietaryPreference ?? ""},${reg.paymentStatus},${reg.registrationStatus}');
    }
    return csvData.toString();
  }

  Future<void> sendEventAnnouncement(String eventId, String title, String body) async {
    await _client.from('event_announcements').insert({
      'event_id': eventId,
      'sender_id': _client.auth.currentUser!.id,
      'title': title,
      'body': body
    });
  }

  Future<void> issueCertificate(String registrationId) async {
    await _client.functions.invoke('generate-event-certificate', body: {
      'registration_id': registrationId,
    });
  }

  Future<String> _uploadScreenshot(String eventId, String tempId, String path) async {
    final fileName = '${tempId}_payment.jpg';
    final fileBytes = await _client.storage.from('event-assets').upload(
      'registration-payments/$eventId/$fileName',
      _client.auth.currentUser!.id as dynamic
    );
    return _client.storage.from('event-assets').getPublicUrl(fileBytes);
  }

  String _generateRandomString(int len) {
    var r = Random();
    const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    return List.generate(len, (index) => chars[r.nextInt(chars.length)]).join();
  }
}

final eventRegistrationProvider = StateNotifierProvider<EventRegistrationNotifier, AsyncValue<void>>((ref) {
  return EventRegistrationNotifier(Supabase.instance.client);
});
