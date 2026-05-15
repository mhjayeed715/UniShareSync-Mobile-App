class EventModel {
  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.time,
    required this.venue,
    required this.organizerClub,
    required this.seatCapacity,
    required this.registeredCount,
    required this.status,
    required this.createdBy,
    required this.createdByName,
    this.createdByAvatar,
    required this.createdAt,
    this.isUserRegistered = false,
  });

  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String time;
  final String venue;
  final String organizerClub;
  final int seatCapacity;
  final int registeredCount;
  final EventStatus status;
  final String createdBy;
  final String createdByName;
  final String? createdByAvatar;
  final DateTime createdAt;
  final bool isUserRegistered;

  bool get isFull => registeredCount >= seatCapacity;
  bool get canRegister => status == EventStatus.upcoming && !isFull;
  int get availableSeats => seatCapacity - registeredCount;

  factory EventModel.fromMap(Map<String, dynamic> map) {
    return EventModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      date: _parseDateTime(map['date']),
      time: map['time']?.toString() ?? '',
      venue: map['venue']?.toString() ?? '',
      organizerClub: map['organizer_club']?.toString() ?? '',
      seatCapacity: _parseInt(map['seat_capacity']),
      registeredCount: _parseInt(map['registered_count']),
      status: EventStatus.fromString(map['status']?.toString() ?? 'upcoming'),
      createdBy: map['created_by']?.toString() ?? '',
      createdByName: map['created_by_name']?.toString() ?? '',
      createdByAvatar: map['created_by_avatar']?.toString(),
      createdAt: _parseDateTime(map['created_at']),
      isUserRegistered: map['is_user_registered'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'time': time,
      'venue': venue,
      'organizer_club': organizerClub,
      'seat_capacity': seatCapacity,
      'registered_count': registeredCount,
      'status': status.value,
      'created_by': createdBy,
      'created_by_name': createdByName,
      'created_by_avatar': createdByAvatar,
      'created_at': createdAt.toIso8601String(),
      'is_user_registered': isUserRegistered,
    };
  }

  EventModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    String? time,
    String? venue,
    String? organizerClub,
    int? seatCapacity,
    int? registeredCount,
    EventStatus? status,
    String? createdBy,
    String? createdByName,
    String? createdByAvatar,
    DateTime? createdAt,
    bool? isUserRegistered,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      time: time ?? this.time,
      venue: venue ?? this.venue,
      organizerClub: organizerClub ?? this.organizerClub,
      seatCapacity: seatCapacity ?? this.seatCapacity,
      registeredCount: registeredCount ?? this.registeredCount,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdByAvatar: createdByAvatar ?? this.createdByAvatar,
      createdAt: createdAt ?? this.createdAt,
      isUserRegistered: isUserRegistered ?? this.isUserRegistered,
    );
  }
}

enum EventStatus {
  upcoming('upcoming', 'Upcoming'),
  ongoing('ongoing', 'Ongoing'),
  completed('completed', 'Completed');

  const EventStatus(this.value, this.displayName);
  final String value;
  final String displayName;

  static EventStatus fromString(String value) {
    return EventStatus.values.firstWhere(
      (status) => status.value == value.toLowerCase(),
      orElse: () => EventStatus.upcoming,
    );
  }
}

DateTime _parseDateTime(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (_) {}
  }
  return DateTime.now();
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}
