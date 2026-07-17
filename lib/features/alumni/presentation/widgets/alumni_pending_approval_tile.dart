import 'package:flutter/material.dart';
import '../../data/models/alumni_profile_model.dart';

class AlumniPendingApprovalTile extends StatelessWidget {
  final AlumniProfile profile;
  final VoidCallback onApprove;
  final Function(String rejectionNote) onReject;

  const AlumniPendingApprovalTile({
    super.key,
    required this.profile,
    required this.onApprove,
    required this.onReject,
  });

  void _showRejectDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        title: const Text(
          'Reject Alumni Entry',
          style: TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reason for rejecting ${profile.fullName}\'s profile:',
              style: const TextStyle(color: Color(0xFF475569), fontSize: 13, fontFamily: 'Outfit'),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: controller,
                maxLines: 3,
                style: const TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit'),
                decoration: const InputDecoration(
                  hintText: 'e.g., Student ID could not be verified or is invalid.',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontFamily: 'Outfit'),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit')),
          ),
          FilledButton(
            onPressed: () {
              final note = controller.text.trim();
              if (note.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a rejection reason.')),
                );
                return;
              }
              onReject(note);
              Navigator.of(dialogContext).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Reject', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _getSourceLabel(AlumniEntrySource source) {
    switch (source) {
      case AlumniEntrySource.adminAdded:
        return 'Admin Added';
      case AlumniEntrySource.facultyAdded:
        return 'Faculty Added';
    }
  }

  Color _getSourceColor(AlumniEntrySource source) {
    switch (source) {
      case AlumniEntrySource.adminAdded:
        return const Color(0xFF2563EB);
      case AlumniEntrySource.facultyAdded:
        return const Color(0xFF8B5CF6);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar Placeholder
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFEAF6FF),
                  child: Text(
                    profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : 'A',
                    style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 14),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              profile.fullName,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getSourceColor(profile.entrySource).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _getSourceColor(profile.entrySource).withOpacity(0.2)),
                            ),
                            child: Text(
                              _getSourceLabel(profile.entrySource),
                              style: TextStyle(
                                color: _getSourceColor(profile.entrySource),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Batch ${profile.batchYear.toString().padLeft(2, '0')} · CSE Department',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontFamily: 'Outfit'),
                      ),
                      if (profile.currentJobTitle != null && profile.currentCompany != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${profile.currentJobTitle} at ${profile.currentCompany}',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontFamily: 'Outfit'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showRejectDialog(context),
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: const Text('Reject', style: TextStyle(fontSize: 12, fontFamily: 'Outfit')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check_rounded, size: 14),
                  label: const Text('Approve', style: TextStyle(fontSize: 12, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
