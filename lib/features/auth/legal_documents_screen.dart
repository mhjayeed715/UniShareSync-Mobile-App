import 'package:flutter/material.dart';

class _LegalSectionData {
  const _LegalSectionData({required this.title, required this.body});

  final String title;
  final String body;
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _LegalDocumentScreen(
      title: 'Privacy Policy',
      lastUpdated: 'Last updated: February 2026',
      sections: const [
        _LegalSectionData(
          title: '1. Information We Collect',
          body:
              'We collect information you provide directly, including your name, email address, student/faculty ID, and profile information. We also collect data about your usage of the platform to improve our services.',
        ),
        _LegalSectionData(
          title: '2. How We Use Your Information',
          body:
              'Your information is used to provide and improve our services, communicate with you about updates and features, and ensure platform security. We never sell your personal data to third parties.',
        ),
        _LegalSectionData(
          title: '3. Data Security',
          body:
              'We implement industry-standard security measures including encryption, secure authentication (JWT), and role-based access control to protect your data.',
        ),
        _LegalSectionData(
          title: '4. Your Rights',
          body:
              'You have the right to access, update, or delete your personal information at any time through your profile settings. You can also request a copy of your data by contacting us.',
        ),
        _LegalSectionData(
          title: '5. Cookies',
          body:
              'We use essential cookies to maintain your session and preferences. No third-party tracking cookies are used.',
        ),
        _LegalSectionData(
          title: '6. Contact',
          body:
              'For privacy-related inquiries, contact us at mehrabjayeed715@gmail.com',
        ),
      ],
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _LegalDocumentScreen(
      title: 'Terms of Service',
      lastUpdated: 'Last updated: February 2026',
      sections: const [
        _LegalSectionData(
          title: '1. Acceptance of Terms',
          body:
              'By using UniShareSync, you agree to these terms of service. If you do not agree, please do not use the platform.',
        ),
        _LegalSectionData(
          title: '2. User Responsibilities',
          body:
              'Users must provide accurate information, respect intellectual property rights, and not upload harmful or inappropriate content. You are responsible for maintaining the security of your account.',
        ),
        _LegalSectionData(
          title: '3. Content Guidelines',
          body:
              'All uploaded resources must be educational in nature. Plagiarized or copyrighted content without permission is strictly prohibited. Admin reserves the right to remove inappropriate content.',
        ),
        _LegalSectionData(
          title: '4. Account Termination',
          body:
              'We reserve the right to suspend or terminate accounts that violate these terms or engage in abusive behavior.',
        ),
        _LegalSectionData(
          title: '5. Limitation of Liability',
          body:
              'UniShareSync is provided "as is" without warranties. We are not liable for any damages arising from your use of the platform.',
        ),
      ],
    );
  }
}

class _LegalDocumentScreen extends StatelessWidget {
  const _LegalDocumentScreen({
    required this.title,
    required this.lastUpdated,
    required this.sections,
  });

  final String title;
  final String lastUpdated;
  final List<_LegalSectionData> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF10223D),
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF8FBFF), Color(0xFFEAF6FF)],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.35,
                child: CustomPaint(
                  painter: _LegalDotGridPainter(
                    color: Color(0x334F9EFF),
                    spacing: 24,
                    radius: 1.0,
                  ),
                ),
              ),
            ),
          ),
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Text(
                lastUpdated,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              ...sections.map((section) => _LegalSectionCard(data: section)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegalSectionCard extends StatelessWidget {
  const _LegalSectionCard({required this.data});

  final _LegalSectionData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.92)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F9EFF).withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.body,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalDotGridPainter extends CustomPainter {
  const _LegalDotGridPainter({
    required this.color,
    required this.spacing,
    required this.radius,
  });

  final Color color;
  final double spacing;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    for (double y = 0; y <= size.height; y += spacing) {
      for (double x = 0; x <= size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LegalDotGridPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.spacing != spacing ||
        oldDelegate.radius != radius;
  }
}
