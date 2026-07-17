import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/listing.dart';
import 'models/loan.dart';
import 'models/trust_score.dart';
import 'services/listing_service.dart';
import 'campus_share_browse_screen.dart';
import 'campus_share_create_screen.dart';
import 'campus_share_my_loans_screen.dart';
import 'campus_share_detail_screen.dart';
import 'campus_share_request_details_screen.dart';

class CampusShareHomeScreen extends StatefulWidget {
  const CampusShareHomeScreen({super.key});

  @override
  State<CampusShareHomeScreen> createState() => _CampusShareHomeScreenState();
}

class _CampusShareHomeScreenState extends State<CampusShareHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _service = CampusShareService();
  final _uid = Supabase.instance.client.auth.currentUser?.id ?? '';

  TrustScore? _trust;
  List<Listing> _myListings = [];
  List<ExchangeRequest> _sentRequests = [];
  List<ExchangeRequest> _receivedRequests = [];
  bool _loadingListings = true;
  bool _loadingRequests = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() => setState(() {}));
    _loadTabContext();
  }

  void _loadTabContext() {
    _loadTrust();
    _loadMyListings();
    _loadRequests();
  }

  Future<void> _loadTrust() async {
    final t = await _service.getTrustScore(_uid);
    if (mounted) setState(() => _trust = t);
  }

  Future<void> _loadMyListings() async {
    setState(() => _loadingListings = true);
    try {
      final rows = await Supabase.instance.client
          .from('campus_share_listings')
          .select()
          .eq('user_id', _uid)
          .order('created_at', ascending: false) as List<dynamic>;
      if (mounted) {
        setState(() {
          _myListings =
              rows.map((r) => Listing.fromJson(r as Map<String, dynamic>)).toList();
          _loadingListings = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingListings = false);
    }
  }

  Future<void> _loadRequests() async {
    setState(() => _loadingRequests = true);
    try {
      final sentRows = await Supabase.instance.client
          .from('exchange_requests')
          .select()
          .eq('borrower_id', _uid)
          .order('created_at', ascending: false) as List<dynamic>;

      final receivedRows = await Supabase.instance.client
          .from('exchange_requests')
          .select()
          .eq('lender_id', _uid)
          .order('created_at', ascending: false) as List<dynamic>;

      if (mounted) {
        setState(() {
          _sentRequests = sentRows
              .map((r) => ExchangeRequest.fromJson(r as Map<String, dynamic>))
              .toList();
          _receivedRequests = receivedRows
              .map((r) => ExchangeRequest.fromJson(r as Map<String, dynamic>))
              .toList();
          _loadingRequests = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRequests = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'CampusShare',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (_trust != null) _TrustBadge(trust: _trust!),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: const Color(0xFFF97316),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFFF97316),
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          tabs: const [
            Tab(text: 'Browse'),
            Tab(text: 'My Listings'),
            Tab(text: 'Requests'),
            Tab(text: 'My Loans'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          const CampusShareBrowseScreen(),
          _MyListingsTab(
            listings: _myListings,
            loading: _loadingListings,
            onRefresh: _loadMyListings,
          ),
          _MyRequestsTab(
            sentRequests: _sentRequests,
            receivedRequests: _receivedRequests,
            loading: _loadingRequests,
            onRefresh: _loadRequests,
          ),
          CampusShareMyLoansScreen(userId: _uid),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CampusShareCreateScreen()),
          );
          _loadMyListings();
        },
        backgroundColor: const Color(0xFFF97316),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'List Item',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ── Trust badge ───────────────────────────────────────────────────────────────
class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.trust});
  final TrustScore trust;

  Color get _color => switch (trust.tier) {
        TrustTier.trusted => const Color(0xFF4CAF50),
        TrustTier.verified => const Color(0xFF2196F3),
        TrustTier.caution => const Color(0xFFFFC107),
        TrustTier.restricted => const Color(0xFFFF9800),
        TrustTier.suspended => const Color(0xFFF44336),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, color: _color, size: 13),
          const SizedBox(width: 4),
          Text(
            '${trust.score} · ${trust.tierLabel}',
            style: TextStyle(
              color: _color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── My Listings tab ───────────────────────────────────────────────────────────
class _MyListingsTab extends StatelessWidget {
  const _MyListingsTab({
    required this.listings,
    required this.loading,
    required this.onRefresh,
  });
  final List<Listing> listings;
  final bool loading;
  final VoidCallback onRefresh;

  void _showOptions(BuildContext context, Listing listing) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                listing.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.visibility_rounded, color: Color(0xFF2196F3)),
                title: const Text('View Details', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CampusShareDetailScreen(listing: listing),
                    ),
                  ).then((_) => onRefresh());
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: Color(0xFFF97316)),
                title: const Text('Edit Listing', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CampusShareCreateScreen(listing: listing),
                    ),
                  ).then((_) => onRefresh());
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.red),
                title: const Text('Delete Listing', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Listing?'),
                      content: const Text('Are you sure you want to permanently delete this listing?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    try {
                      await CampusShareService().deleteListing(listing.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Listing deleted successfully!')),
                      );
                      onRefresh();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (listings.isEmpty) {
      return const Center(
        child: Text(
          'No listings yet.\nTap "List Item" to share something.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF64748B), height: 1.5),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: listings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final listing = listings[i];
          return GestureDetector(
            onTap: () => _showOptions(context, listing),
            child: _ListingCard(listing: listing),
          );
        },
      ),
    );
  }
}

// ── My Requests tab ───────────────────────────────────────────────────────────
class _MyRequestsTab extends StatefulWidget {
  const _MyRequestsTab({
    required this.sentRequests,
    required this.receivedRequests,
    required this.loading,
    required this.onRefresh,
  });
  final List<ExchangeRequest> sentRequests;
  final List<ExchangeRequest> receivedRequests;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  State<_MyRequestsTab> createState() => _MyRequestsTabState();
}

class _MyRequestsTabState extends State<_MyRequestsTab> with SingleTickerProviderStateMixin {
  late TabController _subTabCtrl;

  @override
  void initState() {
    super.initState();
    _subTabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _subTabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TabBar(
            controller: _subTabCtrl,
            indicatorColor: const Color(0xFFF97316),
            labelColor: const Color(0xFFF97316),
            unselectedLabelColor: const Color(0xFF64748B),
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFFFF7ED),
            ),
            tabs: const [
              Tab(text: 'Sent Requests'),
              Tab(text: 'Received Requests'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _subTabCtrl,
            children: [
              _RequestListView(
                requests: widget.sentRequests,
                emptyMessage: 'No requests sent yet.\nBrowse listings to request an item.',
                onRefresh: widget.onRefresh,
              ),
              _RequestListView(
                requests: widget.receivedRequests,
                emptyMessage: 'No requests received yet.\nOthers will request items you post.',
                onRefresh: widget.onRefresh,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RequestListView extends StatelessWidget {
  const _RequestListView({
    required this.requests,
    required this.emptyMessage,
    required this.onRefresh,
  });
  final List<ExchangeRequest> requests;
  final String emptyMessage;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF64748B), height: 1.5),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final req = requests[i];
          return GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CampusShareRequestDetailsScreen(request: req),
                ),
              );
              onRefresh();
            },
            child: _RequestCard(request: req),
          );
        },
      ),
    );
  }
}

// ── Listing card ──────────────────────────────────────────────────────────────
class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.listing});
  final Listing listing;

  Color get _typeColor => switch (listing.type) {
        ListingType.borrow => const Color(0xFF2196F3),
        ListingType.rent => const Color(0xFF8B5CF6),
        ListingType.sell => const Color(0xFF10B981),
      };

  String get _typeLabel => switch (listing.type) {
        ListingType.borrow => 'Borrow',
        ListingType.rent => 'Rent',
        ListingType.sell => 'Sell',
      };

  Color get _statusColor {
    if (listing.status == ListingStatus.active) return const Color(0xFF10B981);
    if (listing.status == ListingStatus.available) return const Color(0xFF2196F3);
    return const Color(0xFF64748B);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.95)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F9EFF).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _typeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.inventory_2_rounded, color: _typeColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _Chip(label: _typeLabel, color: _typeColor),
                    const SizedBox(width: 6),
                    _Chip(
                      label: listing.status.name,
                      color: _statusColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Request card ──────────────────────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});
  final ExchangeRequest request;

  Color get _statusColor {
    return switch (request.status) {
      'active' => const Color(0xFF10B981),
      'overdue' || 'severely_overdue' => const Color(0xFFEF4444),
      'completed' => const Color(0xFF64748B),
      _ => const Color(0xFF2196F3),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.95)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F9EFF).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.swap_horiz_rounded, color: _statusColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Request #${request.id.substring(0, 8)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _Chip(label: request.status, color: _statusColor),
                    if (request.daysOverdue > 0) ...[
                      const SizedBox(width: 6),
                      _Chip(
                        label: '${request.daysOverdue}d overdue',
                        color: const Color(0xFFEF4444),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared chip widget ────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
