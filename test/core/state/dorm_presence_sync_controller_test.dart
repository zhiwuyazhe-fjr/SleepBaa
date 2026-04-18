import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/data/in_memory_repositories.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/state/dorm_presence_sync_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'syncPresenceFromCurrentLocation is a no-op when the user has no verified phone identity',
    () async {
      // A signed-out profile (uid empty, no phone) mirrors the state while the
      // user is sitting on the login page. Resuming the app from SMS must not
      // trigger any backend sync that would flip auth state.
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository(
        initialProfile: buildDefaultUserProfile().copyWith(
          uid: '',
          clearDormId: true,
          clearPhoneNumber: true,
          clearPhoneLinkedAt: true,
          clearAvatar: true,
        ),
      );
      final _RecordingDormRepository dormRepository =
          _RecordingDormRepository();

      final DormPresenceSyncController controller = DormPresenceSyncController(
        authRepository: authRepository,
        dormRepository: dormRepository,
      );

      await controller.syncPresenceFromCurrentLocation();
      await controller.restoreCachedLocationAnchor();

      expect(dormRepository.statusUpdates, isEmpty);
      expect(
        dormRepository.hydrateCalls,
        0,
        reason:
            'Presence sync must not mutate dorm state when unauthenticated.',
      );

      controller.dispose();
    },
  );
}

class _RecordingDormRepository extends InMemoryDormRepository {
  _RecordingDormRepository() : super(currentUserId: 'unused');

  int hydrateCalls = 0;
  final List<Map<String, Object?>> statusUpdates = <Map<String, Object?>>[];

  @override
  Future<void> updateCurrentUserStatus({
    required String uid,
    DormMemberStatus? status,
    DormPresenceStatus? presenceStatus,
    bool? sleepModeActive,
    String? note,
  }) async {
    statusUpdates.add(<String, Object?>{
      'uid': uid,
      'status': status,
      'presenceStatus': presenceStatus,
      'sleepModeActive': sleepModeActive,
      'note': note,
    });
    return super.updateCurrentUserStatus(
      uid: uid,
      status: status,
      presenceStatus: presenceStatus,
      sleepModeActive: sleepModeActive,
      note: note,
    );
  }

  @override
  void hydrateCurrentDormLocationAnchor(DormLocationAnchor anchor) {
    hydrateCalls += 1;
    super.hydrateCurrentDormLocationAnchor(anchor);
  }
}
