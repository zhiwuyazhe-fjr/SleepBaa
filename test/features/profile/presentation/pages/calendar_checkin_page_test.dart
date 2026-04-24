import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/backend/app_environment.dart';
import 'package:sleep_dorm_app/core/data/in_memory_repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/app_notification_service.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/calendar_checkin_page.dart';

void main() {
  testWidgets('selected completed session shows sleep goal met chip', (
    WidgetTester tester,
  ) async {
    late BuildContext appContext;
    final DateTime now = DateTime.now();
    final DateTime targetDay = DateTime(
      now.year,
      now.month,
      DateUtils.getDaysInMonth(now.year, now.month) >= 28 ? 28 : 1,
    );

    await tester.pumpWidget(
      AppScope(
        environment: AppEnvironment.inMemory(),
        initialSettings: buildDefaultUserSettings().copyWith(
          sleepGoalHours: 7.5,
        ),
        appNotificationService: _StubAppNotificationService(),
        child: MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              appContext = context;
              return CalendarCheckinPage(initialSelectedDay: targetDay);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final AppServices services = AppScope.of(appContext);
    final DateTime startedAt = DateTime(
      targetDay.year,
      targetDay.month,
      targetDay.day,
      0,
      30,
    );
    await services.sleepSessionRepository.saveSession(
      SleepSession(
        id: 'session-goal-met',
        uid: services.authRepository.currentUser.uid,
        startedAt: startedAt,
        endedAt: startedAt.add(const Duration(hours: 8)),
        sleepDayKey: sleepDayKeyFromDate(targetDay),
        status: SleepSessionStatus.completed,
        sleepModeActive: false,
        dormId: services.authRepository.currentUser.dormId,
        recommendations: const <NightRecommendation>[],
        selectedRecommendationIds: const <String>[],
        segments: <SleepSegment>[
          SleepSegment(
            startedAt: startedAt,
            endedAt: startedAt.add(const Duration(hours: 8)),
          ),
        ],
        trackedDurationMinutes: 480,
        awakenings: const <NightAwakeningEntry>[],
        feedback: const <RecommendationFeedback>[],
        summary: const MorningSummary(
          sleepQuality: 4,
          restedLevel: 4,
          totalSleepHours: 8,
          awakeningsCount: 0,
          note: 'slept well',
        ),
      ),
      syncRemote: false,
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('睡眠时长已达标'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('睡眠时长已达标'), findsOneWidget);
  });
}

class _StubAppNotificationService extends AppNotificationService {
  @override
  bool get isSupported => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> cancelSleepModeNotification() async {}

  @override
  Future<void> scheduleBedtimeReminder({required TimeOfDay time}) async {}

  @override
  Future<void> cancelBedtimeReminder() async {}
}
