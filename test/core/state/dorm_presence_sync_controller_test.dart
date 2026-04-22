import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/data/in_memory_repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/state/dorm_location_anchor_cache.dart';
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

  test(
    'restoreCachedLocationAnchor ignores latest anchor from a different dorm',
    () async {
      final Dorm currentDorm = buildDefaultDorm(
        'cloud-user',
      ).copyWith(id: 'dorm-current', clearLocationAnchor: true);
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository(
        initialProfile: buildDefaultUserProfile().copyWith(
          uid: 'cloud-user',
          dormId: 'dorm-current',
          phoneNumber: '+8613800000000',
          phoneLinkedAt: DateTime(2026, 4, 22, 20),
        ),
      );
      final _RecordingDormRepository dormRepository = _RecordingDormRepository(
        initialDorm: currentDorm,
        currentUserId: 'cloud-user',
      );
      final _FakeDormLocationAnchorCache cache = _FakeDormLocationAnchorCache(
        latestAnchor: DormLocationAnchor(
          latitude: 39.9042,
          longitude: 116.4074,
          radiusMeters: 100,
          recordedAt: DateTime(2026, 4, 21, 20),
          recordedByUid: 'cloud-user',
        ),
      );
      final DormPresenceSyncController controller = DormPresenceSyncController(
        authRepository: authRepository,
        dormRepository: dormRepository,
        cache: cache,
      );

      await controller.restoreCachedLocationAnchor();

      expect(cache.readCalls, <String>['cloud-user:dorm-current']);
      expect(cache.readLatestCalls, 0);
      expect(dormRepository.hydrateCalls, 0);
      expect(dormRepository.currentDorm.locationAnchor, isNull);

      controller.dispose();
    },
  );
}

class _RecordingDormRepository extends InMemoryDormRepository {
  _RecordingDormRepository({super.initialDorm, super.currentUserId = 'unused'});

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

class _FakeDormLocationAnchorCache extends DormLocationAnchorCache {
  _FakeDormLocationAnchorCache({this.latestAnchor})
    : anchorByDorm = const <String, DormLocationAnchor>{};

  final Map<String, DormLocationAnchor> anchorByDorm;
  final DormLocationAnchor? latestAnchor;
  final List<String> readCalls = <String>[];
  int readLatestCalls = 0;

  @override
  Future<DormLocationAnchor?> read({
    required String uid,
    required String dormId,
  }) async {
    readCalls.add('$uid:$dormId');
    return anchorByDorm[dormId];
  }

  @override
  Future<DormLocationAnchor?> readLatest({required String uid}) async {
    readLatestCalls += 1;
    return latestAnchor;
  }

  @override
  Future<void> save({
    required String uid,
    required String dormId,
    required DormLocationAnchor anchor,
  }) async {}
}
