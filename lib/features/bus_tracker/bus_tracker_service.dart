import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'bus_tracker_models.dart';

class BusTrackerService {
  BusTrackerService._();
  static final BusTrackerService instance = BusTrackerService._();

  static const String _timetableBoxName = 'bus_timetable';
  static const String _table = 'bus_locations';

  // Must match the interval in the Postgres trigger/cron (25 s)
  static const int staleSeconds = 25;

  final _supabase = Supabase.instance.client;

  // ── Timetable ─────────────────────────────────────────────────────────────

  Future<void> initTimetable() async {
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(TimetableEntryAdapter());
    }
    final Box<TimetableEntry> box;
    if (Hive.isBoxOpen(_timetableBoxName)) {
      box = Hive.box<TimetableEntry>(_timetableBoxName);
    } else {
      box = await Hive.openBox<TimetableEntry>(_timetableBoxName);
    }
    if (box.isEmpty) await box.addAll(kTimetableSeed);
  }

  List<TimetableEntry> getTimetable() {
    if (!Hive.isBoxOpen(_timetableBoxName)) return kTimetableSeed;
    final box = Hive.box<TimetableEntry>(_timetableBoxName);
    return box.isEmpty ? kTimetableSeed : box.values.toList();
  }

  // ── ETA ───────────────────────────────────────────────────────────────────

  int estimateMinutes(LatLng busPos, LatLng stopPos) {
    const dist = Distance();
    final meters = dist(busPos, stopPos);
    return ((meters / 1000) / 30 * 60).round().clamp(0, 999);
  }

  // ── Live locations ────────────────────────────────────────────────────────

  Stream<Map<String, BusLocation>> watchLocations() {
    final controller = StreamController<Map<String, BusLocation>>.broadcast();
    final cache = <String, BusLocation>{};
    final channelName =
        'bus-locations-${DateTime.now().millisecondsSinceEpoch}';

    bool isFresh(BusLocation loc) =>
        DateTime.now().toUtc().difference(loc.updatedAt).inSeconds <
        staleSeconds;

    void emit() {
      // Always prune before emitting — belt-and-suspenders
      cache.removeWhere((_, loc) => !isFresh(loc));
      if (!controller.isClosed) controller.add(Map.from(cache));
    }

    Future<void> fetchAll() async {
      try {
        final cutoff = DateTime.now()
            .toUtc()
            .subtract(const Duration(seconds: staleSeconds))
            .toIso8601String();
        final rows = await _supabase
            .from(_table)
            .select(
              'bus_id,driver_id,broadcaster_name,session_token,latitude,longitude,heading,speed,updated_at',
            )
            .gte('updated_at', cutoff) as List<dynamic>;
        cache.clear();
        for (final r in rows) {
          final loc = BusLocation.fromMap(r as Map<String, dynamic>);
          cache[loc.busId] = loc;
        }
      } catch (e) {
        // ignore fetch errors — emit whatever is cached
      }
      emit();
    }

    fetchAll();

    // Prune every 5 s in case realtime misses a delete event
    final pruneTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => emit());

    final channel = _supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _table,
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.delete) {
              final busId = payload.oldRecord['bus_id'] as String?;
              if (busId != null) {
                cache.remove(busId);
              } else {
                fetchAll();
                return;
              }
              emit();
              return;
            }
            final record = payload.newRecord;
            if (record.isNotEmpty) {
              final loc = BusLocation.fromMap(record);
              if (isFresh(loc)) {
                cache[loc.busId] = loc;
              } else {
                cache.remove(loc.busId);
              }
              emit();
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      pruneTimer.cancel();
      _supabase.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  // ── Ownership ─────────────────────────────────────────────────────────────

  String get _ownerToken =>
      _supabase.auth.currentUser?.id ?? _localOwnerToken;

  static final String _localOwnerToken =
      'local-${DateTime.now().millisecondsSinceEpoch}';

  // ── Claim check ───────────────────────────────────────────────────────────

  Future<BusLocation?> _getExistingRow(String busId) async {
    try {
      final rows = await _supabase
          .from(_table)
          .select()
          .eq('bus_id', busId)
          .limit(1) as List<dynamic>;
      if (rows.isEmpty) return null;
      return BusLocation.fromMap(rows.first as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ── Broadcasting ──────────────────────────────────────────────────────────

  Timer? _broadcastTimer;
  String? _activeBusId;
  bool get isBroadcasting => _broadcastTimer != null;
  String? get activeBusId => _activeBusId;

  Future<String?> startBroadcasting(
      String busId, String broadcasterName) async {
    final existing = await _getExistingRow(busId);

    if (existing != null) {
      final isStale = !DateTime.now()
          .toUtc()
          .difference(existing.updatedAt)
          .inSeconds
          .let((s) => s < staleSeconds);
      final isMine = existing.sessionToken == _ownerToken;

      if (!isStale && !isMine) {
        return '${existing.broadcasterName ?? 'Someone'} is already sharing this bus live.';
      }
      // Stale or ours — force delete before claiming
      await _deleteRow(busId);
    }

    _activeBusId = busId;
    final firstError = await _broadcastOnce(busId, broadcasterName);
    if (firstError != null) {
      _activeBusId = null;
      return firstError;
    }
    _broadcastTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _broadcastOnce(busId, broadcasterName);
    });
    return null;
  }

  Future<void> stopBroadcasting() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    final busId = _activeBusId;
    _activeBusId = null;
    if (busId == null) return;
    await _deleteRow(busId);
  }

  Future<void> _deleteRow(String busId) async {
    for (var i = 0; i < 3; i++) {
      try {
        await _supabase.from(_table).delete().eq('bus_id', busId);
        return;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 400));
      }
    }
    // All retries failed — backdate so trigger/cron evicts it on next DB write
    try {
      await _supabase.from(_table).update({
        'updated_at': '2000-01-01T00:00:00.000Z',
      }).eq('bus_id', busId);
    } catch (_) {}
  }

  Future<String?> _broadcastOnce(String busId, String broadcasterName) async {
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );
    } catch (_) {
      pos = await Geolocator.getLastKnownPosition();
    }
    if (pos == null) return 'Could not get GPS location. Please try again.';
    try {
      await _supabase.from(_table).upsert(
        {
          'bus_id': busId,
          'driver_id': _supabase.auth.currentUser?.id,
          'broadcaster_name': broadcasterName,
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'heading': pos.heading,
          'speed': pos.speed,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'bus_id',
      );
      return null;
    } catch (e) {
      return 'Failed to share location: $e';
    }
  }

  // ── Permission ────────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }
}

extension _IntLet on int {
  T let<T>(T Function(int) f) => f(this);
}
