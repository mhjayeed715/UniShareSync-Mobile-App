import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/alumni_profile_model.dart';
import '../../data/repositories/alumni_repository.dart';

class AlumniState {
  final AsyncValue<List<AlumniProfile>> profiles;
  final bool fromCache;
  final DateTime? cachedAt;

  const AlumniState({
    required this.profiles,
    required this.fromCache,
    this.cachedAt,
  });

  AlumniState copyWith({
    AsyncValue<List<AlumniProfile>>? profiles,
    bool? fromCache,
    DateTime? cachedAt,
  }) {
    return AlumniState(
      profiles: profiles ?? this.profiles,
      fromCache: fromCache ?? this.fromCache,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }
}

class AlumniNotifier extends StateNotifier<AlumniState> {
  AlumniNotifier(this._repository)
      : super(const AlumniState(
          profiles: AsyncValue.loading(),
          fromCache: false,
        ));

  final AlumniRepository _repository;
  AlumniFilters _currentFilters = const AlumniFilters();
  AlumniSort _currentSort = AlumniSort.newestBatch;
  String _currentQuery = '';

  AlumniFilters get currentFilters => _currentFilters;
  AlumniSort get currentSort => _currentSort;
  String get currentQuery => _currentQuery;

  Future<void> fetchAlumni({
    AlumniFilters? filters,
    String? searchQuery,
    AlumniSort? sort,
    bool forceRefresh = false,
  }) async {
    if (filters != null) _currentFilters = filters;
    if (searchQuery != null) _currentQuery = searchQuery;
    if (sort != null) _currentSort = sort;

    if (!state.profiles.hasValue || forceRefresh) {
      state = state.copyWith(profiles: const AsyncValue.loading());
    }

    try {
      final result = await _repository.fetchAlumni(
        filters: _currentFilters,
        searchQuery: _currentQuery,
        sort: _currentSort,
        forceRefresh: forceRefresh,
      );

      state = AlumniState(
        profiles: AsyncValue.data(result.profiles),
        fromCache: result.fromCache,
        cachedAt: result.cachedAt,
      );
    } catch (e, stack) {
      state = state.copyWith(profiles: AsyncValue.error(e, stack));
    }
  }

  Future<List<int>> fetchAvailableBatchYears() async {
    return _repository.fetchAvailableBatchYears();
  }

  // Groups list by batch year
  Map<int, List<AlumniProfile>> groupByBatch(List<AlumniProfile> list) {
    final Map<int, List<AlumniProfile>> grouped = {};
    for (final alumni in list) {
      grouped.putIfAbsent(alumni.batchYear, () => []).add(alumni);
    }
    
    // Sort batch groups by name alphabetically (which is already done by local sort, but ensure it)
    for (final key in grouped.keys) {
      grouped[key]!.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    }
    
    return grouped;
  }
}

final alumniRepositoryProvider = Provider<AlumniRepository>((ref) {
  return AlumniRepository();
});

final alumniProvider = StateNotifierProvider<AlumniNotifier, AlumniState>((ref) {
  final repo = ref.watch(alumniRepositoryProvider);
  return AlumniNotifier(repo);
});
