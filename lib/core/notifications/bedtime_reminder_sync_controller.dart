import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/app_notification_service.dart';

class BedtimeReminderSyncController {
  BedtimeReminderSyncController({
    required AuthRepository authRepository,
    required UserSettingsRepository settingsRepository,
    required AppNotificationService notificationService,
  }) : _authRepository = authRepository,
       _settingsRepository = settingsRepository,
       _notificationService = notificationService;

  final AuthRepository _authRepository;
  final UserSettingsRepository _settingsRepository;
  final AppNotificationService _notificationService;

  Future<void> _syncTail = Future<void>.value();
  bool _started = false;
  String _lastFingerprint = '';

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    _authRepository.addListener(_handleDependencyChanged);
    _settingsRepository.addListener(_handleDependencyChanged);
    unawaited(sync(force: true));
  }

  void handleAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(sync(force: true));
    }
  }

  Future<void> sync({bool force = false}) {
    if (!_started) {
      return Future<void>.value();
    }
    final Future<void> next = _syncTail.then((_) => _runSync(force: force));
    _syncTail = next.catchError((Object error, StackTrace stackTrace) {});
    return next;
  }

  Future<void> _runSync({required bool force}) async {
    final String uid = _authRepository.currentUser.uid.trim();
    if (!_authRepository.isAuthenticated || uid.isEmpty) {
      _lastFingerprint = '';
      await _notificationService.cancelBedtimeReminder();
      return;
    }

    final UserSettings settings = _settingsRepository.currentSettings;
    final String fingerprint =
        '$uid|${settings.bedtimeReminderEnabled}|'
        '${settings.bedtimeReminder.hour}:${settings.bedtimeReminder.minute}';
    if (!force && fingerprint == _lastFingerprint) {
      return;
    }

    if (!settings.bedtimeReminderEnabled) {
      await _notificationService.cancelBedtimeReminder();
      _lastFingerprint = fingerprint;
      return;
    }

    await _notificationService.scheduleBedtimeReminder(
      time: settings.bedtimeReminder,
    );
    _lastFingerprint = fingerprint;
  }

  void _handleDependencyChanged() {
    unawaited(sync());
  }

  Future<void> dispose() async {
    if (!_started) {
      return;
    }
    _started = false;
    _authRepository.removeListener(_handleDependencyChanged);
    _settingsRepository.removeListener(_handleDependencyChanged);
    await _syncTail;
  }
}
