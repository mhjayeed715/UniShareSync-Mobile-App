import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unisharesync_mobile_app/services/auth_service.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';
import '../providers/communities_provider.dart';
import 'community_detail_screen.dart';
import 'community_create_edit_screen.dart';

class CommunitiesBrowseScreen extends ConsumerStatefulWidget {
  const CommunitiesBrowseScreen({super.key});

  @override
  ConsumerState<CommunitiesBrowseScreen> createState() => _CommunitiesBrowseScreenState();
}

class _CommunitiesBrowseScreenState extends ConsumerState<CommunitiesBrowseScreen> {
  final _searchController = TextEditingController();
  UserRole? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(communitiesProvider.notifier).fetchCommunities();
    });
  }

  void _loadUserRole() async {
    final role = await AuthService().getCurrentRole();
    if (mounted) {
      setState(() => _userRole = role);
    }
  }

  void _onSearchChanged(String val) {
    ref.read(communitiesProvider.notifier).fetchCommunities(search: val);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communitiesProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FBFF), Color(0xFFEAF6FF)],
          ),
        ),
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              floating: false,
              pinned: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                'Communities',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: const InputDecoration(
                          hintText: 'Search communities (AI, Robotics, Programming)...',
                          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
          body: state.when(
            loading: () => ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 3,
              itemBuilder: (context, idx) {
                return const _CommunityCardSkeleton();
              },
            ),
            error: (err, stack) => Center(child: Text('Error: $err')),
            data: (communities) {
              if (communities.isEmpty) {
                return const Center(child: Text('No communities found.'));
              }
              return RefreshIndicator(
                onRefresh: () => ref.read(communitiesProvider.notifier).fetchCommunities(search: _searchController.text),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: communities.length,
                  itemBuilder: (context, idx) {
                    final comm = communities[idx];
                    return _buildCommunityCard(context, comm);
                  },
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: (_userRole == UserRole.faculty || _userRole == UserRole.admin)
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CommunityCreateEditScreen(),
                ));
              },
              backgroundColor: const Color(0xFF4F9EFF),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Community', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildCommunityCard(BuildContext context, comm) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.9)),
            ),
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CommunityDetailScreen(communityId: comm.id),
                ));
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Image.network(
                        comm.coverPhotoUrl ?? 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800',
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade300, height: 120),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: CircleAvatar(
                          radius: 28,
                          backgroundImage: NetworkImage(comm.logoUrl ?? 'https://images.unsplash.com/photo-1579621970795-87faff3f905d?w=200'),
                        ),
                      )
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(comm.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 4),
                        Text(comm.tagline, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${comm.memberCount} members', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.grey, fontSize: 12)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'SCORE: ${comm.activityScore}',
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommunityCardSkeleton extends StatefulWidget {
  const _CommunityCardSkeleton();

  @override
  State<_CommunityCardSkeleton> createState() => _CommunityCardSkeletonState();
}

class _CommunityCardSkeletonState extends State<_CommunityCardSkeleton>
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
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildShimmerBox(width: double.infinity, height: 120, borderRadius: 20),
                    Positioned(
                      bottom: -16,
                      left: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: _buildShimmerCircle(radius: 28),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildShimmerBox(width: 160, height: 18, borderRadius: 4),
                      const SizedBox(height: 6),
                      _buildShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildShimmerBox(width: 80, height: 12, borderRadius: 4),
                          _buildShimmerBox(width: 70, height: 20, borderRadius: 6),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
