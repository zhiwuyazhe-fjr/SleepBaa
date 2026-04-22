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
import 'package:sleep_dorm_app/core/notifications/app_notification_service.dart';
import 'package:sleep_dorm_app/core/notifications/cloudbase_notification_sync_controller.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/support/dorm_member_status_presenter.dart';

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
      final DateTime startedAt = DateTime(2026, 4, 12, 23, 0);

      final SleepSession session = await repository.startOrResumeSleepSession(
        recommendationSnapshot: const <NightRecommendation>[],
        dormId: 'dorm-204',
        at: startedAt,
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

      final DateTime startedAt = DateTime(2026, 4, 12, 23, 0);
      final SleepSession session = await repository.startOrResumeSleepSession(
        recommendationSnapshot: const <NightRecommendation>[],
        dormId: 'dorm-204',
        at: startedAt,
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
    'cloudbase sleep session repository waits for the initial remote lookup before becoming ready',
    () {
      final _FakeCloudBaseAppApiClient appApiClient =
          _FakeCloudBaseAppApiClient(
            onPost: (String path, Map<String, dynamic> body) async {
              return <String, dynamic>{'ok': true, 'path': path, 'body': body};
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

      expect(repository.isReadyForSessionLookup, isFalse);

      snapshotStore.beginRefresh();
      expect(repository.isReadyForSessionLookup, isFalse);

      snapshotStore.completeRefresh(error: 'bootstrap failed');
      expect(repository.isReadyForSessionLookup, isTrue);
    },
  );

  test(
    'cloudbase sleep session repository becomes ready after the first payload is applied',
    () {
      final _FakeCloudBaseAppApiClient appApiClient =
          _FakeCloudBaseAppApiClient(
            onPost: (String path, Map<String, dynamic> body) async {
              return <String, dynamic>{'ok': true, 'path': path, 'body': body};
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
      final SleepSession session = _buildRemoteSleepSession(
        uid: 'cloud-user',
        id: 'cloud-session-1',
      );

      snapshotStore.beginRefresh();
      snapshotStore.completeRefresh(
        payload: <String, dynamic>{
          'data': <String, dynamic>{
            'user': <String, dynamic>{'uid': 'cloud-user'},
            'settings': const <String, dynamic>{},
            'dorm': const <String, dynamic>{},
            'sleepSessions': <Map<String, dynamic>>[
              _sleepSessionToPayload(session),
            ],
            'dreamEntries': const <Map<String, dynamic>>[],
            'sleepCaptureRecords': const <Map<String, dynamic>>[],
            'assistantThreads': const <Map<String, dynamic>>[],
            'assistantMessages': const <String, List<Map<String, dynamic>>>{},
            'cardSnapshots': const <String, Map<String, dynamic>>{},
            'userState': const <String, dynamic>{},
            'notifications': const <Map<String, dynamic>>[],
          },
        },
      );

      expect(repository.isReadyForSessionLookup, isTrue);
      expect(repository.sessions.single.id, session.id);
    },
  );

  test(
    'cloudbase sleep session repository is immediately ready when app api is unavailable',
    () {
      final _TestSnapshotStore snapshotStore = _TestSnapshotStore(
        appApiClient: _UnconfiguredCloudBaseAppApiClient(),
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
            appApiClient: _UnconfiguredCloudBaseAppApiClient(),
          );

      expect(repository.isReadyForSessionLookup, isTrue);
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

      await repository.pauseActiveSleepSession(at: DateTime(2026, 4, 13, 2, 0));

      expect(repository.activeSession, isNull);
      expect(
        repository.sessionForSleepDayKey(session.sleepDayKey)?.status,
        SleepSessionStatus.paused,
      );

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
    'cloudbase sleep session repository syncs archived stale sessions through the exit endpoint',
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
        at: DateTime(2026, 4, 16, 23, 0),
      );

      await pumpEventQueue();
      expect(calls.map((call) => call.path), <String>['/api/sleep/enter']);

      final List<SleepSession> archived = await repository
          .archivePastCutoffSessions(now: DateTime(2026, 4, 17, 20, 5));

      expect(archived, hasLength(1));
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

      final Map<String, dynamic> exitBody = Map<String, dynamic>.from(
        calls.last.body['session'] as Map,
      );
      expect(exitBody['id'], session.id);
      expect(exitBody['status'], SleepSessionStatus.awaitingFeedback.name);
      expect(exitBody['trackedDurationMinutes'], 1260);

      exitCompleter.complete(<String, dynamic>{'ok': true});
      await pumpEventQueue();

      expect(snapshotStore.refreshCount, 1);
    },
  );

  test(
    'cloudbase sleep session repository normalizes ended active sessions from snapshots',
    () async {
      final _FakeCloudBaseAppApiClient appApiClient =
          _FakeCloudBaseAppApiClient(
            onPost: (String path, Map<String, dynamic> body) async =>
                <String, dynamic>{'ok': true, 'path': path, 'body': body},
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

      snapshotStore.pushPayload(<String, dynamic>{
        'data': <String, dynamic>{
          'user': <String, dynamic>{'uid': 'cloud-user', 'dormId': 'dorm-204'},
          'userState': <String, dynamic>{'currentPhase': 'morning_feedback'},
          'sleepSessions': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'session-dirty',
              'uid': 'cloud-user',
              'startedAt': '2026-04-13T23:00:00.000Z',
              'endedAt': '2026-04-14T07:00:00.000Z',
              'status': SleepSessionStatus.active.name,
              'sleepModeActive': true,
              'dormId': 'dorm-204',
              'recommendations': const <Map<String, dynamic>>[],
              'selectedRecommendationIds': const <String>[],
              'awakenings': const <Map<String, dynamic>>[],
              'feedback': const <Map<String, dynamic>>[],
              'summary': null,
              'updatedAt': '2026-04-14T07:00:00.000Z',
            },
          ],
        },
      });

      expect(repository.activeSession, isNull);
      expect(repository.latestAwaitingFeedbackSession?.id, 'session-dirty');
      expect(
        repository.sessions.single.status,
        SleepSessionStatus.awaitingFeedback,
      );
      expect(repository.sessions.single.sleepModeActive, isFalse);
      expect(
        repository.sessions.single.displayEndAt,
        DateTime.parse('2026-04-14T07:00:00.000Z').toLocal(),
      );
      expect(repository.sessions.single.trackedDurationMinutes, 480);
    },
  );

  test(
    'cloudbase sleep session repository suppresses active sessions outside sleep mode phase',
    () async {
      final _FakeCloudBaseAppApiClient appApiClient =
          _FakeCloudBaseAppApiClient(
            onPost: (String path, Map<String, dynamic> body) async =>
                <String, dynamic>{'ok': true, 'path': path, 'body': body},
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

      snapshotStore.pushPayload(<String, dynamic>{
        'data': <String, dynamic>{
          'user': <String, dynamic>{'uid': 'cloud-user', 'dormId': 'dorm-204'},
          'userState': <String, dynamic>{
            'currentPhase': 'morning_feedback',
            'activeSessionId': 'session-phase-mismatch',
          },
          'sleepSessions': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'session-phase-mismatch',
              'uid': 'cloud-user',
              'startedAt': '2026-04-13T23:00:00.000Z',
              'endedAt': null,
              'status': SleepSessionStatus.active.name,
              'sleepModeActive': true,
              'dormId': 'dorm-204',
              'recommendations': const <Map<String, dynamic>>[],
              'selectedRecommendationIds': const <String>[],
              'awakenings': const <Map<String, dynamic>>[],
              'feedback': const <Map<String, dynamic>>[],
              'summary': null,
              'updatedAt': '2026-04-14T07:00:00.000Z',
            },
          ],
        },
      });

      expect(repository.activeSession, isNull);
      expect(repository.latestAwaitingFeedbackSession, isNull);
      expect(
        repository.sessions.single.status,
        SleepSessionStatus.awaitingFeedback,
      );
      expect(repository.sessions.single.sleepModeActive, isFalse);
      expect(repository.sessions.single.displayEndAt, isNull);
      expect(repository.sessions.single.trackedDurationMinutes, 0);
    },
  );

  test(
    'cloudbase sleep session repository keeps a complete local awaiting session when a newer snapshot is incomplete',
    () async {
      final _FakeCloudBaseAppApiClient appApiClient =
          _FakeCloudBaseAppApiClient(
            onPost: (String path, Map<String, dynamic> body) async =>
                <String, dynamic>{'ok': true, 'path': path, 'body': body},
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

      final DateTime startedAt = DateTime(2026, 4, 13, 23, 0);
      final DateTime endedAt = DateTime(2026, 4, 14, 7, 0);
      final SleepSession active = await repository.startOrResumeSleepSession(
        recommendationSnapshot: const <NightRecommendation>[],
        dormId: 'dorm-204',
        at: startedAt,
      );
      await repository.finishActiveSleepSession(at: endedAt);

      snapshotStore.pushPayload(<String, dynamic>{
        'data': <String, dynamic>{
          'user': <String, dynamic>{'uid': 'cloud-user', 'dormId': 'dorm-204'},
          'userState': <String, dynamic>{
            'currentPhase': 'morning_feedback',
            'activeSessionId': active.id,
          },
          'sleepSessions': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': active.id,
              'uid': 'cloud-user',
              'startedAt': startedAt.toUtc().toIso8601String(),
              'endedAt': null,
              'sleepDayKey': sleepDayKeyFromDate(startedAt),
              'status': SleepSessionStatus.active.name,
              'sleepModeActive': true,
              'dormId': 'dorm-204',
              'recommendations': const <Map<String, dynamic>>[],
              'selectedRecommendationIds': const <String>[],
              'awakenings': const <Map<String, dynamic>>[],
              'feedback': const <Map<String, dynamic>>[],
              'summary': null,
              'updatedAt': endedAt
                  .add(const Duration(minutes: 10))
                  .toUtc()
                  .toIso8601String(),
            },
          ],
        },
      });

      expect(repository.activeSession, isNull);
      expect(repository.latestAwaitingFeedbackSession?.id, active.id);
      expect(
        repository.sessions.single.status,
        SleepSessionStatus.awaitingFeedback,
      );
      expect(repository.sessions.single.sleepModeActive, isFalse);
      expect(repository.sessions.single.displayEndAt, endedAt);
      expect(repository.sessions.single.trackedDurationMinutes, 480);
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

  test('dorm online count uses foreground heartbeat fields only', () {
    final DateTime now = DateTime(2026, 4, 22, 12);
    final List<DormMember> members = <DormMember>[
      DormMember(
        uid: 'online',
        name: 'Online',
        status: DormMemberStatus.quiet,
        presenceStatus: DormPresenceStatus.returned,
        sleepModeActive: false,
        appOnline: true,
        appLastSeenAt: now.subtract(const Duration(seconds: 30)),
        lastActiveAt: now.subtract(const Duration(days: 1)),
        note: '',
      ),
      DormMember(
        uid: 'stale-heartbeat',
        name: 'Stale',
        status: DormMemberStatus.quiet,
        presenceStatus: DormPresenceStatus.returned,
        sleepModeActive: false,
        appOnline: true,
        appLastSeenAt: now.subtract(const Duration(seconds: 91)),
        lastActiveAt: now,
        note: '',
      ),
      DormMember(
        uid: 'offline',
        name: 'Offline',
        status: DormMemberStatus.quiet,
        presenceStatus: DormPresenceStatus.returned,
        sleepModeActive: false,
        appOnline: false,
        appLastSeenAt: now.subtract(const Duration(seconds: 10)),
        lastActiveAt: now,
        note: '',
      ),
      DormMember(
        uid: 'legacy-active',
        name: 'Legacy',
        status: DormMemberStatus.quiet,
        presenceStatus: DormPresenceStatus.returned,
        sleepModeActive: false,
        lastActiveAt: now.subtract(const Duration(seconds: 10)),
        note: '',
      ),
    ];

    expect(dormAppOnlineMemberCount(members, now: now), 1);
  });

  test(
    'cloudbase dorm repository prefers explicit sleepModeActive false over legacy sleeping status',
    () {
      final _FakeCloudBaseAppApiClient appApiClient =
          _FakeCloudBaseAppApiClient(
            onPost: (String path, Map<String, dynamic> body) async =>
                <String, dynamic>{'ok': true},
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
      final CloudBaseDormRepository repository = CloudBaseDormRepository(
        authRepository: authRepository,
        snapshotStore: snapshotStore,
        appApiClient: appApiClient,
      );

      snapshotStore.pushPayload(
        _dormPayload(<String, dynamic>{
          'uid': 'cloud-user',
          'name': 'Cloud User',
          'status': DormMemberStatus.sleeping.name,
          'presenceStatus': DormPresenceStatus.returned.name,
          'sleepModeActive': false,
          'lastActiveAt': '2026-04-21T23:00:00.000Z',
          'note': 'awake now',
        }),
      );

      final DormMember member = repository.currentDorm.members.single;
      expect(member.sleepModeActive, isFalse);
      expect(sleepingDormMemberCount(repository.currentDorm.members), 0);
    },
  );

  test(
    'cloudbase dorm repository keeps legacy sleeping fallback when sleepModeActive is missing',
    () {
      final _FakeCloudBaseAppApiClient appApiClient =
          _FakeCloudBaseAppApiClient(
            onPost: (String path, Map<String, dynamic> body) async =>
                <String, dynamic>{'ok': true},
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
      final CloudBaseDormRepository repository = CloudBaseDormRepository(
        authRepository: authRepository,
        snapshotStore: snapshotStore,
        appApiClient: appApiClient,
      );

      snapshotStore.pushPayload(
        _dormPayload(<String, dynamic>{
          'uid': 'cloud-user',
          'name': 'Cloud User',
          'status': DormMemberStatus.sleeping.name,
          'presenceStatus': DormPresenceStatus.returned.name,
          'lastActiveAt': '2026-04-21T23:00:00.000Z',
          'note': 'legacy sleeping',
        }),
      );

      final DormMember member = repository.currentDorm.members.single;
      expect(member.sleepModeActive, isTrue);
      expect(sleepingDormMemberCount(repository.currentDorm.members), 1);
    },
  );

  test(
    'cloudbase dorm repository parses heartbeat fields and posts heartbeat endpoint',
    () async {
      final List<_PostCall> calls = <_PostCall>[];
      final _FakeCloudBaseAppApiClient appApiClient =
          _FakeCloudBaseAppApiClient(
            onPost: (String path, Map<String, dynamic> body) async {
              calls.add(_PostCall(path: path, body: body));
              return <String, dynamic>{'ok': true};
            },
          );
      final _TestSnapshotStore snapshotStore = _TestSnapshotStore(
        appApiClient: appApiClient,
      );
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository(
        initialProfile: buildDefaultUserProfile().copyWith(
          uid: 'cloud-user',
          dormId: 'dorm-204',
          phoneNumber: '+86 13800138000',
        ),
      );
      final CloudBaseDormRepository repository = CloudBaseDormRepository(
        authRepository: authRepository,
        snapshotStore: snapshotStore,
        appApiClient: appApiClient,
      );

      snapshotStore.pushPayload(
        _dormPayload(<String, dynamic>{
          'uid': 'cloud-user',
          'name': 'Cloud User',
          'status': DormMemberStatus.quiet.name,
          'presenceStatus': DormPresenceStatus.returned.name,
          'sleepModeActive': false,
          'appOnline': true,
          'appLastSeenAt': '2026-04-22T04:00:00.000Z',
          'lastActiveAt': '2026-04-21T23:00:00.000Z',
          'note': '',
        }),
      );

      DormMember member = repository.currentDorm.members.single;
      expect(member.appOnline, isTrue);
      expect(member.appLastSeenAt, DateTime.parse('2026-04-22T04:00:00.000Z'));

      await repository.updateCurrentUserOnlineStatus(
        uid: 'cloud-user',
        online: false,
      );

      member = repository.currentDorm.members.single;
      expect(member.appOnline, isFalse);
      expect(calls.map((call) => call.path), <String>[
        '/api/dorm/member/heartbeat',
      ]);
      expect(calls.single.body['online'], isFalse);
      expect(snapshotStore.refreshCount, 0);
    },
  );

  test(
    'cloudbase dorm repository keeps newer local heartbeat during stale snapshot refresh',
    () async {
      final _FakeCloudBaseAppApiClient appApiClient =
          _FakeCloudBaseAppApiClient(
            onPost: (String path, Map<String, dynamic> body) async =>
                <String, dynamic>{'ok': true},
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
      final CloudBaseDormRepository repository = CloudBaseDormRepository(
        authRepository: authRepository,
        snapshotStore: snapshotStore,
        appApiClient: appApiClient,
      );

      snapshotStore.pushPayload(
        _dormPayload(<String, dynamic>{
          'uid': 'cloud-user',
          'name': 'Cloud User',
          'status': DormMemberStatus.quiet.name,
          'presenceStatus': DormPresenceStatus.returned.name,
          'sleepModeActive': false,
          'appOnline': true,
          'appLastSeenAt': '2026-04-22T04:00:00.000Z',
          'lastActiveAt': '2026-04-21T23:00:00.000Z',
          'note': '',
        }),
      );

      await repository.updateCurrentUserOnlineStatus(
        uid: 'cloud-user',
        online: false,
      );
      final DormMember localMember = repository.currentDorm.members.single;
      final DateTime localHeartbeatAt = localMember.appLastSeenAt!;

      snapshotStore.pushPayload(
        _dormPayload(<String, dynamic>{
          'uid': 'cloud-user',
          'name': 'Cloud User',
          'status': DormMemberStatus.quiet.name,
          'presenceStatus': DormPresenceStatus.returned.name,
          'sleepModeActive': false,
          'appOnline': true,
          'appLastSeenAt': localHeartbeatAt
              .subtract(const Duration(minutes: 5))
              .toUtc()
              .toIso8601String(),
          'lastActiveAt': '2026-04-21T23:00:00.000Z',
          'note': '',
        }),
      );

      final DormMember mergedMember = repository.currentDorm.members.single;
      expect(mergedMember.appOnline, isFalse);
      expect(mergedMember.appLastSeenAt, localHeartbeatAt);
    },
  );

  test(
    'cloudbase dorm repository adopts newer remote heartbeat during snapshot refresh',
    () async {
      final _FakeCloudBaseAppApiClient appApiClient =
          _FakeCloudBaseAppApiClient(
            onPost: (String path, Map<String, dynamic> body) async =>
                <String, dynamic>{'ok': true},
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
      final CloudBaseDormRepository repository = CloudBaseDormRepository(
        authRepository: authRepository,
        snapshotStore: snapshotStore,
        appApiClient: appApiClient,
      );

      snapshotStore.pushPayload(
        _dormPayload(<String, dynamic>{
          'uid': 'cloud-user',
          'name': 'Cloud User',
          'status': DormMemberStatus.quiet.name,
          'presenceStatus': DormPresenceStatus.returned.name,
          'sleepModeActive': false,
          'appOnline': true,
          'appLastSeenAt': '2026-04-22T04:00:00.000Z',
          'lastActiveAt': '2026-04-21T23:00:00.000Z',
          'note': '',
        }),
      );

      await repository.updateCurrentUserOnlineStatus(
        uid: 'cloud-user',
        online: false,
      );
      final DateTime localHeartbeatAt =
          repository.currentDorm.members.single.appLastSeenAt!;
      final String newerHeartbeatAt = localHeartbeatAt
          .add(const Duration(minutes: 5))
          .toUtc()
          .toIso8601String();

      snapshotStore.pushPayload(
        _dormPayload(<String, dynamic>{
          'uid': 'cloud-user',
          'name': 'Cloud User',
          'status': DormMemberStatus.quiet.name,
          'presenceStatus': DormPresenceStatus.returned.name,
          'sleepModeActive': false,
          'appOnline': true,
          'appLastSeenAt': newerHeartbeatAt,
          'lastActiveAt': '2026-04-21T23:00:00.000Z',
          'note': '',
        }),
      );

      final DormMember mergedMember = repository.currentDorm.members.single;
      expect(mergedMember.appOnline, isTrue);
      expect(mergedMember.appLastSeenAt, DateTime.parse(newerHeartbeatAt));
    },
  );

  test(
    'cloudbase dorm repository keeps local sleep exit during stale snapshot refresh',
    () async {
      final List<_PostCall> calls = <_PostCall>[];
      final Completer<Map<String, dynamic>> syncCompleter =
          Completer<Map<String, dynamic>>();
      final _FakeCloudBaseAppApiClient appApiClient =
          _FakeCloudBaseAppApiClient(
            onPost: (String path, Map<String, dynamic> body) {
              calls.add(_PostCall(path: path, body: body));
              return syncCompleter.future;
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
      final CloudBaseDormRepository repository = CloudBaseDormRepository(
        authRepository: authRepository,
        snapshotStore: snapshotStore,
        appApiClient: appApiClient,
      );
      final Map<String, dynamic> stalePayload = _dormPayload(<String, dynamic>{
        'uid': 'cloud-user',
        'name': 'Cloud User',
        'status': DormMemberStatus.quiet.name,
        'presenceStatus': DormPresenceStatus.returned.name,
        'sleepModeActive': true,
        'lastActiveAt': '2026-04-21T23:00:00.000Z',
        'note': 'sleeping',
      });

      snapshotStore.pushPayload(stalePayload);
      await repository.updateCurrentUserStatus(
        uid: 'cloud-user',
        sleepModeActive: false,
        note: 'waiting for feedback',
      );
      expect(repository.currentDorm.members.single.sleepModeActive, isFalse);

      await pumpEventQueue();
      expect(calls.single.path, '/api/dorm/member/status');
      snapshotStore.pushPayload(stalePayload);

      expect(repository.currentDorm.members.single.sleepModeActive, isFalse);
      expect(
        repository.currentDorm.members.single.note,
        'waiting for feedback',
      );

      syncCompleter.complete(<String, dynamic>{'ok': true});
      await pumpEventQueue();

      expect(snapshotStore.refreshCount, 1);
    },
  );

  test(
    'cloudbase repositories preserve displayed avatar urls for unchanged resources',
    () {
      final _FakeCloudBaseAppApiClient appApiClient =
          _FakeCloudBaseAppApiClient(
            onPost: (String path, Map<String, dynamic> body) async =>
                <String, dynamic>{'ok': true},
          );
      final _TestSnapshotStore snapshotStore = _TestSnapshotStore(
        appApiClient: appApiClient,
      );
      final CloudBaseAuthRepository authRepository = CloudBaseAuthRepository(
        environment: _testCloudBaseEnvironment,
        authClient: CloudBaseAuthClient(environment: _testCloudBaseEnvironment),
        appApiClient: appApiClient,
        sessionStore: _FakeSessionStore(),
        snapshotStore: snapshotStore,
      );
      final CloudBaseDormRepository dormRepository = CloudBaseDormRepository(
        authRepository: authRepository,
        snapshotStore: snapshotStore,
        appApiClient: appApiClient,
      );

      snapshotStore.pushPayload(
        _dormPayload(
          <String, dynamic>{
            'uid': 'cloud-user',
            'name': 'Cloud User',
            'status': DormMemberStatus.quiet.name,
            'presenceStatus': DormPresenceStatus.returned.name,
            'sleepModeActive': false,
            'lastActiveAt': '2026-04-21T23:00:00.000Z',
            'note': '',
            'avatarUrl': 'https://cdn.example.com/avatar.png?sig=first',
          },
          user: <String, dynamic>{
            'uid': 'cloud-user',
            'displayName': 'Cloud User',
            'dormId': 'dorm-204',
            'avatarUrl': 'https://cdn.example.com/me.png?sig=first',
            'avatarStoragePath': 'avatars/cloud-user.png',
          },
        ),
      );
      snapshotStore.pushPayload(
        _dormPayload(
          <String, dynamic>{
            'uid': 'cloud-user',
            'name': 'Cloud User',
            'status': DormMemberStatus.quiet.name,
            'presenceStatus': DormPresenceStatus.returned.name,
            'sleepModeActive': false,
            'lastActiveAt': '2026-04-21T23:00:00.000Z',
            'note': '',
            'avatarUrl': 'https://cdn.example.com/avatar.png?sig=second',
          },
          user: <String, dynamic>{
            'uid': 'cloud-user',
            'displayName': 'Cloud User',
            'dormId': 'dorm-204',
            'avatarUrl': 'https://cdn.example.com/me.png?sig=second',
            'avatarStoragePath': 'avatars/cloud-user.png',
          },
        ),
      );

      expect(
        authRepository.currentUser.avatarUrl,
        'https://cdn.example.com/me.png?sig=first',
      );
      expect(
        dormRepository.currentDorm.members.single.avatarUrl,
        'https://cdn.example.com/avatar.png?sig=first',
      );

      authRepository.dispose();
      dormRepository.dispose();
    },
  );

  test(
    'cloudbase dorm repository parses missing presence status as unknown',
    () async {
      final _FakeCloudBaseAppApiClient appApiClient =
          _FakeCloudBaseAppApiClient(
            onPost: (String path, Map<String, dynamic> body) async =>
                <String, dynamic>{'ok': true, 'path': path, 'body': body},
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
          },
          'dorm': <String, dynamic>{
            'id': 'dorm-204',
            'name': '梅苑 2 栋 204',
            'members': <Map<String, dynamic>>[
              <String, dynamic>{
                'uid': 'cloud-user',
                'name': 'Cloud User',
                'status': DormMemberStatus.quiet.name,
                'sleepModeActive': false,
              },
              <String, dynamic>{
                'uid': 'roommate-away',
                'name': 'Roommate',
                'status': DormMemberStatus.away.name,
                'sleepModeActive': false,
              },
            ],
          },
        },
      });

      expect(
        repository.currentDorm.members
            .firstWhere((DormMember member) => member.uid == 'cloud-user')
            .presenceStatus,
        DormPresenceStatus.unknown,
      );
      expect(
        repository.currentDorm.members
            .firstWhere((DormMember member) => member.uid == 'roommate-away')
            .presenceStatus,
        DormPresenceStatus.away,
      );
    },
  );

  test(
    'cloudbase insights repository parses profile duration and quality trends from snapshots',
    () async {
      final _FakeCloudBaseAppApiClient appApiClient =
          _FakeCloudBaseAppApiClient(
            onPost: (String path, Map<String, dynamic> body) async =>
                <String, dynamic>{'ok': true, 'path': path, 'body': body},
          );
      final _TestSnapshotStore snapshotStore = _TestSnapshotStore(
        appApiClient: appApiClient,
      );
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository(
        initialProfile: buildDefaultUserProfile().copyWith(uid: 'cloud-user'),
      );
      final InMemorySleepSessionRepository sleepSessionRepository =
          InMemorySleepSessionRepository(
            initialSessions: const <SleepSession>[],
          );
      final CloudBaseInsightsRepository repository =
          CloudBaseInsightsRepository(
            authRepository: authRepository,
            snapshotStore: snapshotStore,
            appApiClient: appApiClient,
            sleepSessionRepository: sleepSessionRepository,
            dormRepository: InMemoryDormRepository(currentUserId: 'cloud-user'),
            dreamRepository: InMemoryDreamRepository(userId: 'cloud-user'),
          );

      snapshotStore.pushPayload(<String, dynamic>{
        'data': <String, dynamic>{
          'user': <String, dynamic>{'uid': 'cloud-user'},
          'cardSnapshots': <String, dynamic>{
            'profile_report': <String, dynamic>{
              'generatedAt': '2026-04-13T12:00:00.000Z',
              'cards': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'sleep-report-summary',
                  'type': 'sleep_report_summary',
                  'title': '本周睡眠快照',
                  'payload': <String, dynamic>{
                    'averageSleepHours': 6.8,
                    'averageSleepQuality': 78,
                    'averageRestedLevel': 74,
                    'calmNights': 4,
                    'dreamEntriesCount': 2,
                    'highlights': <String>['steady'],
                  },
                },
                <String, dynamic>{
                  'id': 'sleep-duration-trend',
                  'type': 'sleep_duration_trend',
                  'payload': <String, dynamic>{
                    'metricKey': 'sleep_duration',
                    'unit': 'hours',
                    'points': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'dateKey': '2026-04-07',
                        'weekdayLabel': '一',
                        'value': null,
                      },
                      <String, dynamic>{
                        'dateKey': '2026-04-08',
                        'weekdayLabel': '二',
                        'value': 6.9,
                      },
                    ],
                  },
                },
                <String, dynamic>{
                  'id': 'sleep-quality-trend',
                  'type': 'sleep_quality_trend',
                  'payload': <String, dynamic>{
                    'metricKey': 'sleep_quality',
                    'unit': 'score',
                    'points': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'dateKey': '2026-04-07',
                        'weekdayLabel': '一',
                        'value': null,
                      },
                      <String, dynamic>{
                        'dateKey': '2026-04-08',
                        'weekdayLabel': '二',
                        'value': 84,
                      },
                    ],
                  },
                },
              ],
            },
          },
        },
      });

      expect(repository.profileSleepDurationTrend.unit, 'hours');
      expect(repository.profileSleepDurationTrend.points[1].value, 6.9);
      expect(repository.profileSleepQualityTrend.unit, 'score');
      expect(repository.profileSleepQualityTrend.points[1].value, 84);

      repository.dispose();
      authRepository.dispose();
      sleepSessionRepository.dispose();
    },
  );

  test(
    'cloudbase insights repository prefers newer local completed sessions over stale profile snapshots',
    () async {
      final _FakeCloudBaseAppApiClient appApiClient =
          _FakeCloudBaseAppApiClient(
            onPost: (String path, Map<String, dynamic> body) async =>
                <String, dynamic>{'ok': true, 'path': path, 'body': body},
          );
      final _TestSnapshotStore snapshotStore = _TestSnapshotStore(
        appApiClient: appApiClient,
      );
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository(
        initialProfile: buildDefaultUserProfile().copyWith(uid: 'cloud-user'),
      );
      final DateTime now = DateTime.now();
      final InMemorySleepSessionRepository sleepSessionRepository =
          InMemorySleepSessionRepository(
            initialSessions: <SleepSession>[
              SleepSession(
                id: 'session-local-fresh',
                uid: 'cloud-user',
                startedAt: now.subtract(const Duration(hours: 8)),
                endedAt: now.subtract(const Duration(minutes: 30)),
                sleepDayKey: sleepDayKeyFromDate(
                  now.subtract(const Duration(hours: 8)),
                ),
                status: SleepSessionStatus.completed,
                sleepModeActive: false,
                dormId: 'dorm-204',
                recommendations: const <NightRecommendation>[],
                selectedRecommendationIds: const <String>[],
                segments: <SleepSegment>[
                  SleepSegment(
                    startedAt: now.subtract(const Duration(hours: 8)),
                    endedAt: now.subtract(const Duration(minutes: 30)),
                  ),
                ],
                trackedDurationMinutes: 450,
                awakenings: const <NightAwakeningEntry>[],
                feedback: const <RecommendationFeedback>[],
                summary: const MorningSummary(
                  sleepQuality: 4,
                  restedLevel: 4,
                  totalSleepHours: 7.5,
                  awakeningsCount: 0,
                  note: 'fresh local feedback',
                ),
                updatedAt: now,
              ),
            ],
          );
      final CloudBaseInsightsRepository repository =
          CloudBaseInsightsRepository(
            authRepository: authRepository,
            snapshotStore: snapshotStore,
            appApiClient: appApiClient,
            sleepSessionRepository: sleepSessionRepository,
            dormRepository: InMemoryDormRepository(currentUserId: 'cloud-user'),
            dreamRepository: InMemoryDreamRepository(userId: 'cloud-user'),
          );

      snapshotStore.pushPayload(<String, dynamic>{
        'data': <String, dynamic>{
          'user': <String, dynamic>{'uid': 'cloud-user'},
          'cardSnapshots': <String, dynamic>{
            'profile_report': <String, dynamic>{
              'generatedAt': now
                  .subtract(const Duration(minutes: 5))
                  .toUtc()
                  .toIso8601String(),
              'cards': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'sleep-report-summary',
                  'type': 'sleep_report_summary',
                  'title': 'stale snapshot',
                  'payload': <String, dynamic>{
                    'averageSleepHours': 6.0,
                    'averageSleepQuality': 60,
                    'averageRestedLevel': 60,
                    'calmNights': 1,
                    'dreamEntriesCount': 0,
                    'highlights': <String>['stale'],
                  },
                },
                <String, dynamic>{
                  'id': 'sleep-duration-trend',
                  'type': 'sleep_duration_trend',
                  'payload': <String, dynamic>{
                    'metricKey': 'sleep_duration',
                    'unit': 'hours',
                    'points': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'dateKey': '2026-04-07',
                        'weekdayLabel': '一',
                        'value': 6.0,
                      },
                    ],
                  },
                },
                <String, dynamic>{
                  'id': 'sleep-quality-trend',
                  'type': 'sleep_quality_trend',
                  'payload': <String, dynamic>{
                    'metricKey': 'sleep_quality',
                    'unit': 'score',
                    'points': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'dateKey': '2026-04-07',
                        'weekdayLabel': '一',
                        'value': 60,
                      },
                    ],
                  },
                },
              ],
            },
          },
        },
      });

      expect(repository.currentReport.averageSleepHours, 7.5);
      expect(
        repository.profileSleepDurationTrend.points.any(
          (SleepTrendPoint point) => point.value == 7.5,
        ),
        isTrue,
      );
      expect(
        repository.profileSleepQualityTrend.points.any(
          (SleepTrendPoint point) => point.value == 80,
        ),
        isTrue,
      );

      repository.dispose();
      authRepository.dispose();
      sleepSessionRepository.dispose();
    },
  );

  test(
    'cloudbase feedback submission keeps newer local completed sessions when refreshed snapshots are stale',
    () async {
      final DateTime now = DateTime.now();
      final DateTime startedAt = now.subtract(const Duration(hours: 8));
      final DateTime endedAt = now.subtract(const Duration(minutes: 20));
      final List<_PostCall> calls = <_PostCall>[];
      final Map<String, dynamic> stalePayload = <String, dynamic>{
        'data': <String, dynamic>{
          'user': <String, dynamic>{'uid': 'cloud-user'},
          'userState': <String, dynamic>{
            'currentPhase': 'morning_feedback',
            'activeSessionId': 'session-feedback-stale',
          },
          'sleepSessions': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'session-feedback-stale',
              'uid': 'cloud-user',
              'startedAt': startedAt.toUtc().toIso8601String(),
              'endedAt': endedAt.toUtc().toIso8601String(),
              'sleepDayKey': sleepDayKeyFromDate(startedAt),
              'status': SleepSessionStatus.awaitingFeedback.name,
              'sleepModeActive': false,
              'dormId': 'dorm-204',
              'recommendations': const <Map<String, dynamic>>[],
              'selectedRecommendationIds': const <String>[],
              'segments': <Map<String, dynamic>>[
                <String, dynamic>{
                  'startedAt': startedAt.toUtc().toIso8601String(),
                  'endedAt': endedAt.toUtc().toIso8601String(),
                },
              ],
              'trackedDurationMinutes': 460,
              'awakenings': const <Map<String, dynamic>>[],
              'feedback': const <Map<String, dynamic>>[],
              'summary': null,
              'updatedAt': now
                  .subtract(const Duration(minutes: 10))
                  .toUtc()
                  .toIso8601String(),
            },
          ],
          'dreamEntries': const <Map<String, dynamic>>[],
          'sleepCaptureRecords': const <Map<String, dynamic>>[],
          'assistantThreads': const <Map<String, dynamic>>[],
          'assistantMessages': const <String, List<Map<String, dynamic>>>{},
          'notifications': const <Map<String, dynamic>>[],
          'cardSnapshots': <String, dynamic>{
            'profile_report': <String, dynamic>{
              'generatedAt': now
                  .subtract(const Duration(minutes: 5))
                  .toUtc()
                  .toIso8601String(),
              'cards': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'sleep-report-summary',
                  'type': 'sleep_report_summary',
                  'title': 'stale snapshot',
                  'payload': <String, dynamic>{
                    'averageSleepHours': 0.0,
                    'averageSleepQuality': 0.0,
                    'averageRestedLevel': 0.0,
                    'calmNights': 0,
                    'dreamEntriesCount': 0,
                    'highlights': <String>[],
                  },
                },
              ],
            },
          },
        },
      };
      final _FakeCloudBaseAppApiClient appApiClient =
          _FakeCloudBaseAppApiClient(
            onPost: (String path, Map<String, dynamic> body) async {
              calls.add(_PostCall(path: path, body: body));
              return <String, dynamic>{'ok': true, 'path': path, 'body': body};
            },
          );
      final _TestSnapshotStore snapshotStore = _TestSnapshotStore(
        appApiClient: appApiClient,
      );
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository(
        initialProfile: buildDefaultUserProfile().copyWith(uid: 'cloud-user'),
      );
      final CloudBaseSleepSessionRepository sleepSessionRepository =
          CloudBaseSleepSessionRepository(
            authRepository: authRepository,
            snapshotStore: snapshotStore,
            appApiClient: appApiClient,
          );
      final CloudBaseFeedbackRepository feedbackRepository =
          CloudBaseFeedbackRepository(
            sleepSessionRepository: sleepSessionRepository,
            appApiClient: appApiClient,
            snapshotStore: snapshotStore,
          );
      final CloudBaseInsightsRepository insightsRepository =
          CloudBaseInsightsRepository(
            authRepository: authRepository,
            snapshotStore: snapshotStore,
            appApiClient: appApiClient,
            sleepSessionRepository: sleepSessionRepository,
            dormRepository: InMemoryDormRepository(currentUserId: 'cloud-user'),
            dreamRepository: InMemoryDreamRepository(userId: 'cloud-user'),
          );

      snapshotStore.pushPayload(stalePayload);
      snapshotStore.onRefresh = () {
        snapshotStore.pushPayload(stalePayload);
      };

      await feedbackRepository.submitFeedback(
        session: sleepSessionRepository.sessions.single,
        summary: const MorningSummary(
          sleepQuality: 4,
          restedLevel: 5,
          totalSleepHours: 7.5,
          awakeningsCount: 0,
          note: 'fresh local feedback',
        ),
        recommendationFeedback: const <RecommendationFeedback>[],
      );

      expect(
        sleepSessionRepository.sessions.single.hasSubmittedFeedback,
        isTrue,
      );
      expect(
        sleepSessionRepository.sessions.single.status,
        SleepSessionStatus.completed,
      );
      expect(insightsRepository.currentReport.averageSleepHours, 7.5);
      expect(calls.map((call) => call.path), <String>['/api/feedback/morning']);
      final Map<String, dynamic> requestBody = calls.single.body;
      expect(requestBody['sessionId'], 'session-feedback-stale');
      expect(requestBody['session'], isA<Map<String, dynamic>>());
      final Map<String, dynamic> sessionBody = Map<String, dynamic>.from(
        requestBody['session'] as Map,
      );
      expect(sessionBody['id'], 'session-feedback-stale');
      expect(sessionBody['status'], SleepSessionStatus.completed.name);
      expect(sessionBody['summary'], isA<Map<String, dynamic>>());
      expect(requestBody['feedback'], isA<List<dynamic>>());

      insightsRepository.dispose();
      feedbackRepository.dispose();
      authRepository.dispose();
      sleepSessionRepository.dispose();
    },
  );

  test('cloudbase notification repository syncs read state', () async {
    final List<_PostCall> calls = <_PostCall>[];
    final _FakeCloudBaseAppApiClient appApiClient = _FakeCloudBaseAppApiClient(
      onPost: (String path, Map<String, dynamic> body) async {
        calls.add(_PostCall(path: path, body: body));
        return <String, dynamic>{'ok': true};
      },
    );
    final _TestSnapshotStore snapshotStore = _TestSnapshotStore(
      appApiClient: appApiClient,
    );
    final InMemoryAuthRepository authRepository = InMemoryAuthRepository(
      initialProfile: buildDefaultUserProfile().copyWith(uid: 'cloud-user'),
    );
    final CloudBaseNotificationRepository repository =
        CloudBaseNotificationRepository(
          authRepository: authRepository,
          snapshotStore: snapshotStore,
          appApiClient: appApiClient,
        );

    await repository.upsertNotification(
      NotificationItem(
        id: 'notif-1',
        category: NotificationCategory.system,
        title: 'Remote sync',
        body: 'Ensure the notification sync stays aligned.',
        createdAt: DateTime(2026, 4, 13, 12, 0),
        route: '/notifications',
        readAt: null,
        ownerUid: 'cloud-user',
      ),
    );

    await repository.markRead('notif-1');

    expect(repository.notifications.single.isRead, isTrue);
    expect(calls.map((call) => call.path).toList(growable: false), <String>[
      '/api/notifications/read',
    ]);
    expect(calls[0].body['notificationId'], 'notif-1');
    expect(calls[0].body['readAt'], isA<String>());

    repository.dispose();
    authRepository.dispose();
  });

  test(
    'cloudbase user settings keeps pending quick actions when refreshed snapshot omits them',
    () async {
      final List<_PostCall> calls = <_PostCall>[];
      final Map<String, dynamic> stalePayload = <String, dynamic>{
        'data': <String, dynamic>{
          'user': <String, dynamic>{'uid': 'cloud-user'},
          'settings': <String, dynamic>{'sleepGoalHours': 7.5},
        },
      };
      final _FakeCloudBaseAppApiClient appApiClient =
          _FakeCloudBaseAppApiClient(
            onPost: (String path, Map<String, dynamic> body) async {
              calls.add(_PostCall(path: path, body: body));
              return <String, dynamic>{'ok': true};
            },
          );
      final _TestSnapshotStore snapshotStore = _TestSnapshotStore(
        appApiClient: appApiClient,
      );
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository(
        initialProfile: buildDefaultUserProfile().copyWith(uid: 'cloud-user'),
      );
      final CloudBaseUserSettingsRepository repository =
          CloudBaseUserSettingsRepository(
            authRepository: authRepository,
            snapshotStore: snapshotStore,
            appApiClient: appApiClient,
          );
      snapshotStore.onRefresh = () {
        snapshotStore.pushPayload(stalePayload);
      };

      final List<String> selectedIds = <String>[
        HomeQuickActionIds.profileSettings,
        HomeQuickActionIds.thoughtVault,
        HomeQuickActionIds.dreamJournal,
        HomeQuickActionIds.profileReport,
      ];
      await repository.saveSettings(
        repository.currentSettings.copyWith(homeQuickActionIds: selectedIds),
      );

      expect(repository.currentSettings.homeQuickActionIds, selectedIds);
      expect(calls.map((call) => call.path), <String>['/api/profile/save']);
      final Map<String, dynamic> settingsBody = Map<String, dynamic>.from(
        calls.single.body['settings'] as Map,
      );
      expect(settingsBody['homeQuickActionIds'], selectedIds);

      snapshotStore.pushPayload(stalePayload);

      expect(repository.currentSettings.homeQuickActionIds, selectedIds);

      repository.dispose();
      authRepository.dispose();
    },
  );

  test(
    'cloudbase notification sync controller only surfaces newly fetched unread notifications',
    () async {
      final _FakeCloudBaseAppApiClient appApiClient =
          _FakeCloudBaseAppApiClient(
            onPost: (String path, Map<String, dynamic> body) async {
              return <String, dynamic>{'ok': true};
            },
          );
      final _TestSnapshotStore snapshotStore = _TestSnapshotStore(
        appApiClient: appApiClient,
      );
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository(
        initialProfile: buildDefaultUserProfile().copyWith(uid: 'cloud-user'),
      );
      final CloudBaseNotificationRepository repository =
          CloudBaseNotificationRepository(
            authRepository: authRepository,
            snapshotStore: snapshotStore,
            appApiClient: appApiClient,
          );

      snapshotStore.pushPayload(
        _bootstrapPayloadWithNotifications(<NotificationItem>[
          NotificationItem(
            id: 'notif-existing',
            category: NotificationCategory.system,
            title: 'Existing',
            body: 'Already synced before polling starts.',
            createdAt: DateTime(2026, 4, 13, 18, 0),
            route: '/notifications',
            readAt: null,
            ownerUid: 'cloud-user',
          ),
        ]),
      );

      final List<String> shownNotificationIds = <String>[];
      final CloudBaseNotificationSyncController controller =
          CloudBaseNotificationSyncController(
            authRepository: authRepository,
            notificationRepository: repository,
            notificationService: AppNotificationService(),
            snapshotStore: snapshotStore,
            onShowNotificationItem: (NotificationItem item) async {
              shownNotificationIds.add(item.id);
            },
          );

      controller.start();
      snapshotStore.onRefresh = () {
        snapshotStore.pushPayload(
          _bootstrapPayloadWithNotifications(<NotificationItem>[
            NotificationItem(
              id: 'notif-existing',
              category: NotificationCategory.system,
              title: 'Existing',
              body: 'Already synced before polling starts.',
              createdAt: DateTime(2026, 4, 13, 18, 0),
              route: '/notifications',
              readAt: null,
              ownerUid: 'cloud-user',
            ),
            NotificationItem(
              id: 'notif-new',
              category: NotificationCategory.reminder,
              title: 'Fresh reminder',
              body: 'Pulled from CloudBase after the initial prime.',
              createdAt: DateTime(2026, 4, 13, 18, 5),
              route: '/feedback/morning',
              readAt: null,
              ownerUid: 'cloud-user',
            ),
          ]),
        );
      };

      await controller.refresh(showNewLocalNotifications: true);

      expect(shownNotificationIds, <String>['notif-new']);

      await controller.dispose();
      repository.dispose();
      authRepository.dispose();
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
  bool _isRefreshing = false;
  String? _lastError;
  int refreshCount = 0;
  FutureOr<void> Function()? onRefresh;

  @override
  Map<String, dynamic> get payload => _nextPayload;

  @override
  bool get hasPayload => _nextPayload.isNotEmpty;

  @override
  bool get isRefreshing => _isRefreshing;

  @override
  String? get lastError => _lastError;

  void pushPayload(Map<String, dynamic> payload) {
    _nextPayload = payload;
    _isRefreshing = false;
    _lastError = null;
    notifyListeners();
  }

  void beginRefresh() {
    _isRefreshing = true;
    _lastError = null;
    notifyListeners();
  }

  void completeRefresh({Map<String, dynamic>? payload, String? error}) {
    if (payload != null) {
      _nextPayload = payload;
    }
    _isRefreshing = false;
    _lastError = error;
    notifyListeners();
  }

  @override
  Future<void> refresh() async {
    refreshCount += 1;
    await onRefresh?.call();
  }
}

const AppEnvironment _testCloudBaseEnvironment = AppEnvironment(
  target: AppBackendTarget.production,
  appIdPrefix: 'com.dormsleep.app',
  cloudbaseEnvId: 'demo-env',
  cloudbaseAuthBaseUrl: 'https://example.com',
  cloudbaseAppApiBaseUrl: 'https://example.com',
  cloudbasePublishableKey: 'publishable-key',
  cloudbaseClientId: 'demo-env',
);

Map<String, dynamic> _bootstrapPayloadWithNotifications(
  List<NotificationItem> notifications,
) {
  return <String, dynamic>{
    'data': <String, dynamic>{
      'user': <String, dynamic>{'uid': 'cloud-user'},
      'settings': <String, dynamic>{},
      'dorm': <String, dynamic>{},
      'sleepSessions': const <Map<String, dynamic>>[],
      'dreamEntries': const <Map<String, dynamic>>[],
      'sleepCaptureRecords': const <Map<String, dynamic>>[],
      'assistantThreads': const <Map<String, dynamic>>[],
      'assistantMessages': const <String, List<Map<String, dynamic>>>{},
      'cardSnapshots': const <String, Map<String, dynamic>>{},
      'userState': const <String, dynamic>{},
      'notifications': notifications
          .map(
            (NotificationItem item) => <String, dynamic>{
              'id': item.id,
              'category': item.category.name,
              'title': item.title,
              'body': item.body,
              'createdAt': item.createdAt.toIso8601String(),
              'route': item.route,
              'readAt': item.readAt?.toIso8601String(),
              'ownerUid': item.ownerUid,
            },
          )
          .toList(growable: false),
    },
  };
}

Map<String, dynamic> _dormPayload(
  Map<String, dynamic> member, {
  Map<String, dynamic>? user,
}) {
  return <String, dynamic>{
    'data': <String, dynamic>{
      'user':
          user ??
          <String, dynamic>{
            'uid': 'cloud-user',
            'displayName': 'Cloud User',
            'dormId': 'dorm-204',
          },
      'settings': const <String, dynamic>{},
      'dorm': <String, dynamic>{
        'id': 'dorm-204',
        'name': 'Dorm',
        'overview': '',
        'noiseDb': 32,
        'lightLabel': '',
        'quietLabel': '',
        'rules': const <Map<String, dynamic>>[],
        'events': const <Map<String, dynamic>>[],
        'invites': const <Map<String, dynamic>>[],
        'members': <Map<String, dynamic>>[member],
      },
      'sleepSessions': const <Map<String, dynamic>>[],
      'dreamEntries': const <Map<String, dynamic>>[],
      'sleepCaptureRecords': const <Map<String, dynamic>>[],
      'assistantThreads': const <Map<String, dynamic>>[],
      'assistantMessages': const <String, List<Map<String, dynamic>>>{},
      'cardSnapshots': const <String, Map<String, dynamic>>{},
      'userState': const <String, dynamic>{},
      'notifications': const <Map<String, dynamic>>[],
    },
  };
}

class _FakeCloudBaseAppApiClient extends CloudBaseAppApiClient {
  _FakeCloudBaseAppApiClient({required this.onPost})
    : super(
        environment: _testCloudBaseEnvironment,
        sessionStore: _FakeSessionStore(),
        authClient: CloudBaseAuthClient(environment: _testCloudBaseEnvironment),
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

class _UnconfiguredCloudBaseAppApiClient extends _FakeCloudBaseAppApiClient {
  _UnconfiguredCloudBaseAppApiClient()
    : super(
        onPost: (String path, Map<String, dynamic> body) async {
          throw StateError('App API should not be called when unconfigured.');
        },
      );

  @override
  bool get isConfigured => false;
}

SleepSession _buildRemoteSleepSession({
  required String uid,
  required String id,
}) {
  final DateTime startedAt = DateTime(2026, 4, 12, 23, 0);
  final DateTime endedAt = DateTime(2026, 4, 13, 7, 0);
  return SleepSession(
    id: id,
    uid: uid,
    startedAt: startedAt,
    endedAt: endedAt,
    sleepDayKey: sleepDayKeyFromDate(startedAt),
    status: SleepSessionStatus.awaitingFeedback,
    sleepModeActive: false,
    dormId: 'dorm-204',
    recommendations: const <NightRecommendation>[],
    selectedRecommendationIds: const <String>[],
    segments: <SleepSegment>[
      SleepSegment(startedAt: startedAt, endedAt: endedAt),
    ],
    trackedDurationMinutes: endedAt.difference(startedAt).inMinutes,
    awakenings: const <NightAwakeningEntry>[],
    feedback: const <RecommendationFeedback>[],
    summary: null,
    updatedAt: endedAt,
  );
}

Map<String, dynamic> _sleepSessionToPayload(SleepSession session) {
  return <String, dynamic>{
    'id': session.id,
    'uid': session.uid,
    'startedAt': session.startedAt.toIso8601String(),
    'endedAt': session.endedAt?.toIso8601String(),
    'sleepDayKey': session.sleepDayKey,
    'status': session.status.name,
    'sleepModeActive': session.sleepModeActive,
    'dormId': session.dormId,
    'recommendations': const <Map<String, dynamic>>[],
    'selectedRecommendationIds': const <String>[],
    'segments': <Map<String, dynamic>>[
      <String, dynamic>{
        'startedAt': session.startedAt.toIso8601String(),
        'endedAt': session.endedAt?.toIso8601String(),
      },
    ],
    'trackedDurationMinutes': session.trackedDurationMinutes,
    'awakenings': const <Map<String, dynamic>>[],
    'feedback': const <Map<String, dynamic>>[],
    'summary': null,
    'updatedAt': session.updatedAt?.toIso8601String(),
  };
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
