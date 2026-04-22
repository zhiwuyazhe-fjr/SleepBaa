import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class DormOnlineSyncController {
  DormOnlineSyncController({
    required AuthRepository authRepository,
    required DormRepository dormRepository,
    Duration heartbeatInterval = const Duration(seconds: 30),
  }) : _authRepository = authRepository,
       _dormRepository = dormRepository,
       _heartbeatInterval = heartbeatInterval;

  final AuthRepository _authRepository;
  final DormRepository _dormRepository;
  final Duration _heartbeatInterval;

  Timer? _timer;
  bool _started = false;
  bool _isSyncing = false;

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    _startTimer();
    unawaited(markOnline(refreshSnapshot: true));
  }

  Future<void> markOnline({bool refreshSnapshot = false}) {
    return _syncOnlineState(online: true, refreshSnapshot: refreshSnapshot);
  }

  Future<void> markOffline() {
    return _syncOnlineState(online: false, refreshSnapshot: false);
  }

  void handleAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_started) {
          start();
          return;
        }
        _startTimer();
        unawaited(markOnline(refreshSnapshot: true));
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _stopTimer();
        unawaited(markOffline());
        break;
    }
  }

  void _startTimer() {
    if (_timer != null) {
      return;
    }
    _timer = Timer.periodic(_heartbeatInterval, (_) {
      unawaited(markOnline(refreshSnapshot: true));
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _syncOnlineState({
    required bool online,
    required bool refreshSnapshot,
  }) async {
    if (_isSyncing) {
      return;
    }
    if (!_authRepository.hasVerifiedPhoneIdentity) {
      return;
    }
    final UserProfile currentUser = _authRepository.currentUser;
    final String uid = currentUser.uid.trim();
    if (uid.isEmpty || _dormRepository.currentDorm.id.trim().isEmpty) {
      return;
    }
    _isSyncing = true;
    try {
      await _dormRepository.updateCurrentUserOnlineStatus(
        uid: uid,
        online: online,
      );
      if (refreshSnapshot) {
        await _dormRepository.refreshDormSnapshot();
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> dispose() async {
    _stopTimer();
  }
}
