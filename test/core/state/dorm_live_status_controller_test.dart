import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/data/in_memory_repositories.dart';
import 'package:sleep_dorm_app/core/state/dorm_live_status_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'activates immediate refresh and periodic polling while page is visible',
    () async {
      final _RecordingDormRepository dormRepository =
          _RecordingDormRepository();
      final List<_ManualPeriodicTimer> timers = <_ManualPeriodicTimer>[];
      DateTime now = DateTime(2026, 4, 22, 22, 0);
      final DormLiveStatusController controller = DormLiveStatusController(
        dormRepository: dormRepository,
        clock: () => now,
        periodicTimerFactory:
            (Duration duration, void Function(Timer) callback) {
              final _ManualPeriodicTimer timer = _ManualPeriodicTimer(
                duration: duration,
                callback: callback,
              );
              timers.add(timer);
              return timer;
            },
      );

      controller.setPageActive(pageId: 'dorm-page', active: true);
      await pumpEventQueue();

      expect(controller.isPolling, isTrue);
      expect(controller.currentTime, now);
      expect(dormRepository.refreshCalls, 1);
      expect(timers, hasLength(1));
      expect(timers.single.duration, const Duration(seconds: 15));

      now = now.add(const Duration(seconds: 15));
      timers.single.fire();
      await pumpEventQueue();

      expect(controller.currentTime, now);
      expect(dormRepository.refreshCalls, 2);

      controller.dispose();
    },
  );

  test(
    'stops polling when no dorm page is visible and restarts on resume',
    () async {
      final _RecordingDormRepository dormRepository =
          _RecordingDormRepository();
      final List<_ManualPeriodicTimer> timers = <_ManualPeriodicTimer>[];
      DateTime now = DateTime(2026, 4, 22, 23, 0);
      final DormLiveStatusController controller = DormLiveStatusController(
        dormRepository: dormRepository,
        clock: () => now,
        periodicTimerFactory:
            (Duration duration, void Function(Timer) callback) {
              final _ManualPeriodicTimer timer = _ManualPeriodicTimer(
                duration: duration,
                callback: callback,
              );
              timers.add(timer);
              return timer;
            },
      );

      controller.setPageActive(pageId: 'dorm-page', active: true);
      await pumpEventQueue();
      expect(dormRepository.refreshCalls, 1);
      expect(timers.single.isActive, isTrue);

      controller.setPageActive(pageId: 'dorm-page', active: false);
      expect(controller.isPolling, isFalse);
      expect(timers.single.isActive, isFalse);

      controller.setPageActive(pageId: 'dorm-status-page', active: true);
      await pumpEventQueue();
      expect(dormRepository.refreshCalls, 2);
      expect(controller.isPolling, isTrue);
      expect(timers, hasLength(2));

      controller.handleAppLifecycleState(AppLifecycleState.paused);
      expect(controller.isPolling, isFalse);
      expect(timers.last.isActive, isFalse);

      now = now.add(const Duration(minutes: 1));
      controller.handleAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      expect(controller.isPolling, isTrue);
      expect(controller.currentTime, now);
      expect(dormRepository.refreshCalls, 3);
      expect(timers, hasLength(3));

      controller.dispose();
    },
  );
}

class _RecordingDormRepository extends InMemoryDormRepository {
  _RecordingDormRepository() : super(currentUserId: 'test-user');

  int refreshCalls = 0;

  @override
  Future<void> refreshDormSnapshot() async {
    refreshCalls += 1;
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
