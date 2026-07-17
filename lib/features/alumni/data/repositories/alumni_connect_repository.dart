import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/alumni_connect_request_model.dart';

class AlumniConnectRepository {
  AlumniConnectRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // ──────────────────────────────────────────────
  // Rate Limit Checks
  // ──────────────────────────────────────────────
  Future<void> checkConnectRateLimit({
    required String senderId,
    required String alumniId,
  }) async {
    final now = DateTime.now();

    // 1. Daily limit check (last 24 hours)
    final oneDayAgo = now.subtract(const Duration(hours: 24));
    final dailyResponse = await _client
        .from('alumni_connect_requests')
        .select('id')
        .eq('sender_id', senderId)
        .gte('sent_at', oneDayAgo.toIso8601String());
    
    final dailyCount = (dailyResponse as List).length;
    if (dailyCount >= 3) {
      throw StateError("You've reached your daily limit of 3 connect requests. Try again tomorrow.");
    }

    // 2. Weekly duplicate check to same alumni (last 7 days)
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final weeklyResponse = await _client
        .from('alumni_connect_requests')
        .select('id')
        .eq('sender_id', senderId)
        .eq('alumni_id', alumniId)
        .gte('sent_at', sevenDaysAgo.toIso8601String());
    
    if ((weeklyResponse as List).isNotEmpty) {
      throw StateError("You already sent a connect request to this alumni recently. Please wait before sending another.");
    }
  }

  // ──────────────────────────────────────────────
  // Send Connect Request Flow
  // ──────────────────────────────────────────────
  Future<void> sendConnectRequest({
    required String alumniId,
    required String message,
    required String senderName,
    required String senderEmail,
    int? senderSemester,
  }) async {
    final senderId = _client.auth.currentUser?.id;
    if (senderId == null) {
      throw StateError("You must be logged in to send a connect request.");
    }

    // 1. Double check rate limits before insert
    await checkConnectRateLimit(senderId: senderId, alumniId: alumniId);

    // 2. Insert into alumni_connect_requests table
    final response = await _client
        .from('alumni_connect_requests')
        .insert({
          'alumni_id': alumniId,
          'sender_id': senderId,
          'message': message,
          'sender_name': senderName,
          'sender_email': senderEmail,
          'sender_semester': senderSemester,
          'delivery_status': 'pending'
        })
        .select('id')
        .single();

    final requestId = response['id'] as String;

    // 3. Call send-connect-request-email Supabase Edge Function
    try {
      final FunctionResponse res = await _client.functions.invoke(
        'send-connect-request-email',
        body: {
          'alumni_id': alumniId,
          'sender_name': senderName,
          'sender_email': senderEmail,
          'sender_semester': senderSemester,
          'message': message,
          'request_id': requestId
        },
      );

      if (res.status != 200) {
        throw Exception("Edge function execution failed with status ${res.status}");
      }
    } catch (_) {
      // Supabase Edge Function call failures are handled gracefully; the database record stands.
      // We will set delivery_status to failed locally if function invocation throws.
      try {
        await _client
            .from('alumni_connect_requests')
            .update({'delivery_status': 'failed'})
            .eq('id', requestId);
      } catch (_) {}
      rethrow;
    }
  }

  // ──────────────────────────────────────────────
  // Fetch Connect Requests Logs (Admin)
  // ──────────────────────────────────────────────
  Future<List<AlumniConnectRequest>> fetchConnectRequestsLog() async {
    final response = await _client
        .from('alumni_connect_requests')
        .select()
        .order('sent_at', ascending: false);
    
    final rows = response as List;
    return rows.map((r) => AlumniConnectRequest.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  Future<void> deleteConnectRequest(String requestId) async {
    await _client
        .from('alumni_connect_requests')
        .delete()
        .eq('id', requestId);
  }

  Future<void> clearAllConnectRequests() async {
    await _client
        .from('alumni_connect_requests')
        .delete()
        .neq('id', '00000000-0000-0000-0000-000000000000');
  }
}
