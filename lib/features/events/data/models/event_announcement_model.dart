class EventAnnouncementModel {
  const EventAnnouncementModel({
    required this.id,
    required this.eventId,
    required this.senderId,
    required this.title,
    required this.body,
    required this.sentAt,
  });

  final String id;
  final String eventId;
  final String senderId;
  final String title;
  final String body;
  final DateTime sentAt;

  factory EventAnnouncementModel.fromMap(Map<String, dynamic> map) {
    return EventAnnouncementModel(
      id: map['id']?.toString() ?? '',
      eventId: map['event_id']?.toString() ?? '',
      senderId: map['sender_id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      sentAt: DateTime.parse(map['sent_at']?.toString() ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'sender_id': senderId,
      'title': title,
      'body': body,
      'sent_at': sentAt.toIso8601String(),
    };
  }
}
