import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/loan.dart';
import 'models/dispute.dart';
import 'services/listing_service.dart';
import 'dispute_details_dialog.dart';
import 'dart:typed_data';

class CampusShareMyLoansScreen extends StatefulWidget {
  const CampusShareMyLoansScreen({super.key, required this.userId});
  final String userId;

  @override
  State<CampusShareMyLoansScreen> createState() =>
      _CampusShareMyLoansScreenState();
}

class _CampusShareMyLoansScreenState extends State<CampusShareMyLoansScreen> {
  final _service = CampusShareService();
  List<ActiveLoan> _loans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final loans = await _service.getActiveLoans(widget.userId);
      if (mounted) setState(() { _loans = loans; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _initiateReturn(ActiveLoan loan) async {
    try {
      await _service.initiateReturn(loan.id, widget.userId);
      _snack('Return initiated. Waiting for lender confirmation.');
      _load();
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _confirmReturn(ActiveLoan loan) async {
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

      damageCost = res['cost'] as double;
      final photoBytes = res['photoBytes'] as Uint8List?;
      final photoName = res['photoName'] as String?;

      if (photoBytes != null && photoName != null) {
        try {
          final path = 'disputes/${widget.userId}/${DateTime.now().millisecondsSinceEpoch}_$photoName';
          await Supabase.instance.client.storage
              .from('campus-share-photos')
              .uploadBinary(path, photoBytes);
          final url = Supabase.instance.client.storage
              .from('campus-share-photos')
              .getPublicUrl(path);
          evidenceUrls = [url];
        } catch (storageErr) {
          _snack('Failed to upload evidence photo: $storageErr');
          return;
        }
      }
    }

    try {
      await _service.confirmReturn(
        loanId: loan.id,
        lenderId: widget.userId,
        condition: selected!,
        damageCostBdt: damageCost,
        evidencePhotos: evidenceUrls,
      );
      _snack(selected == ReturnCondition.fine
          ? 'Return confirmed. Loan completed!'
          : 'Return marked. Dispute opened for review.');
      _load();
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _resolveDispute(ActiveLoan loan) async {
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

    try {
      await _service.endDisputeByLender(
        loanId: loan.id,
        lenderId: widget.userId,
      );
      _snack('Dispute resolved and loan completed!');
      _load();
    } catch (e) {
      _snack(e.toString());
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loans.isEmpty) {
      return const Center(
        child: Text(
          'No active loans.\nBorrow an item to see it here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF64748B), height: 1.5),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _loans.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final loan = _loans[i];
          final isBorrower = loan.borrowerId == widget.userId;
          return _LoanCard(
            loan: loan,
            isBorrower: isBorrower,
            onInitiateReturn: isBorrower &&
                    loan.status == 'active'
                ? () => _initiateReturn(loan)
                : null,
            onConfirmReturn: !isBorrower &&
                    loan.status == 'return_initiated'
                ? () => _confirmReturn(loan)
                : null,
            onResolveDispute: !isBorrower &&
                    loan.status == 'disputed'
                ? () => _resolveDispute(loan)
                : null,
          );
        },
      ),
    );
  }
}

// ── Loan card ─────────────────────────────────────────────────────────────────
class _LoanCard extends StatelessWidget {
  const _LoanCard({
    required this.loan,
    required this.isBorrower,
    this.onInitiateReturn,
    this.onConfirmReturn,
    this.onResolveDispute,
  });
  final ActiveLoan loan;
  final bool isBorrower;
  final VoidCallback? onInitiateReturn;
  final VoidCallback? onConfirmReturn;
  final VoidCallback? onResolveDispute;

  bool get _isOverdue =>
      loan.status == 'overdue' || loan.status == 'severely_overdue';

  Color get _statusColor {
    if (loan.status == 'severely_overdue') return const Color(0xFFDC2626);
    if (loan.status == 'overdue') return const Color(0xFFEF4444);
    if (loan.status == 'return_initiated') return const Color(0xFFF97316);
    if (loan.status == 'disputed') return const Color(0xFFDC2626);
    return const Color(0xFF10B981);
  }

  String get _dueLabel {
    if (loan.status == 'disputed') return 'Disputed';
    final days = loan.daysUntilDue;
    if (_isOverdue) return '${loan.daysOverdue}d overdue';
    if (days == 0) return 'Due today';
    if (days < 0) return '${days.abs()}d overdue';
    return 'Due in ${days}d';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isOverdue
            ? const Color(0xFFFEF2F2)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isOverdue
              ? const Color(0xFFFCA5A5)
              : Colors.white.withOpacity(0.95),
        ),
        boxShadow: [
          BoxShadow(
            color: _statusColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isBorrower
                      ? Icons.download_rounded
                      : Icons.upload_rounded,
                  color: _statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan.listingTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isBorrower ? 'Lender: ${loan.lenderName} · #${loan.id.substring(0, 8)}' : 'Borrower: ${loan.borrowerName} · #${loan.id.substring(0, 8)}',
                      style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _dueLabel,
                  style: TextStyle(
                      color: _statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (_isOverdue && loan.currentPenaltyBdt > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFDC2626), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Penalty accrued: BDT ${loan.currentPenaltyBdt.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
          if (onInitiateReturn != null || onConfirmReturn != null || onResolveDispute != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _statusColor,
                  side: BorderSide(color: _statusColor),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onInitiateReturn ?? onConfirmReturn ?? onResolveDispute,
                child: Text(
                  onInitiateReturn != null
                      ? 'Mark as Returned'
                      : (onConfirmReturn != null ? 'Confirm Return' : 'Resolve Dispute'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Return condition bottom sheet ─────────────────────────────────────────────
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
