import 'dart:async';

import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/app_notification_service.dart';

class SleepModeNotificationController {
  SleepModeNotificationController({
    required SleepSessionRepository sleepSessionRepository,
    required AppNotificationService notificationService,
  }) : _sleepSessionRepository = sleepSessionRepository,
       _notificationService = notificationService;

  final SleepSessionRepository _sleepSessionRepository;
  final AppNotificationService _notificationService;

  bool _started = false;

  void start() {
    if (_started) {
      return;
    }
    _sleepSessionRepository.addListener(_sync);
    _started = true;
    unawaited(synchronize());
  }

  Future<void> synchronize() {
    return _sync();
  }

  Future<void> _sync() async {
    if (!_notificationService.isSupported) {
      return;
    }
    final SleepSession? activeSession = _sleepSessionRepository.activeSession;
    if (activeSession != null &&
        activeSession.sleepModeActive &&
        activeSession.status == SleepSessionStatus.active &&
        activeSession.endedAt == null) {
      unawaited(
        _notificationService.showSleepModeNotification(session: activeSession),
      );
      return;
    }
    unawaited(_notificationService.cancelSleepModeNotification());
  }

  void dispose() {
    if (!_started) {
      return;
    }
    _sleepSessionRepository.removeListener(_sync);
    _started = false;
  }
}
