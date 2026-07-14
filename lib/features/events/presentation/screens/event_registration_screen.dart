import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/event_model.dart';
import '../providers/event_registration_provider.dart';
import 'package:unisharesync_mobile_app/services/auth_service.dart';

class EventRegistrationScreen extends ConsumerStatefulWidget {
  final EventModel event;

  const EventRegistrationScreen({super.key, required this.event});

  @override
  ConsumerState<EventRegistrationScreen> createState() => _EventRegistrationScreenState();
}

class _EventRegistrationScreenState extends ConsumerState<EventRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _txnIdController = TextEditingController();
  
  String _selectedSemester = 'Semester 1';
  String _selectedPaymentMethod = 'bkash';
  bool _submitting = false;

  String _email = 'cse_student@smuct.edu.bd';
  String _studentId = '193071004';
  String _department = 'CSE';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() async {
    try {
      final profile = await AuthService().getCurrentProfile();
      if (mounted && profile != null) {
        setState(() {
          _fullNameController.text = profile.fullName;
          _email = profile.email;
          _studentId = profile.studentId ?? '193071004';
          _department = profile.department ?? 'CSE';
          
          if (profile.semester != null) {
            final semStr = profile.semester!.replaceAll(RegExp(r'[^0-9]'), '');
            final semNum = int.tryParse(semStr);
            if (semNum != null && semNum >= 1 && semNum <= 12) {
              _selectedSemester = 'Semester $semNum';
            }
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _fullNameController.dispose();
    _txnIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Registration'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.event.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Full Name (Pre-filled)', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: TextEditingController(text: _email),
                key: ValueKey(_email),
                enabled: false,
                decoration: const InputDecoration(labelText: 'University Email (Locked)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number (BD Mobile, 11 digits)', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  if (val.length != 11 || !val.startsWith('01')) return 'Must be exactly 11 digits and start with 01';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _selectedSemester,
                items: List.generate(12, (index) => 'Semester ${index + 1}')
                    .map((sem) => DropdownMenuItem(value: sem, child: Text(sem)))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedSemester = val!;
                  });
                },
                decoration: const InputDecoration(labelText: 'Semester', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),

              if (widget.event.isPaid) ...[
                const Divider(),
                const Text('Payment Section', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(
                  widget.event.paymentInstructions ?? 'Please send BDT ${widget.event.entryFee} to Nagad/bKash.',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedPaymentMethod,
                  items: const [
                    DropdownMenuItem(value: 'bkash', child: Text('bKash')),
                    DropdownMenuItem(value: 'nagad', child: Text('Nagad')),
                    DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'cash_at_venue', child: Text('Cash at Venue')),
                  ],
                  onChanged: (val) => setState(() => _selectedPaymentMethod = val!),
                  decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                if (_selectedPaymentMethod != 'cash_at_venue') ...[
                  TextFormField(
                    controller: _txnIdController,
                    decoration: const InputDecoration(labelText: 'Transaction ID', border: OutlineInputBorder()),
                    validator: (val) => val == null || val.isEmpty ? 'Transaction ID is required for digital payments' : null,
                  ),
                  const SizedBox(height: 16),
                ]
              ],
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submitRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F9EFF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Submit Registration', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final payload = {
      'event_id': widget.event.id,
      'full_name': _fullNameController.text,
      'email': _email,
      'phone': _phoneController.text,
      'semester': int.parse(_selectedSemester.split(' ').last),
      'student_faculty_id': _studentId,
      'department': _department,
      'payment_method': widget.event.isPaid ? _selectedPaymentMethod : null,
      'transaction_id': widget.event.isPaid && _selectedPaymentMethod != 'cash_at_venue' ? _txnIdController.text : null,
      'payment_status': widget.event.isPaid ? 'pending' : 'not_required',
      'registration_status': widget.event.isPaid ? 'pending' : 'confirmed',
    };

    try {
      await ref.read(eventRegistrationProvider.notifier).registerForEvent(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration completed successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
