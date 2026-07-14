class ClubModel {
  const ClubModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.memberCount,
    required this.ownerId,
    required this.ownerName,
    this.ownerAvatar,
    this.logoUrl,
    required this.createdAt,
    this.isUserMember = false,
    this.joinRequestStatus,
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final int memberCount;
  final String ownerId;
  final String ownerName;
  final String? ownerAvatar;
  final String? logoUrl;
  final DateTime createdAt;
  final bool isUserMember;
  final String? joinRequestStatus; // 'pending', 'approved', 'rejected', or null

  bool get hasRequestPending => joinRequestStatus?.toLowerCase() == 'pending';
  bool get wasRequestRejected => joinRequestStatus?.toLowerCase() == 'rejected';

  factory ClubModel.fromMap(Map<String, dynamic> map) {
    return ClubModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      memberCount: _parseInt(map['member_count']),
      ownerId: map['owner_id']?.toString() ?? '',
      ownerName: map['owner_name']?.toString() ?? '',
      ownerAvatar: map['owner_avatar']?.toString(),
      logoUrl: map['logo_url']?.toString(),
      createdAt: _parseDateTime(map['created_at']),
      isUserMember: map['is_user_member'] == true,
      joinRequestStatus: map['join_request_status']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'member_count': memberCount,
      'owner_id': ownerId,
      'owner_name': ownerName,
      'owner_avatar': ownerAvatar,
      'logo_url': logoUrl,
      'created_at': createdAt.toIso8601String(),
      'is_user_member': isUserMember,
      'join_request_status': joinRequestStatus,
    };
  }

  ClubModel copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    int? memberCount,
    String? ownerId,
    String? ownerName,
    String? ownerAvatar,
    String? logoUrl,
    DateTime? createdAt,
    bool? isUserMember,
    Object? joinRequestStatus = _sentinel,
  }) {
    return ClubModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      memberCount: memberCount ?? this.memberCount,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      ownerAvatar: ownerAvatar ?? this.ownerAvatar,
      logoUrl: logoUrl ?? this.logoUrl,
      createdAt: createdAt ?? this.createdAt,
      isUserMember: isUserMember ?? this.isUserMember,
      joinRequestStatus: joinRequestStatus == _sentinel
          ? this.joinRequestStatus
          : joinRequestStatus as String?,
    );
  }
}

const Object _sentinel = Object();

class ClubJoinRequest {
  const ClubJoinRequest({
    required this.id,
    required this.clubId,
    required this.requesterId,
    required this.requesterName,
    this.requesterAvatar,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String clubId;
  final String requesterId;
  final String requesterName;
  final String? requesterAvatar;
  final String status;
  final DateTime createdAt;

  bool get isPending => status.toLowerCase() == 'pending';

  factory ClubJoinRequest.fromMap(Map<String, dynamic> map) {
    return ClubJoinRequest(
      id: map['id']?.toString() ?? '',
      clubId: map['club_id']?.toString() ?? '',
      requesterId: map['requester_id']?.toString() ?? '',
      requesterName: map['requester_name']?.toString() ?? 'Student',
      requesterAvatar: map['requester_avatar']?.toString(),
      status: map['status']?.toString() ?? 'pending',
      createdAt: _parseDateTime(map['created_at']),
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

