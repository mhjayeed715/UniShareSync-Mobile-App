// Sell transaction
class Transaction {
  final String id;
  final String listingId;
  final String listingTitle;
  final String sellerId;
  final String buyerId;
  final String sellerName;
  final String buyerName;
  final double amountBdt;
  final String status; // pending|approved|meetup_arranged|sold|completed|cancelled
  final DateTime? meetupConfirmedAt;
  final DateTime? completedAt;
  final DateTime createdAt;

  const Transaction({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.sellerId,
    required this.buyerId,
    required this.sellerName,
    required this.buyerName,
    required this.amountBdt,
    required this.status,
    this.meetupConfirmedAt,
    this.completedAt,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
        id: j['id'] as String,
        listingId: j['listing_id'] as String,
        listingTitle: j['listing_title'] as String,
        sellerId: j['seller_id'] as String,
        buyerId: j['buyer_id'] as String,
        sellerName: j['seller_name'] as String,
        buyerName: j['buyer_name'] as String,
        amountBdt: (j['amount_bdt'] as num).toDouble(),
        status: j['status'] as String,
        meetupConfirmedAt: j['meetup_confirmed_at'] != null
            ? DateTime.parse(j['meetup_confirmed_at'] as String)
            : null,
        completedAt: j['completed_at'] != null
            ? DateTime.parse(j['completed_at'] as String)
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'listing_id': listingId,
        'listing_title': listingTitle,
        'seller_id': sellerId,
        'buyer_id': buyerId,
        'seller_name': sellerName,
        'buyer_name': buyerName,
        'amount_bdt': amountBdt,
        'status': status,
        'meetup_confirmed_at': meetupConfirmedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
      };
}

// Sell negotiation message (max 3 per transaction)
class ExchangeMessage {
  final String id;
  final String transactionId;
  final String senderId;
  final String message;
  final DateTime createdAt;

  const ExchangeMessage({
    required this.id,
    required this.transactionId,
    required this.senderId,
    required this.message,
    required this.createdAt,
  });

  factory ExchangeMessage.fromJson(Map<String, dynamic> j) => ExchangeMessage(
        id: j['id'] as String,
        transactionId: j['transaction_id'] as String,
        senderId: j['sender_id'] as String,
        message: j['message'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'transaction_id': transactionId,
        'sender_id': senderId,
        'message': message,
      };
}

// Rating — tied to exchange_request (covers both borrow/rent and sell)
class ExchangeRating {
  final String id;
  final String requestId;
  final String fromUserId;
  final String toUserId;
  final int stars; // 1–5
  final String? review;
  final DateTime createdAt;

  const ExchangeRating({
    required this.id,
    required this.requestId,
    required this.fromUserId,
    required this.toUserId,
    required this.stars,
    this.review,
    required this.createdAt,
  });

  factory ExchangeRating.fromJson(Map<String, dynamic> j) => ExchangeRating(
        id: j['id'] as String,
        requestId: j['request_id'] as String,
        fromUserId: j['from_user_id'] as String,
        toUserId: j['to_user_id'] as String,
        stars: j['stars'] as int,
        review: j['review'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'request_id': requestId,
        'from_user_id': fromUserId,
        'to_user_id': toUserId,
        'stars': stars,
        'review': review,
      };
}
