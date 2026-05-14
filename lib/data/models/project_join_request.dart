class ProjectJoinRequest {
  const ProjectJoinRequest({
    required this.id,
    required this.projectId,
    required this.requesterId,
    required this.requesterName,
    required this.requesterAvatarUrl,
    required this.status,
    required this.requestedAt,
  });

  final String id;
  final String projectId;
  final String requesterId;
  final String requesterName;
  final String? requesterAvatarUrl;
  final String status;
  final DateTime requestedAt;

  bool get isPending => status.toLowerCase() == 'pending';

  factory ProjectJoinRequest.fromMap(Map<String, dynamic> map) {
    return ProjectJoinRequest(
      id: map['id']?.toString() ?? '',
      projectId: map['project_id']?.toString() ?? '',
      requesterId: map['requester_id']?.toString() ?? '',
      requesterName: map['requester_name']?.toString() ?? 'Student',
      requesterAvatarUrl: map['requester_avatar_url']?.toString(),
      status: map['status']?.toString() ?? 'pending',
      requestedAt: _parseDateTime(map['created_at'] ?? map['requested_at']),
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
