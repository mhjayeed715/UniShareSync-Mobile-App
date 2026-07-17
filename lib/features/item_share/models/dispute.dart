enum DisputeType { damage, nonReturn }

enum DisputeStatus {
  open,
  underReview,
  resolvedLenderFavor,
  resolvedBorrowerFavor,
  resolvedMutual,
}

class Dispute {
  final String id;
  final String loanId;
  final String listingTitle;
  final String lenderId;
  final String lenderName;
  final String borrowerId;
  final String borrowerName;
  final DisputeType type;
  final double declaredCostBdt;
  final DisputeStatus status;
  final String adminComment;
  final List<String> evidencePhotos;
  final String? resolvedBy; // UUID of admin who resolved
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const Dispute({
    required this.id,
    required this.loanId,
    required this.listingTitle,
    required this.lenderId,
    required this.lenderName,
    required this.borrowerId,
    required this.borrowerName,
    required this.type,
    required this.declaredCostBdt,
    required this.status,
    this.adminComment = '',
    this.evidencePhotos = const [],
    this.resolvedBy,
    required this.createdAt,
    this.resolvedAt,
  });

  // Damage disputes require at least 1 evidence photo
  bool get canOpen => type != DisputeType.damage || evidencePhotos.isNotEmpty;

  factory Dispute.fromJson(Map<String, dynamic> j) => Dispute(
        id: j['id'] as String,
        loanId: j['loan_id'] as String,
        listingTitle: j['listing_title'] as String,
        lenderId: j['lender_id'] as String,
        lenderName: j['lender_name'] as String,
        borrowerId: j['borrower_id'] as String,
        borrowerName: j['borrower_name'] as String,
        type: j['type'] == 'non_return' ? DisputeType.nonReturn : DisputeType.damage,
        declaredCostBdt: (j['declared_cost_bdt'] as num?)?.toDouble() ?? 0.0,
        status: _parseStatus(j['status'] as String),
        adminComment: j['admin_comment'] as String? ?? '',
        evidencePhotos: List<String>.from(j['evidence_photos'] ?? []),
        resolvedBy: j['resolved_by'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        resolvedAt: j['resolved_at'] != null
            ? DateTime.parse(j['resolved_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'loan_id': loanId,
        'listing_title': listingTitle,
        'lender_id': lenderId,
        'lender_name': lenderName,
        'borrower_id': borrowerId,
        'borrower_name': borrowerName,
        'type': type == DisputeType.nonReturn ? 'non_return' : 'damage',
        'declared_cost_bdt': declaredCostBdt,
        'status': _statusToString(status),
        'admin_comment': adminComment,
        'evidence_photos': evidencePhotos,
      };

  static DisputeStatus _parseStatus(String s) => switch (s) {
        'under_review'             => DisputeStatus.underReview,
        'resolved_lender_favor'    => DisputeStatus.resolvedLenderFavor,
        'resolved_borrower_favor'  => DisputeStatus.resolvedBorrowerFavor,
        'resolved_mutual'          => DisputeStatus.resolvedMutual,
        _                          => DisputeStatus.open,
      };

  static String _statusToString(DisputeStatus s) => switch (s) {
        DisputeStatus.underReview           => 'under_review',
        DisputeStatus.resolvedLenderFavor   => 'resolved_lender_favor',
        DisputeStatus.resolvedBorrowerFavor => 'resolved_borrower_favor',
        DisputeStatus.resolvedMutual        => 'resolved_mutual',
        _                                   => 'open',
      };
}
