import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/user_role.dart';
import '../../../../services/auth_service.dart';
import '../../data/repositories/alumni_repository.dart';
import '../providers/alumni_provider.dart';
import '../widgets/alumni_card_widget.dart';
import '../widgets/alumni_filter_sheet.dart';
import '../widgets/alumni_batch_section_header.dart';
import 'alumni_add_edit_screen.dart';
import 'alumni_admin_screen.dart';

class AlumniBrowseScreen extends ConsumerStatefulWidget {
  const AlumniBrowseScreen({super.key});

  @override
  ConsumerState<AlumniBrowseScreen> createState() => _AlumniBrowseScreenState();
}

class _AlumniBrowseScreenState extends ConsumerState<AlumniBrowseScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  UserRole _userRole = UserRole.student;
  final Map<int, bool> _collapsedBatches = {};
  List<int> _availableBatches = [];

  // Filter and Sorting state
  AlumniFilters _filters = const AlumniFilters();
  AlumniSort _sort = AlumniSort.newestBatch;
  bool _mentorMode = false;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(alumniProvider.notifier).fetchAlumni(forceRefresh: true);
      _loadBatches();
    });
  }

  void _loadUserRole() async {
    final role = await AuthService().getCurrentRole();
    setState(() {
      _userRole = role ?? UserRole.student;
    });
  }

  void _loadBatches() async {
    final list = await ref.read(alumniProvider.notifier).fetchAvailableBatchYears();
    setState(() {
      _availableBatches = list;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(alumniProvider.notifier).fetchAlumni(searchQuery: query);
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AlumniFilterSheet(
        currentFilters: _filters,
        availableBatches: _availableBatches,
        onApply: (appliedFilters) {
          setState(() {
            _filters = appliedFilters;
            // Sync mentor mode state with filter toggle
            if (appliedFilters.isOpenToMentor == true) {
              _mentorMode = true;
            } else if (_mentorMode && appliedFilters.isOpenToMentor == null) {
              _mentorMode = false;
            }
          });
          ref.read(alumniProvider.notifier).fetchAlumni(filters: _filters);
        },
      ),
    );
  }

  void _toggleMentorMode() {
    setState(() {
      _mentorMode = !_mentorMode;
      _filters = _filters.copyWith(isOpenToMentor: _mentorMode ? true : null);
    });
    ref.read(alumniProvider.notifier).fetchAlumni(filters: _filters);
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_filters.batchYears != null && _filters.batchYears!.isNotEmpty) count++;
    if (_filters.industries != null && _filters.industries!.isNotEmpty) count++;
    if (_filters.location != null && _filters.location!.trim().isNotEmpty) count++;
    if (_filters.isOpenToMentor == true) count++;
    if (_filters.mentorAreas != null && _filters.mentorAreas!.isNotEmpty) count++;
    if (_filters.hasLinkedin == true) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(alumniProvider);
    final isSearchingOrFiltering = _searchController.text.trim().isNotEmpty || _getActiveFilterCount() > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8FBFF), // Light Blue Start
              Color(0xFFEAF6FF), // Light Blue End
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Custom Header Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'AlumniConnect',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    if (_userRole == UserRole.admin)
                      IconButton(
                        icon: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF2563EB)),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AlumniAdminScreen()),
                        ),
                        tooltip: 'Admin Board',
                      ),
                    if (_userRole == UserRole.faculty || _userRole == UserRole.admin)
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF10B981)),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AlumniAddEditScreen()),
                        ),
                        tooltip: 'Add Profile',
                      ),
                  ],
                ),
              ),

              // Search sliver box (Debounced)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit'),
                    decoration: InputDecoration(
                      hintText: 'Search by name, company, role, batch...',
                      hintStyle: TextStyle(color: const Color(0xFF94A3B8), fontFamily: 'Outfit'),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(alumniProvider.notifier).fetchAlumni(searchQuery: '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),

              // Filters & Sort Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    // Filter button with badge
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _showFilterSheet,
                          icon: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF0F172A)),
                          label: const Text('Filter', style: TextStyle(fontFamily: 'Outfit', fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0F172A),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                        ),
                        if (_getActiveFilterCount() > 0)
                          Positioned(
                            right: -6,
                            top: -6,
                            child: CircleAvatar(
                              radius: 9,
                              backgroundColor: const Color(0xFF2563EB),
                              child: Text(
                                '${_getActiveFilterCount()}',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    // Sorting dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<AlumniSort>(
                          value: _sort,
                          dropdownColor: Colors.white,
                          icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                          style: const TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontSize: 13),
                          onChanged: (newSort) {
                            if (newSort != null) {
                              setState(() {
                                _sort = newSort;
                              });
                              ref.read(alumniProvider.notifier).fetchAlumni(sort: newSort);
                            }
                          },
                          items: const [
                            DropdownMenuItem(value: AlumniSort.newestBatch, child: Text('Newest Batch First')),
                            DropdownMenuItem(value: AlumniSort.oldestBatch, child: Text('Oldest Batch First')),
                            DropdownMenuItem(value: AlumniSort.alphabetical, child: Text('Alphabetical (A-Z)')),
                            DropdownMenuItem(value: AlumniSort.recentlyAdded, child: Text('Most Recently Added')),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Offline Banner
              if (state.fromCache)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFF59E0B).withOpacity(0.15),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.offline_bolt_rounded, color: Color(0xFFD97706), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Showing cached results · Last updated ${state.cachedAt != null ? DateFormat('jm').format(state.cachedAt!) : 'recently'}',
                          style: const TextStyle(
                            color: Color(0xFFD97706),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Body Content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(alumniProvider.notifier).fetchAlumni(forceRefresh: true);
                    _loadBatches();
                  },
                  backgroundColor: Colors.white,
                  color: const Color(0xFF2563EB),
                  child: state.profiles.when(
                    data: (profiles) {
                      if (profiles.isEmpty) {
                        return _buildEmptyState(isSearchingOrFiltering);
                      }

                      // Grouped batch view (when NOT searching/filtering)
                      if (!isSearchingOrFiltering) {
                        final groupedMap = ref.read(alumniProvider.notifier).groupByBatch(profiles);
                        final sortedGroupYears = groupedMap.keys.toList()
                          ..sort((a, b) => _sort == AlumniSort.oldestBatch ? a.compareTo(b) : b.compareTo(a));

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: sortedGroupYears.length,
                          itemBuilder: (context, idx) {
                            final year = sortedGroupYears[idx];
                            final batchAlumni = groupedMap[year] ?? [];
                            final isCollapsed = _collapsedBatches[year] ?? false;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AlumniBatchSectionHeader(
                                  batchYear: year,
                                  alumniCount: batchAlumni.length,
                                  isCollapsed: isCollapsed,
                                  onTap: () {
                                    setState(() {
                                      _collapsedBatches[year] = !isCollapsed;
                                    });
                                  },
                                ),
                                if (!isCollapsed) ...[
                                  const SizedBox(height: 4),
                                  ...batchAlumni.map((p) => AlumniCardWidget(profile: p)),
                                  const SizedBox(height: 12),
                                ],
                              ],
                            );
                          },
                        );
                      }

                      // Flat list view (when search/filters applied)
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: profiles.length,
                        itemBuilder: (context, idx) {
                          return AlumniCardWidget(profile: profiles[idx]);
                        },
                      );
                    },
                    loading: () => ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: 4,
                      itemBuilder: (context, idx) {
                        return const AlumniCardSkeleton();
                      },
                    ),
                    error: (err, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Error loading directory: $err',
                          style: const TextStyle(color: Color(0xFFEF4444), fontFamily: 'Outfit'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleMentorMode,
        backgroundColor: _mentorMode ? const Color(0xFFFBBF24) : const Color(0xFF2563EB),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: _mentorMode ? const Color(0xFFD97706) : const Color(0xFF1D4ED8),
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.star_rounded,
          color: _mentorMode ? const Color(0xFF78350F) : Colors.white,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool activeFilters) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  size: 60,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No Alumni Found',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                activeFilters
                    ? "No results match your search query or filters. Try clearing filters or searching by batch year."
                    : "No approved profiles are currently available in the directory.",
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                  fontFamily: 'Outfit',
                ),
                textAlign: TextAlign.center,
              ),
              if (activeFilters) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    _clearAll();
                    ref.read(alumniProvider.notifier).fetchAlumni(searchQuery: '', filters: const AlumniFilters());
                  },
                  child: const Text(
                    'Clear All Search & Filters',
                    style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _clearAll() {
    setState(() {
      _filters = const AlumniFilters();
      _mentorMode = false;
    });
  }
}

class AlumniCardSkeleton extends StatefulWidget {
  const AlumniCardSkeleton({super.key});

  @override
  State<AlumniCardSkeleton> createState() => _AlumniCardSkeletonState();
}

class _AlumniCardSkeletonState extends State<AlumniCardSkeleton>
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
                  color: Colors.black.withOpacity(0.01),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildShimmerCircle(radius: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _buildShimmerBox(width: 120, height: 16, borderRadius: 4),
                              const Spacer(),
                              _buildShimmerBox(width: 70, height: 20, borderRadius: 12),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _buildShimmerBox(width: 160, height: 12, borderRadius: 4),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildShimmerBox(width: 12, height: 12, borderRadius: 2),
                              const SizedBox(width: 4),
                              _buildShimmerBox(width: 100, height: 12, borderRadius: 4),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, thickness: 1, color: Color(0xFFE2E8F0)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildShimmerCircle(radius: 10),
                        const SizedBox(width: 12),
                        _buildShimmerCircle(radius: 10),
                      ],
                    ),
                    _buildShimmerBox(width: 76, height: 28, borderRadius: 8),
                  ],
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
