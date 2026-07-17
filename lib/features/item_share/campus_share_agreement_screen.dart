import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/listing.dart';
import 'models/loan.dart';
import 'services/listing_service.dart';

class CampusShareAgreementScreen extends StatefulWidget {
  const CampusShareAgreementScreen({
    super.key,
    required this.listing,
    required this.request,
  });
  final Listing listing;
  final ExchangeRequest request;

  @override
  State<CampusShareAgreementScreen> createState() =>
      _CampusShareAgreementScreenState();
}

class _CampusShareAgreementScreenState
    extends State<CampusShareAgreementScreen> {
  final _service = CampusShareService();
  bool _agreed = false;
  bool _signing = false;
  DateTime _returnDate = DateTime.now().add(const Duration(days: 7));
  Map<String, dynamic>? _lenderProfile;
  Map<String, dynamic>? _borrowerProfile;
  bool _loadingProfiles = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final db = Supabase.instance.client;
    try {
      final lenderProf = await db
          .from('profiles')
          .select('full_name, email')
          .eq('id', widget.request.lenderId)
          .maybeSingle();
      final borrowerProf = await db
          .from('profiles')
          .select('full_name, email')
          .eq('id', widget.request.borrowerId)
          .maybeSingle();

      int days = 7;
      if (widget.listing.type == ListingType.borrow) {
        final row = await db
            .from('loan_terms_borrow')
            .select('loan_duration_days')
            .eq('listing_id', widget.listing.id)
            .maybeSingle();
        if (row != null) {
          days = row['loan_duration_days'] as int;
        }
      } else if (widget.listing.type == ListingType.rent) {
        final row = await db
            .from('loan_terms_rent')
            .select('rental_duration_days')
            .eq('listing_id', widget.listing.id)
            .maybeSingle();
        if (row != null) {
          days = row['rental_duration_days'] as int;
        }
      }

      if (mounted) {
        setState(() {
          _lenderProfile = lenderProf;
          _borrowerProfile = borrowerProf;
          _returnDate = DateTime.now().add(Duration(days: days));
          _loadingProfiles = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProfiles = false);
    }
  }

  String _buildAgreementText() {
    final l = widget.listing;
    final r = widget.request;
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final due = '${_returnDate.day}/${_returnDate.month}/${_returnDate.year}';
    final lenderName = _lenderProfile?['full_name'] ?? _lenderProfile?['email']?.toString().split('@').first ?? r.lenderId;
    final borrowerName = _borrowerProfile?['full_name'] ?? _borrowerProfile?['email']?.toString().split('@').first ?? uid;

    return '''CAMPUSSHARE BORROW AGREEMENT
Listing ID: ${l.id}
Item: ${l.title}
Category: ${l.category.name}
Condition: ${l.condition.name}

Lender: $lenderName (${r.lenderId})
Borrower: $borrowerName ($uid)
Request ID: ${r.id}

Loan Start: ${DateTime.now().toLocal().toString().substring(0, 16)}
Agreed Return Date: $due

TERMS:
1. I agree to return this item by $due in the same condition I received it.
2. If I return the item late, I agree to pay the penalty declared by the lender per day, up to the maximum cap set by the lender.
3. If the item is damaged during my custody, I agree to pay the assessed repair/replacement cost declared by the lender and verified by Admin.
4. If I fail to return the item within the grace period after the due date, this will be reported to Admin and will affect my trust score.
5. Non-return beyond the maximum overdue period will result in escalation to Admin and a severe trust score deduction.

DEPOSIT: As declared by the lender (if any), to be returned upon safe return of the item.

ACKNOWLEDGMENT:
By accepting this agreement, I confirm that I have read, understood, and agree to all terms above. My user ID and the timestamp of acceptance serve as my digital signature.

Borrower User ID: $uid ($borrowerName)
Accepted At: ${DateTime.now().toIso8601String()}''';
  }

  Future<void> _sign() async {
    if (!_agreed) return;
    setState(() => _signing = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
      await _service.signAgreement(
        requestId: widget.request.id,
        borrowerId: uid,
        agreementText: _buildAgreementText(),
        agreedReturnDate: _returnDate,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Agreement signed! Waiting for lender to activate.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _signing = false);
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
        title: const Text(
          'Borrow Agreement',
          style: TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
              fontSize: 17),
        ),
      ),
      body: _loadingProfiles
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        children: [
          // Return date picker
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.95)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    color: Color(0xFFF97316), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Agreed Return Date',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A))),
                      Text(
                        '${_returnDate.day}/${_returnDate.month}/${_returnDate.year}',
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _returnDate,
                      firstDate: DateTime.now().add(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (picked != null) setState(() => _returnDate = picked);
                  },
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Agreement text box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: Text(
              _buildAgreementText(),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                color: Color(0xFF431407),
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // I Agree checkbox
          GestureDetector(
            onTap: () => setState(() => _agreed = !_agreed),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _agreed
                    ? const Color(0xFFECFDF5)
                    : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _agreed
                      ? const Color(0xFF10B981)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _agreed
                          ? const Color(0xFF10B981)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _agreed
                            ? const Color(0xFF10B981)
                            : const Color(0xFFCBD5E1),
                        width: 2,
                      ),
                    ),
                    child: _agreed
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 14)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'I have read and agree to all terms in this agreement. I understand this serves as my digital signature.',
                      style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _agreed
                ? const Color(0xFF10B981)
                : const Color(0xFF94A3B8),
            minimumSize: const Size.fromHeight(52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _agreed && !_signing ? _sign : null,
          child: _signing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text(
                  'Sign & Submit Request',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
        ),
      ),
    );
  }
}
