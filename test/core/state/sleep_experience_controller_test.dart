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
      final SleepExperienceController controller = SleepExperienceController(
        authRepository: authRepository,
        settingsRepository: settingsRepository,
        recommendationRepository: recommendationRepository,
        sleepSessionRepository: sleepSessionRepository,
        feedbackRepository: feedbackRepository,
        sleepCaptureRepository: sleepCaptureRepository,
        notificationRepository: notificationRepository,
        dormRepository: dormRepository,
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
    final SleepExperienceController controller = SleepExperienceController(
      authRepository: authRepository,
      settingsRepository: settingsRepository,
      recommendationRepository: recommendationRepository,
      sleepSessionRepository: sleepSessionRepository,
      feedbackRepository: feedbackRepository,
      sleepCaptureRepository: sleepCaptureRepository,
      notificationRepository: notificationRepository,
      dormRepository: dormRepository,
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
