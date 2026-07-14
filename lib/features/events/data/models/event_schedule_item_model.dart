class EventScheduleItemModel {
  const EventScheduleItemModel({
    required this.id,
    required this.eventId,
    required this.startTime,
    required this.endTime,
    required this.title,
    this.description,
    this.speakerId,
    required this.displayOrder,
  });

  final String id;
  final String eventId;
  final DateTime startTime;
  final DateTime endTime;
  final String title;
  final String? description;
  final String? speakerId;
  final int displayOrder;

  factory EventScheduleItemModel.fromMap(Map<String, dynamic> map) {
    return EventScheduleItemModel(
      id: map['id']?.toString() ?? '',
      eventId: map['event_id']?.toString() ?? '',
      startTime: DateTime.parse(map['start_time']?.toString() ?? DateTime.now().toIso8601String()),
      endTime: DateTime.parse(map['end_time']?.toString() ?? DateTime.now().toIso8601String()),
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString(),
      speakerId: map['speaker_id']?.toString(),
      displayOrder: map['display_order'] is int ? map['display_order'] as int : 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'title': title,
      'description': description,
      'speaker_id': speakerId,
      'display_order': displayOrder,
    };
  }
}
