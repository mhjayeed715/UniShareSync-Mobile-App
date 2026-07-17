import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/listing.dart';
import '../models/loan.dart';
import '../models/dispute.dart';
import '../models/transaction.dart';
import '../models/trust_score.dart';

class CampusShareService {
  final SupabaseClient _db = Supabase.instance.client;

  // ── Listings ──────────────────────────────────────────────────

  Future<Listing> createListing(Listing listing) async {
    final trust = await getTrustScore(listing.userId);
    if (trust != null && !trust.canCreateListing) {
      throw Exception('Trust score too low to create listings (tier: ${trust.tierLabel})');
    }
    final needsApproval = trust?.listingNeedsAdminApproval ?? false;

    // Duplicate detection: same owner + same title + same category
    final dupe = await _db
        .from('campus_share_listings')
        .select('id')
        .eq('user_id', listing.userId)
        .eq('title', listing.title)
        .eq('category', Listing.toSnake(listing.category.name))
        .eq('status', 'available')
        .maybeSingle();
    if (dupe != null) {
      throw DuplicateListingException(
          'You already have an available listing with this title and category.');
    }

    final row = listing.toJson()
      ..['admin_approved'] = !needsApproval
      ..['is_draft'] = false;

    final response =
        await _db.from('campus_share_listings').insert(row).select().single();
    final l = Listing.fromJson(response);
    return _enrichSingleListing(l);
  }

  Future<List<Listing>> fetchListings({
    String? keyword,
    ItemCategory? category,
    ListingType? type,
    ItemCondition? condition,
    List<String>? semesterTags,
    String? status,
  }) async {
    var q = _db
        .from('campus_share_listings')
        .select()
        .eq('is_draft', false)
        .eq('admin_approved', true);

    if (keyword != null && keyword.isNotEmpty) {
      q = q.or('title.ilike.%$keyword%,description.ilike.%$keyword%');
    }
    if (category != null) q = q.eq('category', Listing.toSnake(category.name));
    if (type != null) q = q.eq('type', type.name);
    if (condition != null) q = q.eq('condition', Listing.toSnake(condition.name));
    if (status != null) q = q.eq('status', status);
    if (semesterTags != null && semesterTags.isNotEmpty) {
      q = q.contains('semester_tags', semesterTags);
    }

    final rows = await q.order('updated_at', ascending: false).limit(50)
        as List<dynamic>;
    final listings = rows.map((r) => Listing.fromJson(r as Map<String, dynamic>)).toList();
    return _enrichListings(listings);
  }

  Future<Listing?> getListingById(String id) async {
    final row = await _db
        .from('campus_share_listings')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    final l = Listing.fromJson(row);
    return _enrichSingleListing(l);
  }

  Future<void> updateListing(Listing listing) async {
    await _db.from('campus_share_listings').update({
      'title': listing.title,
      'description': listing.description,
      'category': Listing.toSnake(listing.category.name),
      'condition': Listing.toSnake(listing.condition.name),
      'semester_tags': listing.semesterTags,
      'photos': listing.photos,
      'type': listing.type.name,
      'status': Listing.toSnake(listing.status.name),
      'trust_score_required': listing.trustScoreRequired,
      'admin_approved': listing.adminApproved,
      'is_draft': listing.isDraft,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', listing.id);
  }

  Future<void> deleteListing(String listingId) async {
    final listing = await getListingById(listingId);
    if (listing == null) return;
    if (listing.status != ListingStatus.available &&
        listing.status != ListingStatus.cancelled &&
        listing.status != ListingStatus.completed &&
        listing.status != ListingStatus.sold) {
      throw Exception('Cannot delete a listing with active requests or loans (status: ${listing.status.name}).');
    }
    await _db.from('campus_share_listings').delete().eq('id', listingId);
  }

  Future<List<Listing>> fetchAllListingsAdmin() async {
    final rows = await _db
        .from('campus_share_listings')
        .select()
        .order('created_at', ascending: false) as List<dynamic>;
    final listings = rows.map((r) => Listing.fromJson(r as Map<String, dynamic>)).toList();
    return _enrichListings(listings);
  }

  Future<void> updateListingStatus(String id, String status) async {
    await _db.from('campus_share_listings').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // ── Requests ──────────────────────────────────────────────────

  Future<ExchangeRequest> createRequest({
    required String listingId,
    required String borrowerId,
    required String lenderId,
  }) async {
    // Trust score gate
    final trust = await getTrustScore(borrowerId);
    if (trust != null && !trust.canBorrow) {
      throw Exception('Trust score too low to borrow (tier: ${trust.tierLabel})');
    }

    // Concurrent active loans check
    final maxLoans = trust?.maxConcurrentBorrows ?? 3;
    final activeCount = await _db
        .from('exchange_requests')
        .select('id')
        .eq('borrower_id', borrowerId)
        .inFilter('status', ['active', 'overdue', 'severely_overdue', 'approved',
            'agreement_pending', 'return_initiated', 'disputed']);
    if ((activeCount as List).length >= maxLoans) {
      throw Exception(
          'You already have $maxLoans active loan(s). Return an item before borrowing more.');
    }

    final row = await _db.from('exchange_requests').insert({
      'listing_id': listingId,
      'borrower_id': borrowerId,
      'lender_id': lenderId,
      'status': 'requested',
    }).select().single();

    await updateListingStatus(listingId, 'requested');
    final request = ExchangeRequest.fromJson(row);

    // Push notification to lender
    final listing = await getListingById(listingId);
    final isSell = listing?.type == ListingType.sell;
    final action = isSell ? 'buy' : (listing?.type == ListingType.rent ? 'rent' : 'borrow');
    await _sendPush(
      userId: lenderId,
      title: 'New Item Request',
      body: 'Someone requested to $action your item "${listing?.title ?? 'Item'}".',
      type: 'item_share_request',
      data: {'requestId': request.id, 'listingId': listingId},
    );

    return request;
  }

  Future<ExchangeRequest> approveRequest(String requestId) async {
    final reqRow = await _db.from('exchange_requests').select('listing_id, borrower_id').eq('id', requestId).single();
    final listing = await getListingById(reqRow['listing_id'] as String);
    final isSell = listing?.type == ListingType.sell;
    
    final nextStatus = isSell ? 'approved' : 'agreement_pending';

    final row = await _db
        .from('exchange_requests')
        .update({'status': nextStatus})
        .eq('id', requestId)
        .select()
        .single();
    final request = ExchangeRequest.fromJson(row);

    // Push notification to borrower
    await _sendPush(
      userId: request.borrowerId,
      title: isSell ? 'Purchase Request Approved' : 'Request Approved',
      body: isSell 
          ? 'The seller approved your purchase request for "${listing?.title}".'
          : 'Your request for "${listing?.title}" was approved. Please sign the agreement.',
      type: isSell ? 'item_sell_approved' : 'item_share_approved',
      data: {'requestId': request.id, 'listingId': request.listingId},
    );

    return request;
  }

  Future<void> declineRequest(String requestId) async {
    final reqRow = await _db.from('exchange_requests').update({'status': 'cancelled'}).eq('id', requestId).select().single();
    final request = ExchangeRequest.fromJson(reqRow);
    await updateListingStatus(request.listingId, 'available');

    // Notify borrower
    final listing = await getListingById(request.listingId);
    await _sendPush(
      userId: request.borrowerId,
      title: 'Request Declined',
      body: 'Your request for "${listing?.title}" was declined.',
      type: 'item_share_declined',
      data: {'requestId': requestId, 'listingId': request.listingId},
    );
  }

  Future<void> cancelRequestByBorrower(String requestId) async {
    final reqRow = await _db.from('exchange_requests')
        .update({'status': 'cancelled'})
        .eq('id', requestId)
        .select()
        .single();
    final request = ExchangeRequest.fromJson(reqRow);
    await updateListingStatus(request.listingId, 'available');

    final listing = await getListingById(request.listingId);
    await _sendPush(
      userId: request.lenderId,
      title: 'Request Cancelled',
      body: 'The borrower cancelled their request for "${listing?.title}".',
      type: 'item_share_cancelled',
      data: {'requestId': requestId, 'listingId': request.listingId},
    );
  }

  // ── Agreements ────────────────────────────────────────────────

  Future<ExchangeAgreement> signAgreement({
    required String requestId,
    required String borrowerId,
    required String agreementText,
    required DateTime agreedReturnDate,
  }) async {
    // Save immutable snapshot
    final agreementRow = await _db.from('exchange_agreements').insert({
      'request_id': requestId,
      'borrower_id': borrowerId,
      'agreement_text': agreementText,
    }).select().single();

    // Update request: mark signed, set agreed_return_date, advance status
    final reqRow = await _db.from('exchange_requests').update({
      'status': 'approved',
      'agreement_accepted_at': DateTime.now().toIso8601String(),
      'agreement_text_snapshot': agreementText,
      'agreed_return_date': agreedReturnDate.toIso8601String(),
    }).eq('id', requestId).select().single();

    final request = ExchangeRequest.fromJson(reqRow);
    final listing = await getListingById(request.listingId);

    // Notify lender
    await _sendPush(
      userId: request.lenderId,
      title: 'Agreement Signed',
      body: 'Borrower signed the agreement for "${listing?.title}". You can now hand over the item.',
      type: 'item_share_signed',
      data: {'requestId': requestId, 'listingId': request.listingId},
    );

    return ExchangeAgreement.fromJson(agreementRow);
  }

  // ── Loans ─────────────────────────────────────────────────────

  Future<ActiveLoan> activateLoan({
    required String requestId,
    required String listingId,
    required String borrowerId,
    required String lenderId,
    required DateTime dueDate,
    double depositPaidBdt = 0.0,
  }) async {
    final row = await _db.from('loans').insert({
      'request_id': requestId,
      'listing_id': listingId,
      'borrower_id': borrowerId,
      'lender_id': lenderId,
      'status': 'active',
      'due_date': dueDate.toIso8601String(),
      'deposit_paid_bdt': depositPaidBdt,
    }).select().single();

    await _db.from('exchange_requests')
        .update({'status': 'active'}).eq('id', requestId);
    await updateListingStatus(listingId, 'active');

    final listing = await getListingById(listingId);
    // Notify borrower
    await _sendPush(
      userId: borrowerId,
      title: 'Loan Activated',
      body: 'Your loan for "${listing?.title}" is now active. Due date is ${dueDate.day}/${dueDate.month}/${dueDate.year}.',
      type: 'item_share_activated',
      data: {'requestId': requestId, 'listingId': listingId},
    );

    return ActiveLoan.fromJson(row);
  }

  Future<void> initiateReturn(String loanId, String borrowerId) async {
    final row = await _db.from('loans')
        .update({'status': 'return_initiated', 'returned_at': DateTime.now().toIso8601String()})
        .eq('id', loanId)
        .eq('borrower_id', borrowerId)
        .select()
        .single();

    await _db.from('exchange_requests')
        .update({'status': 'return_initiated'})
        .eq('id', row['request_id']);

    // Notify lender
    final listing = await getListingById(row['listing_id'] as String);
    await _sendPush(
      userId: row['lender_id'] as String,
      title: 'Return Initiated',
      body: 'Borrower has marked "${listing?.title}" as returned. Please confirm receipt.',
      type: 'item_share_return_initiated',
      data: {'loanId': loanId, 'listingId': row['listing_id']},
    );
  }

  Future<void> confirmReturn({
    required String loanId,
    required String lenderId,
    required ReturnCondition condition,
    double damageCostBdt = 0.0,
    List<String> evidencePhotos = const [],
  }) async {
    final row = await _db.from('loans').update({
      'status': condition == ReturnCondition.fine ? 'return_confirmed' : 'disputed',
      'confirmed_at': DateTime.now().toIso8601String(),
      'return_condition': condition.name,
      if (condition != ReturnCondition.fine) 'damage_claimed': true,
      if (condition != ReturnCondition.fine) 'claimed_damage_cost': damageCostBdt,
    }).eq('id', loanId).eq('lender_id', lenderId).select().single();

    final reqStatus = condition == ReturnCondition.fine ? 'completed' : 'disputed';
    await _db.from('exchange_requests')
        .update({'status': reqStatus})
        .eq('id', row['request_id']);

    await updateListingStatus(row['listing_id'] as String, condition == ReturnCondition.fine ? 'available' : 'disputed');

    final listing = await getListingById(row['listing_id'] as String);

    if (condition != ReturnCondition.fine) {
      final profiles = await _db.from('profiles')
          .select('id, full_name')
          .inFilter('id', [row['borrower_id'] as String, lenderId]);

      String lenderName = 'Lender';
      String borrowerName = 'Borrower';
      for (final p in profiles) {
        if (p['id'] == lenderId) {
          lenderName = p['full_name'] as String? ?? 'Lender';
        } else if (p['id'] == row['borrower_id']) {
          borrowerName = p['full_name'] as String? ?? 'Borrower';
        }
      }

      final type = condition == ReturnCondition.notReturned ? DisputeType.nonReturn : DisputeType.damage;
      final finalPhotos = condition == ReturnCondition.damaged && evidencePhotos.isEmpty
          ? ['https://via.placeholder.com/150']
          : evidencePhotos;

      await openDispute(
        loanId: loanId,
        listingTitle: listing?.title ?? 'Unknown Item',
        lenderId: lenderId,
        lenderName: lenderName,
        borrowerId: row['borrower_id'] as String,
        borrowerName: borrowerName,
        type: type,
        declaredCostBdt: damageCostBdt > 0 ? damageCostBdt : ((row['deposit_paid_bdt'] as num?)?.toDouble() ?? 0.0),
        evidencePhotos: finalPhotos,
      );
    }

    // Notify borrower
    await _sendPush(
      userId: row['borrower_id'] as String,
      title: condition == ReturnCondition.fine ? 'Return Confirmed' : 'Dispute Opened',
      body: condition == ReturnCondition.fine
          ? 'Your return for "${listing?.title}" was confirmed.'
          : 'Lender reported issues with "${listing?.title}". A dispute has been opened for admin review.',
      type: 'item_share_return_confirmed',
      data: {'loanId': loanId, 'listingId': row['listing_id']},
    );
  }

  Future<List<ActiveLoan>> getActiveLoans(String userId) async {
    final rows = await _db
        .from('loans')
        .select()
        .or('borrower_id.eq.$userId,lender_id.eq.$userId')
        .inFilter('status', ['active', 'overdue', 'severely_overdue', 'return_initiated', 'disputed'])
        as List<dynamic>;
    
    final loans = rows.map((r) => ActiveLoan.fromJson(r as Map<String, dynamic>)).toList();
    if (loans.isEmpty) return loans;

    try {
      final listingIds = loans.map((l) => l.listingId).toSet().toList();
      final userIds = loans.expand((l) => [l.borrowerId, l.lenderId]).toSet().toList();

      final listings = await _db.from('campus_share_listings').select('id, title').inFilter('id', listingIds);
      final profiles = await _db.from('profiles').select('id, full_name').inFilter('id', userIds);

      final listingMap = {for (final row in listings as List<dynamic>) row['id'] as String: row['title'] as String};
      final profileMap = {for (final row in profiles as List<dynamic>) row['id'] as String: row['full_name'] as String};

      return loans.map((l) {
        return ActiveLoan(
          id: l.id,
          requestId: l.requestId,
          listingId: l.listingId,
          borrowerId: l.borrowerId,
          lenderId: l.lenderId,
          status: l.status,
          startedAt: l.startedAt,
          dueDate: l.dueDate,
          returnedAt: l.returnedAt,
          confirmedAt: l.confirmedAt,
          daysOverdue: l.daysOverdue,
          currentPenaltyBdt: l.currentPenaltyBdt,
          depositPaidBdt: l.depositPaidBdt,
          damageClaimed: l.damageClaimed,
          claimedDamageCost: l.claimedDamageCost,
          returnCondition: l.returnCondition,
          listingTitle: listingMap[l.listingId] ?? 'Item',
          borrowerName: profileMap[l.borrowerId] ?? 'Borrower',
          lenderName: profileMap[l.lenderId] ?? 'Lender',
        );
      }).toList();
    } catch (e) {
      return loans;
    }
  }

  // ── Disputes ──────────────────────────────────────────────────

  Future<Dispute> openDispute({
    required String loanId,
    required String listingTitle,
    required String lenderId,
    required String lenderName,
    required String borrowerId,
    required String borrowerName,
    required DisputeType type,
    required double declaredCostBdt,
    required List<String> evidencePhotos,
  }) async {
    if (type == DisputeType.damage && evidencePhotos.isEmpty) {
      throw Exception('At least 1 evidence photo is required to open a damage dispute.');
    }
    final row = await _db.from('disputes').insert({
      'loan_id': loanId,
      'listing_title': listingTitle,
      'lender_id': lenderId,
      'lender_name': lenderName,
      'borrower_id': borrowerId,
      'borrower_name': borrowerName,
      'type': type == DisputeType.nonReturn ? 'non_return' : 'damage',
      'declared_cost_bdt': declaredCostBdt,
      'evidence_photos': evidencePhotos,
    }).select().single();
    return Dispute.fromJson(row);
  }

  Future<void> resolveDispute({
    required String disputeId,
    required String status,
    required String adminComment,
    required String adminId,
  }) async {
    final row = await _db.from('disputes').update({
      'status': status,
      'admin_comment': adminComment,
      'resolved_by': adminId,
      'resolved_at': DateTime.now().toIso8601String(),
    }).eq('id', disputeId).select().single();

    final loanId = row['loan_id'] as String;
    final loanRow = await _db.from('loans').select().eq('id', loanId).single();
    final requestId = loanRow['request_id'] as String;
    final listingId = loanRow['listing_id'] as String;

    await _db.from('loans').update({'status': 'completed'}).eq('id', loanId);
    await _db.from('exchange_requests').update({'status': 'completed'}).eq('id', requestId);
    await updateListingStatus(listingId, 'available');
  }

  Future<void> endDisputeByLender({
    required String loanId,
    required String lenderId,
  }) async {
    final loanRow = await _db.from('loans')
        .select()
        .eq('id', loanId)
        .eq('lender_id', lenderId)
        .single();
    final requestId = loanRow['request_id'] as String;
    final listingId = loanRow['listing_id'] as String;

    await _db.from('disputes').update({
      'status': 'resolved_mutual',
      'admin_comment': 'Resolved directly by lender.',
      'resolved_at': DateTime.now().toIso8601String(),
    }).eq('loan_id', loanId);

    await _db.from('loans').update({'status': 'completed'}).eq('id', loanId);
    await _db.from('exchange_requests').update({'status': 'completed'}).eq('id', requestId);
    await updateListingStatus(listingId, 'available');
  }

  Future<List<Dispute>> fetchAllDisputes() async {
    final rows = await _db
        .from('disputes')
        .select()
        .order('created_at', ascending: false) as List<dynamic>;
    return rows.map((r) => Dispute.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<void> completeSale({
    required String requestId,
    required String listingId,
    required String buyerId,
  }) async {
    await _db.from('exchange_requests').update({'status': 'completed'}).eq('id', requestId);
    await updateListingStatus(listingId, 'sold');

    final listing = await getListingById(listingId);
    await _sendPush(
      userId: buyerId,
      title: 'Purchase Completed',
      body: 'Your purchase of "${listing?.title}" has been completed.',
      type: 'item_sell_completed',
      data: {'requestId': requestId, 'listingId': listingId},
    );
  }

  Future<void> _sendPush({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
    bool skipInApp = false,
  }) async {
    try {
      await _db.functions.invoke(
        'send-push-notification',
        body: {
          'type': type,
          'title': title,
          'body': body,
          'userId': userId,
          'skipInApp': skipInApp,
          if (data != null) 'data': data,
        },
      );
    } catch (e) {
      print('ERROR [Push] Failed to send campus share notification: $e');
    }
  }

  // ── Ratings ───────────────────────────────────────────────────

  Future<ExchangeRating> submitRating({
    required String requestId,
    required String fromUserId,
    required String toUserId,
    required int stars,
    String? review,
  }) async {
    final row = await _db.from('exchange_ratings').insert({
      'request_id': requestId,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'stars': stars,
      'review': review,
    }).select().single();
    return ExchangeRating.fromJson(row);
  }

  // ── Transactions (Sell) ───────────────────────────────────────

  Future<Transaction> createTransaction({
    required String listingId,
    required String listingTitle,
    required String sellerId,
    required String buyerId,
    required String sellerName,
    required String buyerName,
    required double amountBdt,
  }) async {
    final row = await _db.from('transactions').insert({
      'listing_id': listingId,
      'listing_title': listingTitle,
      'seller_id': sellerId,
      'buyer_id': buyerId,
      'seller_name': sellerName,
      'buyer_name': buyerName,
      'amount_bdt': amountBdt,
      'status': 'pending',
    }).select().single();
    return Transaction.fromJson(row);
  }

  Future<void> confirmMeetup(String transactionId) async {
    await _db.from('transactions').update({
      'status': 'meetup_arranged',
      'meetup_confirmed_at': DateTime.now().toIso8601String(),
    }).eq('id', transactionId);
  }

  Future<void> confirmReceived(String transactionId, String buyerId) async {
    await _db.from('transactions').update({
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', transactionId).eq('buyer_id', buyerId);
  }

  Future<ExchangeMessage> sendMessage({
    required String transactionId,
    required String senderId,
    required String message,
  }) async {
    final row = await _db.from('exchange_messages').insert({
      'transaction_id': transactionId,
      'sender_id': senderId,
      'message': message,
    }).select().single();
    return ExchangeMessage.fromJson(row);
  }

  Future<List<ExchangeMessage>> getMessages(String transactionId) async {
    final rows = await _db
        .from('exchange_messages')
        .select()
        .eq('transaction_id', transactionId)
        .order('created_at') as List<dynamic>;
    return rows.map((r) => ExchangeMessage.fromJson(r as Map<String, dynamic>)).toList();
  }

  // ── Trust Scores ──────────────────────────────────────────────

  Future<TrustScore?> getTrustScore(String userId) async {
    final row = await _db
        .from('user_trust_scores')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row != null ? TrustScore.fromJson(row) : null;
  }

  Future<List<TrustScoreHistory>> getTrustHistory(String userId) async {
    final rows = await _db
        .from('trust_score_history')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50) as List<dynamic>;
    return rows
        .map((r) => TrustScoreHistory.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<Listing>> _enrichListings(List<Listing> listings) async {
    if (listings.isEmpty) return listings;
    final userIds = listings.map((l) => l.userId).toSet().toList();
    try {
      final profiles = await _db
          .from('profiles')
          .select('id, full_name, avatar_url')
          .inFilter('id', userIds);
      
      final profileMap = {
        for (final row in profiles as List<dynamic>)
          row['id'] as String: row
      };

      return listings.map((l) {
        final prof = profileMap[l.userId];
        if (prof != null) {
          return l.copyWith(
            userName: prof['full_name'] as String?,
            userAvatarUrl: prof['avatar_url'] as String?,
          );
        }
        return l;
      }).toList();
    } catch (e) {
      print('DEBUG: Error enriching listings: $e');
      return listings;
    }
  }

  Future<Listing> _enrichSingleListing(Listing listing) async {
    final enriched = await _enrichListings([listing]);
    return enriched.first;
  }
}

class DuplicateListingException implements Exception {
  final String message;
  DuplicateListingException(this.message);
  @override
  String toString() => message;
}
