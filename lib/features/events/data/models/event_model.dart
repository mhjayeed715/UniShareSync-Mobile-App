import 'event_speaker_model.dart';
import 'event_schedule_item_model.dart';
import 'event_custom_field_model.dart';

class EventModel {
  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.eventType,
    required this.status,
    required this.visibility,
    required this.organizerId,
    this.organizingCommunityId,
    this.organizingCommunityName,
    this.facultyInChargeId,
    required this.venue,
    required this.isOnline,
    this.onlineLink,
    required this.eventDate,
    required this.eventEndDate,
    required this.registrationDeadline,
    required this.seatCapacity,
    required this.registeredCount,
    required this.waitlistCount,
    required this.requiresRegistration,
    required this.isPaid,
    required this.entryFee,
    this.paymentInstructions,
    required this.offersCertificate,
    this.certificateTemplateUrl,
    this.bannerUrl,
    required this.createdAt,
    this.approvedBy,
    this.approvedAt,
    this.speakers = const [],
    this.scheduleItems = const [],
    this.customFields = const [],
    this.isUserRegistered = false,
  });

  final String id;
  final String title;
  final String description;
  final String eventType; // enum: workshop, seminar, hackathon, cultural_program, sports_competition, guest_lecture, webinar, community_event, university_official, other
  final String status;    // enum: draft, pending_approval, upcoming, registration_open, registration_closed, ongoing, completed, cancelled
  final String visibility;// enum: public, members_only, department_only
  final String organizerId;
  final String? organizingCommunityId;
  final String? organizingCommunityName;
  final String? facultyInChargeId;
  final String venue;
  final bool isOnline;
  final String? onlineLink;
  final DateTime eventDate;
  final DateTime eventEndDate;
  final DateTime registrationDeadline;
  final int seatCapacity;
  final int registeredCount;
  final int waitlistCount;
  final bool requiresRegistration;
  final bool isPaid;
  final double entryFee;
  final String? paymentInstructions;
  final bool offersCertificate;
  final String? certificateTemplateUrl;
  final String? bannerUrl;
  final DateTime createdAt;
  final String? approvedBy;
  final DateTime? approvedAt;

  final List<EventSpeakerModel> speakers;
  final List<EventScheduleItemModel> scheduleItems;
  final List<EventCustomFieldModel> customFields;
  final bool isUserRegistered;

  bool get isFull => registeredCount >= seatCapacity;
  bool get isRegistrationClosed => DateTime.now().isAfter(registrationDeadline) || status == 'registration_closed';
  bool get canRegister => requiresRegistration && (status == 'registration_open' || status == 'upcoming' || status == 'approved') && !isRegistrationClosed && !isUserRegistered;
  int get availableSeats => seatCapacity - registeredCount;

  factory EventModel.fromMap(Map<String, dynamic> map) {
    // Check joined organizing community
    final communityMap = map['organizing_community'] as Map<String, dynamic>?;
    final communityName = communityMap?['name']?.toString();

    // Speakers join
    var speakersList = <EventSpeakerModel>[];
    if (map['event_speakers'] != null) {
      speakersList = (map['event_speakers'] as List)
          .map((s) => EventSpeakerModel.fromMap(s as Map<String, dynamic>))
          .toList();
    }

    // Schedule items join
    var scheduleList = <EventScheduleItemModel>[];
    if (map['event_schedule_items'] != null) {
      scheduleList = (map['event_schedule_items'] as List)
          .map((s) => EventScheduleItemModel.fromMap(s as Map<String, dynamic>))
          .toList();
    }

    // Custom fields join
    var customFieldsList = <EventCustomFieldModel>[];
    if (map['event_custom_fields'] != null) {
      customFieldsList = (map['event_custom_fields'] as List)
          .map((s) => EventCustomFieldModel.fromMap(s as Map<String, dynamic>))
          .toList();
    }

    return EventModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      eventType: map['event_type']?.toString() ?? 'other',
      status: map['status']?.toString() ?? 'draft',
      visibility: map['visibility']?.toString() ?? 'public',
      organizerId: map['organizer_id']?.toString() ?? '',
      organizingCommunityId: map['organizing_community_id']?.toString(),
      organizingCommunityName: communityName,
      facultyInChargeId: map['faculty_in_charge_id']?.toString(),
      venue: map['venue']?.toString() ?? '',
      isOnline: map['is_online'] == true,
      onlineLink: map['online_link']?.toString(),
      eventDate: _parseDateTime(map['event_date']),
      eventEndDate: _parseDateTime(map['event_end_date']),
      registrationDeadline: _parseDateTime(map['registration_deadline']),
      seatCapacity: _parseInt(map['seat_capacity']),
      registeredCount: _parseInt(map['registered_count']),
      waitlistCount: _parseInt(map['waitlist_count']),
      requiresRegistration: map['requires_registration'] != false,
      isPaid: map['is_paid'] == true,
      entryFee: _parseDouble(map['entry_fee_bdt']),
      paymentInstructions: map['payment_instructions']?.toString(),
      offersCertificate: map['offers_certificate'] == true,
      certificateTemplateUrl: map['certificate_template_url']?.toString(),
      bannerUrl: map['banner_url']?.toString(),
      createdAt: _parseDateTime(map['created_at']),
      approvedBy: map['approved_by']?.toString(),
      approvedAt: map['approved_at'] != null ? _parseDateTime(map['approved_at']) : null,
      speakers: speakersList,
      scheduleItems: scheduleList,
      customFields: customFieldsList,
      isUserRegistered: map['is_user_registered'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'event_type': eventType,
      'status': status,
      'visibility': visibility,
      'organizer_id': organizerId,
      'organizing_community_id': organizingCommunityId,
      'faculty_in_charge_id': facultyInChargeId,
      'venue': venue,
      'is_online': isOnline,
      'online_link': onlineLink,
      'event_date': eventDate.toIso8601String(),
      'event_end_date': eventEndDate.toIso8601String(),
      'registration_deadline': registrationDeadline.toIso8601String(),
      'seat_capacity': seatCapacity,
      'registered_count': registeredCount,
      'waitlist_count': waitlistCount,
      'requires_registration': requiresRegistration,
      'is_paid': isPaid,
      'entry_fee_bdt': entryFee,
      'payment_instructions': paymentInstructions,
      'offers_certificate': offersCertificate,
      'certificate_template_url': certificateTemplateUrl,
      'banner_url': bannerUrl,
      'created_at': createdAt.toIso8601String(),
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
    };
  }

  EventModel copyWith({
    String? id,
    String? title,
    String? description,
    String? eventType,
    String? status,
    String? visibility,
    String? organizerId,
    String? organizingCommunityId,
    String? organizingCommunityName,
    String? facultyInChargeId,
    String? venue,
    bool? isOnline,
    String? onlineLink,
    DateTime? eventDate,
    DateTime? eventEndDate,
    DateTime? registrationDeadline,
    int? seatCapacity,
    int? registeredCount,
    int? waitlistCount,
    bool? requiresRegistration,
    bool? isPaid,
    double? entryFee,
    String? paymentInstructions,
    bool? offersCertificate,
    String? certificateTemplateUrl,
    String? bannerUrl,
    DateTime? createdAt,
    String? approvedBy,
    DateTime? approvedAt,
    List<EventSpeakerModel>? speakers,
    List<EventScheduleItemModel>? scheduleItems,
    List<EventCustomFieldModel>? customFields,
    bool? isUserRegistered,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      eventType: eventType ?? this.eventType,
      status: status ?? this.status,
      visibility: visibility ?? this.visibility,
      organizerId: organizerId ?? this.organizerId,
      organizingCommunityId: organizingCommunityId ?? this.organizingCommunityId,
      organizingCommunityName: organizingCommunityName ?? this.organizingCommunityName,
      facultyInChargeId: facultyInChargeId ?? this.facultyInChargeId,
      venue: venue ?? this.venue,
      isOnline: isOnline ?? this.isOnline,
      onlineLink: onlineLink ?? this.onlineLink,
      eventDate: eventDate ?? this.eventDate,
      eventEndDate: eventEndDate ?? this.eventEndDate,
      registrationDeadline: registrationDeadline ?? this.registrationDeadline,
      seatCapacity: seatCapacity ?? this.seatCapacity,
      registeredCount: registeredCount ?? this.registeredCount,
      waitlistCount: waitlistCount ?? this.waitlistCount,
      requiresRegistration: requiresRegistration ?? this.requiresRegistration,
      isPaid: isPaid ?? this.isPaid,
      entryFee: entryFee ?? this.entryFee,
      paymentInstructions: paymentInstructions ?? this.paymentInstructions,
      offersCertificate: offersCertificate ?? this.offersCertificate,
      certificateTemplateUrl: certificateTemplateUrl ?? this.certificateTemplateUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      createdAt: createdAt ?? this.createdAt,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      speakers: speakers ?? this.speakers,
      scheduleItems: scheduleItems ?? this.scheduleItems,
      customFields: customFields ?? this.customFields,
      isUserRegistered: isUserRegistered ?? this.isUserRegistered,
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

double _parseDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value) ?? 0.0;
  }
  return 0.0;
}
