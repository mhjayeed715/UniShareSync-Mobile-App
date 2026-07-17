import 'dart:convert';
import 'dart:typed_data';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image/image.dart' as img;
import '../models/alumni_profile_model.dart';

class AlumniFilters {
  final List<int>? batchYears;
  final List<AlumniIndustry>? industries;
  final String? location;
  final bool? isOpenToMentor;
  final List<String>? mentorAreas;
  final bool? hasLinkedin;

  const AlumniFilters({
    this.batchYears,
    this.industries,
    this.location,
    this.isOpenToMentor,
    this.mentorAreas,
    this.hasLinkedin,
  });

  AlumniFilters copyWith({
    List<int>? batchYears,
    List<AlumniIndustry>? industries,
    String? location,
    bool? isOpenToMentor,
    List<String>? mentorAreas,
    bool? hasLinkedin,
  }) {
    return AlumniFilters(
      batchYears: batchYears ?? this.batchYears,
      industries: industries ?? this.industries,
      location: location ?? this.location,
      isOpenToMentor: isOpenToMentor ?? this.isOpenToMentor,
      mentorAreas: mentorAreas ?? this.mentorAreas,
      hasLinkedin: hasLinkedin ?? this.hasLinkedin,
    );
  }

  bool get isEmpty =>
      (batchYears == null || batchYears!.isEmpty) &&
      (industries == null || industries!.isEmpty) &&
      (location == null || location!.trim().isEmpty) &&
      (isOpenToMentor == null || !isOpenToMentor!) &&
      (mentorAreas == null || mentorAreas!.isEmpty) &&
      (hasLinkedin == null || !hasLinkedin!);
}

enum AlumniSort {
  newestBatch,
  oldestBatch,
  alphabetical,
  recentlyAdded
}

class AlumniFetchResult {
  final List<AlumniProfile> profiles;
  final bool fromCache;
  final DateTime? cachedAt;

  const AlumniFetchResult({
    required this.profiles,
    required this.fromCache,
    this.cachedAt,
  });
}

class AlumniRepository {
  AlumniRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const String _cacheBoxName = 'alumni_list_cache';
  static const String _listCacheKey = 'alumni_list';
  static const String _timestampCacheKey = 'alumni_list_timestamp';

  Future<Box<String>> _openCacheBox() async {
    if (Hive.isBoxOpen(_cacheBoxName)) {
      return Hive.box<String>(_cacheBoxName);
    }
    return Hive.openBox<String>(_cacheBoxName);
  }

  // ──────────────────────────────────────────────
  // Fetch Directory (verified + published)
  // ──────────────────────────────────────────────
  Future<AlumniFetchResult> fetchAlumni({
    AlumniFilters? filters,
    String? searchQuery,
    AlumniSort sort = AlumniSort.newestBatch,
    bool forceRefresh = false,
  }) async {
    final box = await _openCacheBox();

    // Check offline availability or local cache first if not forced refresh
    final cachedData = box.get(_listCacheKey);
    final cachedTimestampStr = box.get(_timestampCacheKey);
    final cachedTimestamp = cachedTimestampStr != null ? DateTime.tryParse(cachedTimestampStr) : null;
    final isCacheExpired = cachedTimestamp == null ||
        DateTime.now().difference(cachedTimestamp).inHours >= 24;

    if (!forceRefresh && cachedData != null && !isCacheExpired) {
      try {
        final decoded = jsonDecode(cachedData) as List;
        final list = decoded.map((m) => AlumniProfile.fromMap(Map<String, dynamic>.from(m))).toList();
        final filteredList = _applyLocalFilters(list, filters, searchQuery, sort);
        return AlumniFetchResult(
          profiles: filteredList,
          fromCache: true,
          cachedAt: cachedTimestamp,
        );
      } catch (_) {
        // Fallback to network if decoding fails
      }
    }

    try {
      // Build Supabase Query
      var query = _client
          .from('alumni_profiles')
          .select()
          .eq('is_verified', true)
          .eq('is_published', true);

      // Perform Fetch
      final response = await query;
      final rawList = response as List<dynamic>;
      final list = rawList.map((m) => AlumniProfile.fromMap(Map<String, dynamic>.from(m))).toList();

      // Update Hive Cache (strip contact info: emails/phones for security and offline caching constraints)
      final strippedList = list.map((profile) {
        final map = profile.toMap();
        map.remove('email');
        map.remove('phone');
        return map;
      }).toList();

      await box.put(_listCacheKey, jsonEncode(strippedList));
      await box.put(_timestampCacheKey, DateTime.now().toIso8601String());

      // Apply filters and sorting
      final filteredList = _applyLocalFilters(list, filters, searchQuery, sort);
      return AlumniFetchResult(
        profiles: filteredList,
        fromCache: false,
      );
    } catch (e) {
      // Fetch failed, try to load from expired cache as fallback
      if (cachedData != null) {
        final decoded = jsonDecode(cachedData) as List;
        final list = decoded.map((m) => AlumniProfile.fromMap(Map<String, dynamic>.from(m))).toList();
        final filteredList = _applyLocalFilters(list, filters, searchQuery, sort);
        return AlumniFetchResult(
          profiles: filteredList,
          fromCache: true,
          cachedAt: cachedTimestamp,
        );
      }
      rethrow;
    }
  }

  List<AlumniProfile> _applyLocalFilters(
    List<AlumniProfile> list,
    AlumniFilters? filters,
    String? searchQuery,
    AlumniSort sort,
  ) {
    var result = List<AlumniProfile>.from(list);

    // Apply Search
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final query = searchQuery.trim().toLowerCase();
      result = result.where((p) {
        final nameMatch = p.fullName.toLowerCase().contains(query);
        final companyMatch = (p.currentCompany ?? '').toLowerCase().contains(query);
        final titleMatch = (p.currentJobTitle ?? '').toLowerCase().contains(query);
        final batchMatch = p.batchYear.toString().contains(query);
        return nameMatch || companyMatch || titleMatch || batchMatch;
      }).toList();
    }

    // Apply Filters
    if (filters != null && !filters.isEmpty) {
      if (filters.batchYears != null && filters.batchYears!.isNotEmpty) {
        result = result.where((p) => filters.batchYears!.contains(p.batchYear)).toList();
      }
      if (filters.industries != null && filters.industries!.isNotEmpty) {
        result = result.where((p) => p.industry != null && filters.industries!.contains(p.industry)).toList();
      }
      if (filters.location != null && filters.location!.trim().isNotEmpty) {
        final loc = filters.location!.trim().toLowerCase();
        result = result.where((p) => (p.currentLocation ?? '').toLowerCase().contains(loc)).toList();
      }
      if (filters.isOpenToMentor == true) {
        result = result.where((p) => p.isOpenToMentor).toList();
      }
      if (filters.mentorAreas != null && filters.mentorAreas!.isNotEmpty) {
        result = result.where((p) {
          if (p.mentorAreas == null) return false;
          return filters.mentorAreas!.any((area) =>
              p.mentorAreas!.any((a) => a.toLowerCase().contains(area.toLowerCase())));
        }).toList();
      }
      if (filters.hasLinkedin == true) {
        result = result.where((p) => p.linkedinUrl != null && p.linkedinUrl!.isNotEmpty).toList();
      }
    }

    // Apply Sorting
    switch (sort) {
      case AlumniSort.oldestBatch:
        result.sort((a, b) {
          int cmp = a.batchYear.compareTo(b.batchYear);
          if (cmp != 0) return cmp;
          return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
        });
        break;
      case AlumniSort.alphabetical:
        result.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
        break;
      case AlumniSort.recentlyAdded:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case AlumniSort.newestBatch:
        result.sort((a, b) {
          int cmp = b.batchYear.compareTo(a.batchYear);
          if (cmp != 0) return cmp;
          return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
        });
        break;
    }

    return result;
  }

  // ──────────────────────────────────────────────
  // Fetch Detail Profile
  // ──────────────────────────────────────────────
  Future<AlumniProfile> fetchProfileDetail(String alumniId) async {
    final box = await _openCacheBox();

    try {
      final response = await _client
          .from('alumni_profiles')
          .select()
          .eq('id', alumniId)
          .single();

      final profile = AlumniProfile.fromMap(response);

      // Save to detail cache, but explicitly strip emails/phones for local privacy
      final strippedMap = profile.toMap()
        ..remove('email')
        ..remove('phone');
      await box.put('alumni_detail_$alumniId', jsonEncode(strippedMap));

      return profile;
    } catch (e) {
      // If offline or network fails, read from cached detail
      final cached = box.get('alumni_detail_$alumniId');
      if (cached != null) {
        return AlumniProfile.fromMap(jsonDecode(cached));
      }
      rethrow;
    }
  }

  // ──────────────────────────────────────────────
  // CRUD Operations (Admin / Faculty)
  // ──────────────────────────────────────────────
  Future<void> addAlumniProfile(AlumniProfile profile, Uint8List? imageBytes) async {
    // Perform email duplication pre-check
    if (profile.email != null && profile.email!.trim().isNotEmpty) {
      final dup = await _client
          .from('alumni_profiles')
          .select('id')
          .eq('email', profile.email!.trim())
          .maybeSingle();
      if (dup != null) {
        throw StateError("An alumni with this email already exists in the directory.");
      }
    }

    var insertedProfile = profile;
    
    // 1. Upload photo if provided
    if (imageBytes != null) {
      final resizedBytes = resizeImageTo400x400(imageBytes);
      final filename = '${profile.id}/photo.jpg';
      
      await _client.storage.from('alumni-assets').uploadBinary(
        'profile-photos/$filename',
        resizedBytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      
      final photoUrl = _client.storage.from('alumni-assets').getPublicUrl('profile-photos/$filename');
      insertedProfile = profile.copyWith(profilePhotoUrl: photoUrl);
    }

    // 2. Insert into database
    await _client.from('alumni_profiles').insert(insertedProfile.toMap());

    // 3. Trigger pending FCM notification if not verified (inserts inside Edge Function trigger)
    if (!insertedProfile.isVerified) {
      try {
        await _client.functions.invoke('send-pending-alumni-fcm', body: {
          'record': insertedProfile.toMap()
        });
      } catch (_) {}
    }
  }

  Future<void> updateAlumniProfile(AlumniProfile profile, Uint8List? imageBytes, bool hasPhotoChanged) async {
    // Duplication check on email update
    if (profile.email != null && profile.email!.trim().isNotEmpty) {
      final dup = await _client
          .from('alumni_profiles')
          .select('id')
          .eq('email', profile.email!.trim())
          .neq('id', profile.id)
          .maybeSingle();
      if (dup != null) {
        throw StateError("An alumni with this email already exists in the directory.");
      }
    }

    var updatedProfile = profile;

    // 1. Handle image upload if photo changed
    if (hasPhotoChanged && imageBytes != null) {
      final resizedBytes = resizeImageTo400x400(imageBytes);
      final filename = '${profile.id}/photo.jpg';
      
      await _client.storage.from('alumni-assets').uploadBinary(
        'profile-photos/$filename',
        resizedBytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      
      final photoUrl = _client.storage.from('alumni-assets').getPublicUrl('profile-photos/$filename');
      updatedProfile = profile.copyWith(profilePhotoUrl: photoUrl);
    } else if (hasPhotoChanged && imageBytes == null) {
      // Photo was removed
      final filename = '${profile.id}/photo.jpg';
      try {
        await _client.storage.from('alumni-assets').remove(['profile-photos/$filename']);
      } catch (_) {}
      updatedProfile = profile.copyWith(profilePhotoUrl: null);
    }

    // 2. Perform DB Update
    await _client
        .from('alumni_profiles')
        .update(updatedProfile.toMap())
        .eq('id', profile.id);
  }

  Future<void> softDeleteAlumniProfile(String alumniId) async {
    // 1. Remove photo if exists
    final filename = '$alumniId/photo.jpg';
    try {
      await _client.storage.from('alumni-assets').remove(['profile-photos/$filename']);
    } catch (_) {}

    // 2. Hard delete from database
    await _client
        .from('alumni_profiles')
        .delete()
        .eq('id', alumniId);
  }

  // ──────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────
  Uint8List resizeImageTo400x400(Uint8List data) {
    try {
      final image = img.decodeImage(data);
      if (image == null) return data;
      final resized = img.copyResize(image, width: 400, height: 400);
      return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
    } catch (_) {
      return data;
    }
  }

  Future<List<int>> fetchAvailableBatchYears() async {
    final response = await _client
        .from('alumni_profiles')
        .select('batch_year')
        .eq('is_verified', true)
        .eq('is_published', true);
    
    final rows = response as List;
    final years = rows.map((r) => r['batch_year'] as int).toSet().toList();
    years.sort((a, b) => b.compareTo(a)); // Descending order
    return years;
  }
}
