enum TrustTier { trusted, verified, caution, restricted, suspended }

class TrustScore {
  final String userId;
  final int score;
  final int totalLends;
  final int totalBorrows;
  final double totalPenaltiesIncurredBdt;
  final int totalDisputesRaised;
  final int consecutiveCleanLoans;
  final DateTime lastUpdated;

  const TrustScore({
    required this.userId,
    required this.score,
    this.totalLends = 0,
    this.totalBorrows = 0,
    this.totalPenaltiesIncurredBdt = 0.0,
    this.totalDisputesRaised = 0,
    this.consecutiveCleanLoans = 0,
    required this.lastUpdated,
  });

  TrustTier get tier {
    if (score >= 80) return TrustTier.trusted;
    if (score >= 60) return TrustTier.verified;
    if (score >= 40) return TrustTier.caution;
    if (score >= 20) return TrustTier.restricted;
    return TrustTier.suspended;
  }

  String get tierLabel => switch (tier) {
        TrustTier.trusted    => 'Trusted',
        TrustTier.verified   => 'Verified',
        TrustTier.caution    => 'Caution',
        TrustTier.restricted => 'Restricted',
        TrustTier.suspended  => 'Suspended',
      };

  // Color hex for badge display
  String get colorHex => switch (tier) {
        TrustTier.trusted    => '#4CAF50',
        TrustTier.verified   => '#2196F3',
        TrustTier.caution    => '#FFC107',
        TrustTier.restricted => '#FF9800',
        TrustTier.suspended  => '#F44336',
      };

  int get maxConcurrentBorrows => switch (tier) {
        TrustTier.trusted    => 3,
        TrustTier.verified   => 2,
        TrustTier.caution    => 1,
        TrustTier.restricted => 0,
        TrustTier.suspended  => 0,
      };

  bool get canCreateListing =>
      tier != TrustTier.restricted && tier != TrustTier.suspended;

  bool get canBorrow =>
      tier != TrustTier.suspended && tier != TrustTier.restricted;

  // Caution tier listings need admin approval before publishing
  bool get listingNeedsAdminApproval => tier == TrustTier.caution;

  factory TrustScore.fromJson(Map<String, dynamic> j) => TrustScore(
        userId: j['user_id'] as String,
        score: j['score'] as int,
        totalLends: j['total_lends'] as int? ?? 0,
        totalBorrows: j['total_borrows'] as int? ?? 0,
        totalPenaltiesIncurredBdt:
            (j['total_penalties_incurred_bdt'] as num?)?.toDouble() ?? 0.0,
        totalDisputesRaised: j['total_disputes_raised'] as int? ?? 0,
        consecutiveCleanLoans: j['consecutive_clean_loans'] as int? ?? 0,
        lastUpdated: DateTime.parse(j['last_updated'] as String),
      );
}

class TrustScoreHistory {
  final String id;
  final String userId;
  final int delta;
  final String reason;
  final int scoreAfter;
  final DateTime createdAt;

  const TrustScoreHistory({
    required this.id,
    required this.userId,
    required this.delta,
    required this.reason,
    required this.scoreAfter,
    required this.createdAt,
  });

  factory TrustScoreHistory.fromJson(Map<String, dynamic> j) => TrustScoreHistory(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        delta: j['delta'] as int,
        reason: j['reason'] as String,
        scoreAfter: j['score_after'] as int,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
