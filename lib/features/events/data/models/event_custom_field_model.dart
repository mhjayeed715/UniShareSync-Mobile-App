class EventCustomFieldModel {
  const EventCustomFieldModel({
    required this.id,
    required this.eventId,
    required this.fieldLabel,
    required this.fieldType, // 'text', 'dropdown', 'checkbox'
    this.options = const [],
    required this.isRequired,
    required this.displayOrder,
  });

  final String id;
  final String eventId;
  final String fieldLabel;
  final String fieldType;
  final List<String> options;
  final bool isRequired;
  final int displayOrder;

  factory EventCustomFieldModel.fromMap(Map<String, dynamic> map) {
    List<String> parsedOptions = [];
    if (map['options'] != null) {
      if (map['options'] is List) {
        parsedOptions = (map['options'] as List).map((o) => o.toString()).toList();
      }
    }
    return EventCustomFieldModel(
      id: map['id']?.toString() ?? '',
      eventId: map['event_id']?.toString() ?? '',
      fieldLabel: map['field_label']?.toString() ?? '',
      fieldType: map['field_type']?.toString() ?? 'text',
      options: parsedOptions,
      isRequired: map['is_required'] == true,
      displayOrder: map['display_order'] is int ? map['display_order'] as int : 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'field_label': fieldLabel,
      'field_type': fieldType,
      'options': options,
      'is_required': isRequired,
      'display_order': displayOrder,
    };
  }
}
