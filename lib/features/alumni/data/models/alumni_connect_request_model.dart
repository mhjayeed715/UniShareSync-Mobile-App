class AlumniConnectRequest {
  final String id;
  final String alumniId;
  final String senderId;
  final String message;
  final DateTime sentAt;
  final String deliveryStatus; // 'pending', 'sent', 'failed'
  final String senderName;
  final String senderEmail;
  final int? senderSemester;

  AlumniConnectRequest({
    required this.id,
    required this.alumniId,
    required this.senderId,
    required this.message,
    required this.sentAt,
    required this.deliveryStatus,
    required this.senderName,
    required this.senderEmail,
    this.senderSemester,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'alumni_id': alumniId,
      'sender_id': senderId,
      'message': message,
      'sent_at': sentAt.toIso8601String(),
      'delivery_status': deliveryStatus,
      'sender_name': senderName,
      'sender_email': senderEmail,
      'sender_semester': senderSemester,
    };
  }

  factory AlumniConnectRequest.fromMap(Map<String, dynamic> map) {
    return AlumniConnectRequest(
      id: map['id'] ?? '',
      alumniId: map['alumni_id'] ?? '',
      senderId: map['sender_id'] ?? '',
      message: map['message'] ?? '',
      sentAt: DateTime.tryParse(map['sent_at']?.toString() ?? '') ?? DateTime.now(),
      deliveryStatus: map['delivery_status'] ?? 'pending',
      senderName: map['sender_name'] ?? '',
      senderEmail: map['sender_email'] ?? '',
      senderSemester: map['sender_semester'] is int ? map['sender_semester'] : int.tryParse(map['sender_semester']?.toString() ?? ''),
    );
  }
}
