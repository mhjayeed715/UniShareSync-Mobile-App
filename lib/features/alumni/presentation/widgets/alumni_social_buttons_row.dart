import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/alumni_profile_model.dart';

class AlumniSocialButtonsRow extends StatelessWidget {
  final AlumniProfile profile;

  const AlumniSocialButtonsRow({super.key, required this.profile});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Widget _buildSocialIcon({
    required String? url,
    required bool isVisible,
    required String iconUrl,
    required IconData fallbackIcon,
    required String tooltip,
  }) {
    if (!isVisible || url == null || url.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: IconButton(
          icon: Image.network(
            iconUrl,
            width: 22,
            height: 22,
            color: const Color(0xFF64748B),
            errorBuilder: (_, __, ___) => Icon(
              fallbackIcon,
              size: 22,
              color: const Color(0xFF64748B),
            ),
          ),
          onPressed: () => _launchUrl(url),
          tooltip: tooltip,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if there are any social links to display
    final showLinkedin = profile.showLinkedin && profile.linkedinUrl != null && profile.linkedinUrl!.isNotEmpty;
    final showGithub = profile.showGithub && profile.githubUrl != null && profile.githubUrl!.isNotEmpty;
    final showWebsite = profile.websiteUrl != null && profile.websiteUrl!.isNotEmpty;
    final showFacebook = profile.facebookUrl != null && profile.facebookUrl!.isNotEmpty;

    if (!showLinkedin && !showGithub && !showWebsite && !showFacebook) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        child: const Text(
          'No social links provided',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 13,
            fontStyle: FontStyle.italic,
            fontFamily: 'Outfit',
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSocialIcon(
            url: profile.linkedinUrl,
            isVisible: profile.showLinkedin,
            iconUrl: 'https://cdn-icons-png.flaticon.com/512/174/174857.png',
            fallbackIcon: Icons.link_rounded,
            tooltip: 'LinkedIn',
          ),
          _buildSocialIcon(
            url: profile.githubUrl,
            isVisible: profile.showGithub,
            iconUrl: 'https://cdn-icons-png.flaticon.com/512/25/25231.png',
            fallbackIcon: Icons.link_rounded,
            tooltip: 'GitHub',
          ),
          _buildSocialIcon(
            url: profile.websiteUrl,
            isVisible: true, // Website visibility defaults to true if present
            iconUrl: 'https://cdn-icons-png.flaticon.com/512/1006/1006771.png',
            fallbackIcon: Icons.language_rounded,
            tooltip: 'Portfolio Website',
          ),
          _buildSocialIcon(
            url: profile.facebookUrl,
            isVisible: true, // Facebook visibility defaults to true in BD context
            iconUrl: 'https://cdn-icons-png.flaticon.com/512/124/124010.png',
            fallbackIcon: Icons.facebook_rounded,
            tooltip: 'Facebook',
          ),
        ],
      ),
    );
  }
}
