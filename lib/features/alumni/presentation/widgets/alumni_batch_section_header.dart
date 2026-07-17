import 'package:flutter/material.dart';

class AlumniBatchSectionHeader extends StatelessWidget {
  final int batchYear;
  final int alumniCount;
  final bool isCollapsed;
  final VoidCallback onTap;

  const AlumniBatchSectionHeader({
    super.key,
    required this.batchYear,
    required this.alumniCount,
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gradYear = batchYear < 100 ? (2006 + batchYear) : (batchYear + 4);
    final batchStr = batchYear.toString().padLeft(2, '0');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF2563EB).withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isCollapsed ? Icons.keyboard_arrow_right_rounded : Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFF2563EB),
              ),
              const SizedBox(width: 8),
              Text(
                'Batch $batchStr',
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '· Graduated ~$gradYear',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontFamily: 'Outfit',
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$alumniCount Alumni',
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
