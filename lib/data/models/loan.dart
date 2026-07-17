import 'package:supabase_flutter/supabase_flutter.dart';

class BorrowTerms {
  final int loanDurationDays;
  final double penaltyPerDayBDT;
  final double maxPenaltyBDT;
  final int gracePeriodDays;
  final double depositBDT;

  const BorrowTerms({
    required this.loanDurationDays,
    required this.penaltyPerDayBDT,
    required this.maxPenaltyBDT,
    this.gracePeriodDays = 1,
    this.depositBDT = 0.0,
  });
}

class RentTerms {
  final int rentalDurationDays;
  final double rentalRateBDTPerDay;
  final double securityDepositBDT;

  const RentTerms({
    required this.rentalDurationDays,
    required this.rentalRateBDTPerDay,
    required this.securityDepositBDT,
  });
}

class SellTerms {
  final double priceBDT;

  const SellTerms({required this.priceBDT});
}

class ActiveLoan {
  final String id;
  final String listingId;
  final String listingTitle;
  final String listingCategory;
  final String borrowerId;
  final String borrowerName;
  final String lenderId;
  final String lenderName;
  final String status; // 'approved', 'active', 'overdue', 'severely_overdue', 'return_initiated', etc.
  final DateTime startedAt;
  final DateTime dueDate;
  final DateTime? returnedAt;
  final DateTime? confirmedAt;
  final double currentPenaltyBDT;
  final double depositBDT;
  final bool damageClaimed;
  final double claimedDamageCostBDT;
  final String disputeStatus; // 'none', 'pending', 'open', 'under_review', etc.

  ActiveLoan({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.listingCategory,
    required this.borrowerId,
    required this.borrowerName,
    required this.lenderId,
    required this.lenderName,
    required this.status,
    required this.startedAt,
    required this.dueDate,
    this.returnedAt,
    this.confirmedAt,
    this.currentPenaltyBDT = 0.0,
    this.depositBDT = 0.0,
    this.damageClaimed = false,
    this.claimedDamageCostBDT = 0.0,
    this.disputeStatus = 'none',
  });

  String get overdueDisplayString {
    final days = dueDate.difference(DateTime.now()).inDays;
    if (days < 0) {
      return 'Overdue ${days.abs()} days';
    }
    return 'Due ${days}d';
  }

  String get penaltyWarning {
    if (status == 'severely_overdue') return 'SEVERELY OVERDUE';
    if (status == 'overdue') return 'Penalties accruing';
    return '';
  }

  int get daysUntilDue => dueDate.difference(DateTime.now()).inDays;

  Future<Map<String, dynamic>> getTerms() async {
    return await Supabase.instance.client
        .from('loan_terms_borrow')
        .select()
        .eq('listing_id', listingId)
        .single();
  }
}