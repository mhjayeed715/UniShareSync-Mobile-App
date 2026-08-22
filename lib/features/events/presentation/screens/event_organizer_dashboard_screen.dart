import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:unisharesync_mobile_app/core/utils/csv_saver.dart';
import '../../data/models/event_model.dart';
import '../../data/models/event_registration_model.dart';
import '../providers/event_registration_provider.dart';

class EventOrganizerDashboardScreen extends ConsumerStatefulWidget {
  final EventModel event;

  const EventOrganizerDashboardScreen({super.key, required this.event});

  @override
  ConsumerState<EventOrganizerDashboardScreen> createState() => _EventOrganizerDashboardScreenState();
}

class _EventOrganizerDashboardScreenState extends ConsumerState<EventOrganizerDashboardScreen> {
  final _searchController = TextEditingController();
  List<EventRegistrationModel> _registrants = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRegistrants();
  }

  void _loadRegistrants() {
    setState(() => _loading = true);
    ref.read(eventRegistrationProvider.notifier)
       .fetchEventRegistrants(widget.event.id, {'search': _searchController.text})
       .then((list) {
         if (mounted) {
           setState(() {
             _registrants = list;
             _loading = false;
           });
         }
       }).catchError((e) {
         if (mounted) {
           setState(() => _loading = false);
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
         }
       });
  }

  void _exportCSV() async {
    try {
      final csv = await ref.read(eventRegistrationProvider.notifier).exportRegistrantsCSV(widget.event.id);
      
      // Copy to Clipboard
      await Clipboard.setData(ClipboardData(text: csv));

      // Save to File using conditional loader
      final sanitizedTitle = widget.event.title.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
      final fileName = 'registrants_$sanitizedTitle.csv';
      final savedPath = await saveCsvFile(csv, fileName);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('CSV Exported Successfully'),
            content: Text(
              '1. Copied to Clipboard!\n\n'
              '2. Saved Location:\n'
              '$savedPath\n\n'
              'You can paste it directly or import it into any spreadsheet app.'
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  void _verifyPayment(EventRegistrationModel reg, String status) async {
    try {
      await ref.read(eventRegistrationProvider.notifier).verifyPayment(reg.id, status, null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration marked as $status')));
      _loadRegistrants();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _checkIn(EventRegistrationModel reg) async {
    try {
      await ref.read(eventRegistrationProvider.notifier).checkInAttendee(reg.id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendee checked in successfully')));
      _loadRegistrants();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _issueCertificate(EventRegistrationModel reg) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating certificate...')),
      );
      await ref.read(eventRegistrationProvider.notifier).issueCertificate(reg.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Certificate generated and issued successfully!')),
        );
        _loadRegistrants();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to issue certificate: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organizer Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.download_rounded), onPressed: _exportCSV, tooltip: 'Export CSV'),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => _loadRegistrants(),
                    decoration: const InputDecoration(
                      labelText: 'Search registrants...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading 
              ? const Center(child: CircularProgressIndicator())
              : _registrants.isEmpty 
                  ? const Center(child: Text('No registrants found.'))
                  : ListView.builder(
                      itemCount: _registrants.length,
                      itemBuilder: (context, idx) {
                        final reg = _registrants[idx];
                        final isCheckedIn = reg.registrationStatus == 'attended' || reg.checkedInAt != null;
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(reg.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    ),
                                    Chip(
                                      label: Text(isCheckedIn ? 'CHECKED IN' : reg.registrationStatus.toUpperCase()),
                                      backgroundColor: isCheckedIn 
                                          ? Colors.blue.shade100 
                                          : reg.registrationStatus == 'confirmed' 
                                              ? Colors.green.shade100 
                                              : Colors.amber.shade100,
                                    )
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('ID: ${reg.studentFacultyId} · Semester ${reg.semester}'),
                                Text('Phone: ${reg.phone}'),
                                if (reg.paymentMethod != null) ...[
                                  const Divider(),
                                  Text('Payment: ${reg.paymentMethod} (Txn: ${reg.transactionId ?? 'N/A'})'),
                                  Text('Payment Status: ${reg.paymentStatus.toUpperCase()}', 
                                    style: TextStyle(fontWeight: FontWeight.bold, color: reg.paymentStatus == 'verified' ? Colors.green : Colors.red),
                                  ),
                                  const SizedBox(height: 12),
                                  if (reg.paymentStatus == 'pending')
                                    Row(
                                      children: [
                                        ElevatedButton(
                                          onPressed: () => _verifyPayment(reg, 'verified'),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                          child: const Text('Verify Payment', style: TextStyle(color: Colors.white)),
                                        ),
                                        const SizedBox(width: 12),
                                        OutlinedButton(
                                          onPressed: () => _verifyPayment(reg, 'rejected'),
                                          child: const Text('Reject'),
                                        )
                                      ],
                                    )
                                ],
                                if (reg.registrationStatus == 'confirmed' && !isCheckedIn) ...[
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: () => _checkIn(reg),
                                    icon: const Icon(Icons.check_rounded),
                                    label: const Text('Mark Checked-in'),
                                  )
                                ],
                                if (widget.event.offersCertificate && (isCheckedIn || reg.registrationStatus == 'confirmed')) ...[
                                  const SizedBox(height: 10),
                                  if (reg.certificateIssued && reg.certificateUrl != null)
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        final uri = Uri.tryParse(reg.certificateUrl!);
                                        if (uri != null && await canLaunchUrl(uri)) {
                                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                                        }
                                      },
                                      icon: const Icon(Icons.verified_rounded, color: Colors.green, size: 18),
                                      label: const Text('View Issued Certificate', style: TextStyle(color: Colors.green)),
                                    )
                                  else
                                    ElevatedButton.icon(
                                      onPressed: () => _issueCertificate(reg),
                                      icon: const Icon(Icons.card_membership_rounded, size: 18),
                                      label: const Text('Issue Certificate'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF4F9EFF),
                                        foregroundColor: Colors.white,
                                      ),
                                    )
                                ]
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          )
        ],
      ),
    );
  }
}
