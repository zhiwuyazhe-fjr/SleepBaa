import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/data/in_memory_repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/state/audio_playback_controller.dart';
import 'package:sleep_dorm_app/core/state/sleep_experience_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'exit sleep mode immediately syncs dorm sleeping count back down',
    () async {
      final _SleepControllerHarness harness = _SleepControllerHarness.create();

      await harness.controller.enterSleepMode();
      final int sleepingCountAfterEnter = harness.dormRepository.currentDorm.members
          .where((DormMember member) => member.sleepModeActive)
          .length;

      await harness.controller.exitSleepMode();

      final DormMember currentMember = harness.dormRepository.currentDorm.members
          .firstWhere(
            (DormMember member) => member.uid == harness.authRepository.currentUser.uid,
          );
      expect(currentMember.sleepModeActive, isFalse);
      expect(currentMember.status, DormMemberStatus.quiet);
      expect(
        harness.dormRepository.currentDorm.members
            .where((DormMember member) => member.sleepModeActive)
            .length,
        sleepingCountAfterEnter - 1,
      );

      harness.dispose();
    },
  );

  test('pause sleep mode marks session paused and clears dorm sleeping state', () async {
    final _SleepControllerHarness harness = _SleepControllerHarness.create();

    await harness.controller.enterSleepMode();
    await harness.controller.pauseSleepMode();

    final SleepSession paused = harness.sleepSessionRepository
        .sessionForSleepDayKey(sleepDayKeyFromDate(DateTime.now()))!;
    final DormMember currentMember = harness.dormRepository.currentDorm.members
        .firstWhere(
          (DormMember member) => member.uid == harness.authRepository.currentUser.uid,
        );

    expect(paused.status, SleepSessionStatus.paused);
    expect(paused.sleepModeActive, isFalse);
    expect(currentMember.sleepModeActive, isFalse);

    harness.dispose();
  });

  test('submitting morning feedback restores dorm status to normal', () async {
    final _SleepControllerHarness harness = _SleepControllerHarness.create();

    await harness.controller.enterSleepMode();
    await harness.controller.exitSleepMode();
    final SleepSession session = harness.sleepSessionRepository.latestAwaitingFeedbackSession!;

    await harness.controller.submitMorningFeedback(
      session: session,
      summary: const MorningSummary(
        sleepQuality: 4,
        restedLevel: 4,
        totalSleepHours: 7.2,
        awakeningsCount: 0,
        note: 'Stable night',
      ),
      feedback: const <RecommendationFeedback>[],
    );

    final DormMember currentMember = harness.dormRepository.currentDorm.members
        .firstWhere(
          (DormMember member) => member.uid == harness.authRepository.currentUser.uid,
        );
    expect(currentMember.status, DormMemberStatus.quiet);
    expect(currentMember.sleepModeActive, isFalse);

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

      final SleepSession awaiting = harness.sleepSessionRepository.latestAwaitingFeedbackSession!;
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
