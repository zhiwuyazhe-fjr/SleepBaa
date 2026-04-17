import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/backend/app_environment.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_app_api_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_auth_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_session_store.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_snapshot_store.dart';
import 'package:sleep_dorm_app/core/data/cloudbase_repositories.dart';
import 'package:sleep_dorm_app/core/data/in_memory_repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

void main() {
  test(
    'cloudbase sleep session repository skips auth refresh when current user is already hydrated',
    () async {
      final _FakeCloudBaseAppApiClient appApiClient =
          _FakeCloudBaseAppApiClient(
            onPost: (String path, Map<String, dynamic> body) async {
              return <String, dynamic>{'ok': true, 'path': path, 'body': body};
            },
          );
      final _TestSnapshotStore snapshotStore = _TestSnapshotStore(
        appApiClient: appApiClient,
      );
      final _ThrowingEnsureAuthRepository authRepository =
          _ThrowingEnsureAuthRepository(
            initialProfile: buildDefaultUserProfile().copyWith(
              uid: 'cloud-user',
              dormId: 'dorm-204',
            ),
          );
      final CloudBaseSleepSessionRepository repository =
          CloudBaseSleepSessionRepository(
            authRepository: authRepository,
            snapshotStore: snapshotStore,
            appApiClient: appApiClient,
          );

      final SleepSession session = await repository.startOrResumeSleepSession(
        recommendationSnapshot: const <NightRecommendation>[],
        dormId: 'dorm-204',
      );

      expect(session.uid, 'cloud-user');
      expect(authRepository.ensureAuthenticatedCalls, 0);
    },
  );

  test(
    'cloudbase sleep session repository keeps local state responsive while remote sync is queued',
    () async {
      final List<_PostCall> calls = <_PostCall>[];
      final Completer<Map<String, dynamic>> enterCompleter =
          Completer<Map<String, dynamic>>();
      final Completer<Map<String, dynamic>> exitCompleter =
          Completer<Map<String, dynamic>>();
      final _FakeCloudBaseAppApiClient appApiClient =
          _FakeCloudBaseAppApiClient(
            onPost: (String path, Map<String, dynamic> body) {
              calls.add(_PostCall(path: path, body: body));
              if (path == '/api/sleep/enter') {
                return enterCompleter.future;
              }
              if (path == '/api/sleep/exit') {
                return exitCompleter.future;
              }
              throw StateError('Unexpected path: $path');
            },
          );
      final _TestSnapshotStore snapshotStore = _TestSnapshotStore(
        appApiClient: appApiClient,
      );
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository(
        initialProfile: buildDefaultUserProfile().copyWith(
          uid: 'cloud-user',
          dormId: 'dorm-204',
        ),
      );
      final CloudBaseSleepSessionRepository repository =
          CloudBaseSleepSessionRepository(
            authRepository: authRepository,
            snapshotStore: snapshotStore,
            appApiClient: appApiClient,
          );

      final SleepSession session = await repository.startOrResumeSleepSession(
        recommendationSnapshot: const <NightRecommendation>[],
        dormId: 'dorm-204',
      );

      expect(repository.activeSession?.id, session.id);

      await pumpEventQueue();
      expect(calls.map((call) => call.path), <String>['/api/sleep/enter']);

      await repository.finishActiveSleepSession(
        at: DateTime(2026, 4, 13, 7, 0),
      );

      expect(repository.activeSession, isNull);
      expect(repository.latestAwaitingFeedbackSession?.id, session.id);

      await pumpEventQueue();
      expect(calls.length, 1);

      enterCompleter.complete(<String, dynamic>{'ok': true});
      await pumpEventQueue();

      expect(calls.map((call) => call.path), <String>[
        '/api/sleep/enter',
        '/api/sleep/exit',
      ]);

      final Map<String, dynamic> enterBody = Map<String, dynamic>.from(
        calls.first.body['session'] as Map,
      );
      final Map<String, dynamic> exitBody = Map<String, dynamic>.from(
        calls.last.body['session'] as Map,
      );
      expect(enterBody['id'], session.id);
      expect(exitBody['id'], session.id);
      expect(exitBody['status'], SleepSessionStatus.awaitingFeedback.name);

      exitCompleter.complete(<String, dynamic>{'ok': true});
      await pumpEventQueue();

      expect(snapshotStore.refreshCount, 1);
    },
  );

  test(
    'cloudbase sleep session repository syncs pause events through the pause endpoint',
    () async {
      final List<_PostCall> calls = <_PostCall>[];
      final Completer<Map<String, dynamic>> enterCompleter =
          Completer<Map<String, dynamic>>();
      final Completer<Map<String, dynamic>> pauseCompleter =
          Completer<Map<String, dynamic>>();
      final _FakeCloudBaseAppApiClient appApiClient =
          _FakeCloudBaseAppApiClient(
            onPost: (String path, Map<String, dynamic> body) {
              calls.add(_PostCall(path: path, body: body));
              if (path == '/api/sleep/enter') {
                return enterCompleter.future;
              }
              if (path == '/api/sleep/pause') {
                return pauseCompleter.future;
              }
              throw StateError('Unexpected path: $path');
            },
          );
      final _TestSnapshotStore snapshotStore = _TestSnapshotStore(
        appApiClient: appApiClient,
      );
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository(
        initialProfile: buildDefaultUserProfile().copyWith(
          uid: 'cloud-user',
          dormId: 'dorm-204',
        ),
      );
      final CloudBaseSleepSessionRepository repository =
          CloudBaseSleepSessionRepository(
            authRepository: authRepository,
            snapshotStore: snapshotStore,
            appApiClient: appApiClient,
          );

      final SleepSession session = await repository.startOrResumeSleepSession(
        recommendationSnapshot: const <NightRecommendation>[],
        dormId: 'dorm-204',
      );

      await pumpEventQueue();
      expect(calls.map((call) => call.path), <String>['/api/sleep/enter']);

      await repository.pauseActiveSleepSession(
        at: DateTime(2026, 4, 13, 2, 0),
      );

      expect(repository.activeSession, isNull);
      expect(repository.sessionForSleepDayKey(session.sleepDayKey)?.status, SleepSessionStatus.paused);

      await pumpEventQueue();
      expect(calls.length, 1);

      enterCompleter.complete(<String, dynamic>{'ok': true});
      await pumpEventQueue();

      expect(calls.map((call) => call.path), <String>[
        '/api/sleep/enter',
        '/api/sleep/pause',
      ]);

      final Map<String, dynamic> pauseBody = Map<String, dynamic>.from(
        calls.last.body['session'] as Map,
      );
      expect(pauseBody['id'], session.id);
      expect(pauseBody['status'], SleepSessionStatus.paused.name);

      pauseCompleter.complete(<String, dynamic>{'ok': true});
      await pumpEventQueue();

      expect(snapshotStore.refreshCount, 1);
    },
  );

  test(
    'cloudbase dorm repository keeps local dorm status responsive while remote sync is queued',
    () async {
      final List<_PostCall> calls = <_PostCall>[];
      final Completer<Map<String, dynamic>> firstSyncCompleter =
          Completer<Map<String, dynamic>>();
      final Completer<Map<String, dynamic>> secondSyncCompleter =
          Completer<Map<String, dynamic>>();
      int syncIndex = 0;
      final _FakeCloudBaseAppApiClient appApiClient =
          _FakeCloudBaseAppApiClient(
            onPost: (String path, Map<String, dynamic> body) {
              calls.add(_PostCall(path: path, body: body));
              if (path != '/api/dorm/member/status') {
                throw StateError('Unexpected path: $path');
              }
              syncIndex += 1;
              return syncIndex == 1
                  ? firstSyncCompleter.future
                  : secondSyncCompleter.future;
            },
          );
      final _TestSnapshotStore snapshotStore = _TestSnapshotStore(
        appApiClient: appApiClient,
      );
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository(
        initialProfile: buildDefaultUserProfile().copyWith(
          uid: 'cloud-user',
          dormId: 'dorm-204',
          displayName: 'Cloud User',
          earnedBadgeIds: const <String>['first-week', 'early-sleeper'],
          equippedBadgeId: 'early-sleeper',
        ),
      );
      final CloudBaseDormRepository repository = CloudBaseDormRepository(
        authRepository: authRepository,
        snapshotStore: snapshotStore,
        appApiClient: appApiClient,
      );

      snapshotStore.pushPayload(<String, dynamic>{
        'data': <String, dynamic>{
          'user': <String, dynamic>{
            'uid': 'cloud-user',
            'displayName': 'Cloud User',
            'dormId': 'dorm-204',
            'earnedBadgeIds': <String>['first-week', 'early-sleeper'],
            'equippedBadgeId': 'early-sleeper',
          },
          'dorm': <String, dynamic>{
            'id': 'dorm-204',
            'name': '梅苑 2 栋 204',
            'overview': '宿舍整体状态平稳。',
            'noiseDb': 32,
            'lightLabel': '偏暗',
            'quietLabel': '良好',
            'rules': const <Map<String, dynamic>>[],
            'events': const <Map<String, dynamic>>[],
            'invites': const <Map<String, dynamic>>[],
            'members': <Map<String, dynamic>>[
              <String, dynamic>{
                'uid': 'cloud-user',
                'name': 'Cloud User',
                'status': DormMemberStatus.quiet.name,
                'presenceStatus': DormPresenceStatus.returned.name,
                'sleepModeActive': false,
                'lastActiveAt': '2026-04-13T15:00:00.000Z',
                'note': '准备休息。',
                'displayBadgeId': 'early-sleeper',
              },
            ],
          },
        },
      });

      await repository.updateCurrentUserStatus(
        uid: 'cloud-user',
        sleepModeActive: true,
        note: '已进入睡眠模式',
      );
      await repository.updateCurrentUserStatus(
        uid: 'cloud-user',
        sleepModeActive: false,
        note: '等待晨间反馈',
      );

      final DormMember currentMember = repository.currentDorm.members.first;
      expect(currentMember.sleepModeActive, isFalse);
      expect(currentMember.note, '等待晨间反馈');

      await pumpEventQueue();
      expect(calls.length, 1);
      expect(calls.first.body['sleepModeActive'], isTrue);

      firstSyncCompleter.complete(<String, dynamic>{'ok': true});
      await pumpEventQueue();

      expect(calls.length, 2);
      expect(calls.last.body['sleepModeActive'], isFalse);
      expect(calls.last.body['note'], '等待晨间反馈');

      secondSyncCompleter.complete(<String, dynamic>{'ok': true});
      await pumpEventQueue();

      expect(snapshotStore.refreshCount, 1);
    },
  );
}

class _PostCall {
  const _PostCall({required this.path, required this.body});

  final String path;
  final Map<String, dynamic> body;
}

class _TestSnapshotStore extends CloudBaseSnapshotStore {
  _TestSnapshotStore({required super.appApiClient});

  Map<String, dynamic> _nextPayload = <String, dynamic>{};
  int refreshCount = 0;

  @override
  Map<String, dynamic> get payload => _nextPayload;

  void pushPayload(Map<String, dynamic> payload) {
    _nextPayload = payload;
    notifyListeners();
  }

  @override
  Future<void> refresh() async {
    refreshCount += 1;
  }
}

class _FakeCloudBaseAppApiClient extends CloudBaseAppApiClient {
  _FakeCloudBaseAppApiClient({required this.onPost})
    : super(
        environment: const AppEnvironment(
          target: AppBackendTarget.production,
          appIdPrefix: 'com.dormsleep.app',
          cloudbaseEnvId: 'demo-env',
          cloudbaseAuthBaseUrl: 'https://example.com',
          cloudbaseAppApiBaseUrl: 'https://example.com',
          cloudbasePublishableKey: 'publishable-key',
          cloudbaseClientId: 'demo-env',
        ),
        sessionStore: _FakeSessionStore(),
        authClient: CloudBaseAuthClient(
          environment: const AppEnvironment(
            target: AppBackendTarget.production,
            appIdPrefix: 'com.dormsleep.app',
            cloudbaseEnvId: 'demo-env',
            cloudbaseAuthBaseUrl: 'https://example.com',
            cloudbaseAppApiBaseUrl: 'https://example.com',
            cloudbasePublishableKey: 'publishable-key',
            cloudbaseClientId: 'demo-env',
          ),
        ),
      );

  final Future<Map<String, dynamic>> Function(
    String path,
    Map<String, dynamic> body,
  )
  onPost;

  @override
  bool get isConfigured => true;

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic> body = const <String, dynamic>{},
  }) {
    return onPost(path, body);
  }
}

class _FakeSessionStore extends CloudBaseSessionStore {
  _FakeSessionStore();
}

class _ThrowingEnsureAuthRepository extends InMemoryAuthRepository {
  _ThrowingEnsureAuthRepository({required super.initialProfile});

  int ensureAuthenticatedCalls = 0;

  @override
  Future<UserProfile> ensureAuthenticated() {
    ensureAuthenticatedCalls += 1;
    throw StateError('ensureAuthenticated should not be called');
  }
}
