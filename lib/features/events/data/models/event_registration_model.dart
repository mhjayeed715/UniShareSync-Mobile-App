class EventRegistrationModel {
  const EventRegistrationModel({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.semester,
    required this.studentFacultyId,
    required this.department,
    this.tshirtSize,
    this.dietaryPreference,
    this.teamName,
    this.githubUrl,
    this.howHeard,
    this.customFieldResponses = const {},
    this.paymentMethod,
    this.transactionId,
    this.paymentScreenshotUrl,
    required this.paymentStatus, // 'not_required', 'pending', 'verified', 'rejected'
    required this.registrationStatus, // 'pending', 'confirmed', 'waitlisted', 'cancelled', 'attended'
    this.waitlistPosition,
    required this.registeredAt,
    this.confirmedAt,
    this.checkedInAt,
    this.checkedInBy,
    required this.certificateIssued,
    this.certificateUrl,
  });

  final String id;
  final String eventId;
  final String userId;
  final String fullName;
  final String email;
  final String phone;
  final int semester;
  final String studentFacultyId;
  final String department;
  final String? tshirtSize;
  final String? dietaryPreference;
  final String? teamName;
  final String? githubUrl;
  final String? howHeard;
  final Map<String, dynamic> customFieldResponses;
  final String? paymentMethod;
  final String? transactionId;
  final String? paymentScreenshotUrl;
  final String paymentStatus;
  final String registrationStatus;
  final int? waitlistPosition;
  final DateTime registeredAt;
  final DateTime? confirmedAt;
  final DateTime? checkedInAt;
  final String? checkedInBy;
  final bool certificateIssued;
  final String? certificateUrl;

  factory EventRegistrationModel.fromMap(Map<String, dynamic> map) {
    return EventRegistrationModel(
      id: map['id']?.toString() ?? '',
      eventId: map['event_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      semester: map['semester'] is int ? map['semester'] as int : 1,
      studentFacultyId: map['student_faculty_id']?.toString() ?? '',
      department: map['department']?.toString() ?? 'CSE',
      tshirtSize: map['tshirt_size']?.toString(),
      dietaryPreference: map['dietary_preference']?.toString(),
      teamName: map['team_name']?.toString(),
      githubUrl: map['github_url']?.toString(),
      howHeard: map['how_heard']?.toString(),
      customFieldResponses: map['custom_field_responses'] is Map 
          ? Map<String, dynamic>.from(map['custom_field_responses'] as Map)
          : {},
      paymentMethod: map['payment_method']?.toString(),
      transactionId: map['transaction_id']?.toString(),
      paymentScreenshotUrl: map['payment_screenshot_url']?.toString(),
      paymentStatus: map['payment_status']?.toString() ?? 'not_required',
      registrationStatus: map['registration_status']?.toString() ?? 'pending',
      waitlistPosition: map['waitlist_position'] is int ? map['waitlist_position'] as int : null,
      registeredAt: DateTime.parse(map['registered_at']?.toString() ?? DateTime.now().toIso8601String()),
      confirmedAt: map['confirmed_at'] != null ? DateTime.parse(map['confirmed_at']) : null,
      checkedInAt: map['checked_in_at'] != null ? DateTime.parse(map['checked_in_at']) : null,
      checkedInBy: map['checked_in_by']?.toString(),
      certificateIssued: map['certificate_issued'] == true,
      certificateUrl: map['certificate_url']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'user_id': userId,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'semester': semester,
      'student_faculty_id': studentFacultyId,
      'department': department,
      'tshirt_size': tshirtSize,
      'dietary_preference': dietaryPreference,
      'team_name': teamName,
      'github_url': githubUrl,
      'how_heard': howHeard,
      'custom_field_responses': customFieldResponses,
      'payment_method': paymentMethod,
      'transaction_id': transactionId,
      'payment_screenshot_url': paymentScreenshotUrl,
      'payment_status': paymentStatus,
      'registration_status': registrationStatus,
      'waitlist_position': waitlistPosition,
      'registered_at': registeredAt.toIso8601String(),
      'confirmed_at': confirmedAt?.toIso8601String(),
      'checked_in_at': checkedInAt?.toIso8601String(),
      'checked_in_by': checkedInBy,
      'certificate_issued': certificateIssued,
      'certificate_url': certificateUrl,
    };
  }
}
