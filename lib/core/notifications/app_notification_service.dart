import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {}

class NotificationLaunchIntent {
  const NotificationLaunchIntent({
    required this.route,
    required this.markAsRead,
    this.notificationId,
  });

  final String route;
  final bool markAsRead;
  final String? notificationId;

  bool get isSleepModeLaunch =>
      route == AppRoutes.homePostSleep && notificationId == null;
}

class AppNotificationService {
  AppNotificationService({
    FlutterLocalNotificationsPlugin? localNotificationsPlugin,
    TargetPlatform? platformOverride,
  }) : _localNotifications =
           localNotificationsPlugin ?? FlutterLocalNotificationsPlugin(),
       _platformOverride = platformOverride;

  static const String generalChannelId = 'sleep_dorm_messages';
  static const String sleepModeChannelId =
      'sleep_dorm_sleep_mode_foreground_v2';
  static const int sleepModeNotificationId = 900001;
  static const String _generalChannelName = 'Sleep Dorm Messages';
  static const String _generalChannelDescription =
      'General message center notifications.';
  static const String _sleepModeChannelName = '睡眠模式常驻通知';
  static const String _sleepModeChannelDescription = '睡眠模式进行中时显示在通知栏和锁屏上的常驻通知。';
  static const String _sleepModeNotificationTitle = '睡眠模式进行中';
  static const String _sleepModeNotificationBody = '点击可返回睡眠模式页面';

  final FlutterLocalNotificationsPlugin _localNotifications;
  final TargetPlatform? _platformOverride;
  final StreamController<NotificationLaunchIntent> _launchIntentController =
      StreamController<NotificationLaunchIntent>.broadcast();

  NotificationLaunchIntent? _initialLaunchIntent;
  bool _initialized = false;
  Future<void> _sleepModeNotificationTail = Future<void>.value();
  int _sleepModeNotificationRequestId = 0;

  bool get isSupported =>
      !kIsWeb &&
      (_platformOverride ?? defaultTargetPlatform) == TargetPlatform.android;

  Stream<NotificationLaunchIntent> get launchIntents =>
      _launchIntentController.stream;

  Future<void> initialize() async {
    if (_initialized || !isSupported) {
      return;
    }

    await _initializeLocalNotifications();

    final NotificationAppLaunchDetails? launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    final String? localPayload = launchDetails?.notificationResponse?.payload
        ?.trim();
    if ((launchDetails?.didNotificationLaunchApp ?? false) &&
        localPayload != null &&
        localPayload.isNotEmpty) {
      _initialLaunchIntent = _intentFromPayload(localPayload);
    }

    _initialized = true;
    if (_initialLaunchIntent != null && _launchIntentController.hasListener) {
      _launchIntentController.add(_initialLaunchIntent!);
      _initialLaunchIntent = null;
    }
  }

  Future<void> _initializeLocalNotifications() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _androidPlugin;
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final String? payload = response.payload?.trim();
        if (payload == null || payload.isEmpty) {
          return;
        }
        final NotificationLaunchIntent? intent = _intentFromPayload(payload);
        if (intent != null) {
          _launchIntentController.add(intent);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        generalChannelId,
        _generalChannelName,
        description: _generalChannelDescription,
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        sleepModeChannelId,
        _sleepModeChannelName,
        description: _sleepModeChannelDescription,
        importance: Importance.high,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<NotificationLaunchIntent?> takeInitialLaunchIntent() async {
    final NotificationLaunchIntent? intent = _initialLaunchIntent;
    _initialLaunchIntent = null;
    return intent;
  }

  Future<void> showNotificationItem(NotificationItem item) async {
    if (!isSupported) {
      return;
    }
    await _localNotifications.show(
      _notificationIdFor(item.id),
      item.title,
      item.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          generalChannelId,
          _generalChannelName,
          channelDescription: _generalChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.public,
        ),
      ),
      payload: jsonEncode(<String, Object?>{
        'kind': 'notification',
        'notificationId': item.id,
        'route': item.route,
      }),
    );
  }

  Future<void> showSleepModeNotification({
    required SleepSession session,
  }) async {
    if (!isSupported) {
      return;
    }
    final int requestId = ++_sleepModeNotificationRequestId;
    final String payload = jsonEncode(<String, Object?>{
      'kind': 'sleep_mode',
      'sessionId': session.id,
      'route': AppRoutes.homePostSleep,
    });
    await _enqueueSleepModeNotificationOperation(() async {
      if (requestId != _sleepModeNotificationRequestId) {
        return;
      }
      await _localNotifications.show(
        sleepModeNotificationId,
        _sleepModeNotificationTitle,
        _sleepModeNotificationBody,
        NotificationDetails(android: _sleepModeNotificationDetails),
        payload: payload,
      );
    });
  }

  Future<void> cancelSleepModeNotification() async {
    final int requestId = ++_sleepModeNotificationRequestId;
    await _enqueueSleepModeNotificationOperation(() async {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _androidPlugin;
      if (androidPlugin != null) {
        try {
          await androidPlugin.stopForegroundService();
        } catch (_) {
          // Older builds may have started a foreground service; ignore cleanup
          // failures so regular notification cancellation can still proceed.
        }
      }
      if (requestId != _sleepModeNotificationRequestId) {
        return;
      }
      await _localNotifications.cancel(sleepModeNotificationId);
    });
  }

  Future<void> cancelNotificationForItem(String notificationId) {
    return _localNotifications.cancel(_notificationIdFor(notificationId));
  }

  NotificationLaunchIntent? _intentFromPayload(String payload) {
    final Map<String, dynamic> data = _payloadMapOf(payload);
    final String kind = _stringOf(data['kind']);
    if (kind == 'sleep_mode') {
      return const NotificationLaunchIntent(
        route: AppRoutes.homePostSleep,
        markAsRead: false,
      );
    }
    final String route = _stringOf(data['route'], AppRoutes.notifications);
    if (route.isEmpty) {
      return null;
    }
    return NotificationLaunchIntent(
      route: route,
      markAsRead: true,
      notificationId: _stringOf(data['notificationId']),
    );
  }

  int _notificationIdFor(String key) {
    return key.codeUnits.fold<int>(
      17,
      (int previous, int unit) => (previous * 31 + unit) & 0x7fffffff,
    );
  }

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin =>
      _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

  AndroidNotificationDetails get _sleepModeNotificationDetails =>
      const AndroidNotificationDetails(
        sleepModeChannelId,
        _sleepModeChannelName,
        channelDescription: _sleepModeChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        ongoing: true,
        autoCancel: false,
        visibility: NotificationVisibility.public,
        playSound: false,
        enableVibration: false,
        silent: true,
        onlyAlertOnce: true,
        showWhen: false,
        category: AndroidNotificationCategory.status,
      );

  Future<void> _enqueueSleepModeNotificationOperation(
    Future<void> Function() operation,
  ) {
    final Future<void> next = _sleepModeNotificationTail.then(
      (_) => operation(),
    );
    _sleepModeNotificationTail = next.catchError(
      (Object error, StackTrace stackTrace) {},
    );
    return next;
  }

  Future<void> dispose() async {
    await _launchIntentController.close();
  }
}

Map<String, dynamic> _payloadMapOf(String payload) {
  try {
    final Object? decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {
    return <String, dynamic>{};
  }
  return <String, dynamic>{};
}

String _stringOf(dynamic value, [String fallback = '']) {
  return value is String ? value : fallback;
}
