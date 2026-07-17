import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/alumni_detail_provider.dart';
import '../../../../services/auth_service.dart';

class AlumniConnectButton extends ConsumerStatefulWidget {
  final String alumniId;
  final String alumniName;
  final bool isMentorButton;

  const AlumniConnectButton({
    super.key,
    required this.alumniId,
    required this.alumniName,
    this.isMentorButton = false,
  });

  @override
  ConsumerState<AlumniConnectButton> createState() => _AlumniConnectButtonState();
}

class _AlumniConnectButtonState extends ConsumerState<AlumniConnectButton> {
  bool _checkingLimit = false;

  void _onTap() async {
    setState(() {
      _checkingLimit = true;
    });

    try {
      // 1. Perform rate limit checks first
      await ref.read(alumniDetailProvider.notifier).checkConnectRateLimit(widget.alumniId);

      if (!mounted) return;
      setState(() {
        _checkingLimit = false;
      });

      // 2. Open request bottom sheet
      _showRequestSheet();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checkingLimit = false;
      });
      // Show rate limit or duplication error SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll("Exception:", "").replaceAll("StateError:", "").trim()),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showRequestSheet() async {
    final senderProfile = await AuthService().getCurrentProfile();
    if (!mounted || senderProfile == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AlumniConnectRequestSheet(
        alumniId: widget.alumniId,
        alumniName: widget.alumniName,
        senderName: senderProfile.fullName,
        senderEmail: senderProfile.email,
        onSubmit: (message) async {
          await ref.read(alumniDetailProvider.notifier).sendConnectRequest(
                alumniId: widget.alumniId,
                message: message,
              );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMentor = widget.isMentorButton;
    return ElevatedButton.icon(
      onPressed: _checkingLimit ? null : _onTap,
      icon: _checkingLimit
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.send_rounded, size: 16),
      label: Text(
        _checkingLimit
            ? 'Checking limits...'
            : isMentor
                ? 'Request Mentorship Connection'
                : 'Request to Connect',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: 'Outfit',
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isMentor ? const Color(0xFFF59E0B) : const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    );
  }
}

class AlumniConnectRequestSheet extends StatefulWidget {
  final String alumniId;
  final String alumniName;
  final String senderName;
  final String senderEmail;
  final Future<void> Function(String) onSubmit;

  const AlumniConnectRequestSheet({
    super.key,
    required this.alumniId,
    required this.alumniName,
    required this.senderName,
    required this.senderEmail,
    required this.onSubmit,
  });

  @override
  State<AlumniConnectRequestSheet> createState() => _AlumniConnectRequestSheetState();
}

class _AlumniConnectRequestSheetState extends State<AlumniConnectRequestSheet> {
  final TextEditingController _messageController = TextEditingController();
  bool _submitting = false;

  void _submit() async {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message.')),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      await widget.onSubmit(msg);

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Your message has been sent to ${widget.alumniName}. They will reply to your university email directly.",
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connect request failed: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Request Connection',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Connect with ${widget.alumniName}',
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 14,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 18),

              // Sender details (Read-only)
              Row(
                children: [
                  Expanded(
                    child: _buildReadOnlyField(
                      label: 'Sender Name',
                      value: widget.senderName,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildReadOnlyField(
                      label: 'Reply Email',
                      value: widget.senderEmail,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Message text field
              const Text(
                'Your Message (Max 300 characters)',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontSize: 14),
                  maxLines: 4,
                  maxLength: 300,
                  decoration: InputDecoration(
                    hintText: "Hi, I'm interested in ML — could you spare 15 mins to chat?",
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Outfit'),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14),
                    counterStyle: const TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Send Connection Request',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontFamily: 'Outfit'),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
