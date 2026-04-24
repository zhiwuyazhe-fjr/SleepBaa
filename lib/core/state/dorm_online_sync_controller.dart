import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

typedef DormOnlineSyncPeriodicTimerFactory =
    Timer Function(Duration duration, void Function(Timer timer) callback);

class DormOnlineSyncController {
  DormOnlineSyncController({
    required AuthRepository authRepository,
    required DormRepository dormRepository,
    Duration heartbeatInterval = const Duration(seconds: 20),
    DormOnlineSyncPeriodicTimerFactory? periodicTimerFactory,
  }) : _authRepository = authRepository,
       _dormRepository = dormRepository,
       _heartbeatInterval = heartbeatInterval,
       _periodicTimerFactory = periodicTimerFactory ?? Timer.periodic;

  final AuthRepository _authRepository;
  final DormRepository _dormRepository;
  final Duration _heartbeatInterval;
  final DormOnlineSyncPeriodicTimerFactory _periodicTimerFactory;

  Timer? _heartbeatTimer;
  bool _started = false;
  bool _isDrainingSync = false;
  bool? _queuedOnlineState;
  bool _queuedRefreshSnapshot = false;
  Completer<void>? _drainCompleter;

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    _startHeartbeatTimer();
    unawaited(markOnline());
  }

  Future<void> markOnline({bool refreshSnapshot = false}) {
    _startHeartbeatTimer();
    return _enqueueSync(online: true, refreshSnapshot: refreshSnapshot);
  }

  Future<void> markOffline() {
    _stopHeartbeatTimer();
    return _enqueueSync(online: false, refreshSnapshot: false);
  }

  void handleAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_started) {
          start();
          return;
        }
        _startHeartbeatTimer();
        unawaited(markOnline());
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _stopHeartbeatTimer();
        break;
    }
  }

  void _startHeartbeatTimer() {
    if (_heartbeatTimer != null) {
      return;
    }
    _heartbeatTimer = _periodicTimerFactory(_heartbeatInterval, (_) {
      unawaited(markOnline());
    });
  }

  void _stopHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _enqueueSync({
    required bool online,
    required bool refreshSnapshot,
  }) async {
    final String? uid = _currentSyncUid();
    if (uid == null) {
      return;
    }
    _queuedOnlineState = online;
    _queuedRefreshSnapshot = _queuedRefreshSnapshot || refreshSnapshot;
    if (_isDrainingSync) {
      return _drainCompleter?.future ?? Future<void>.value();
    }
    _isDrainingSync = true;
    _drainCompleter = Completer<void>();
    unawaited(_drainSyncLoop());
    return _drainCompleter!.future;
  }

  String? _currentSyncUid() {
    if (!_authRepository.hasVerifiedPhoneIdentity) {
      return null;
    }
    final UserProfile currentUser = _authRepository.currentUser;
    final String uid = currentUser.uid.trim();
    if (uid.isEmpty || _dormRepository.currentDorm.id.trim().isEmpty) {
      return null;
    }
    return uid;
  }

  Future<void> _drainSyncLoop() async {
    try {
      while (_queuedOnlineState != null) {
        final String? uid = _currentSyncUid();
        final bool online = _queuedOnlineState!;
        final bool refreshSnapshot = online && _queuedRefreshSnapshot;
        _queuedOnlineState = null;
        _queuedRefreshSnapshot = false;
        if (uid == null) {
          continue;
        }
        await _dormRepository.updateCurrentUserOnlineStatus(
          uid: uid,
          online: online,
        );
        if (refreshSnapshot) {
          await _dormRepository.refreshDormSnapshot();
        }
      }
      _drainCompleter?.complete();
    } catch (error, stackTrace) {
      _drainCompleter?.completeError(error, stackTrace);
      rethrow;
    } finally {
      _drainCompleter = null;
      _isDrainingSync = false;
    }
  }

  Future<void> dispose() async {
    _stopHeartbeatTimer();
  }
}
