import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/listing.dart';
import 'models/loan.dart';
import 'models/dispute.dart';
import 'services/listing_service.dart';
import 'campus_share_agreement_screen.dart';
import 'dispute_details_dialog.dart';
import 'dart:typed_data';

class CampusShareRequestDetailsScreen extends StatefulWidget {
  const CampusShareRequestDetailsScreen({super.key, required this.request});
  final ExchangeRequest request;

  @override
  State<CampusShareRequestDetailsScreen> createState() =>
      _CampusShareRequestDetailsScreenState();
}

class _CampusShareRequestDetailsScreenState
    extends State<CampusShareRequestDetailsScreen> {
  final _service = CampusShareService();
  final _uid = Supabase.instance.client.auth.currentUser?.id ?? '';
  late ExchangeRequest _request;

  Listing? _listing;
  Map<String, dynamic>? _borrowerProfile;
  Map<String, dynamic>? _lenderProfile;
  ActiveLoan? _activeLoan;
  bool _loading = true;
  bool _actioning = false;

  @override
  void initState() {
    super.initState();
    _request = widget.request;
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final db = Supabase.instance.client;
    try {
      final reqRow = await db
          .from('exchange_requests')
          .select()
          .eq('id', widget.request.id)
          .single();
      final latestRequest = ExchangeRequest.fromJson(reqRow);

      final listing = await _service.getListingById(latestRequest.listingId);

      final bProf = await db
          .from('profiles')
          .select('full_name, email, role, avatar_url')
          .eq('id', latestRequest.borrowerId)
          .maybeSingle();

      final lProf = await db
          .from('profiles')
          .select('full_name, email, role, avatar_url')
          .eq('id', latestRequest.lenderId)
          .maybeSingle();

      ActiveLoan? activeLoan;
      if (latestRequest.status == 'active' ||
          latestRequest.status == 'overdue' ||
          latestRequest.status == 'severely_overdue' ||
          latestRequest.status == 'return_initiated' ||
          latestRequest.status == 'return_confirmed' ||
          latestRequest.status == 'disputed' ||
          latestRequest.status == 'completed') {
        final rows = await db
            .from('loans')
            .select()
            .eq('request_id', latestRequest.id)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (rows != null) {
          activeLoan = ActiveLoan.fromJson(rows);
        }
      }

      if (mounted) {
        setState(() {
          _request = latestRequest;
          _listing = listing;
          _borrowerProfile = bProf;
          _lenderProfile = lProf;
          _activeLoan = activeLoan;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Error loading details: $e');
      }
    }
  }

  Future<void> _approve() async {
    setState(() => _actioning = true);
    try {
      await _service.approveRequest(_request.id);
      _snack('Request approved!');
      _loadAll();
    } catch (e) {
      _snack(e.toString());
    } finally {
      setState(() => _actioning = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _actioning = true);
    try {
      await _service.declineRequest(_request.id);
      _snack('Request declined.');
      _loadAll();
    } catch (e) {
      _snack(e.toString());
    } finally {
      setState(() => _actioning = false);
    }
  }

  Future<void> _activateLoan() async {
    if (_listing == null) return;
    setState(() => _actioning = true);
    try {
      // Calculate due date based on loan days
      int days = 14;
      if (_listing!.type == ListingType.borrow) {
        final row = await Supabase.instance.client
            .from('loan_terms_borrow')
            .select('loan_duration_days')
            .eq('listing_id', _listing!.id)
            .maybeSingle();
        if (row != null) days = row['loan_duration_days'] as int;
      } else if (_listing!.type == ListingType.rent) {
        final row = await Supabase.instance.client
            .from('loan_terms_rent')
            .select('rental_duration_days')
            .eq('listing_id', _listing!.id)
            .maybeSingle();
        if (row != null) days = row['rental_duration_days'] as int;
      }

      await _service.activateLoan(
        requestId: _request.id,
        listingId: _listing!.id,
        borrowerId: _request.borrowerId,
        lenderId: _request.lenderId,
        dueDate: DateTime.now().add(Duration(days: days)),
      );
      _snack('Loan activated successfully!');
      _loadAll();
    } catch (e) {
      _snack(e.toString());
    } finally {
      setState(() => _actioning = false);
    }
  }

  Future<void> _completeSale() async {
    if (_listing == null) return;
    setState(() => _actioning = true);
    try {
      await _service.completeSale(
        requestId: _request.id,
        listingId: _listing!.id,
        buyerId: _request.borrowerId,
      );
      _snack('Sale completed!');
      _loadAll();
    } catch (e) {
      _snack(e.toString());
    } finally {
      setState(() => _actioning = false);
    }
  }

  Future<void> _initiateReturn() async {
    if (_activeLoan == null) return;
    setState(() => _actioning = true);
    try {
      await _service.initiateReturn(_activeLoan!.id, _request.borrowerId);
      _snack('Return initiated! Waiting for lender to confirm.');
      _loadAll();
    } catch (e) {
      _snack(e.toString());
    } finally {
      setState(() => _actioning = false);
    }
  }

  Future<void> _confirmReturn() async {
    if (_activeLoan == null) return;
    ReturnCondition? selected;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReturnConfirmSheet(
        onConfirm: (cond) {
          selected = cond;
          Navigator.pop(context);
        },
      ),
    );
    if (selected == null) return;

    double damageCost = 0.0;
    List<String> evidenceUrls = [];

    if (selected != ReturnCondition.fine) {
      final type = selected == ReturnCondition.notReturned
          ? DisputeType.nonReturn
          : DisputeType.damage;
      final res = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => DisputeDetailsDialog(type: type),
      );
      if (res == null) return; // cancelled

      setState(() => _actioning = true);

      damageCost = res['cost'] as double;
      final photoBytes = res['photoBytes'] as Uint8List?;
      final photoName = res['photoName'] as String?;

      if (photoBytes != null && photoName != null) {
        try {
          final path = 'disputes/$_uid/${DateTime.now().millisecondsSinceEpoch}_$photoName';
          await Supabase.instance.client.storage
              .from('campus-share-photos')
              .uploadBinary(path, photoBytes);
          final url = Supabase.instance.client.storage
              .from('campus-share-photos')
              .getPublicUrl(path);
          evidenceUrls = [url];
        } catch (storageErr) {
          _snack('Failed to upload evidence photo: $storageErr');
          setState(() => _actioning = false);
          return;
        }
      }
    } else {
      setState(() => _actioning = true);
    }

    try {
      await _service.confirmReturn(
        loanId: _activeLoan!.id,
        lenderId: _request.lenderId,
        condition: selected!,
        damageCostBdt: damageCost,
        evidencePhotos: evidenceUrls,
      );
      _snack(selected == ReturnCondition.fine
          ? 'Return confirmed. Loan completed!'
          : 'Return marked. Dispute opened for review.');
      _loadAll();
    } catch (e) {
      _snack(e.toString());
    } finally {
      setState(() => _actioning = false);
    }
  }

  Future<void> _resolveDisputeByLender() async {
    if (_activeLoan == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve Dispute?'),
        content: const Text(
            'Are you sure you want to end this dispute and mark the transaction as completed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF10B981)),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _actioning = true);
    try {
      await _service.endDisputeByLender(
        loanId: _activeLoan!.id,
        lenderId: _request.lenderId,
      );
      _snack('Dispute resolved and loan completed!');
      _loadAll();
    } catch (e) {
      _snack(e.toString());
    } finally {
      setState(() => _actioning = false);
    }
  }

  Future<void> _cancelRequestByBorrower() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Request?'),
        content: const Text('Are you sure you want to cancel this request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _actioning = true);
    try {
      await _service.cancelRequestByBorrower(_request.id);
      _snack('Request cancelled.');
      _loadAll();
    } catch (e) {
      _snack(e.toString());
    } finally {
      setState(() => _actioning = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isLender = _request.lenderId == _uid;
    final r = _request;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Request Details',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                _StatusBanner(status: r.status, isLender: isLender),
                const SizedBox(height: 16),
                if (_listing != null) ...[
                  const _SectionTitle(title: 'Item Shared'),
                  const SizedBox(height: 8),
                  _ItemCard(listing: _listing!),
                  const SizedBox(height: 16),
                ],
                const _SectionTitle(title: 'Participants'),
                const SizedBox(height: 8),
                _ParticipantsCard(
                  isLender: isLender,
                  lenderName: _lenderProfile?['full_name'] ?? 'Lender',
                  borrowerName: _borrowerProfile?['full_name'] ?? 'Borrower',
                  lenderEmail: _lenderProfile?['email'] ?? '',
                  borrowerEmail: _borrowerProfile?['email'] ?? '',
                  lenderAvatarUrl: _lenderProfile?['avatar_url']?.toString(),
                  borrowerAvatarUrl: _borrowerProfile?['avatar_url']?.toString(),
                ),
                const SizedBox(height: 16),
                if (r.agreementTextSnapshot != null) ...[
                  const _SectionTitle(title: 'Signed Agreement'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFED7AA)),
                    ),
                    child: Text(
                      r.agreementTextSnapshot!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Color(0xFF431407),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_activeLoan != null) ...[
                  const _SectionTitle(title: 'Active Loan Details'),
                  const SizedBox(height: 8),
                  _LoanDetailsCard(loan: _activeLoan!),
                  const SizedBox(height: 16),
                ],
              ],
            ),
      bottomNavigationBar: _loading || _actioning
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: _buildActionButtons(isLender),
            ),
    );
  }

  Widget _buildActionButtons(bool isLender) {
    final status = widget.request.status;
    final type = _listing?.type ?? ListingType.borrow;

    if (isLender) {
      if (status == 'requested') {
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _decline,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Decline',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _approve,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Approve',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        );
      }
      if (status == 'approved') {
        final btnText = type == ListingType.sell ? 'Confirm Sale & Handover' : 'Hand Over & Start Loan';
        final action = type == ListingType.sell ? _completeSale : _activateLoan;
        final color = type == ListingType.sell ? const Color(0xFF10B981) : const Color(0xFF2196F3);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: action,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(btnText,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _decline,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Decline / Cancel Request',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      }
      if (status == 'return_initiated') {
        return FilledButton(
          onPressed: _confirmReturn,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF97316),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('Confirm Return Receipt',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        );
      }
      if (status == 'disputed') {
        return FilledButton(
          onPressed: _resolveDisputeByLender,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('Resolve / End Dispute',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        );
      }
    } else {
      // Borrower actions
      if (status == 'requested' || status == 'approved' || status == 'agreement_pending') {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status == 'agreement_pending') ...[
              FilledButton(
                onPressed: () async {
                  if (_listing == null) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CampusShareAgreementScreen(
                        listing: _listing!,
                        request: widget.request,
                      ),
                    ),
                  );
                  _loadAll();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Review & Sign Agreement',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton(
              onPressed: _cancelRequestByBorrower,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel Request',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      }
      if ((status == 'active' || status == 'overdue' || status == 'severely_overdue') &&
          _activeLoan != null) {
        return FilledButton(
          onPressed: _initiateReturn,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF97316),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('Initiate Return',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        );
      }
    }

    return const SizedBox.shrink();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: Color(0xFF475569),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status, required this.isLender});
  final String status;
  final bool isLender;

  Color get _color => switch (status) {
        'active' => const Color(0xFF10B981),
        'overdue' || 'severely_overdue' => const Color(0xFFEF4444),
        'completed' => const Color(0xFF64748B),
        'cancelled' => const Color(0xFFDC2626),
        _ => const Color(0xFF2196F3),
      };

  String get _label => status.toUpperCase().replaceAll('_', ' ');

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: _color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STATUS: $_label',
                  style: TextStyle(
                    color: _color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isLender
                      ? 'You are the lender/seller for this exchange.'
                      : 'You are the borrower/buyer for this exchange.',
                  style: TextStyle(
                    color: _color.withOpacity(0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.listing});
  final Listing listing;

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
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.inventory_2_rounded,
                color: Color(0xFF2196F3), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  listing.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantsCard extends StatelessWidget {
  const _ParticipantsCard({
    required this.isLender,
    required this.lenderName,
    required this.borrowerName,
    required this.lenderEmail,
    required this.borrowerEmail,
    this.lenderAvatarUrl,
    this.borrowerAvatarUrl,
  });

  final bool isLender;
  final String lenderName;
  final String borrowerName;
  final String lenderEmail;
  final String borrowerEmail;
  final String? lenderAvatarUrl;
  final String? borrowerAvatarUrl;

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
        children: [
          _ParticipantRow(
            roleLabel: 'Lender / Seller',
            name: lenderName,
            email: lenderEmail,
            isSelf: isLender,
            avatarUrl: lenderAvatarUrl,
          ),
          const Divider(height: 20),
          _ParticipantRow(
            roleLabel: 'Borrower / Buyer',
            name: borrowerName,
            email: borrowerEmail,
            isSelf: !isLender,
            avatarUrl: borrowerAvatarUrl,
          ),
        ],
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.roleLabel,
    required this.name,
    required this.email,
    required this.isSelf,
    this.avatarUrl,
  });

  final String roleLabel;
  final String name;
  final String email;
  final bool isSelf;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFF64748B).withOpacity(0.1),
          backgroundImage: (avatarUrl ?? '').trim().isNotEmpty
              ? NetworkImage(avatarUrl!.trim())
              : null,
          child: (avatarUrl ?? '').trim().isNotEmpty
              ? null
              : const Icon(Icons.person_rounded,
                  color: Color(0xFF64748B), size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$roleLabel ${isSelf ? "(You)" : ""}',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                ),
              ),
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (email.isNotEmpty)
                Text(
                  email,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoanDetailsCard extends StatelessWidget {
  const _LoanDetailsCard({required this.loan});
  final ActiveLoan loan;

  @override
  Widget build(BuildContext context) {
    final start = '${loan.startedAt.day}/${loan.startedAt.month}/${loan.startedAt.year}';
    final due = '${loan.dueDate.day}/${loan.dueDate.month}/${loan.dueDate.year}';

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
        children: [
          _DetailRow(label: 'Loan Started', value: start),
          const SizedBox(height: 8),
          _DetailRow(
            label: 'Due Date',
            value: due,
            valueColor: loan.isOverdue ? Colors.red : null,
          ),
          if (loan.isOverdue) ...[
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Days Overdue',
              value: '${loan.daysOverdue} days',
              valueColor: Colors.red,
            ),
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Accrued Penalty',
              value: 'BDT ${loan.currentPenaltyBdt.toStringAsFixed(0)}',
              valueColor: Colors.red,
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 12.5)),
        Text(value,
            style: TextStyle(
                color: valueColor ?? const Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
                fontSize: 12.5)),
      ],
    );
  }
}

class _ReturnConfirmSheet extends StatelessWidget {
  const _ReturnConfirmSheet({required this.onConfirm});
  final ValueChanged<ReturnCondition> onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            const Text('How was the item returned?',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A))),
            const SizedBox(height: 16),
            _ConditionTile(
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF10B981),
              label: 'Returned Fine',
              subtitle: 'Item returned in same condition.',
              onTap: () => onConfirm(ReturnCondition.fine),
            ),
            const SizedBox(height: 8),
            _ConditionTile(
              icon: Icons.broken_image_rounded,
              color: const Color(0xFFF97316),
              label: 'Returned Damaged',
              subtitle: 'Item has damage. A dispute will be opened.',
              onTap: () => onConfirm(ReturnCondition.damaged),
            ),
            const SizedBox(height: 8),
            _ConditionTile(
              icon: Icons.block_rounded,
              color: const Color(0xFFDC2626),
              label: 'Not Returned',
              subtitle: 'Borrower did not return the item.',
              onTap: () => onConfirm(ReturnCondition.notReturned),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConditionTile extends StatelessWidget {
  const _ConditionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: color.withOpacity(0.5), size: 20),
          ],
        ),
      ),
    );
  }
}
