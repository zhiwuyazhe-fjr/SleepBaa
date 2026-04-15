import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/data/in_memory_repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/app_notification_service.dart';
import 'package:sleep_dorm_app/core/notifications/sleep_mode_notification_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'sleep mode notification controller only shows notification for active sleep mode sessions',
    () async {
      final InMemorySleepSessionRepository repository =
          InMemorySleepSessionRepository(
            initialUid: 'test-user',
            initialSessions: const <SleepSession>[],
          );
      final _FakeSleepModeNotificationService notificationService =
          _FakeSleepModeNotificationService();
      final SleepModeNotificationController controller =
          SleepModeNotificationController(
            sleepSessionRepository: repository,
            notificationService: notificationService,
          );

      controller.start();

      expect(notificationService.shownSleepSessions, isEmpty);

      final SleepSession session = await repository.startSleepSession(
        recommendationSnapshot: const <NightRecommendation>[],
        dormId: 'dorm-204',
      );
      await pumpEventQueue();

      expect(session.sleepModeActive, isFalse);
      expect(notificationService.shownSleepSessions, isEmpty);

      final int cancelCallsBeforeSleepMode =
          notificationService.cancelSleepModeNotificationCalls;
      await repository.updateActiveSession(sleepModeActive: true);
      await pumpEventQueue();

      expect(notificationService.shownSleepSessions.length, 1);
      expect(
        notificationService.shownSleepSessions.single.sleepModeActive,
        isTrue,
      );

      await repository.updateActiveSession(
        sleepModeActive: false,
        status: SleepSessionStatus.awaitingFeedback,
        endedAt: DateTime(2026, 4, 13, 7, 0),
      );
      await pumpEventQueue();

      expect(
        notificationService.cancelSleepModeNotificationCalls,
        greaterThan(cancelCallsBeforeSleepMode),
      );

      controller.dispose();
      repository.dispose();
    },
  );

  test(
    'sleep mode notification controller ignores ended active sessions',
    () async {
      final InMemorySleepSessionRepository repository =
          InMemorySleepSessionRepository(
            initialUid: 'test-user',
            initialSessions: <SleepSession>[
              SleepSession(
                id: 'dirty-session',
                uid: 'test-user',
                startedAt: DateTime(2026, 4, 13, 23, 0),
                endedAt: DateTime(2026, 4, 14, 7, 0),
                status: SleepSessionStatus.active,
                sleepModeActive: true,
                dormId: 'dorm-204',
                recommendations: const <NightRecommendation>[],
                selectedRecommendationIds: const <String>[],
                awakenings: const <NightAwakeningEntry>[],
                feedback: const <RecommendationFeedback>[],
                summary: null,
                updatedAt: DateTime(2026, 4, 14, 7, 0),
              ),
            ],
          );
      final _FakeSleepModeNotificationService notificationService =
          _FakeSleepModeNotificationService();
      final SleepModeNotificationController controller =
          SleepModeNotificationController(
            sleepSessionRepository: repository,
            notificationService: notificationService,
          );

      controller.start();
      await pumpEventQueue();

      expect(notificationService.shownSleepSessions, isEmpty);
      expect(
        notificationService.cancelSleepModeNotificationCalls,
        greaterThan(0),
      );

      controller.dispose();
      repository.dispose();
    },
  );
}

class _FakeSleepModeNotificationService extends AppNotificationService {
  final List<SleepSession> shownSleepSessions = <SleepSession>[];
  int cancelSleepModeNotificationCalls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> showSleepModeNotification({
    required SleepSession session,
  }) async {
    shownSleepSessions.add(session);
  }

  @override
  Future<void> cancelSleepModeNotification() async {
    cancelSleepModeNotificationCalls += 1;
  }
}
