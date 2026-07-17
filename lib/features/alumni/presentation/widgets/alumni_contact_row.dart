import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AlumniContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final bool isVisible;
  final VoidCallback? onAction;

  const AlumniContactRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.isVisible,
    this.onAction,
  });

  void _copyToClipboard(BuildContext context) {
    if (value == null) return;
    Clipboard.setData(ClipboardData(text: value!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF64748B)),
          const SizedBox(width: 14),
          Expanded(
            child: isVisible && value != null && value!.isNotEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value!,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Contact info hidden by alumni',
                        style: TextStyle(
                          color: const Color(0xFF94A3B8),
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
          ),
          if (isVisible && value != null && value!.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF2563EB)),
              onPressed: () => _copyToClipboard(context),
              tooltip: 'Copy',
            ),
            if (onAction != null)
              IconButton(
                icon: const Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF2563EB)),
                onPressed: onAction,
                tooltip: 'Open',
              ),
          ] else ...[
            const Icon(Icons.lock_rounded, size: 16, color: Color(0xFF94A3B8)),
          ]
        ],
      ),
    );
  }
}
