import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/listing.dart';
import 'models/trust_score.dart';
import 'services/listing_service.dart';
import 'campus_share_agreement_screen.dart';

class CampusShareDetailScreen extends StatefulWidget {
  const CampusShareDetailScreen({super.key, required this.listing});
  final Listing listing;

  @override
  State<CampusShareDetailScreen> createState() =>
      _CampusShareDetailScreenState();
}

class _CampusShareDetailScreenState extends State<CampusShareDetailScreen> {
  final _service = CampusShareService();
  TrustScore? _lenderTrust;
  Map<String, dynamic>? _lenderProfile;
  bool _requesting = false;
  int _photoIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadLenderTrust();
  }

  Future<void> _loadLenderTrust() async {
    final t = await _service.getTrustScore(widget.listing.userId);
    final db = Supabase.instance.client;
    Map<String, dynamic>? profile;
    try {
      profile = await db
          .from('profiles')
          .select('full_name, email, avatar_url')
          .eq('id', widget.listing.userId)
          .maybeSingle();
    } catch (e) {
      print('DEBUG: Error loading lender profile: $e');
    }
    if (mounted) {
      setState(() {
        _lenderTrust = t;
        _lenderProfile = profile;
      });
    }
  }

  Future<void> _requestItem() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    if (uid == widget.listing.userId) {
      _snack('You cannot request your own listing.');
      return;
    }
    setState(() => _requesting = true);
    try {
      final request = await _service.createRequest(
        listingId: widget.listing.id,
        borrowerId: uid,
        lenderId: widget.listing.userId,
      );
      if (!mounted) return;
      // For borrow/rent go to agreement screen; sell goes directly
      bool signed = false;
      if (widget.listing.type != ListingType.sell) {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => CampusShareAgreementScreen(
              listing: widget.listing,
              request: request,
            ),
          ),
        );
        signed = result ?? false;
      } else {
        _snack('Request sent! Waiting for seller approval.');
        signed = true;
      }
      if (signed && mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    final typeColor = switch (l.type) {
      ListingType.borrow => const Color(0xFF2196F3),
      ListingType.rent => const Color(0xFF8B5CF6),
      ListingType.sell => const Color(0xFF10B981),
    };
    final typeLabel = switch (l.type) {
      ListingType.borrow => 'Borrow',
      ListingType.rent => 'Rent',
      ListingType.sell => 'Sell',
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          l.title,
          style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
              fontSize: 17),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        children: [
          // Photo carousel
          if (l.photos.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 220,
                child: PageView.builder(
                  itemCount: l.photos.length,
                  onPageChanged: (i) => setState(() => _photoIndex = i),
                  itemBuilder: (_, i) => Image.network(
                    l.photos[i],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFE2E8F0),
                      child: const Icon(Icons.image_not_supported_rounded,
                          size: 40, color: Color(0xFF94A3B8)),
                    ),
                  ),
                ),
              ),
            ),
            if (l.photos.length > 1) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  l.photos.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _photoIndex == i ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _photoIndex == i
                          ? const Color(0xFFF97316)
                          : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
          // Title + type badge
          Row(
            children: [
              Expanded(
                child: Text(
                  l.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              _Badge(label: typeLabel, color: typeColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l.description,
            style: const TextStyle(
                color: Color(0xFF475569), height: 1.5, fontSize: 14),
          ),
          const SizedBox(height: 16),
          // Details card
          _InfoCard(children: [
            _InfoRow(
                label: 'Category',
                value: l.category.name.replaceAll(RegExp(r'(?<=[a-z])(?=[A-Z])'), ' ')),
            _InfoRow(
                label: 'Condition',
                value: l.condition.name[0].toUpperCase() +
                    l.condition.name.substring(1)),
            if (l.semesterTags.isNotEmpty)
              _InfoRow(label: 'Semesters', value: l.semesterTags.join(', ')),
            _InfoRow(label: 'Min Trust Score', value: '${l.trustScoreRequired}'),
          ]),
          const SizedBox(height: 12),
          // Lender profile
          if (_lenderProfile != null) ...[
            _LenderProfileCard(profile: _lenderProfile!),
            const SizedBox(height: 12),
          ],
          // Lender trust
          if (_lenderTrust != null)
            _InfoCard(children: [
              _InfoRow(
                label: 'Lender Trust',
                value: '${_lenderTrust!.score} · ${_lenderTrust!.tierLabel}',
                valueColor: _trustColor(_lenderTrust!.tier),
              ),
              _InfoRow(
                  label: 'Total Lends',
                  value: '${_lenderTrust!.totalLends}'),
            ]),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: l.status == ListingStatus.available
                ? typeColor
                : const Color(0xFF94A3B8),
            minimumSize: const Size.fromHeight(52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: l.status == ListingStatus.available && !_requesting
              ? _requestItem
              : null,
          child: _requesting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  l.status == ListingStatus.available
                      ? 'Request $typeLabel'
                      : 'Not Available',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
        ),
      ),
    );
  }

  Color _trustColor(TrustTier tier) => switch (tier) {
        TrustTier.trusted => const Color(0xFF4CAF50),
        TrustTier.verified => const Color(0xFF2196F3),
        TrustTier.caution => const Color(0xFFFFC107),
        TrustTier.restricted => const Color(0xFFFF9800),
        TrustTier.suspended => const Color(0xFFF44336),
      };
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

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
            color: const Color(0xFF4F9EFF).withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? const Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

class _LenderProfileCard extends StatelessWidget {
  const _LenderProfileCard({required this.profile});
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile['avatar_url']?.toString();
    final name = profile['full_name']?.toString() ?? profile['email']?.toString().split('@').first ?? 'Unknown';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.95)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F9EFF).withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFDCEBFF),
            backgroundImage: (avatarUrl ?? '').trim().isNotEmpty
                ? NetworkImage(avatarUrl!.trim())
                : null,
            child: (avatarUrl ?? '').trim().isNotEmpty
                ? null
                : Text(
                    name.isEmpty ? 'U' : name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF1D4ED8),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Listed By',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
