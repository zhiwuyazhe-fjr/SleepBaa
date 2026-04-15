import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
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

      await controller.enterSleepMode();
      final int sleepingCountAfterEnter = dormRepository.currentDorm.members
          .where((DormMember member) => member.sleepModeActive)
          .length;

      await controller.exitSleepMode();

      final DormMember currentMember = dormRepository.currentDorm.members
          .firstWhere(
            (DormMember member) => member.uid == authRepository.currentUser.uid,
          );
      expect(currentMember.sleepModeActive, isFalse);
      expect(currentMember.status, DormMemberStatus.quiet);
      expect(
        dormRepository.currentDorm.members
            .where((DormMember member) => member.sleepModeActive)
            .length,
        sleepingCountAfterEnter - 1,
      );
      expect(notificationService.shownSleepSessions, hasLength(1));
      expect(notificationService.cancelSleepModeNotificationCalls, 2);

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
    'exit sleep mode still cancels notifications when activeSession getter is null',
    () async {
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository();
      final InMemoryUserSettingsRepository settingsRepository =
          InMemoryUserSettingsRepository();
      final InMemoryRecommendationRepository recommendationRepository =
          InMemoryRecommendationRepository();
      final SleepSession seedSession = SleepSession(
        id: 'session-fallback',
        uid: authRepository.currentUser.uid,
        startedAt: DateTime(2026, 4, 15, 0, 10),
        endedAt: null,
        status: SleepSessionStatus.active,
        sleepModeActive: true,
        dormId: 'dorm-1',
        recommendations: const <NightRecommendation>[],
        selectedRecommendationIds: const <String>[],
        awakenings: const <NightAwakeningEntry>[],
        feedback: const <RecommendationFeedback>[],
        summary: null,
        updatedAt: DateTime(2026, 4, 15, 0, 10),
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

      await controller.exitSleepMode();

      expect(notificationService.cancelSleepModeNotificationCalls, 2);
      expect(sleepSessionRepository.savedSessions, hasLength(1));
      expect(
        sleepSessionRepository.savedSessions.single.status,
        SleepSessionStatus.awaitingFeedback,
      );
      expect(
        sleepSessionRepository.savedSessions.single.sleepModeActive,
        isFalse,
      );

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

    await controller.enterSleepMode();
    await controller.exitSleepMode();
    final SleepSession session =
        sleepSessionRepository.latestAwaitingFeedbackSession!;

    await controller.submitMorningFeedback(
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

    final DormMember currentMember = dormRepository.currentDorm.members
        .firstWhere(
          (DormMember member) => member.uid == authRepository.currentUser.uid,
        );
    expect(currentMember.status, DormMemberStatus.quiet);
    expect(currentMember.sleepModeActive, isFalse);
    expect(currentMember.note, '已完成晨间反馈');

    controller.dispose();
    authRepository.dispose();
    settingsRepository.dispose();
    recommendationRepository.dispose();
    sleepSessionRepository.dispose();
    feedbackRepository.dispose();
    sleepCaptureRepository.dispose();
    notificationRepository.dispose();
    dormRepository.dispose();
  });
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

class _NullActiveSleepSessionRepository extends ChangeNotifier
    implements SleepSessionRepository {
  _NullActiveSleepSessionRepository(this._session);

  SleepSession _session;
  final List<SleepSession> savedSessions = <SleepSession>[];

  @override
  SleepSession? get activeSession => null;

  @override
  SleepSession? get latestAwaitingFeedbackSession => null;

  @override
  List<SleepSession> get sessions => <SleepSession>[_session];

  @override
  List<SleepSession> recentSessions({int count = 7}) => sessions;

  @override
  List<SleepSession> sessionsForMonth(DateTime month) => sessions;

  @override
  Future<SleepSession> startSleepSession({
    required List<NightRecommendation> recommendationSnapshot,
    required String? dormId,
    bool sleepModeActive = false,
  }) async {
    return _session;
  }

  @override
  Future<void> updateActiveSession({
    bool? sleepModeActive,
    SleepSessionStatus? status,
    DateTime? endedAt,
    List<String>? selectedRecommendationIds,
  }) async {}

  @override
  Future<void> saveSession(SleepSession session) async {
    savedSessions.add(session);
    _session = session;
    notifyListeners();
  }
}
