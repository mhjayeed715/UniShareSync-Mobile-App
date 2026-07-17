import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/alumni_profile_model.dart';
import '../screens/alumni_detail_screen.dart';

class AlumniCardWidget extends StatelessWidget {
  final AlumniProfile profile;

  const AlumniCardWidget({super.key, required this.profile});

  Color _getAvatarBgColor(String name) {
    final hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    final colors = [
      const Color(0xFF2563EB), // Electric Blue
      const Color(0xFF3B82F6),
      const Color(0xFF1D4ED8),
      const Color(0xFF1E40AF),
      const Color(0xFF0EA5E9), // Sky Blue
      const Color(0xFF0284C7),
    ];
    return colors[hash % colors.length];
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'AC';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  IconData _getIndustryIcon(AlumniIndustry? industry) {
    switch (industry) {
      case AlumniIndustry.softwareDevelopment:
        return Icons.code_rounded;
      case AlumniIndustry.dataScienceAi:
        return Icons.insights_rounded;
      case AlumniIndustry.cybersecurity:
        return Icons.security_rounded;
      case AlumniIndustry.hardwareEmbedded:
        return Icons.memory_rounded;
      case AlumniIndustry.academiaResearch:
        return Icons.school_rounded;
      case AlumniIndustry.entrepreneurship:
        return Icons.lightbulb_rounded;
      case AlumniIndustry.governmentPublicSector:
        return Icons.account_balance_rounded;
      case AlumniIndustry.financeFintech:
        return Icons.payments_rounded;
      case AlumniIndustry.healthcareTech:
        return Icons.local_hospital_rounded;
      case AlumniIndustry.other:
      default:
        return Icons.category_rounded;
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
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
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar / Profile photo
                profile.profilePhotoUrl != null
                    ? CircleAvatar(
                        radius: 28,
                        backgroundImage: NetworkImage(profile.profilePhotoUrl!),
                        backgroundColor: Colors.transparent,
                      )
                    : CircleAvatar(
                        radius: 28,
                        backgroundColor: _getAvatarBgColor(profile.fullName),
                        child: Text(
                          _getInitials(profile.fullName),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                const SizedBox(width: 14),
                // Identity details
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
                                fontSize: 17,
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
                              color: const Color(0xFF2563EB).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF2563EB).withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              'Batch ${profile.batchYear.toString().padLeft(2, '0')}',
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
                      const SizedBox(height: 5),
                      if (profile.currentJobTitle != null && profile.currentCompany != null) ...[
                        Text(
                          '${profile.currentJobTitle} · ${profile.currentCompany}',
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 13.5,
                            fontFamily: 'Outfit',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                      ],
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 13,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              profile.currentLocation ?? 'Dhaka, Bangladesh',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                                fontFamily: 'Outfit',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Divider line
            Container(
              height: 1,
              color: const Color(0xFFE2E8F0),
            ),
            const SizedBox(height: 12),
            // Badges & Action row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Industry + Mentor Badges
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Industry badge
                      if (profile.industry != null) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getIndustryIcon(profile.industry),
                              size: 13,
                              color: const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              profile.industry!.displayName,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        ),
                      ],
                      // Mentor badge
                      if (profile.isOpenToMentor) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBBF24).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                '⭐ Mentor',
                                style: TextStyle(
                                  color: Color(0xFFD97706),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Quick Action Icons & View Button
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (profile.showLinkedin && profile.linkedinUrl != null && profile.linkedinUrl!.isNotEmpty) ...[
                      GestureDetector(
                        onTap: () => _launchUrl(profile.linkedinUrl!),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Image.network(
                            'https://cdn-icons-png.flaticon.com/512/174/174857.png',
                            width: 18,
                            height: 18,
                            color: const Color(0xFF64748B),
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.link_rounded,
                              size: 18,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (profile.showGithub && profile.githubUrl != null && profile.githubUrl!.isNotEmpty) ...[
                      GestureDetector(
                        onTap: () => _launchUrl(profile.githubUrl!),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Image.network(
                            'https://cdn-icons-png.flaticon.com/512/25/25231.png',
                            width: 18,
                            height: 18,
                            color: const Color(0xFF64748B),
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.link_rounded,
                              size: 18,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AlumniDetailScreen(alumniId: profile.id),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'View Profile',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
