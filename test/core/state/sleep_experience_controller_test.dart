import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/core/data/in_memory_repositories.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/app_notification_service.dart';
import 'package:sleep_dorm_app/core/state/audio_playback_controller.dart';
import 'package:sleep_dorm_app/core/state/sleep_experience_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'exit sleep mode immediately syncs dorm sleeping count back down',
    () async {
      final _SleepControllerHarness harness = _SleepControllerHarness.create();

      await harness.controller.enterSleepMode();
      final int sleepingCountAfterEnter = harness
          .dormRepository
          .currentDorm
          .members
          .where((DormMember member) => member.sleepModeActive)
          .length;

      await harness.controller.exitSleepMode();

      final DormMember currentMember = harness
          .dormRepository
          .currentDorm
          .members
          .firstWhere(
            (DormMember member) =>
                member.uid == harness.authRepository.currentUser.uid,
          );
      expect(currentMember.sleepModeActive, isFalse);
      expect(currentMember.status, DormMemberStatus.quiet);
      expect(
        harness.dormRepository.currentDorm.members
            .where((DormMember member) => member.sleepModeActive)
            .length,
        sleepingCountAfterEnter - 1,
      );
      expect(harness.notificationService.shownSleepSessions, hasLength(1));
      expect(harness.notificationService.cancelSleepModeNotificationCalls, 1);

      harness.dispose();
    },
  );

  test(
    'finish sleep mode still cancels notifications when there is no active session',
    () async {
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository();
      final InMemoryUserSettingsRepository settingsRepository =
          InMemoryUserSettingsRepository();
      final InMemoryRecommendationRepository recommendationRepository =
          InMemoryRecommendationRepository();
      final DateTime startedAt = DateTime(2026, 4, 15, 0, 10);
      final SleepSession seedSession = SleepSession(
        id: 'session-fallback',
        uid: authRepository.currentUser.uid,
        startedAt: startedAt,
        endedAt: null,
        sleepDayKey: sleepDayKeyFromDate(startedAt),
        status: SleepSessionStatus.active,
        sleepModeActive: true,
        dormId: 'dorm-1',
        recommendations: const <NightRecommendation>[],
        selectedRecommendationIds: const <String>[],
        segments: <SleepSegment>[
          SleepSegment(startedAt: startedAt, endedAt: null),
        ],
        trackedDurationMinutes: 0,
        awakenings: const <NightAwakeningEntry>[],
        feedback: const <RecommendationFeedback>[],
        summary: null,
        updatedAt: startedAt,
      );
      final _NullActiveSleepSessionRepository sleepSessionRepository =
          _NullActiveSleepSessionRepository(seedSession);
      final InMemoryFeedbackRepository feedbackRepository =
          InMemoryFeedbackRepository(
            sleepSessionRepository: sleepSessionRepository,
          );
      final InMemorySleepCaptureRepository sleepCaptureRepository =
          InMemorySleepCaptureRepository();
      final InMemoryNotificationRepository notificationRepository =
          InMemoryNotificationRepository();
      final InMemoryDormRepository dormRepository = InMemoryDormRepository(
        currentUserId: authRepository.currentUser.uid,
      );
      final _FakeNotificationService notificationService =
          _FakeNotificationService();
      final SleepExperienceController controller = SleepExperienceController(
        authRepository: authRepository,
        settingsRepository: settingsRepository,
        recommendationRepository: recommendationRepository,
        sleepSessionRepository: sleepSessionRepository,
        feedbackRepository: feedbackRepository,
        sleepCaptureRepository: sleepCaptureRepository,
        notificationRepository: notificationRepository,
        dormRepository: dormRepository,
        appNotificationService: notificationService,
        audioPlaybackController: AudioPlaybackController(),
        pushNotificationGateway: const NoOpPushNotificationGateway(),
      );

      expect(
        await controller.finishSleepMode(),
        FinishSleepModeResult.noActiveSession,
      );

      expect(notificationService.cancelSleepModeNotificationCalls, 1);
      expect(sleepSessionRepository.savedSessions, isEmpty);

      controller.dispose();
      authRepository.dispose();
      settingsRepository.dispose();
      recommendationRepository.dispose();
      sleepSessionRepository.dispose();
      feedbackRepository.dispose();
      sleepCaptureRepository.dispose();
      notificationRepository.dispose();
      dormRepository.dispose();
    },
  );

  test(
    'finish sleep mode falls back to current sleep-day awaiting feedback session',
    () async {
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository();
      final InMemoryUserSettingsRepository settingsRepository =
          InMemoryUserSettingsRepository();
      final InMemoryRecommendationRepository recommendationRepository =
          InMemoryRecommendationRepository();
      final String currentSleepDayKey = sleepDayKeyFromDate(DateTime.now());
      final SleepSession fallbackSession = SleepSession(
        id: 'session-awaiting-feedback',
        uid: authRepository.currentUser.uid,
        startedAt: DateTime.now().subtract(const Duration(hours: 1)),
        endedAt: DateTime.now(),
        sleepDayKey: currentSleepDayKey,
        status: SleepSessionStatus.awaitingFeedback,
        sleepModeActive: false,
        dormId: 'dorm-1',
        recommendations: const <NightRecommendation>[],
        selectedRecommendationIds: const <String>[],
        segments: <SleepSegment>[
          SleepSegment(
            startedAt: DateTime.now().subtract(const Duration(hours: 1)),
            endedAt: DateTime.now(),
          ),
        ],
        trackedDurationMinutes: 60,
        awakenings: const <NightAwakeningEntry>[],
        feedback: const <RecommendationFeedback>[],
        summary: null,
        updatedAt: DateTime.now(),
      );
      final _NullActiveSleepSessionRepository sleepSessionRepository =
          _NullActiveSleepSessionRepository(
            fallbackSession,
            sessionForSleepDayKeyResult: fallbackSession,
          );
      final InMemoryFeedbackRepository feedbackRepository =
          InMemoryFeedbackRepository(
            sleepSessionRepository: sleepSessionRepository,
          );
      final InMemorySleepCaptureRepository sleepCaptureRepository =
          InMemorySleepCaptureRepository();
      final InMemoryNotificationRepository notificationRepository =
          InMemoryNotificationRepository();
      final InMemoryDormRepository dormRepository = InMemoryDormRepository(
        currentUserId: authRepository.currentUser.uid,
      );
      final _FakeNotificationService notificationService =
          _FakeNotificationService();
      final SleepExperienceController controller = SleepExperienceController(
        authRepository: authRepository,
        settingsRepository: settingsRepository,
        recommendationRepository: recommendationRepository,
        sleepSessionRepository: sleepSessionRepository,
        feedbackRepository: feedbackRepository,
        sleepCaptureRepository: sleepCaptureRepository,
        notificationRepository: notificationRepository,
        dormRepository: dormRepository,
        appNotificationService: notificationService,
        audioPlaybackController: AudioPlaybackController(),
        pushNotificationGateway: const NoOpPushNotificationGateway(),
      );

      expect(
        await controller.finishSleepMode(),
        FinishSleepModeResult.goToFeedback,
      );
      expect(notificationService.cancelSleepModeNotificationCalls, 1);
      expect(sleepSessionRepository.savedSessions, isEmpty);

      controller.dispose();
      authRepository.dispose();
      settingsRepository.dispose();
      recommendationRepository.dispose();
      sleepSessionRepository.dispose();
      feedbackRepository.dispose();
      sleepCaptureRepository.dispose();
      notificationRepository.dispose();
      dormRepository.dispose();
    },
  );

  test(
    'finish sleep mode ignores historical pending sessions when current sleep-day lookup misses',
    () async {
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository();
      final InMemoryUserSettingsRepository settingsRepository =
          InMemoryUserSettingsRepository();
      final InMemoryRecommendationRepository recommendationRepository =
          InMemoryRecommendationRepository();
      final DateTime historicalStartedAt = DateTime.now().subtract(
        const Duration(days: 2, hours: 6),
      );
      final DateTime historicalEndedAt = historicalStartedAt.add(
        const Duration(hours: 5),
      );
      final SleepSession pendingFeedbackSession = SleepSession(
        id: 'session-awaiting-feedback-latest',
        uid: authRepository.currentUser.uid,
        startedAt: historicalStartedAt,
        endedAt: historicalEndedAt,
        sleepDayKey: sleepDayKeyFromDate(historicalStartedAt),
        status: SleepSessionStatus.awaitingFeedback,
        sleepModeActive: false,
        dormId: 'dorm-1',
        recommendations: const <NightRecommendation>[],
        selectedRecommendationIds: const <String>[],
        segments: <SleepSegment>[
          SleepSegment(
            startedAt: historicalStartedAt,
            endedAt: historicalEndedAt,
          ),
        ],
        trackedDurationMinutes: 300,
        awakenings: const <NightAwakeningEntry>[],
        feedback: const <RecommendationFeedback>[],
        summary: null,
        updatedAt: DateTime.now(),
      );
      final _NullActiveSleepSessionRepository sleepSessionRepository =
          _NullActiveSleepSessionRepository(
            pendingFeedbackSession,
            latestAwaitingFeedbackSessionResult: pendingFeedbackSession,
          );
      final InMemoryFeedbackRepository feedbackRepository =
          InMemoryFeedbackRepository(
            sleepSessionRepository: sleepSessionRepository,
          );
      final InMemorySleepCaptureRepository sleepCaptureRepository =
          InMemorySleepCaptureRepository();
      final InMemoryNotificationRepository notificationRepository =
          InMemoryNotificationRepository();
      final InMemoryDormRepository dormRepository = InMemoryDormRepository(
        currentUserId: authRepository.currentUser.uid,
      );
      final _FakeNotificationService notificationService =
          _FakeNotificationService();
      final SleepExperienceController controller = SleepExperienceController(
        authRepository: authRepository,
        settingsRepository: settingsRepository,
        recommendationRepository: recommendationRepository,
        sleepSessionRepository: sleepSessionRepository,
        feedbackRepository: feedbackRepository,
        sleepCaptureRepository: sleepCaptureRepository,
        notificationRepository: notificationRepository,
        dormRepository: dormRepository,
        appNotificationService: notificationService,
        audioPlaybackController: AudioPlaybackController(),
        pushNotificationGateway: const NoOpPushNotificationGateway(),
      );

      expect(
        await controller.finishSleepMode(),
        FinishSleepModeResult.noActiveSession,
      );
      expect(notificationService.cancelSleepModeNotificationCalls, 1);
      expect(sleepSessionRepository.savedSessions, isEmpty);

      controller.dispose();
      authRepository.dispose();
      settingsRepository.dispose();
      recommendationRepository.dispose();
      sleepSessionRepository.dispose();
      feedbackRepository.dispose();
      sleepCaptureRepository.dispose();
      notificationRepository.dispose();
      dormRepository.dispose();
    },
  );

  test(
    'finish sleep mode prefers current sleep-day completed session over historical pending sessions',
    () async {
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository();
      final InMemoryUserSettingsRepository settingsRepository =
          InMemoryUserSettingsRepository();
      final InMemoryRecommendationRepository recommendationRepository =
          InMemoryRecommendationRepository();
      final String currentSleepDayKey = sleepDayKeyFromDate(DateTime.now());
      final SleepSession fallbackSession = SleepSession(
        id: 'session-feedback-done',
        uid: authRepository.currentUser.uid,
        startedAt: DateTime.now().subtract(const Duration(hours: 2)),
        endedAt: DateTime.now().subtract(const Duration(hours: 1)),
        sleepDayKey: currentSleepDayKey,
        status: SleepSessionStatus.completed,
        sleepModeActive: false,
        dormId: 'dorm-1',
        recommendations: const <NightRecommendation>[],
        selectedRecommendationIds: const <String>[],
        segments: <SleepSegment>[
          SleepSegment(
            startedAt: DateTime.now().subtract(const Duration(hours: 2)),
            endedAt: DateTime.now().subtract(const Duration(hours: 1)),
          ),
        ],
        trackedDurationMinutes: 60,
        awakenings: const <NightAwakeningEntry>[],
        feedback: const <RecommendationFeedback>[],
        summary: const MorningSummary(
          sleepQuality: 4,
          restedLevel: 4,
          totalSleepHours: 7.0,
          awakeningsCount: 0,
          note: 'submitted',
        ),
        updatedAt: DateTime.now(),
      );
      final InMemoryNotificationRepository notificationRepository =
          InMemoryNotificationRepository();
      await notificationRepository.upsertNotification(
        NotificationItem(
          id: 'feedback-${fallbackSession.id}',
          category: NotificationCategory.reminder,
          title: 'feedback',
          body: 'feedback',
          createdAt: DateTime.now(),
          route: AppRoutes.feedbackMorning,
          readAt: null,
        ),
      );
      final DateTime historicalStartedAt = DateTime.now().subtract(
        const Duration(days: 5, hours: 2),
      );
      final DateTime historicalEndedAt = historicalStartedAt.add(
        const Duration(hours: 7),
      );
      final _NullActiveSleepSessionRepository sleepSessionRepository =
          _NullActiveSleepSessionRepository(
            fallbackSession,
            sessionForSleepDayKeyResult: fallbackSession,
            latestAwaitingFeedbackSessionResult: SleepSession(
              id: 'historical-pending-session',
              uid: authRepository.currentUser.uid,
              startedAt: historicalStartedAt,
              endedAt: historicalEndedAt,
              sleepDayKey: sleepDayKeyFromDate(historicalStartedAt),
              status: SleepSessionStatus.awaitingFeedback,
              sleepModeActive: false,
              dormId: 'dorm-1',
              recommendations: const <NightRecommendation>[],
              selectedRecommendationIds: const <String>[],
              segments: <SleepSegment>[
                SleepSegment(
                  startedAt: historicalStartedAt,
                  endedAt: historicalEndedAt,
                ),
              ],
              trackedDurationMinutes: 420,
              awakenings: const <NightAwakeningEntry>[],
              feedback: const <RecommendationFeedback>[],
              summary: null,
              updatedAt: DateTime.now(),
            ),
          );
      final InMemoryFeedbackRepository feedbackRepository =
          InMemoryFeedbackRepository(
            sleepSessionRepository: sleepSessionRepository,
          );
      final InMemorySleepCaptureRepository sleepCaptureRepository =
          InMemorySleepCaptureRepository();
      final InMemoryDormRepository dormRepository = InMemoryDormRepository(
        currentUserId: authRepository.currentUser.uid,
      );
      final _FakeNotificationService notificationService =
          _FakeNotificationService();
      final SleepExperienceController controller = SleepExperienceController(
        authRepository: authRepository,
        settingsRepository: settingsRepository,
        recommendationRepository: recommendationRepository,
        sleepSessionRepository: sleepSessionRepository,
        feedbackRepository: feedbackRepository,
        sleepCaptureRepository: sleepCaptureRepository,
        notificationRepository: notificationRepository,
        dormRepository: dormRepository,
        appNotificationService: notificationService,
        audioPlaybackController: AudioPlaybackController(),
        pushNotificationGateway: const NoOpPushNotificationGateway(),
      );

      expect(
        await controller.finishSleepMode(),
        FinishSleepModeResult.goHomeFeedbackAlreadySubmitted,
      );
      expect(notificationService.cancelSleepModeNotificationCalls, 1);
      expect(
        notificationRepository.notifications
            .firstWhere(
              (NotificationItem item) =>
                  item.id == 'feedback-${fallbackSession.id}',
            )
            .isRead,
        isTrue,
      );
      expect(sleepSessionRepository.savedSessions, isEmpty);

      controller.dispose();
      authRepository.dispose();
      settingsRepository.dispose();
      recommendationRepository.dispose();
      sleepSessionRepository.dispose();
      feedbackRepository.dispose();
      sleepCaptureRepository.dispose();
      notificationRepository.dispose();
      dormRepository.dispose();
    },
  );

  test(
    'pause sleep mode marks session paused and clears dorm sleeping state',
    () async {
      final _SleepControllerHarness harness = _SleepControllerHarness.create();

      await harness.controller.enterSleepMode();
      await harness.controller.pauseSleepMode();

      final SleepSession paused = harness.sleepSessionRepository
          .sessionForSleepDayKey(sleepDayKeyFromDate(DateTime.now()))!;
      final DormMember currentMember = harness
          .dormRepository
          .currentDorm
          .members
          .firstWhere(
            (DormMember member) =>
                member.uid == harness.authRepository.currentUser.uid,
          );

      expect(paused.status, SleepSessionStatus.paused);
      expect(paused.sleepModeActive, isFalse);
      expect(currentMember.sleepModeActive, isFalse);
      expect(harness.notificationService.cancelSleepModeNotificationCalls, 1);

      harness.dispose();
    },
  );

  test(
    'pause sleep mode still cancels notifications when there is no active session',
    () async {
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository();
      final InMemoryUserSettingsRepository settingsRepository =
          InMemoryUserSettingsRepository();
      final InMemoryRecommendationRepository recommendationRepository =
          InMemoryRecommendationRepository();
      final DateTime startedAt = DateTime(2026, 4, 15, 0, 10);
      final SleepSession seedSession = SleepSession(
        id: 'session-paused-fallback',
        uid: authRepository.currentUser.uid,
        startedAt: startedAt,
        endedAt: null,
        sleepDayKey: sleepDayKeyFromDate(startedAt),
        status: SleepSessionStatus.active,
        sleepModeActive: true,
        dormId: 'dorm-1',
        recommendations: const <NightRecommendation>[],
        selectedRecommendationIds: const <String>[],
        segments: <SleepSegment>[
          SleepSegment(startedAt: startedAt, endedAt: null),
        ],
        trackedDurationMinutes: 0,
        awakenings: const <NightAwakeningEntry>[],
        feedback: const <RecommendationFeedback>[],
        summary: null,
        updatedAt: startedAt,
      );
      final _NullActiveSleepSessionRepository sleepSessionRepository =
          _NullActiveSleepSessionRepository(seedSession);
      final InMemoryFeedbackRepository feedbackRepository =
          InMemoryFeedbackRepository(
            sleepSessionRepository: sleepSessionRepository,
          );
      final InMemorySleepCaptureRepository sleepCaptureRepository =
          InMemorySleepCaptureRepository();
      final InMemoryNotificationRepository notificationRepository =
          InMemoryNotificationRepository();
      final InMemoryDormRepository dormRepository = InMemoryDormRepository(
        currentUserId: authRepository.currentUser.uid,
      );
      final _FakeNotificationService notificationService =
          _FakeNotificationService();
      final SleepExperienceController controller = SleepExperienceController(
        authRepository: authRepository,
        settingsRepository: settingsRepository,
        recommendationRepository: recommendationRepository,
        sleepSessionRepository: sleepSessionRepository,
        feedbackRepository: feedbackRepository,
        sleepCaptureRepository: sleepCaptureRepository,
        notificationRepository: notificationRepository,
        dormRepository: dormRepository,
        appNotificationService: notificationService,
        audioPlaybackController: AudioPlaybackController(),
        pushNotificationGateway: const NoOpPushNotificationGateway(),
      );

      await controller.pauseSleepMode();

      expect(notificationService.cancelSleepModeNotificationCalls, 1);
      expect(sleepSessionRepository.savedSessions, isEmpty);

      controller.dispose();
      authRepository.dispose();
      settingsRepository.dispose();
      recommendationRepository.dispose();
      sleepSessionRepository.dispose();
      feedbackRepository.dispose();
      sleepCaptureRepository.dispose();
      notificationRepository.dispose();
      dormRepository.dispose();
    },
  );

  test('submitting morning feedback restores dorm status to normal', () async {
    final _SleepControllerHarness harness = _SleepControllerHarness.create();

    await harness.controller.enterSleepMode();
    await harness.controller.exitSleepMode();
    final SleepSession session =
        harness.sleepSessionRepository.latestAwaitingFeedbackSession!;

    await harness.controller.submitMorningFeedback(
      session: session,
      summary: const MorningSummary(
        sleepQuality: 4,
        restedLevel: 4,
        totalSleepHours: 7.2,
        awakeningsCount: 0,
        note: '状态不错',
      ),
      feedback: const <RecommendationFeedback>[],
    );

    final DormMember currentMember = harness.dormRepository.currentDorm.members
        .firstWhere(
          (DormMember member) =>
              member.uid == harness.authRepository.currentUser.uid,
        );
    expect(currentMember.status, DormMemberStatus.quiet);
    expect(currentMember.sleepModeActive, isFalse);
    expect(currentMember.note, '已完成晨间反馈');

    harness.dispose();
  });

  test(
    'finish sleep mode returns home when same-day feedback has already been submitted',
    () async {
      final _SleepControllerHarness harness = _SleepControllerHarness.create();

      await harness.controller.enterSleepMode();
      expect(
        await harness.controller.finishSleepMode(),
        FinishSleepModeResult.goToFeedback,
      );

      final SleepSession awaiting =
          harness.sleepSessionRepository.latestAwaitingFeedbackSession!;
      await harness.controller.submitMorningFeedback(
        session: awaiting,
        summary: const MorningSummary(
          sleepQuality: 5,
          restedLevel: 4,
          totalSleepHours: 7.8,
          awakeningsCount: 0,
          note: 'Submitted already',
        ),
        feedback: const <RecommendationFeedback>[],
      );

      await harness.controller.enterSleepMode();
      expect(
        await harness.controller.finishSleepMode(),
        FinishSleepModeResult.goHomeFeedbackAlreadySubmitted,
      );

      final SleepSession session = harness.sleepSessionRepository
          .sessionForSleepDayKey(sleepDayKeyFromDate(DateTime.now()))!;
      expect(session.status, SleepSessionStatus.completed);
      expect(session.hasSubmittedFeedback, isTrue);
      expect(session.sleepModeActive, isFalse);

      harness.dispose();
    },
  );

  test(
    'bootstrap archives past-cutoff sessions and schedules the next cutoff timer',
    () async {
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository();
      final InMemoryUserSettingsRepository settingsRepository =
          InMemoryUserSettingsRepository();
      final InMemoryRecommendationRepository recommendationRepository =
          InMemoryRecommendationRepository();
      final SleepSession staleActiveSession = SleepSession(
        id: 'session-cutoff-bootstrap',
        uid: authRepository.currentUser.uid,
        startedAt: DateTime(2026, 4, 15, 23, 10),
        endedAt: null,
        sleepDayKey: sleepDayKeyFromDate(DateTime(2026, 4, 15, 23, 10)),
        status: SleepSessionStatus.active,
        sleepModeActive: true,
        dormId: 'dorm-1',
        recommendations: const <NightRecommendation>[],
        selectedRecommendationIds: const <String>[],
        segments: <SleepSegment>[
          SleepSegment(startedAt: DateTime(2026, 4, 15, 23, 10), endedAt: null),
        ],
        trackedDurationMinutes: 0,
        awakenings: const <NightAwakeningEntry>[],
        feedback: const <RecommendationFeedback>[],
        summary: null,
        updatedAt: DateTime(2026, 4, 15, 23, 10),
      );
      final SleepSession archivedSession = staleActiveSession.copyWith(
        endedAt: DateTime(2026, 4, 16, 20, 0),
        status: SleepSessionStatus.awaitingFeedback,
        sleepModeActive: false,
        segments: <SleepSegment>[
          SleepSegment(
            startedAt: DateTime(2026, 4, 15, 23, 10),
            endedAt: DateTime(2026, 4, 16, 20, 0),
          ),
        ],
        trackedDurationMinutes: 1250,
        updatedAt: DateTime(2026, 4, 16, 20, 0),
      );
      final _NullActiveSleepSessionRepository sleepSessionRepository =
          _NullActiveSleepSessionRepository(
            staleActiveSession,
            sessionsResult: <SleepSession>[staleActiveSession],
            archiveResultsByCall: <List<SleepSession>>[
              <SleepSession>[archivedSession],
            ],
          );
      final InMemoryFeedbackRepository feedbackRepository =
          InMemoryFeedbackRepository(
            sleepSessionRepository: sleepSessionRepository,
          );
      final InMemorySleepCaptureRepository sleepCaptureRepository =
          InMemorySleepCaptureRepository();
      await sleepCaptureRepository.addRecord(
        type: SleepCaptureType.memo,
        sessionId: archivedSession.id,
        content: 'remember to review',
      );
      final InMemoryNotificationRepository notificationRepository =
          InMemoryNotificationRepository();
      final InMemoryDormRepository dormRepository = InMemoryDormRepository(
        currentUserId: authRepository.currentUser.uid,
      );
      final _FakeNotificationService notificationService =
          _FakeNotificationService();
      final _RecordingTimerFactory timerFactory = _RecordingTimerFactory();
      final DateTime now = DateTime(2026, 4, 17, 19, 30);
      final SleepExperienceController controller = SleepExperienceController(
        authRepository: authRepository,
        settingsRepository: settingsRepository,
        recommendationRepository: recommendationRepository,
        sleepSessionRepository: sleepSessionRepository,
        feedbackRepository: feedbackRepository,
        sleepCaptureRepository: sleepCaptureRepository,
        notificationRepository: notificationRepository,
        dormRepository: dormRepository,
        appNotificationService: notificationService,
        audioPlaybackController: AudioPlaybackController(),
        pushNotificationGateway: const NoOpPushNotificationGateway(),
        clock: () => now,
        timerFactory: timerFactory.create,
      );

      await controller.bootstrap();

      expect(sleepSessionRepository.archiveCalls, <DateTime>[now]);
      expect(notificationService.cancelSleepModeNotificationCalls, 1);
      expect(
        notificationRepository.notifications.any(
          (NotificationItem item) =>
              item.id == 'feedback-${archivedSession.id}' &&
              item.route ==
                  AppRoutes.feedbackMorningLocation(
                    sessionId: archivedSession.id,
                  ),
        ),
        isTrue,
      );
      expect(
        sleepCaptureRepository.pendingSleepMemoBanner?.groups.any(
          (PendingSleepMemoGroup group) =>
              group.sessionId == archivedSession.id,
        ),
        isTrue,
      );
      expect(timerFactory.timers, hasLength(1));
      expect(timerFactory.timers.single.duration, const Duration(minutes: 30));

      controller.dispose();
      authRepository.dispose();
      settingsRepository.dispose();
      recommendationRepository.dispose();
      sleepSessionRepository.dispose();
      feedbackRepository.dispose();
      sleepCaptureRepository.dispose();
      notificationRepository.dispose();
      dormRepository.dispose();
    },
  );

  test(
    'handle app resumed rechecks cutoff sessions and reschedules the next timer',
    () async {
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository();
      final InMemoryUserSettingsRepository settingsRepository =
          InMemoryUserSettingsRepository();
      final InMemoryRecommendationRepository recommendationRepository =
          InMemoryRecommendationRepository();
      final SleepSession pausedSession = SleepSession(
        id: 'session-cutoff-resume',
        uid: authRepository.currentUser.uid,
        startedAt: DateTime(2026, 4, 15, 23, 10),
        endedAt: DateTime(2026, 4, 16, 7, 0),
        sleepDayKey: sleepDayKeyFromDate(DateTime(2026, 4, 15, 23, 10)),
        status: SleepSessionStatus.paused,
        sleepModeActive: false,
        dormId: 'dorm-1',
        recommendations: const <NightRecommendation>[],
        selectedRecommendationIds: const <String>[],
        segments: <SleepSegment>[
          SleepSegment(
            startedAt: DateTime(2026, 4, 15, 23, 10),
            endedAt: DateTime(2026, 4, 16, 7, 0),
          ),
        ],
        trackedDurationMinutes: 470,
        awakenings: const <NightAwakeningEntry>[],
        feedback: const <RecommendationFeedback>[],
        summary: null,
        updatedAt: DateTime(2026, 4, 16, 7, 0),
      );
      final SleepSession archivedSession = pausedSession.copyWith(
        status: SleepSessionStatus.awaitingFeedback,
        updatedAt: DateTime(2026, 4, 17, 10, 0),
      );
      final _NullActiveSleepSessionRepository sleepSessionRepository =
          _NullActiveSleepSessionRepository(
            pausedSession,
            sessionsResult: <SleepSession>[pausedSession],
            archiveResultsByCall: <List<SleepSession>>[
              <SleepSession>[archivedSession],
              const <SleepSession>[],
            ],
          );
      final _RecordingTimerFactory timerFactory = _RecordingTimerFactory();
      DateTime now = DateTime(2026, 4, 17, 10, 0);
      final SleepExperienceController controller = SleepExperienceController(
        authRepository: authRepository,
        settingsRepository: settingsRepository,
        recommendationRepository: recommendationRepository,
        sleepSessionRepository: sleepSessionRepository,
        feedbackRepository: InMemoryFeedbackRepository(
          sleepSessionRepository: sleepSessionRepository,
        ),
        sleepCaptureRepository: InMemorySleepCaptureRepository(),
        notificationRepository: InMemoryNotificationRepository(),
        dormRepository: InMemoryDormRepository(
          currentUserId: authRepository.currentUser.uid,
        ),
        appNotificationService: _FakeNotificationService(),
        audioPlaybackController: AudioPlaybackController(),
        pushNotificationGateway: const NoOpPushNotificationGateway(),
        clock: () => now,
        timerFactory: timerFactory.create,
      );

      await controller.handleAppResumed();
      expect(sleepSessionRepository.archiveCalls, <DateTime>[now]);
      expect(timerFactory.timers.last.duration, const Duration(hours: 10));

      final _FakeTimer firstTimer = timerFactory.timers.last;
      now = DateTime(2026, 4, 17, 21, 0);
      await controller.handleAppResumed();

      expect(firstTimer.isActive, isFalse);
      expect(sleepSessionRepository.archiveCalls, <DateTime>[
        DateTime(2026, 4, 17, 10, 0),
        now,
      ]);
      expect(timerFactory.timers.last.duration, const Duration(hours: 23));

      controller.dispose();
      authRepository.dispose();
      settingsRepository.dispose();
      recommendationRepository.dispose();
      sleepSessionRepository.dispose();
    },
  );

  test(
    'sleep cutoff timer archives sessions when the scheduled cutoff fires',
    () async {
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository();
      final InMemoryUserSettingsRepository settingsRepository =
          InMemoryUserSettingsRepository();
      final InMemoryRecommendationRepository recommendationRepository =
          InMemoryRecommendationRepository();
      final SleepSession currentDayActiveSession = SleepSession(
        id: 'session-cutoff-timer',
        uid: authRepository.currentUser.uid,
        startedAt: DateTime(2026, 4, 16, 23, 10),
        endedAt: null,
        sleepDayKey: sleepDayKeyFromDate(DateTime(2026, 4, 16, 23, 10)),
        status: SleepSessionStatus.active,
        sleepModeActive: true,
        dormId: 'dorm-1',
        recommendations: const <NightRecommendation>[],
        selectedRecommendationIds: const <String>[],
        segments: <SleepSegment>[
          SleepSegment(startedAt: DateTime(2026, 4, 16, 23, 10), endedAt: null),
        ],
        trackedDurationMinutes: 0,
        awakenings: const <NightAwakeningEntry>[],
        feedback: const <RecommendationFeedback>[],
        summary: null,
        updatedAt: DateTime(2026, 4, 16, 23, 10),
      );
      final SleepSession archivedSession = currentDayActiveSession.copyWith(
        endedAt: DateTime(2026, 4, 17, 20, 0),
        status: SleepSessionStatus.awaitingFeedback,
        sleepModeActive: false,
        segments: <SleepSegment>[
          SleepSegment(
            startedAt: DateTime(2026, 4, 16, 23, 10),
            endedAt: DateTime(2026, 4, 17, 20, 0),
          ),
        ],
        trackedDurationMinutes: 1250,
        updatedAt: DateTime(2026, 4, 17, 20, 0),
      );
      final _NullActiveSleepSessionRepository sleepSessionRepository =
          _NullActiveSleepSessionRepository(
            currentDayActiveSession,
            sessionsResult: <SleepSession>[currentDayActiveSession],
            archiveResultsByCall: <List<SleepSession>>[
              const <SleepSession>[],
              <SleepSession>[archivedSession],
            ],
          );
      final InMemoryNotificationRepository notificationRepository =
          InMemoryNotificationRepository();
      final _FakeNotificationService notificationService =
          _FakeNotificationService();
      final _RecordingTimerFactory timerFactory = _RecordingTimerFactory();
      DateTime now = DateTime(2026, 4, 17, 19, 55);
      final SleepExperienceController controller = SleepExperienceController(
        authRepository: authRepository,
        settingsRepository: settingsRepository,
        recommendationRepository: recommendationRepository,
        sleepSessionRepository: sleepSessionRepository,
        feedbackRepository: InMemoryFeedbackRepository(
          sleepSessionRepository: sleepSessionRepository,
        ),
        sleepCaptureRepository: InMemorySleepCaptureRepository(),
        notificationRepository: notificationRepository,
        dormRepository: InMemoryDormRepository(
          currentUserId: authRepository.currentUser.uid,
        ),
        appNotificationService: notificationService,
        audioPlaybackController: AudioPlaybackController(),
        pushNotificationGateway: const NoOpPushNotificationGateway(),
        clock: () => now,
        timerFactory: timerFactory.create,
      );

      await controller.bootstrap();
      expect(sleepSessionRepository.archiveCalls, <DateTime>[now]);
      expect(timerFactory.timers.last.duration, const Duration(minutes: 5));

      now = DateTime(2026, 4, 17, 20, 0);
      timerFactory.timers.last.fire();
      await pumpEventQueue();

      expect(sleepSessionRepository.archiveCalls, <DateTime>[
        DateTime(2026, 4, 17, 19, 55),
        now,
      ]);
      expect(notificationService.cancelSleepModeNotificationCalls, 1);
      expect(
        notificationRepository.notifications.any(
          (NotificationItem item) =>
              item.id == 'feedback-${archivedSession.id}',
        ),
        isTrue,
      );
      expect(timerFactory.timers.last.duration, const Duration(hours: 24));

      controller.dispose();
      authRepository.dispose();
      settingsRepository.dispose();
      recommendationRepository.dispose();
      sleepSessionRepository.dispose();
    },
  );
}

class _SleepControllerHarness {
  _SleepControllerHarness._({
    required this.authRepository,
    required this.settingsRepository,
    required this.recommendationRepository,
    required this.sleepSessionRepository,
    required this.feedbackRepository,
    required this.sleepCaptureRepository,
    required this.notificationRepository,
    required this.dormRepository,
    required this.notificationService,
    required this.audioPlaybackController,
    required this.controller,
  });

  factory _SleepControllerHarness.create() {
    final InMemoryAuthRepository authRepository = InMemoryAuthRepository();
    final InMemoryUserSettingsRepository settingsRepository =
        InMemoryUserSettingsRepository();
    final InMemoryRecommendationRepository recommendationRepository =
        InMemoryRecommendationRepository();
    final InMemorySleepSessionRepository sleepSessionRepository =
        InMemorySleepSessionRepository(
          initialUid: authRepository.currentUser.uid,
        );
    final InMemoryFeedbackRepository feedbackRepository =
        InMemoryFeedbackRepository(
          sleepSessionRepository: sleepSessionRepository,
        );
    final InMemorySleepCaptureRepository sleepCaptureRepository =
        InMemorySleepCaptureRepository();
    final InMemoryNotificationRepository notificationRepository =
        InMemoryNotificationRepository();
    final InMemoryDormRepository dormRepository = InMemoryDormRepository(
      currentUserId: authRepository.currentUser.uid,
    );
    final _FakeNotificationService notificationService =
        _FakeNotificationService();
    final AudioPlaybackController audioPlaybackController =
        AudioPlaybackController();
    final SleepExperienceController controller = SleepExperienceController(
      authRepository: authRepository,
      settingsRepository: settingsRepository,
      recommendationRepository: recommendationRepository,
      sleepSessionRepository: sleepSessionRepository,
      feedbackRepository: feedbackRepository,
      sleepCaptureRepository: sleepCaptureRepository,
      notificationRepository: notificationRepository,
      dormRepository: dormRepository,
      appNotificationService: notificationService,
      audioPlaybackController: audioPlaybackController,
      pushNotificationGateway: const NoOpPushNotificationGateway(),
    );
    return _SleepControllerHarness._(
      authRepository: authRepository,
      settingsRepository: settingsRepository,
      recommendationRepository: recommendationRepository,
      sleepSessionRepository: sleepSessionRepository,
      feedbackRepository: feedbackRepository,
      sleepCaptureRepository: sleepCaptureRepository,
      notificationRepository: notificationRepository,
      dormRepository: dormRepository,
      notificationService: notificationService,
      audioPlaybackController: audioPlaybackController,
      controller: controller,
    );
  }

  final InMemoryAuthRepository authRepository;
  final InMemoryUserSettingsRepository settingsRepository;
  final InMemoryRecommendationRepository recommendationRepository;
  final InMemorySleepSessionRepository sleepSessionRepository;
  final InMemoryFeedbackRepository feedbackRepository;
  final InMemorySleepCaptureRepository sleepCaptureRepository;
  final InMemoryNotificationRepository notificationRepository;
  final InMemoryDormRepository dormRepository;
  final _FakeNotificationService notificationService;
  final AudioPlaybackController audioPlaybackController;
  final SleepExperienceController controller;

  void dispose() {
    controller.dispose();
    authRepository.dispose();
    settingsRepository.dispose();
    recommendationRepository.dispose();
    sleepSessionRepository.dispose();
    feedbackRepository.dispose();
    sleepCaptureRepository.dispose();
    notificationRepository.dispose();
    dormRepository.dispose();
  }
}

class _FakeNotificationService extends AppNotificationService {
  final List<SleepSession> shownSleepSessions = <SleepSession>[];
  int cancelSleepModeNotificationCalls = 0;

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

class _RecordingTimerFactory {
  final List<_FakeTimer> timers = <_FakeTimer>[];

  Timer create(Duration duration, void Function() callback) {
    final _FakeTimer timer = _FakeTimer(duration, callback);
    timers.add(timer);
    return timer;
  }
}

class _FakeTimer implements Timer {
  _FakeTimer(this.duration, this._callback);

  final Duration duration;
  final void Function() _callback;
  bool _isActive = true;
  int _tick = 0;

  void fire() {
    if (!_isActive) {
      return;
    }
    _tick += 1;
    _callback();
  }

  @override
  void cancel() {
    _isActive = false;
  }

  @override
  bool get isActive => _isActive;

  @override
  int get tick => _tick;
}

class _NullActiveSleepSessionRepository extends ChangeNotifier
    implements SleepSessionRepository {
  _NullActiveSleepSessionRepository(
    this._session, {
    List<SleepSession>? sessionsResult,
    this.sessionForSleepDayKeyResult,
    this.latestAwaitingFeedbackSessionResult,
    List<List<SleepSession>>? archiveResultsByCall,
  }) : _sessionsResult = sessionsResult,
       _archiveResultsByCall = archiveResultsByCall ?? <List<SleepSession>>[];

  SleepSession _session;
  List<SleepSession>? _sessionsResult;
  final SleepSession? sessionForSleepDayKeyResult;
  final SleepSession? latestAwaitingFeedbackSessionResult;
  final List<SleepSession> savedSessions = <SleepSession>[];
  final List<List<SleepSession>> _archiveResultsByCall;
  final List<DateTime> archiveCalls = <DateTime>[];
  int _archiveCallIndex = 0;

  @override
  SleepSession? get activeSession => null;

  @override
  SleepSession? get latestAwaitingFeedbackSession =>
      latestAwaitingFeedbackSessionResult ??
      sessions
          .where(
            (SleepSession session) =>
                session.status == SleepSessionStatus.awaitingFeedback &&
                !session.sleepModeActive &&
                !session.hasSubmittedFeedback,
          )
          .fold<SleepSession?>(
            null,
            (SleepSession? latest, SleepSession session) =>
                latest == null ||
                    latest.sleepDayDate.isBefore(session.sleepDayDate)
                ? session
                : latest,
          );

  @override
  List<SleepSession> get sessions => List<SleepSession>.unmodifiable(
    _sessionsResult ?? <SleepSession>[_session],
  );

  @override
  List<SleepSession> recentSessions({int count = 7}) => sessions;

  @override
  List<SleepSession> sessionsForMonth(DateTime month) => sessions;

  @override
  SleepSession? sessionForSleepDayKey(String sleepDayKey) =>
      sessionForSleepDayKeyResult ??
      sessions.cast<SleepSession?>().firstWhere(
        (SleepSession? session) => session?.sleepDayKey == sleepDayKey,
        orElse: () => null,
      );

  @override
  Future<List<SleepSession>> archivePastCutoffSessions({
    required DateTime now,
  }) async {
    archiveCalls.add(now);
    if (_archiveCallIndex >= _archiveResultsByCall.length) {
      return const <SleepSession>[];
    }
    final List<SleepSession> result = _archiveResultsByCall[_archiveCallIndex];
    _archiveCallIndex += 1;
    if (result.isNotEmpty) {
      _session = result.last;
      _sessionsResult = result;
    }
    notifyListeners();
    return result;
  }

  @override
  Future<SleepSession> startOrResumeSleepSession({
    required List<NightRecommendation> recommendationSnapshot,
    required String? dormId,
    DateTime? at,
  }) async {
    return _session;
  }

  @override
  Future<SleepSession?> pauseActiveSleepSession({DateTime? at}) async => null;

  @override
  Future<SleepSession?> finishActiveSleepSession({DateTime? at}) async => null;

  @override
  Future<void> saveSession(
    SleepSession session, {
    bool syncRemote = true,
  }) async {
    savedSessions.add(session);
    final List<SleepSession> current = List<SleepSession>.from(
      _sessionsResult ?? <SleepSession>[_session],
    );
    final int index = current.indexWhere(
      (SleepSession item) => item.id == session.id,
    );
    if (index == -1) {
      current.add(session);
    } else {
      current[index] = session;
    }
    _session = session;
    _sessionsResult = current;
    notifyListeners();
  }
}
