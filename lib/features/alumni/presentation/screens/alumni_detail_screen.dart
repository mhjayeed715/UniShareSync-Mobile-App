import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/alumni_detail_provider.dart';
import '../widgets/alumni_contact_row.dart';
import '../widgets/alumni_social_buttons_row.dart';
import '../widgets/alumni_connect_button.dart';
import '../widgets/alumni_mentor_badge.dart';

class AlumniDetailScreen extends ConsumerStatefulWidget {
  final String alumniId;

  const AlumniDetailScreen({super.key, required this.alumniId});

  @override
  ConsumerState<AlumniDetailScreen> createState() => _AlumniDetailScreenState();
}

class _AlumniDetailScreenState extends ConsumerState<AlumniDetailScreen> {
  bool _academicExpanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(alumniDetailProvider.notifier).fetchProfileDetail(widget.alumniId);
    });
  }

  Color _getAvatarBgColor(String name) {
    final hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    final colors = [
      const Color(0xFF2563EB),
      const Color(0xFF3B82F6),
      const Color(0xFF1D4ED8),
      const Color(0xFF1E40AF),
      const Color(0xFF0EA5E9),
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

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(alumniDetailProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8FBFF),
              Color(0xFFEAF6FF),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: detailState.when(
            data: (profile) {
              if (profile == null) {
                return const Center(
                  child: Text('Profile not found', style: TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit')),
                );
              }

              final hasAcademicInfo = (profile.cgpa != null) ||
                  (profile.thesisTitle != null && profile.thesisTitle!.isNotEmpty) ||
                  (profile.notableAchievements != null && profile.notableAchievements!.isNotEmpty);

              return CustomScrollView(
                slivers: [
                  // Sliver App Bar with Back Button
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    pinned: true,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    expandedHeight: 220,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Center(
                        child: Hero(
                          tag: 'avatar_${profile.id}',
                          child: profile.profilePhotoUrl != null
                              ? Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF2563EB), width: 2),
                                    image: DecorationImage(
                                      image: NetworkImage(profile.profilePhotoUrl!),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              : CircleAvatar(
                                  radius: 55,
                                  backgroundColor: _getAvatarBgColor(profile.fullName),
                                  child: Text(
                                    _getInitials(profile.fullName),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),

                  // Profile Details Content
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name & Batch Tag
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  profile.fullName,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Outfit',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
                                      ),
                                      child: Text(
                                        'Batch ${profile.batchYear.toString().padLeft(2, '0')}',
                                        style: const TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                                      ),
                                    ),
                                    if (profile.graduationYear != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Text(
                                          'Graduated ${profile.graduationYear}',
                                          style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Current Role & Company
                          if (profile.currentJobTitle != null && profile.currentCompany != null) ...[
                            _buildSectionHeader('Professional Profile'),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: _glassDecoration(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.currentJobTitle!,
                                    style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    profile.currentCompany!,
                                    style: const TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF64748B)),
                                      const SizedBox(width: 6),
                                      Text(
                                        profile.currentLocation ?? 'Dhaka, Bangladesh',
                                        style: const TextStyle(color: Color(0xFF475569), fontSize: 13, fontFamily: 'Outfit'),
                                      ),
                                      if (profile.yearsOfExperience != null) ...[
                                        const SizedBox(width: 16),
                                        const Icon(Icons.work_history_rounded, size: 16, color: Color(0xFF64748B)),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${profile.yearsOfExperience} yrs experience',
                                          style: const TextStyle(color: Color(0xFF475569), fontSize: 13, fontFamily: 'Outfit'),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (profile.industry != null) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        profile.industry!.displayName,
                                        style: const TextStyle(color: Color(0xFF475569), fontSize: 11, fontFamily: 'Outfit'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Mentorship Section
                          if (profile.isOpenToMentor) ...[
                            _buildSectionHeader('Mentorship'),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFBBF24).withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const AlumniMentorBadge(isLarge: true),
                                  if (profile.mentorAreas != null && profile.mentorAreas!.isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    const Text(
                                      'Areas of Mentorship:',
                                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: profile.mentorAreas!.map((area) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFBBF24).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.2)),
                                        ),
                                        child: Text(
                                          area,
                                          style: const TextStyle(color: Color(0xFFD97706), fontSize: 11, fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                                        ),
                                      )).toList(),
                                    ),
                                  ],
                                  if (profile.mentorAvailability != null && profile.mentorAvailability!.isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    const Text(
                                      'Availability:',
                                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      profile.mentorAvailability!,
                                      style: const TextStyle(color: Color(0xFF475569), fontSize: 13, fontFamily: 'Outfit'),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  // Call to connect
                                  SizedBox(
                                    width: double.infinity,
                                    child: AlumniConnectButton(
                                      alumniId: profile.id,
                                      alumniName: profile.fullName,
                                      isMentorButton: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Contact details
                          _buildSectionHeader('Contact & Social Networks'),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: _glassDecoration(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AlumniContactRow(
                                  icon: Icons.email_rounded,
                                  label: 'Personal Email',
                                  value: profile.email,
                                  isVisible: profile.showEmail,
                                  onAction: () async {
                                    final uri = Uri.parse('mailto:${profile.email}');
                                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                                  },
                                ),
                                AlumniContactRow(
                                  icon: Icons.phone_rounded,
                                  label: 'Phone Number',
                                  value: profile.phone,
                                  isVisible: profile.showPhone,
                                  onAction: () async {
                                    final uri = Uri.parse('tel:${profile.phone}');
                                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                                  },
                                ),
                                const SizedBox(height: 12),
                                // Social Buttons Row
                                Center(child: AlumniSocialButtonsRow(profile: profile)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Academic section
                          if (hasAcademicInfo) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSectionHeader('Academic Background'),
                                IconButton(
                                  icon: Icon(
                                    _academicExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                    color: const Color(0xFF64748B),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _academicExpanded = !_academicExpanded;
                                    });
                                  },
                                ),
                              ],
                            ),
                            if (_academicExpanded)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: _glassDecoration(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (profile.cgpa != null) ...[
                                      Row(
                                        children: [
                                          const Text(
                                            'Cumulative CGPA:',
                                            style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontFamily: 'Outfit'),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            profile.cgpa!.toStringAsFixed(2),
                                            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    if (profile.thesisTitle != null && profile.thesisTitle!.isNotEmpty) ...[
                                      const Text(
                                        'Thesis / Project Title:',
                                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontFamily: 'Outfit'),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        profile.thesisTitle!,
                                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    if (profile.notableAchievements != null && profile.notableAchievements!.isNotEmpty) ...[
                                      const Text(
                                        'Notable University Achievements:',
                                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontFamily: 'Outfit'),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        profile.notableAchievements!,
                                        style: const TextStyle(color: Color(0xFF475569), fontSize: 13, fontFamily: 'Outfit', height: 1.4),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            const SizedBox(height: 32),
                          ],

                          // Sticky Connect Button at bottom (only if not already shown in mentor card)
                          if (!profile.isOpenToMentor) ...[
                            SizedBox(
                              width: double.infinity,
                              child: AlumniConnectButton(
                                alumniId: profile.id,
                                alumniName: profile.fullName,
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const AlumniDetailSkeleton(),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Failed to load profile: $err', style: const TextStyle(color: Color(0xFFEF4444), fontFamily: 'Outfit')),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }

  BoxDecoration _glassDecoration() {
    return BoxDecoration(
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
    );
  }
}

class AlumniDetailSkeleton extends StatefulWidget {
  const AlumniDetailSkeleton({super.key});

  @override
  State<AlumniDetailSkeleton> createState() => _AlumniDetailSkeletonState();
}

class _AlumniDetailSkeletonState extends State<AlumniDetailSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _gradientPosition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _gradientPosition = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                expandedHeight: 220,
                flexibleSpace: FlexibleSpaceBar(
                  background: Center(
                    child: _buildShimmerCircle(radius: 55),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildShimmerBox(width: 180, height: 22, borderRadius: 6),
                      const SizedBox(height: 8),
                      _buildShimmerBox(width: 240, height: 14, borderRadius: 4),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildShimmerBox(width: 80, height: 24, borderRadius: 12),
                          const SizedBox(width: 8),
                          _buildShimmerBox(width: 80, height: 24, borderRadius: 12),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _buildShimmerBox(width: 100, height: 16, borderRadius: 4),
                      ),
                      const SizedBox(height: 12),
                      _buildShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
                      const SizedBox(height: 8),
                      _buildShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
                      const SizedBox(height: 8),
                      _buildShimmerBox(width: 200, height: 12, borderRadius: 4),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildShimmerCircle({required double radius}) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _shimmerGradient(),
      ),
    );
  }

  Widget _buildShimmerBox({
    required double width,
    required double height,
    required double borderRadius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: _shimmerGradient(),
      ),
    );
  }

  LinearGradient _shimmerGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: const [
        Color(0xFFF1F5F9),
        Color(0xFFE2E8F0),
        Color(0xFFF1F5F9),
      ],
      stops: [
        0.0,
        0.5 + _gradientPosition.value * 0.25,
        1.0,
      ],
    );
  }
}
