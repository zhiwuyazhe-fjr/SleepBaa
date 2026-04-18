import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/app_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          calls.add(call);
          switch (call.method) {
            case 'initialize':
              return true;
            case 'getNotificationAppLaunchDetails':
              return <String, Object?>{'notificationLaunchedApp': false};
            case 'requestNotificationsPermission':
              return true;
            case 'stopForegroundService':
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('initialize creates the sleep mode channel', () async {
    final AppNotificationService service = AppNotificationService(
      platformOverride: TargetPlatform.android,
    );

    await service.initialize();

    final MethodCall sleepChannelCall = calls.firstWhere(
      (MethodCall call) =>
          call.method == 'createNotificationChannel' &&
          (call.arguments as Map<Object?, Object?>)['id'] ==
              AppNotificationService.sleepModeChannelId,
    );
    final Map<Object?, Object?> arguments =
        sleepChannelCall.arguments as Map<Object?, Object?>;

    expect(
      arguments['name'],
      isA<String>().having((String value) => value, 'value', isNotEmpty),
    );
    expect(
      arguments['description'],
      isA<String>().having((String value) => value, 'value', isNotEmpty),
    );
    expect(arguments['importance'], Importance.high.value);
    expect(arguments['playSound'], isFalse);
    expect(arguments['enableVibration'], isFalse);
    expect(arguments['showBadge'], isFalse);

    await service.dispose();
  });

  test(
    'showSleepModeNotification shows an ongoing Android notification',
    () async {
      final AppNotificationService service = AppNotificationService(
        platformOverride: TargetPlatform.android,
      );

      await service.showSleepModeNotification(session: _session());

      final MethodCall showCall = calls.singleWhere(
        (MethodCall call) => call.method == 'show',
      );
      final Map<Object?, Object?> arguments =
          showCall.arguments as Map<Object?, Object?>;
      final Map<String, dynamic> payload =
          jsonDecode(arguments['payload']! as String) as Map<String, dynamic>;
      final Map<Object?, Object?> platformSpecifics =
          arguments['platformSpecifics'] as Map<Object?, Object?>;

      expect(arguments['id'], AppNotificationService.sleepModeNotificationId);
      expect(
        arguments['title'],
        isA<String>().having((String value) => value, 'value', isNotEmpty),
      );
      expect(
        arguments['body'],
        isA<String>().having((String value) => value, 'value', isNotEmpty),
      );
      expect(payload['kind'], 'sleep_mode');
      expect(payload['sessionId'], 'session-42');
      expect(payload['route'], AppRoutes.homePostSleep);
      expect(
        platformSpecifics['channelId'],
        AppNotificationService.sleepModeChannelId,
      );
      expect(platformSpecifics['channelName'], isA<String>());
      expect(platformSpecifics['playSound'], isFalse);
      expect(platformSpecifics['enableVibration'], isFalse);
      expect(
        platformSpecifics['visibility'],
        NotificationVisibility.public.index,
      );
      expect(platformSpecifics['ongoing'], isTrue);
      expect(platformSpecifics['autoCancel'], isFalse);

      await service.dispose();
    },
  );

  test('cancelSleepModeNotification clears the notification', () async {
    final AppNotificationService service = AppNotificationService(
      platformOverride: TargetPlatform.android,
    );

    await service.cancelSleepModeNotification();

    expect(calls, hasLength(2));
    expect(calls.first.method, 'stopForegroundService');
    expect(calls.last.method, 'cancel');
    expect(calls.last.arguments, <String, Object?>{
      'id': AppNotificationService.sleepModeNotificationId,
      'tag': null,
    });

    await service.dispose();
  });

  test(
    'sleep mode notification keeps the last requested state when show and cancel race',
    () async {
      final Completer<void> showCompleter = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            calls.add(call);
            switch (call.method) {
              case 'initialize':
                return true;
              case 'getNotificationAppLaunchDetails':
                return <String, Object?>{'notificationLaunchedApp': false};
              case 'requestNotificationsPermission':
                return true;
              case 'show':
                await showCompleter.future;
                return null;
              case 'stopForegroundService':
                return null;
              default:
                return null;
            }
          });

      final AppNotificationService service = AppNotificationService(
        platformOverride: TargetPlatform.android,
      );

      final Future<void> showFuture = service.showSleepModeNotification(
        session: _session(),
      );
      final Future<void> cancelFuture = service.cancelSleepModeNotification();
      showCompleter.complete();
      await Future.wait(<Future<void>>[showFuture, cancelFuture]);

      expect(calls.where((MethodCall call) => call.method == 'show'), isEmpty);
      expect(
        calls.where((MethodCall call) => call.method == 'cancel'),
        hasLength(1),
      );

      await service.dispose();
    },
  );
}

SleepSession _session() {
  final DateTime startedAt = DateTime(2026, 4, 14, 23, 0);
  return SleepSession(
    id: 'session-42',
    uid: 'user-1',
    startedAt: startedAt,
    endedAt: null,
    sleepDayKey: sleepDayKeyFromDate(startedAt),
    status: SleepSessionStatus.active,
    sleepModeActive: true,
    dormId: 'dorm-204',
    recommendations: const <NightRecommendation>[],
    selectedRecommendationIds: const <String>[],
    segments: <SleepSegment>[SleepSegment(startedAt: startedAt, endedAt: null)],
    trackedDurationMinutes: 0,
    awakenings: const <NightAwakeningEntry>[],
    feedback: const <RecommendationFeedback>[],
    summary: null,
    updatedAt: startedAt,
  );
}
