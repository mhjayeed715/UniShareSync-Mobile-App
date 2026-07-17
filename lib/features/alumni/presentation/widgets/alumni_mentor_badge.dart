import 'package:flutter/material.dart';

class AlumniMentorBadge extends StatelessWidget {
  final bool isLarge;

  const AlumniMentorBadge({super.key, this.isLarge = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 12 : 8,
        vertical: isLarge ? 6 : 3,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFBBF24).withOpacity(0.1),
        borderRadius: BorderRadius.circular(isLarge ? 8 : 6),
        border: Border.all(
          color: const Color(0xFFF59E0B).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: isLarge ? 16 : 12,
            color: const Color(0xFFD97706),
          ),
          const SizedBox(width: 4),
          Text(
            'Open to Mentorship',
            style: TextStyle(
              color: const Color(0xFFD97706),
              fontSize: isLarge ? 13 : 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }
}
