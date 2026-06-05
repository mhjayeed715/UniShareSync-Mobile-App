import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/features/scheduler/schedule_models.dart';

class ScheduleService {
  ScheduleService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Stream<List<ScheduleEntry>> watchEntries() {
    return _client
        .from('routines')
        .stream(primaryKey: const ['id'])
        .order('day', ascending: true)
        .order('start_minutes', ascending: true)
        .map(
          (rows) => rows
              .map((row) => ScheduleEntry.fromSupabaseMap(
                    Map<String, dynamic>.from(row),
                  ))
              .toList(growable: false),
        );
  }

  Future<List<ScheduleEntry>> fetchEntries() async {
    final response = await _client
        .from('routines')
        .select()
        .order('day', ascending: true)
        .order('start_minutes', ascending: true);

    return (response as List<dynamic>)
        .map((row) =>
            ScheduleEntry.fromSupabaseMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<ScheduleEntry> createEntry(ScheduleEntry entry) async {
    final payload = entry.toSupabasePayload();
    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      payload['created_by'] = userId;
    }

    final inserted = await _client
        .from('routines')
        .insert(payload)
        .select()
        .single();

    return ScheduleEntry.fromSupabaseMap(
      Map<String, dynamic>.from(inserted),
    );
  }

  Future<ScheduleEntry> updateEntry(ScheduleEntry entry) async {
    if (entry.id == null) {
      throw StateError('Schedule entry id is required for update.');
    }

    final payload = entry.toSupabasePayload();
    payload['updated_at'] = DateTime.now().toIso8601String();

    final updated = await _client
        .from('routines')
        .update(payload)
        .eq('id', entry.id as Object)
        .select()
        .single();

    return ScheduleEntry.fromSupabaseMap(
      Map<String, dynamic>.from(updated),
    );
  }

  Future<void> deleteEntry(String id) async {
    await _client.from('routines').delete().eq('id', id);
  }

  Future<void> replaceSchedule(List<ScheduleEntry> entries) async {
    await _client
        .from('routines')
        .delete()
        .neq('id', '00000000-0000-0000-0000-000000000000');

    if (entries.isEmpty) {
      return;
    }

    final payload = entries
        .map((entry) => entry.toSupabasePayload())
        .toList(growable: false);

    const chunkSize = 300;
    for (var i = 0; i < payload.length; i += chunkSize) {
      final chunk = payload.sublist(
        i,
        i + chunkSize > payload.length ? payload.length : i + chunkSize,
      );
      await _client.from('routines').insert(chunk);
    }
  }
}
