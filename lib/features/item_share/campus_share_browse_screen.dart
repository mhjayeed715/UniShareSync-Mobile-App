import 'package:flutter/material.dart';
import 'models/listing.dart';
import 'services/listing_service.dart';
import 'campus_share_detail_screen.dart';

class CampusShareBrowseScreen extends StatefulWidget {
  const CampusShareBrowseScreen({super.key});

  @override
  State<CampusShareBrowseScreen> createState() =>
      _CampusShareBrowseScreenState();
}

class _CampusShareBrowseScreenState extends State<CampusShareBrowseScreen> {
  final _service = CampusShareService();
  final _searchCtrl = TextEditingController();

  List<Listing> _listings = [];
  bool _loading = true;

  // Filters
  ListingType? _filterType;
  ItemCategory? _filterCategory;
  ItemCondition? _filterCondition;
  String? _filterSemester;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_listings.isEmpty) {
      setState(() => _loading = true);
    }
    try {
      final results = await _service.fetchListings(
        keyword: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        type: _filterType,
        category: _filterCategory,
        condition: _filterCondition,
        semesterTags: _filterSemester != null ? [_filterSemester!] : null,
        status: 'available',
      );
      if (mounted) setState(() { _listings = results; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(
        selectedType: _filterType,
        selectedCategory: _filterCategory,
        selectedCondition: _filterCondition,
        selectedSemester: _filterSemester,
        onApply: (type, cat, cond, sem) {
          setState(() {
            _filterType = type;
            _filterCategory = cat;
            _filterCondition = cond;
            _filterSemester = sem;
          });
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFilter = _filterType != null ||
        _filterCategory != null ||
        _filterCondition != null ||
        _filterSemester != null;

    return Column(
      children: [
        // Search + filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => _load(),
                  decoration: InputDecoration(
                    hintText: 'Search items…',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.9),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _showFilters,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: hasFilter
                        ? const Color(0xFFF97316)
                        : Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: hasFilter ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Semester chips row
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: 13,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              if (i == 0) {
                final active = _filterSemester == null;
                return _SemChip(
                  label: 'All',
                  active: active,
                  onTap: () {
                    setState(() => _filterSemester = null);
                    _load();
                  },
                );
              }
              final sem = 'Semester $i';
              final active = _filterSemester == sem;
              return _SemChip(
                label: 'Sem $i',
                active: active,
                onTap: () {
                  setState(() => _filterSemester = active ? null : sem);
                  _load();
                },
              );
            },
          ),
        ),
        // Listings
        Expanded(
          child: _loading
              ? ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: 5,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, __) => const _SkeletonBrowseCard(),
                )
              : _listings.isEmpty
                  ? const Center(
                      child: Text(
                        'No listings found.\nTry adjusting your filters.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B), height: 1.5),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: _listings.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _BrowseCard(
                          listing: _listings[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CampusShareDetailScreen(
                                listing: _listings[i],
                              ),
                            ),
                          ).then((_) => _load()),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}

// ── Semester chip ─────────────────────────────────────────────────────────────
class _SemChip extends StatelessWidget {
  const _SemChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF97316) : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? const Color(0xFFF97316)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF64748B),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ── Browse card ───────────────────────────────────────────────────────────────
class _BrowseCard extends StatelessWidget {
  const _BrowseCard({required this.listing, required this.onTap});
  final Listing listing;
  final VoidCallback onTap;

  Color get _typeColor => switch (listing.type) {
        ListingType.borrow => const Color(0xFF2196F3),
        ListingType.rent => const Color(0xFF8B5CF6),
        ListingType.sell => const Color(0xFF10B981),
      };

  String get _typeLabel => switch (listing.type) {
        ListingType.borrow => 'Borrow',
        ListingType.rent => 'Rent',
        ListingType.sell => 'Sell',
      };

  String get _conditionLabel => switch (listing.condition) {
        ItemCondition.excellent => 'Excellent',
        ItemCondition.good => 'Good',
        ItemCondition.fair => 'Fair',
        ItemCondition.forParts => 'For Parts',
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.95)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F9EFF).withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo or icon
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: listing.photos.isNotEmpty
                  ? Image.network(
                      listing.photos.first,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _iconBox(),
                    )
                  : _iconBox(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    listing.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _SmallChip(label: _typeLabel, color: _typeColor),
                      _SmallChip(
                          label: _conditionLabel,
                          color: const Color(0xFF64748B)),
                      if (listing.semesterTags.isNotEmpty)
                        _SmallChip(
                          label: listing.semesterTags.first,
                          color: const Color(0xFF8B5CF6),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFCBD5E1), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _iconBox() => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: _typeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.inventory_2_rounded, color: _typeColor, size: 26),
      );
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 10.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Filter bottom sheet ───────────────────────────────────────────────────────
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.selectedType,
    required this.selectedCategory,
    required this.selectedCondition,
    required this.selectedSemester,
    required this.onApply,
  });
  final ListingType? selectedType;
  final ItemCategory? selectedCategory;
  final ItemCondition? selectedCondition;
  final String? selectedSemester;
  final void Function(ListingType?, ItemCategory?, ItemCondition?, String?)
      onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  ListingType? _type;
  ItemCategory? _category;
  ItemCondition? _condition;
  String? _semester;

  @override
  void initState() {
    super.initState();
    _type = widget.selectedType;
    _category = widget.selectedCategory;
    _condition = widget.selectedCondition;
    _semester = widget.selectedSemester;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filters',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A))),
            const SizedBox(height: 16),
            _filterLabel('Type'),
            Wrap(
              spacing: 8,
              children: ListingType.values.map((t) {
                final active = _type == t;
                return ChoiceChip(
                  label: Text(t.name),
                  selected: active,
                  onSelected: (_) =>
                      setState(() => _type = active ? null : t),
                  selectedColor: const Color(0xFFF97316),
                  labelStyle: TextStyle(
                      color: active ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.w600),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            _filterLabel('Condition'),
            Wrap(
              spacing: 8,
              children: ItemCondition.values.map((c) {
                final active = _condition == c;
                return ChoiceChip(
                  label: Text(c.name),
                  selected: active,
                  onSelected: (_) =>
                      setState(() => _condition = active ? null : c),
                  selectedColor: const Color(0xFFF97316),
                  labelStyle: TextStyle(
                      color: active ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.w600),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _type = null;
                        _category = null;
                        _condition = null;
                        _semester = null;
                      });
                    },
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316)),
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onApply(_type, _category, _condition, _semester);
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
                fontSize: 12)),
      );
}

class _SkeletonBrowseCard extends StatefulWidget {
  const _SkeletonBrowseCard();

  @override
  State<_SkeletonBrowseCard> createState() => _SkeletonBrowseCardState();
}

class _SkeletonBrowseCardState extends State<_SkeletonBrowseCard>
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.95)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F9EFF).withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildShimmerBox(width: 56, height: 56, borderRadius: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildShimmerBox(width: 140, height: 16, borderRadius: 4),
                      const SizedBox(height: 8),
                      _buildShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
                      const SizedBox(height: 6),
                      _buildShimmerBox(width: 180, height: 12, borderRadius: 4),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildShimmerBox(width: 60, height: 18, borderRadius: 6),
                          const SizedBox(width: 6),
                          _buildShimmerBox(width: 50, height: 18, borderRadius: 6),
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [
            Color(0xFFE2E8F0),
            Color(0xFFF1F5F9),
            Color(0xFFE2E8F0),
          ],
          stops: [
            0.0,
            0.5 + _gradientPosition.value * 0.25,
            1.0,
          ],
        ),
      ),
    );
  }
}
