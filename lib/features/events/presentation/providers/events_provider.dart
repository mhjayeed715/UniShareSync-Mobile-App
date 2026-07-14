import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/event_model.dart';
import '../../data/repositories/events_repository.dart';

class EventFilters {
  final String? searchQuery;
  final String? eventType;
  final bool? isPaid;
  final DateTime? startDate;
  final DateTime? endDate;

  const EventFilters({
    this.searchQuery,
    this.eventType,
    this.isPaid,
    this.startDate,
    this.endDate,
  });

  EventFilters copyWith({
    String? searchQuery,
    String? eventType,
    bool? isPaid,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return EventFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      eventType: eventType ?? this.eventType,
      isPaid: isPaid ?? this.isPaid,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}

class EventsNotifier extends StateNotifier<AsyncValue<List<EventModel>>> {
  EventsNotifier(this._client) : super(const AsyncValue.loading()) {
    _repository = EventsRepository(_client);
  }

  final SupabaseClient _client;
  late final EventsRepository _repository;
  EventFilters _filters = const EventFilters();
  int _page = 0;
  static const int _pageSize = 15;
  bool _hasMore = true;
  final List<EventModel> _cachedEvents = [];

  Future<void> fetchEvents({required EventFilters filters, bool isRefresh = false}) async {
    if (isRefresh) {
      _page = 0;
      _hasMore = true;
      _cachedEvents.clear();
      state = const AsyncValue.loading();
    }

    if (!_hasMore) return;

    try {
      _filters = filters;
      final from = _page * _pageSize;
      final to = from + _pageSize - 1;

      final events = await _repository.getEvents(
        searchQuery: _filters.searchQuery,
        eventType: _filters.eventType,
        isPaid: _filters.isPaid,
        startDate: _filters.startDate,
        endDate: _filters.endDate,
        from: from,
        to: to,
      );

      if (events.length < _pageSize) {
        _hasMore = false;
      }

      _cachedEvents.addAll(events);
      _page++;

      state = AsyncValue.data(List.from(_cachedEvents));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<EventModel> fetchEventDetail(String eventId) async {
    return _repository.getEventDetail(eventId);
  }

  Future<void> createEvent(Map<String, dynamic> eventData, Uint8List? bannerBytes, String? bannerName) async {
    try {
      String? bannerUrl;
      if (bannerBytes != null && bannerName != null) {
        bannerUrl = await _uploadBanner(bannerBytes, bannerName);
      }
      
      final payload = Map<String, dynamic>.from(eventData);
      if (bannerUrl != null) {
        payload['banner_url'] = bannerUrl;
      }
      payload['organizer_id'] = _client.auth.currentUser!.id;

      await _repository.createEvent(payload);
      await fetchEvents(filters: _filters, isRefresh: true);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateEventStatus(String eventId, String status) async {
    try {
      await _repository.updateEventStatus(eventId, status);
      await fetchEvents(filters: _filters, isRefresh: true);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> cancelEvent(String eventId) async {
    try {
      await _repository.cancelEvent(eventId);
      await fetchEvents(filters: _filters, isRefresh: true);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateEvent(String eventId, Map<String, dynamic> eventData, Uint8List? bannerBytes, String? bannerName) async {
    try {
      String? bannerUrl;
      if (bannerBytes != null && bannerName != null) {
        bannerUrl = await _uploadBanner(bannerBytes, bannerName);
      }
      
      final payload = Map<String, dynamic>.from(eventData);
      if (bannerUrl != null) {
        payload['banner_url'] = bannerUrl;
      }

      await _repository.updateEvent(eventId, payload);
      await fetchEvents(filters: _filters, isRefresh: true);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteEvent(String eventId) async {
    try {
      await _repository.deleteEvent(eventId);
      await fetchEvents(filters: _filters, isRefresh: true);
    } catch (e) {
      rethrow;
    }
  }

  Future<String> _uploadBanner(Uint8List bytes, String fileName) async {
    final path = 'banners/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await _client.storage.from('event-assets').uploadBinary(path, bytes);
    return _client.storage.from('event-assets').getPublicUrl(path);
  }

  StreamSubscription? _seatSubscription;

  void subscribeToSeatCount(String eventId, void Function(int registeredCount) onUpdate) {
    _seatSubscription?.cancel();
    _seatSubscription = _client
        .from('events:id=eq.$eventId')
        .stream(primaryKey: ['id'])
        .listen((data) {
          if (data.isNotEmpty) {
            onUpdate(data.first['registered_count'] as int);
          }
        });
  }

  @override
  void dispose() {
    _seatSubscription?.cancel();
    super.dispose();
  }
}

final eventsProvider = StateNotifierProvider<EventsNotifier, AsyncValue<List<EventModel>>>((ref) {
  return EventsNotifier(Supabase.instance.client);
});
