import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/alumni_profile_model.dart';
import '../../data/repositories/alumni_repository.dart';
import '../../data/repositories/alumni_connect_repository.dart';
import '../../../../services/auth_service.dart';
import 'alumni_provider.dart';

class AlumniDetailNotifier extends StateNotifier<AsyncValue<AlumniProfile?>> {
  AlumniDetailNotifier(this._repository, this._connectRepository)
      : super(const AsyncValue.loading());

  final AlumniRepository _repository;
  final AlumniConnectRepository _connectRepository;

  Future<void> fetchProfileDetail(String alumniId) async {
    state = const AsyncValue.loading();
    try {
      final profile = await _repository.fetchProfileDetail(alumniId);
      state = AsyncValue.data(profile);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> sendConnectRequest({
    required String alumniId,
    required String message,
  }) async {
    final senderProfile = await AuthService().getCurrentProfile();
    if (senderProfile == null) {
      throw StateError("Unable to load your profile. Please check your connection.");
    }

    final senderSemester = senderProfile.semester != null
        ? int.tryParse(senderProfile.semester!.replaceAll(RegExp(r'[^0-9]'), ''))
        : null;

    await _connectRepository.sendConnectRequest(
      alumniId: alumniId,
      message: message,
      senderName: senderProfile.fullName,
      senderEmail: senderProfile.email,
      senderSemester: senderSemester,
    );
  }

  Future<void> checkConnectRateLimit(String alumniId) async {
    final currentUserId = AuthService().currentUserId;
    if (currentUserId == null) {
      throw StateError("You must be logged in to connect with alumni.");
    }
    await _connectRepository.checkConnectRateLimit(
      senderId: currentUserId,
      alumniId: alumniId,
    );
  }
}

final alumniConnectRepositoryProvider = Provider<AlumniConnectRepository>((ref) {
  return AlumniConnectRepository();
});

final alumniDetailProvider = StateNotifierProvider<AlumniDetailNotifier, AsyncValue<AlumniProfile?>>((ref) {
  final repo = ref.watch(alumniRepositoryProvider);
  final connectRepo = ref.watch(alumniConnectRepositoryProvider);
  return AlumniDetailNotifier(repo, connectRepo);
});
