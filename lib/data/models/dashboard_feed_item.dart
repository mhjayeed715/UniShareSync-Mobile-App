class DashboardFeedItem {
  const DashboardFeedItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.category,
    this.createdAt,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? category;
  final DateTime? createdAt;

  factory DashboardFeedItem.fromResourceMap(Map<String, dynamic> map) {
    final title = _readString(
      map,
      const ['title', 'name', 'resource_title', 'file_name'],
      fallback: 'Untitled resource',
    );

    return DashboardFeedItem(
      id: _readId(map, fallbackTitle: title),
      title: title,
      subtitle: _readNullableString(
        map,
        const ['description', 'summary', 'department', 'course', 'file_url'],
      ),
      category:
          _readNullableString(map, const ['category', 'type', 'department']),
      createdAt: _readDateTime(
        map,
        const ['created_at', 'published_at', 'uploaded_at', 'updated_at'],
      ),
    );
  }

  factory DashboardFeedItem.fromNoticeMap(Map<String, dynamic> map) {
    final title = _readString(
      map,
      const ['title', 'headline', 'subject', 'name'],
      fallback: 'Untitled notice',
    );

    return DashboardFeedItem(
      id: _readId(map, fallbackTitle: title),
      title: title,
      subtitle: _readNullableString(
        map,
        const ['content', 'body', 'description', 'summary'],
      ),
      category:
          _readNullableString(map, const ['category', 'type', 'notice_type']),
      createdAt: _readDateTime(
        map,
        const ['created_at', 'published_at', 'updated_at'],
      ),
    );
  }

  factory DashboardFeedItem.fromRoutineMap(Map<String, dynamic> map) {
    final title = _readString(
      map,
      const ['title', 'course_name', 'subject', 'name'],
      fallback: 'Routine item',
    );

    final room = _readNullableString(map, const ['room', 'location', 'venue']);
    final day = _readNullableString(map, const ['day', 'weekday']);
    final startTime = _readNullableString(map, const ['start_time', 'start']);
    final endTime = _readNullableString(map, const ['end_time', 'end']);

    final details = [
      day,
      if (startTime != null || endTime != null)
        '${startTime ?? '--'} - ${endTime ?? '--'}',
      room,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' • ');

    return DashboardFeedItem(
      id: _readId(map, fallbackTitle: title),
      title: title,
      subtitle: details.isEmpty
          ? _readNullableString(map, const ['description', 'details'])
          : details,
      category:
          _readNullableString(map, const ['section', 'semester', 'category']),
      createdAt: _readDateTime(
        map,
        const ['created_at', 'updated_at', 'published_at'],
      ),
    );
  }

  static String _readId(
    Map<String, dynamic> map, {
    required String fallbackTitle,
  }) {
    final explicit = _readNullableString(
        map, const ['id', 'uuid', 'resource_id', 'notice_id']);
    if (explicit != null) {
      return explicit;
    }

    final createdAt = _readDateTime(
      map,
      const ['created_at', 'published_at', 'uploaded_at', 'updated_at'],
    );

    return '$fallbackTitle-${createdAt?.toIso8601String() ?? DateTime.now().microsecondsSinceEpoch}';
  }

  static String _readString(
    Map<String, dynamic> map,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) {
        continue;
      }

      final text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }

    return fallback;
  }

  static String? _readNullableString(
      Map<String, dynamic> map, List<String> keys) {
    final value = _readString(map, keys);
    return value.isEmpty ? null : value;
  }

  static DateTime? _readDateTime(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) {
        continue;
      }

      if (value is DateTime) {
        return value.toLocal();
      }

      if (value is int) {
        final isMilliseconds = value > 100000000000;
        final timestamp = isMilliseconds ? value : value * 1000;
        return DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
      }

      final parsed = DateTime.tryParse(value.toString());
      if (parsed != null) {
        return parsed.toLocal();
      }
    }

    return null;
  }
}
