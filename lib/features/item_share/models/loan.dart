// Borrow terms
class BorrowTerms {
  final int loanDurationDays;
  final double penaltyPerDayBdt;
  final double maxPenaltyBdt;
  final int gracePeriodDays;
  final int maxOverdueDays;
  final double depositBdt;

  const BorrowTerms({
    required this.loanDurationDays,
    required this.penaltyPerDayBdt,
    required this.maxPenaltyBdt,
    this.gracePeriodDays = 1,
    this.maxOverdueDays = 14,
    this.depositBdt = 0.0,
  });

  factory BorrowTerms.fromJson(Map<String, dynamic> j) => BorrowTerms(
        loanDurationDays: j['loan_duration_days'] as int,
        penaltyPerDayBdt: (j['penalty_per_day_bdt'] as num).toDouble(),
        maxPenaltyBdt: (j['max_penalty_bdt'] as num).toDouble(),
        gracePeriodDays: j['grace_period_days'] as int? ?? 1,
        maxOverdueDays: j['max_overdue_days'] as int? ?? 14,
        depositBdt: (j['deposit_bdt'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'loan_duration_days': loanDurationDays,
        'penalty_per_day_bdt': penaltyPerDayBdt,
        'max_penalty_bdt': maxPenaltyBdt,
        'grace_period_days': gracePeriodDays,
        'max_overdue_days': maxOverdueDays,
        'deposit_bdt': depositBdt,
      };
}

// Rent terms
class RentTerms {
  final int rentalDurationDays;
  final double rentalRateBdtPerDay;
  final double securityDepositBdt;
  final double penaltyPerDayBdt;
  final double maxPenaltyBdt;
  final int gracePeriodDays;
  final int maxOverdueDays;

  const RentTerms({
    required this.rentalDurationDays,
    required this.rentalRateBdtPerDay,
    required this.securityDepositBdt,
    this.penaltyPerDayBdt = 0.0,
    this.maxPenaltyBdt = 0.0,
    this.gracePeriodDays = 1,
    this.maxOverdueDays = 14,
  });

  factory RentTerms.fromJson(Map<String, dynamic> j) => RentTerms(
        rentalDurationDays: j['rental_duration_days'] as int,
        rentalRateBdtPerDay: (j['rental_rate_bdt_per_day'] as num).toDouble(),
        securityDepositBdt: (j['security_deposit_bdt'] as num).toDouble(),
        penaltyPerDayBdt: (j['penalty_per_day_bdt'] as num?)?.toDouble() ?? 0.0,
        maxPenaltyBdt: (j['max_penalty_bdt'] as num?)?.toDouble() ?? 0.0,
        gracePeriodDays: j['grace_period_days'] as int? ?? 1,
        maxOverdueDays: j['max_overdue_days'] as int? ?? 14,
      );

  Map<String, dynamic> toJson() => {
        'rental_duration_days': rentalDurationDays,
        'rental_rate_bdt_per_day': rentalRateBdtPerDay,
        'security_deposit_bdt': securityDepositBdt,
        'penalty_per_day_bdt': penaltyPerDayBdt,
        'max_penalty_bdt': maxPenaltyBdt,
        'grace_period_days': gracePeriodDays,
        'max_overdue_days': maxOverdueDays,
      };
}

// Sell terms
class SellTerms {
  final double priceBdt;
  const SellTerms({required this.priceBdt});

  factory SellTerms.fromJson(Map<String, dynamic> j) =>
      SellTerms(priceBdt: (j['price_bdt'] as num).toDouble());

  Map<String, dynamic> toJson() => {'price_bdt': priceBdt};
}

// Exchange Request — the full request/agreement/approval workflow
class ExchangeRequest {
  final String id;
  final String listingId;
  final String borrowerId;
  final String lenderId;
  final String status;
  final DateTime? agreedReturnDate;
  final DateTime? actualReturnDate;
  final int daysOverdue;
  final double penaltyAccruedBdt;
  final DateTime? agreementAcceptedAt;
  final String? agreementTextSnapshot;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExchangeRequest({
    required this.id,
    required this.listingId,
    required this.borrowerId,
    required this.lenderId,
    required this.status,
    this.agreedReturnDate,
    this.actualReturnDate,
    this.daysOverdue = 0,
    this.penaltyAccruedBdt = 0.0,
    this.agreementAcceptedAt,
    this.agreementTextSnapshot,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isSigned => agreementAcceptedAt != null;

  factory ExchangeRequest.fromJson(Map<String, dynamic> j) => ExchangeRequest(
        id: j['id'] as String,
        listingId: j['listing_id'] as String,
        borrowerId: j['borrower_id'] as String,
        lenderId: j['lender_id'] as String,
        status: j['status'] as String,
        agreedReturnDate: j['agreed_return_date'] != null
            ? DateTime.parse(j['agreed_return_date'] as String)
            : null,
        actualReturnDate: j['actual_return_date'] != null
            ? DateTime.parse(j['actual_return_date'] as String)
            : null,
        daysOverdue: j['days_overdue'] as int? ?? 0,
        penaltyAccruedBdt: (j['penalty_accrued_bdt'] as num?)?.toDouble() ?? 0.0,
        agreementAcceptedAt: j['agreement_accepted_at'] != null
            ? DateTime.parse(j['agreement_accepted_at'] as String)
            : null,
        agreementTextSnapshot: j['agreement_text_snapshot'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'listing_id': listingId,
        'borrower_id': borrowerId,
        'lender_id': lenderId,
        'status': status,
        'agreed_return_date': agreedReturnDate?.toIso8601String(),
        'actual_return_date': actualReturnDate?.toIso8601String(),
        'agreement_accepted_at': agreementAcceptedAt?.toIso8601String(),
        'agreement_text_snapshot': agreementTextSnapshot,
      };
}

// Exchange Agreement — immutable snapshot stored at signing
class ExchangeAgreement {
  final String id;
  final String requestId;
  final String borrowerId;
  final String agreementText;
  final DateTime acceptedAt;

  const ExchangeAgreement({
    required this.id,
    required this.requestId,
    required this.borrowerId,
    required this.agreementText,
    required this.acceptedAt,
  });

  factory ExchangeAgreement.fromJson(Map<String, dynamic> j) => ExchangeAgreement(
        id: j['id'] as String,
        requestId: j['request_id'] as String,
        borrowerId: j['borrower_id'] as String,
        agreementText: j['agreement_text'] as String,
        acceptedAt: DateTime.parse(j['accepted_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'request_id': requestId,
        'borrower_id': borrowerId,
        'agreement_text': agreementText,
      };
}

// Active Loan
enum ReturnCondition { fine, damaged, notReturned }

class ActiveLoan {
  final String id;
  final String requestId;
  final String listingId;
  final String borrowerId;
  final String lenderId;
  final String status;
  final DateTime startedAt;
  final DateTime dueDate;
  final DateTime? returnedAt;
  final DateTime? confirmedAt;
  final int daysOverdue;
  final double currentPenaltyBdt;
  final double depositPaidBdt;
  final bool damageClaimed;
  final double claimedDamageCost;
  final ReturnCondition? returnCondition;

  // Enriched fields
  final String listingTitle;
  final String borrowerName;
  final String lenderName;

  const ActiveLoan({
    required this.id,
    required this.requestId,
    required this.listingId,
    required this.borrowerId,
    required this.lenderId,
    required this.status,
    required this.startedAt,
    required this.dueDate,
    this.returnedAt,
    this.confirmedAt,
    this.daysOverdue = 0,
    this.currentPenaltyBdt = 0.0,
    this.depositPaidBdt = 0.0,
    this.damageClaimed = false,
    this.claimedDamageCost = 0.0,
    this.returnCondition,
    this.listingTitle = 'Item',
    this.borrowerName = 'Borrower',
    this.lenderName = 'Lender',
  });

  bool get isOverdue => status == 'overdue' || status == 'severely_overdue';

  int get daysUntilDue => dueDate.difference(DateTime.now()).inDays;

  factory ActiveLoan.fromJson(Map<String, dynamic> j) => ActiveLoan(
        id: j['id'] as String,
        requestId: j['request_id'] as String,
        listingId: j['listing_id'] as String,
        borrowerId: j['borrower_id'] as String,
        lenderId: j['lender_id'] as String,
        status: j['status'] as String,
        startedAt: DateTime.parse(j['started_at'] as String),
        dueDate: DateTime.parse(j['due_date'] as String),
        returnedAt: j['returned_at'] != null
            ? DateTime.parse(j['returned_at'] as String)
            : null,
        confirmedAt: j['confirmed_at'] != null
            ? DateTime.parse(j['confirmed_at'] as String)
            : null,
        daysOverdue: j['days_overdue'] as int? ?? 0,
        currentPenaltyBdt: (j['current_penalty_bdt'] as num?)?.toDouble() ?? 0.0,
        depositPaidBdt: (j['deposit_paid_bdt'] as num?)?.toDouble() ?? 0.0,
        damageClaimed: j['damage_claimed'] as bool? ?? false,
        claimedDamageCost: (j['claimed_damage_cost'] as num?)?.toDouble() ?? 0.0,
        returnCondition: j['return_condition'] != null
            ? ReturnCondition.values.firstWhere(
                (e) => e.name == (j['return_condition'] as String).replaceAll('_', ''),
                orElse: () => ReturnCondition.fine,
              )
            : null,
        listingTitle: j['listing_title'] as String? ?? 'Item',
        borrowerName: j['borrower_name'] as String? ?? 'Borrower',
        lenderName: j['lender_name'] as String? ?? 'Lender',
      );
}
