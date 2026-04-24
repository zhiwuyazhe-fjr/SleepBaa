import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/data/in_memory_repositories.dart';
import 'package:sleep_dorm_app/core/state/dorm_online_sync_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'inactive does not mark offline and pause-resume keeps online state stable',
    () async {
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository(
        initialProfile: buildDefaultUserProfile().copyWith(
          uid: 'test-user',
          dormId: 'dorm-204',
          phoneNumber: '+8613800000000',
          phoneLinkedAt: DateTime(2026, 4, 24, 20),
        ),
      );
      final _RecordingDormRepository dormRepository = _RecordingDormRepository(
        currentUserId: 'test-user',
      );
      final List<_ManualPeriodicTimer> heartbeatTimers =
          <_ManualPeriodicTimer>[];
      final DormOnlineSyncController controller = DormOnlineSyncController(
        authRepository: authRepository,
        dormRepository: dormRepository,
        periodicTimerFactory:
            (Duration duration, void Function(Timer) callback) {
              final _ManualPeriodicTimer timer = _ManualPeriodicTimer(
                duration: duration,
                callback: callback,
              );
              heartbeatTimers.add(timer);
              return timer;
            },
      );

      controller.start();
      await pumpEventQueue();

      expect(heartbeatTimers, hasLength(1));
      expect(heartbeatTimers.single.duration, const Duration(seconds: 20));
      expect(dormRepository.onlineStates, <bool>[true]);

      controller.handleAppLifecycleState(AppLifecycleState.inactive);
      await pumpEventQueue();

      expect(dormRepository.onlineStates, <bool>[true]);
      expect(heartbeatTimers.single.isActive, isTrue);

      controller.handleAppLifecycleState(AppLifecycleState.paused);
      expect(heartbeatTimers.single.isActive, isFalse);
      expect(
        dormRepository.onlineStates.where((bool state) => !state),
        isEmpty,
      );

      controller.handleAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      expect(dormRepository.onlineStates, <bool>[true, true]);
      expect(
        dormRepository.onlineStates.where((bool state) => !state),
        isEmpty,
      );
      expect(heartbeatTimers, hasLength(2));

      await controller.dispose();
    },
  );

  test(
    'background lifecycle stops heartbeats without writing offline',
    () async {
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository(
        initialProfile: buildDefaultUserProfile().copyWith(
          uid: 'test-user',
          dormId: 'dorm-204',
          phoneNumber: '+8613800000000',
          phoneLinkedAt: DateTime(2026, 4, 24, 20),
        ),
      );
      final _RecordingDormRepository dormRepository = _RecordingDormRepository(
        currentUserId: 'test-user',
      );
      final List<_ManualPeriodicTimer> heartbeatTimers =
          <_ManualPeriodicTimer>[];
      final DormOnlineSyncController controller = DormOnlineSyncController(
        authRepository: authRepository,
        dormRepository: dormRepository,
        periodicTimerFactory:
            (Duration duration, void Function(Timer) callback) {
              final _ManualPeriodicTimer timer = _ManualPeriodicTimer(
                duration: duration,
                callback: callback,
              );
              heartbeatTimers.add(timer);
              return timer;
            },
      );

      controller.start();
      await pumpEventQueue();
      expect(heartbeatTimers, hasLength(1));

      controller.handleAppLifecycleState(AppLifecycleState.hidden);
      await pumpEventQueue();

      expect(heartbeatTimers.single.isActive, isFalse);
      expect(dormRepository.onlineStates, <bool>[true]);
      expect(
        dormRepository.onlineStates.where((bool state) => !state),
        isEmpty,
      );

      await controller.dispose();
    },
  );

  test(
    'latest online intent wins while a previous sync is still in flight',
    () async {
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository(
        initialProfile: buildDefaultUserProfile().copyWith(
          uid: 'test-user',
          dormId: 'dorm-204',
          phoneNumber: '+8613800000000',
          phoneLinkedAt: DateTime(2026, 4, 24, 20),
        ),
      );
      final _RecordingDormRepository dormRepository = _RecordingDormRepository(
        currentUserId: 'test-user',
        holdFirstUpdate: true,
      );
      final DormOnlineSyncController controller = DormOnlineSyncController(
        authRepository: authRepository,
        dormRepository: dormRepository,
      );

      final Future<void> first = controller.markOffline();
      await pumpEventQueue();
      final Future<void> second = controller.markOnline(refreshSnapshot: true);

      expect(dormRepository.onlineStates, <bool>[false]);

      dormRepository.releaseFirstUpdate();
      await Future.wait(<Future<void>>[first, second]);
      await pumpEventQueue();

      expect(dormRepository.onlineStates, <bool>[false, true]);
      expect(dormRepository.refreshCalls, 1);

      await controller.dispose();
    },
  );
}

class _RecordingDormRepository extends InMemoryDormRepository {
  _RecordingDormRepository({
    required super.currentUserId,
    this.holdFirstUpdate = false,
  });

  final bool holdFirstUpdate;
  final List<bool> onlineStates = <bool>[];
  int refreshCalls = 0;
  Completer<void>? _firstUpdateHold;

  @override
  Future<void> updateCurrentUserOnlineStatus({
    required String uid,
    required bool online,
  }) async {
    onlineStates.add(online);
    if (holdFirstUpdate && _firstUpdateHold == null) {
      _firstUpdateHold = Completer<void>();
      await _firstUpdateHold!.future;
    }
    await super.updateCurrentUserOnlineStatus(uid: uid, online: online);
  }

  @override
  Future<void> refreshDormSnapshot() async {
    refreshCalls += 1;
  }

  void releaseFirstUpdate() {
    _firstUpdateHold?.complete();
  }
}

class _ManualPeriodicTimer implements Timer {
  _ManualPeriodicTimer({
    required this.duration,
    required void Function(Timer timer) callback,
  }) : _callback = callback;

  final Duration duration;
  final void Function(Timer timer) _callback;

  bool _isActive = true;
  int _tick = 0;

  void fire() {
    if (!_isActive) {
      return;
    }
    _tick += 1;
    _callback(this);
  }

  @override
  bool get isActive => _isActive;

  @override
  int get tick => _tick;

  @override
  void cancel() {
    _isActive = false;
  }
}
