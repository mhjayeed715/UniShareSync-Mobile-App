class EventSpeakerModel {
  const EventSpeakerModel({
    required this.id,
    required this.eventId,
    required this.name,
    required this.designation,
    required this.institution,
    this.photoUrl,
    required this.displayOrder,
  });

  final String id;
  final String eventId;
  final String name;
  final String designation;
  final String institution;
  final String? photoUrl;
  final int displayOrder;

  factory EventSpeakerModel.fromMap(Map<String, dynamic> map) {
    return EventSpeakerModel(
      id: map['id']?.toString() ?? '',
      eventId: map['event_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      designation: map['designation']?.toString() ?? '',
      institution: map['institution']?.toString() ?? '',
      photoUrl: map['photo_url']?.toString(),
      displayOrder: map['display_order'] is int ? map['display_order'] as int : 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'name': name,
      'designation': designation,
      'institution': institution,
      'photo_url': photoUrl,
      'display_order': displayOrder,
    };
  }
}
