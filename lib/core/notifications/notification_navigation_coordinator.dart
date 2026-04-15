import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/notifications/app_notification_service.dart';

class NotificationNavigationCoordinator {
  NotificationNavigationCoordinator({
    required GoRouter router,
    required NotificationRepository notificationRepository,
    required AppNotificationService notificationService,
  }) : _router = router,
       _notificationRepository = notificationRepository,
       _notificationService = notificationService;

  final GoRouter _router;
  final NotificationRepository _notificationRepository;
  final AppNotificationService _notificationService;

  StreamSubscription<NotificationLaunchIntent>? _subscription;
  bool _started = false;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    _subscription = _notificationService.launchIntents.listen((intent) {
      unawaited(_handleIntent(intent));
    });
    final NotificationLaunchIntent? initialIntent =
        await _notificationService.takeInitialLaunchIntent();
    if (initialIntent != null) {
      await _handleIntent(initialIntent);
    }
  }

  Future<void> _handleIntent(NotificationLaunchIntent intent) async {
    if (intent.isSleepModeLaunch || _isShellRootRoute(intent.route)) {
      _router.go(intent.route);
    } else {
      _router.push(intent.route);
    }
    final String? notificationId = intent.notificationId;
    if (!intent.markAsRead || notificationId == null || notificationId.isEmpty) {
      return;
    }
    await _notificationRepository.markRead(notificationId);
    await _notificationService.cancelNotificationForItem(notificationId);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }
}

bool _isShellRootRoute(String route) {
  return route == AppRoutes.homePreSleep ||
      route == AppRoutes.dorm ||
      route == AppRoutes.profile;
}
