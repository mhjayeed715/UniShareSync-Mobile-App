import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/csv_saver.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/alumni_profile_model.dart';
import '../../data/models/alumni_connect_request_model.dart';
import '../../data/repositories/alumni_repository.dart';
import '../../data/repositories/alumni_connect_repository.dart';
import 'alumni_provider.dart';
import 'alumni_detail_provider.dart';

class AlumniAdminState {
  final List<AlumniProfile> pendingApprovals;
  final List<AlumniProfile> allAlumni;
  final List<AlumniConnectRequest> connectRequests;
  final Map<String, dynamic> analytics;
  final bool isLoading;
  final String? errorMessage;

  const AlumniAdminState({
    this.pendingApprovals = const [],
    this.allAlumni = const [],
    this.connectRequests = const [],
    this.analytics = const {},
    this.isLoading = false,
    this.errorMessage,
  });

  AlumniAdminState copyWith({
    List<AlumniProfile>? pendingApprovals,
    List<AlumniProfile>? allAlumni,
    List<AlumniConnectRequest>? connectRequests,
    Map<String, dynamic>? analytics,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AlumniAdminState(
      pendingApprovals: pendingApprovals ?? this.pendingApprovals,
      allAlumni: allAlumni ?? this.allAlumni,
      connectRequests: connectRequests ?? this.connectRequests,
      analytics: analytics ?? this.analytics,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AlumniAdminNotifier extends StateNotifier<AlumniAdminState> {
  AlumniAdminNotifier(this._client, this._repository, this._connectRepository)
      : super(const AlumniAdminState());

  final SupabaseClient _client;
  final AlumniRepository _repository;
  final AlumniConnectRepository _connectRepository;

  // ──────────────────────────────────────────────
  // Pending Approvals
  // ──────────────────────────────────────────────
  Future<void> fetchPendingApprovals() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _client
          .from('alumni_profiles')
          .select()
          .eq('is_verified', false)
          .eq('is_published', false)
          .order('created_at', ascending: false);

      final list = (response as List)
          .map((m) => AlumniProfile.fromMap(Map<String, dynamic>.from(m)))
          .toList();

      state = state.copyWith(pendingApprovals: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  Future<void> approveAlumni(AlumniProfile profile) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final currentUserId = _client.auth.currentUser?.id;
      final approvedAt = DateTime.now();

      // Update in DB
      await _client
          .from('alumni_profiles')
          .update({
            'is_verified': true,
            'is_published': true,
            'approved_by': currentUserId,
            'approved_at': approvedAt.toIso8601String(),
          })
          .eq('id', profile.id);

      final updatedProfile = profile.copyWith(
        isVerified: true,
        isPublished: true,
        approvedBy: currentUserId,
        approvedAt: approvedAt,
      );

      // Invoke send-alumni-approval-notification Edge Function
      try {
        await _client.functions.invoke('send-alumni-approval-notification', body: {
          'record': updatedProfile.toMap(),
          'action': 'approve'
        });
      } catch (_) {}

      // Refresh list
      await fetchPendingApprovals();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  Future<void> rejectAlumni(AlumniProfile profile, String note) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // Update in DB
      await _client
          .from('alumni_profiles')
          .update({
            'rejection_note': note,
            'is_verified': false,
            'is_published': false,
          })
          .eq('id', profile.id);

      final updatedProfile = profile.copyWith(
        rejectionNote: note,
        isVerified: false,
        isPublished: false,
      );

      // Invoke Edge Function
      try {
        await _client.functions.invoke('send-alumni-approval-notification', body: {
          'record': updatedProfile.toMap(),
          'action': 'reject',
          'rejection_note': note
        });
      } catch (_) {}

      // Refresh list
      await fetchPendingApprovals();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  // ──────────────────────────────────────────────
  // CRUD
  // ──────────────────────────────────────────────
  Future<void> fetchAllAlumni() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _client
          .from('alumni_profiles')
          .select()
          .order('batch_year', ascending: false)
          .order('full_name', ascending: true);

      final list = (response as List)
          .map((m) => AlumniProfile.fromMap(Map<String, dynamic>.from(m)))
          .toList();

      state = state.copyWith(allAlumni: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  Future<void> addAlumni(AlumniProfile profile, Uint8List? imageBytes) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.addAlumniProfile(profile, imageBytes);
      await fetchAllAlumni();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<void> updateAlumni(AlumniProfile profile, Uint8List? imageBytes, bool hasPhotoChanged) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // If a Faculty updates an already-approved profile, reset is_verified and is_published.
      // Admins maintain approval.
      final isFaculty = (await _client.from('profiles').select('role').eq('id', _client.auth.currentUser!.id).single())['role'] == 'faculty';
      final requiresReapproval = isFaculty && profile.isVerified;
      
      final updatedProfile = requiresReapproval 
          ? profile.copyWith(isVerified: false, isPublished: false)
          : profile;

      await _repository.updateAlumniProfile(updatedProfile, imageBytes, hasPhotoChanged);
      
      if (requiresReapproval) {
        // Notify Admins about the changes
        try {
          await _client.functions.invoke('send-pending-alumni-fcm', body: {
            'record': updatedProfile.toMap()
          });
        } catch (_) {}
      }

      await fetchAllAlumni();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<void> softDeleteAlumni(String alumniId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.softDeleteAlumniProfile(alumniId);
      await fetchAllAlumni();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      rethrow;
    }
  }



  Future<void> fetchConnectRequestsLog() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _connectRepository.fetchConnectRequestsLog();
      state = state.copyWith(connectRequests: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  Future<void> deleteConnectRequest(String requestId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _connectRepository.deleteConnectRequest(requestId);
      await fetchConnectRequestsLog();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  Future<void> clearAllConnectRequests() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _connectRepository.clearAllConnectRequests();
      await fetchConnectRequestsLog();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  // ──────────────────────────────────────────────
  // Export CSV
  // ──────────────────────────────────────────────
  Future<String> exportAlumniCSV() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // Query all details (ignoring visibility settings because this is Admin-level CSV report export)
      final response = await _client
          .from('alumni_profiles')
          .select()
          .order('batch_year', ascending: false)
          .order('full_name', ascending: true);

      final rows = response as List;
      final csvRows = <List<dynamic>>[];

      // Headers
      csvRows.add([
        'ID', 'Full Name', 'Batch Year', 'Student ID', 'Graduation Year', 'CGPA',
        'Thesis Title', 'Achievements', 'Current Role', 'Company', 'Industry',
        'Location', 'Experience (Years)', 'Email', 'Phone', 'LinkedIn', 'GitHub',
        'Website', 'Facebook', 'Open To Mentorship', 'Mentor Areas', 'Mentor Availability',
        'Source', 'Verified', 'Published', 'Created At'
      ]);

      for (final r in rows) {
        csvRows.add([
          r['id'],
          r['full_name'],
          r['batch_year'],
          r['student_id'] ?? '',
          r['graduation_year'] ?? '',
          r['cgpa'] ?? '',
          r['thesis_title'] ?? '',
          r['notable_achievements'] ?? '',
          r['current_job_title'] ?? '',
          r['current_company'] ?? '',
          r['industry'] ?? '',
          r['current_location'] ?? '',
          r['years_of_experience'] ?? '',
          r['email'] ?? '',
          r['phone'] ?? '',
          r['linkedin_url'] ?? '',
          r['github_url'] ?? '',
          r['website_url'] ?? '',
          r['facebook_url'] ?? '',
          r['is_open_to_mentor'] == true ? 'Yes' : 'No',
          (r['mentor_areas'] as List?)?.join(', ') ?? '',
          r['mentor_availability'] ?? '',
          r['entry_source'],
          r['is_verified'] == true ? 'Yes' : 'No',
          r['is_published'] == true ? 'Yes' : 'No',
          r['created_at']
        ]);
      }

      final csvString = const ListToCsvConverter().convert(csvRows);
      
      // Save CSV using cross-platform utility
      final filename = 'smuct_alumni_directory_${DateTime.now().millisecondsSinceEpoch}.csv';
      final filepath = await saveCsvFile(csvString, filename);

      state = state.copyWith(isLoading: false);
      return filepath;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      rethrow;
    }
  }

  // ──────────────────────────────────────────────
  // Analytics
  // ──────────────────────────────────────────────
  Future<void> fetchAnalytics() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // 1. Fetch total counts
      final totalRes = await _client.from('alumni_profiles').select('id, is_published, is_verified, is_open_to_mentor, batch_year, industry, current_location');
      final totalRows = totalRes as List;

      int totalCount = totalRows.where((r) => r['is_published'] == true && r['is_verified'] == true).length;
      int pendingCount = totalRows.where((r) => r['is_verified'] == false).length;
      int mentorCount = totalRows.where((r) => r['is_published'] == true && r['is_verified'] == true && r['is_open_to_mentor'] == true).length;

      // 2. Batch year distribution
      final Map<int, int> batchMap = {};
      for (final r in totalRows.where((r) => r['is_published'] == true && r['is_verified'] == true)) {
        final year = r['batch_year'] as int;
        batchMap[year] = (batchMap[year] ?? 0) + 1;
      }

      // 3. Industry distribution
      final Map<String, int> industryMap = {};
      for (final r in totalRows.where((r) => r['is_published'] == true && r['is_verified'] == true)) {
        final ind = r['industry']?.toString() ?? 'other';
        industryMap[ind] = (industryMap[ind] ?? 0) + 1;
      }

      // 4. Location breakdown
      final Map<String, int> locationMap = {};
      for (final r in totalRows.where((r) => r['is_published'] == true && r['is_verified'] == true)) {
        final loc = r['current_location']?.toString() ?? '';
        if (loc.trim().isEmpty) continue;
        
        // Group locations: Dhaka, Chittagong, Abroad
        final cleanLoc = loc.toLowerCase();
        String group = 'Abroad';
        if (cleanLoc.contains('dhaka')) {
          group = 'Dhaka';
        } else if (cleanLoc.contains('chittagong')) {
          group = 'Chittagong';
        } else if (cleanLoc.contains('bangladesh')) {
          group = 'Other BD';
        }
        locationMap[group] = (locationMap[group] ?? 0) + 1;
      }

      // 5. Connect requests this month
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final reqRes = await _client
          .from('alumni_connect_requests')
          .select('id')
          .gte('sent_at', startOfMonth.toIso8601String());
      int requestsThisMonth = (reqRes as List).length;

      final analyticsData = {
        'total': totalCount,
        'pending': pendingCount,
        'mentors': mentorCount,
        'batches': batchMap,
        'industries': industryMap,
        'locations': locationMap,
        'requests_this_month': requestsThisMonth
      };

      state = state.copyWith(analytics: analyticsData, isLoading: false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }
}

final alumniAdminProvider = StateNotifierProvider<AlumniAdminNotifier, AlumniAdminState>((ref) {
  final client = Supabase.instance.client;
  final repo = ref.watch(alumniRepositoryProvider);
  final connectRepo = ref.watch(alumniConnectRepositoryProvider);
  return AlumniAdminNotifier(client, repo, connectRepo);
});
