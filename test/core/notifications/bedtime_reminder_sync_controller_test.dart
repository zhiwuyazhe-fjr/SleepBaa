import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/data/in_memory_repositories.dart';
import 'package:sleep_dorm_app/core/notifications/app_notification_service.dart';
import 'package:sleep_dorm_app/core/notifications/bedtime_reminder_sync_controller.dart';

void main() {
  test('start schedules bedtime reminder from current settings', () async {
    final InMemoryAuthRepository authRepository = InMemoryAuthRepository();
    final InMemoryUserSettingsRepository settingsRepository =
        InMemoryUserSettingsRepository();
    final _FakeBedtimeNotificationService notificationService =
        _FakeBedtimeNotificationService();
    final BedtimeReminderSyncController controller =
        BedtimeReminderSyncController(
          authRepository: authRepository,
          settingsRepository: settingsRepository,
          notificationService: notificationService,
        );

    controller.start();
    await _drainMicrotaskQueue();

    expect(notificationService.scheduledTimes, <TimeOfDay>[
      const TimeOfDay(hour: 23, minute: 10),
    ]);

    await controller.dispose();
  });

  test('settings changes reschedule bedtime reminder', () async {
    final InMemoryAuthRepository authRepository = InMemoryAuthRepository();
    final InMemoryUserSettingsRepository settingsRepository =
        InMemoryUserSettingsRepository();
    final _FakeBedtimeNotificationService notificationService =
        _FakeBedtimeNotificationService();
    final BedtimeReminderSyncController controller =
        BedtimeReminderSyncController(
          authRepository: authRepository,
          settingsRepository: settingsRepository,
          notificationService: notificationService,
        );

    controller.start();
    await _drainMicrotaskQueue();
    await settingsRepository.saveSettings(
      settingsRepository.currentSettings.copyWith(
        bedtimeReminder: const TimeOfDay(hour: 22, minute: 45),
      ),
    );
    await _drainMicrotaskQueue();

    expect(notificationService.scheduledTimes, <TimeOfDay>[
      const TimeOfDay(hour: 23, minute: 10),
      const TimeOfDay(hour: 22, minute: 45),
    ]);

    await controller.dispose();
  });

  test('disabled reminders cancel the existing bedtime reminder', () async {
    final InMemoryAuthRepository authRepository = InMemoryAuthRepository();
    final InMemoryUserSettingsRepository settingsRepository =
        InMemoryUserSettingsRepository();
    final _FakeBedtimeNotificationService notificationService =
        _FakeBedtimeNotificationService();
    final BedtimeReminderSyncController controller =
        BedtimeReminderSyncController(
          authRepository: authRepository,
          settingsRepository: settingsRepository,
          notificationService: notificationService,
        );

    controller.start();
    await _drainMicrotaskQueue();
    await settingsRepository.saveSettings(
      settingsRepository.currentSettings.copyWith(
        bedtimeReminderEnabled: false,
      ),
    );
    await _drainMicrotaskQueue();

    expect(notificationService.cancelBedtimeReminderCalls, 1);

    await controller.dispose();
  });

  test('sign out cancels bedtime reminder scheduling', () async {
    final InMemoryAuthRepository authRepository = InMemoryAuthRepository();
    final InMemoryUserSettingsRepository settingsRepository =
        InMemoryUserSettingsRepository();
    final _FakeBedtimeNotificationService notificationService =
        _FakeBedtimeNotificationService();
    final BedtimeReminderSyncController controller =
        BedtimeReminderSyncController(
          authRepository: authRepository,
          settingsRepository: settingsRepository,
          notificationService: notificationService,
        );

    controller.start();
    await _drainMicrotaskQueue();
    await authRepository.signOut();
    await _drainMicrotaskQueue();

    expect(notificationService.cancelBedtimeReminderCalls, 1);

    await controller.dispose();
  });

  test('resumed lifecycle forces a bedtime reminder resync', () async {
    final InMemoryAuthRepository authRepository = InMemoryAuthRepository();
    final InMemoryUserSettingsRepository settingsRepository =
        InMemoryUserSettingsRepository();
    final _FakeBedtimeNotificationService notificationService =
        _FakeBedtimeNotificationService();
    final BedtimeReminderSyncController controller =
        BedtimeReminderSyncController(
          authRepository: authRepository,
          settingsRepository: settingsRepository,
          notificationService: notificationService,
        );

    controller.start();
    await _drainMicrotaskQueue();
    controller.handleAppLifecycleState(AppLifecycleState.resumed);
    await _drainMicrotaskQueue();

    expect(notificationService.scheduledTimes, <TimeOfDay>[
      const TimeOfDay(hour: 23, minute: 10),
      const TimeOfDay(hour: 23, minute: 10),
    ]);

    await controller.dispose();
  });
}

class _FakeBedtimeNotificationService extends AppNotificationService {
  final List<TimeOfDay> scheduledTimes = <TimeOfDay>[];
  int cancelBedtimeReminderCalls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleBedtimeReminder({required TimeOfDay time}) async {
    scheduledTimes.add(time);
  }

  @override
  Future<void> cancelBedtimeReminder() async {
    cancelBedtimeReminderCalls += 1;
  }
}

Future<void> _drainMicrotaskQueue() {
  return Future<void>.delayed(Duration.zero);
}
