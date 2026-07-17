import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/features/item_share/models/listing.dart';
import 'package:unisharesync_mobile_app/features/item_share/models/dispute.dart';
import 'package:unisharesync_mobile_app/features/item_share/services/listing_service.dart';
import 'package:unisharesync_mobile_app/features/item_share/campus_share_create_screen.dart';

class AdminCampusShareScreen extends StatefulWidget {
  const AdminCampusShareScreen({super.key});

  @override
  State<AdminCampusShareScreen> createState() => _AdminCampusShareScreenState();
}

class _AdminCampusShareScreenState extends State<AdminCampusShareScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _service = CampusShareService();
  final _adminId = Supabase.instance.client.auth.currentUser?.id ?? '';

  List<Listing> _listings = [];
  List<Dispute> _disputes = [];
  bool _loadingListings = true;
  bool _loadingDisputes = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadListings();
    _loadDisputes();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadListings() async {
    setState(() => _loadingListings = true);
    try {
      final list = await _service.fetchAllListingsAdmin();
      if (mounted) {
        setState(() {
          _listings = list;
          _loadingListings = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingListings = false);
      _snack('Error loading listings: $e');
    }
  }

  Future<void> _loadDisputes() async {
    setState(() => _loadingDisputes = true);
    try {
      final list = await _service.fetchAllDisputes();
      if (mounted) {
        setState(() {
          _disputes = list;
          _loadingDisputes = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingDisputes = false);
      _snack('Error loading disputes: $e');
    }
  }

  Future<void> _approveListing(Listing listing) async {
    try {
      final updated = Listing(
        id: listing.id,
        userId: listing.userId,
        title: listing.title,
        description: listing.description,
        category: listing.category,
        condition: listing.condition,
        semesterTags: listing.semesterTags,
        photos: listing.photos,
        type: listing.type,
        status: listing.status,
        trustScoreRequired: listing.trustScoreRequired,
        adminApproved: true,
        isDraft: listing.isDraft,
        createdAt: listing.createdAt,
        updatedAt: DateTime.now(),
      );
      await _service.updateListing(updated);
      _snack('Listing approved successfully.');
      _loadListings();
    } catch (e) {
      _snack('Approval failed: $e');
    }
  }

  Future<void> _deleteListing(Listing listing) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Listing?'),
        content: Text('Are you sure you want to permanently delete "${listing.title}"?'),
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
    if (confirm != true) return;
    try {
      await _service.deleteListing(listing.id);
      _snack('Listing deleted.');
      _loadListings();
    } catch (e) {
      _snack('Deletion failed: $e');
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'CampusShare Moderation',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFF8B5CF6),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF8B5CF6),
          tabs: const [
            Tab(text: 'Listings'),
            Tab(text: 'Disputes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _ListingsTab(
            listings: _listings,
            loading: _loadingListings,
            onApprove: _approveListing,
            onEdit: (listing) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CampusShareCreateScreen(listing: listing),
              ),
            ).then((_) => _loadListings()),
            onDelete: _deleteListing,
            onRefresh: _loadListings,
          ),
          _DisputesTab(
            disputes: _disputes,
            loading: _loadingDisputes,
            onResolve: (dispute, status, comment) async {
              try {
                await _service.resolveDispute(
                  disputeId: dispute.id,
                  status: status,
                  adminComment: comment,
                  adminId: _adminId,
                );
                _snack('Dispute resolved successfully!');
                _loadDisputes();
              } catch (e) {
                _snack('Failed to resolve dispute: $e');
              }
            },
            onRefresh: _loadDisputes,
          ),
        ],
      ),
    );
  }
}

// ── Listings Tab ─────────────────────────────────────────────────────────────
class _ListingsTab extends StatefulWidget {
  const _ListingsTab({
    required this.listings,
    required this.loading,
    required this.onApprove,
    required this.onEdit,
    required this.onDelete,
    required this.onRefresh,
  });
  final List<Listing> listings;
  final bool loading;
  final Function(Listing) onApprove;
  final Function(Listing) onEdit;
  final Function(Listing) onDelete;
  final VoidCallback onRefresh;

  @override
  State<_ListingsTab> createState() => _ListingsTabState();
}

class _ListingsTabState extends State<_ListingsTab> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = widget.listings
        .where((l) => _showAll ? true : !l.adminApproved)
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _showAll ? 'All Listings' : 'Pending Approval',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Row(
                children: [
                  const Text('Show All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Switch(
                    value: _showAll,
                    onChanged: (v) => setState(() => _showAll = v),
                    activeThumbColor: const Color(0xFF8B5CF6),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _showAll
                        ? 'No listings found.'
                        : 'No listings pending approval!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => widget.onRefresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final l = filtered[i];
                      return _ListingAdminCard(
                        listing: l,
                        onApprove: () => widget.onApprove(l),
                        onEdit: () => widget.onEdit(l),
                        onDelete: () => widget.onDelete(l),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _ListingAdminCard extends StatelessWidget {
  const _ListingAdminCard({
    required this.listing,
    required this.onApprove,
    required this.onEdit,
    required this.onDelete,
  });
  final Listing listing;
  final VoidCallback onApprove;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final typeColor = switch (listing.type) {
      ListingType.borrow => const Color(0xFF2196F3),
      ListingType.rent => const Color(0xFF8B5CF6),
      ListingType.sell => const Color(0xFF10B981),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F9EFF).withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  listing.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  listing.type.name,
                  style: TextStyle(
                      color: typeColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            listing.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_rounded, size: 16, color: Colors.red),
                label: const Text('Delete', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFFF97316)),
                label: const Text('Edit', style: TextStyle(color: Color(0xFFF97316), fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              if (!listing.adminApproved)
                FilledButton.icon(
                  onPressed: onApprove,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                  label: const Text('Approve', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Disputes Tab ─────────────────────────────────────────────────────────────
class _DisputesTab extends StatefulWidget {
  const _DisputesTab({
    required this.disputes,
    required this.loading,
    required this.onResolve,
    required this.onRefresh,
  });
  final List<Dispute> disputes;
  final bool loading;
  final Function(Dispute, String, String) onResolve;
  final VoidCallback onRefresh;

  @override
  State<_DisputesTab> createState() => _DisputesTabState();
}

class _DisputesTabState extends State<_DisputesTab> {
  bool _showAll = false;

  void _openDisputeDetails(Dispute dispute) {
    final commentCtrl = TextEditingController(text: dispute.adminComment);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resolve Dispute #${dispute.id.substring(0, 8)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              _InfoRow(label: 'Item', value: dispute.listingTitle),
              _InfoRow(label: 'Dispute Type', value: dispute.type.name),
              _InfoRow(label: 'Declared Cost', value: 'BDT ${dispute.declaredCostBdt.toStringAsFixed(0)}'),
              _InfoRow(label: 'Lender', value: dispute.lenderName),
              _InfoRow(label: 'Borrower', value: dispute.borrowerName),
              const SizedBox(height: 12),
              if (dispute.evidencePhotos.isNotEmpty) ...[
                const Text('Evidence Photos:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: dispute.evidencePhotos.length,
                    itemBuilder: (_, idx) => Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          dispute.evidencePhotos[idx],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image, size: 20),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text('Admin Comment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: commentCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Enter internal notes or comments…',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onResolve(dispute, 'resolved_borrower_favor', commentCtrl.text.trim());
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2196F3),
                      side: const BorderSide(color: Color(0xFF2196F3)),
                    ),
                    child: const Text('Borrower Favor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onResolve(dispute, 'resolved_mutual', commentCtrl.text.trim());
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFF64748B)),
                    ),
                    child: const Text('Mutual', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onResolve(dispute, 'resolved_lender_favor', commentCtrl.text.trim());
                    },
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                    child: const Text('Lender Favor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = widget.disputes
        .where((d) => _showAll ? true : d.status == DisputeStatus.open || d.status == DisputeStatus.underReview)
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _showAll ? 'All Disputes' : 'Active Disputes',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Row(
                children: [
                  const Text('Show All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Switch(
                    value: _showAll,
                    onChanged: (v) => setState(() => _showAll = v),
                    activeThumbColor: const Color(0xFF8B5CF6),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _showAll ? 'No disputes found.' : 'No active disputes!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => widget.onRefresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final d = filtered[i];
                      return GestureDetector(
                        onTap: () => _openDisputeDetails(d),
                        child: _DisputeCard(dispute: d),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _DisputeCard extends StatelessWidget {
  const _DisputeCard({required this.dispute});
  final Dispute dispute;

  Color get _statusColor => switch (dispute.status) {
        DisputeStatus.resolvedLenderFavor ||
        DisputeStatus.resolvedBorrowerFavor ||
        DisputeStatus.resolvedMutual =>
          const Color(0xFF64748B),
        DisputeStatus.underReview => const Color(0xFFF97316),
        _ => const Color(0xFFEF4444),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F9EFF).withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dispute #${dispute.id.substring(0, 8)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  dispute.status.name,
                  style: TextStyle(
                      color: _statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _InfoRow(label: 'Item', value: dispute.listingTitle),
          _InfoRow(label: 'Type', value: dispute.type.name),
          _InfoRow(label: 'Borrower', value: dispute.borrowerName),
          _InfoRow(label: 'Lender', value: dispute.lenderName),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}
