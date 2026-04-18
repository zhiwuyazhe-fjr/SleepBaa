import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_snapshot_store.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/app_notification_service.dart';

class CloudBaseNotificationSyncController {
  CloudBaseNotificationSyncController({
    required AuthRepository authRepository,
    required NotificationRepository notificationRepository,
    required AppNotificationService notificationService,
    CloudBaseSnapshotStore? snapshotStore,
    Duration pollInterval = const Duration(seconds: 30),
    Future<void> Function(NotificationItem item)? onShowNotificationItem,
  }) : _authRepository = authRepository,
       _notificationRepository = notificationRepository,
       _snapshotStore = snapshotStore,
       _pollInterval = pollInterval,
       _onShowNotificationItem =
           onShowNotificationItem ?? notificationService.showNotificationItem;

  final AuthRepository _authRepository;
  final NotificationRepository _notificationRepository;
  final CloudBaseSnapshotStore? _snapshotStore;
  final Duration _pollInterval;
  final Future<void> Function(NotificationItem item) _onShowNotificationItem;

  Timer? _timer;
  bool _started = false;
  bool _isRefreshing = false;
  bool _refreshQueued = false;
  String _knownUserId = '';
  bool _hasPrimedCurrentUser = false;

  void start() {
    if (_started || _snapshotStore == null) {
      return;
    }
    _started = true;
    _primeCurrentUser();
    _timer = Timer.periodic(_pollInterval, (_) {
      unawaited(refresh(showNewLocalNotifications: true));
    });
  }

  Future<void> refresh({required bool showNewLocalNotifications}) async {
    final CloudBaseSnapshotStore? snapshotStore = _snapshotStore;
    if (!_started || snapshotStore == null) {
      return;
    }
    final String currentUserId = _authRepository.currentUser.uid;
    if (currentUserId.isEmpty) {
      _knownUserId = '';
      _hasPrimedCurrentUser = false;
      return;
    }
    if (_isRefreshing) {
      _refreshQueued = _refreshQueued || showNewLocalNotifications;
      return;
    }

    _isRefreshing = true;
    bool shouldShowLocalNotifications = showNewLocalNotifications;
    try {
      do {
        _refreshQueued = false;
        _syncKnownUser();
        final Set<String> previousUnreadIds = _currentUnreadNotificationIds();
        final bool hadPrimedCurrentUser = _hasPrimedCurrentUser;
        await snapshotStore.refresh();
        _syncKnownUser();
        _hasPrimedCurrentUser = true;
        if (!shouldShowLocalNotifications || !hadPrimedCurrentUser) {
          shouldShowLocalNotifications = _refreshQueued;
          continue;
        }
        for (final NotificationItem item
            in _notificationRepository.unreadNotifications()) {
          if (previousUnreadIds.contains(item.id)) {
            continue;
          }
          await _onShowNotificationItem(item);
        }
        shouldShowLocalNotifications = _refreshQueued;
      } while (_refreshQueued);
    } finally {
      _isRefreshing = false;
    }
  }

  void handleAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refresh(showNewLocalNotifications: true));
    }
  }

  void _primeCurrentUser() {
    _syncKnownUser();
    if (_knownUserId.isEmpty) {
      return;
    }
    _hasPrimedCurrentUser = true;
  }

  void _syncKnownUser() {
    final String currentUserId = _authRepository.currentUser.uid;
    if (currentUserId == _knownUserId) {
      return;
    }
    _knownUserId = currentUserId;
    _hasPrimedCurrentUser = false;
  }

  Set<String> _currentUnreadNotificationIds() {
    return _notificationRepository
        .unreadNotifications()
        .map((NotificationItem item) => item.id)
        .toSet();
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
  }
}
