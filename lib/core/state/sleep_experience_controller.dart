import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/state/audio_playback_controller.dart';

class SleepExperienceController extends ChangeNotifier {
  SleepExperienceController({
    required AuthRepository authRepository,
    required UserSettingsRepository settingsRepository,
    required RecommendationRepository recommendationRepository,
    required SleepSessionRepository sleepSessionRepository,
    required FeedbackRepository feedbackRepository,
    required SleepCaptureRepository sleepCaptureRepository,
    required NotificationRepository notificationRepository,
    required DormRepository dormRepository,
    required AudioPlaybackController audioPlaybackController,
    required PushNotificationGateway pushNotificationGateway,
  }) : _authRepository = authRepository,
       _settingsRepository = settingsRepository,
       _recommendationRepository = recommendationRepository,
       _sleepSessionRepository = sleepSessionRepository,
       _feedbackRepository = feedbackRepository,
       _sleepCaptureRepository = sleepCaptureRepository,
       _notificationRepository = notificationRepository,
       _dormRepository = dormRepository,
       _audioPlaybackController = audioPlaybackController,
       _pushNotificationGateway = pushNotificationGateway;

  final AuthRepository _authRepository;
  final UserSettingsRepository _settingsRepository;
  final RecommendationRepository _recommendationRepository;
  final SleepSessionRepository _sleepSessionRepository;
  final FeedbackRepository _feedbackRepository;
  final SleepCaptureRepository _sleepCaptureRepository;
  final NotificationRepository _notificationRepository;
  final DormRepository _dormRepository;
  final AudioPlaybackController _audioPlaybackController;
  final PushNotificationGateway _pushNotificationGateway;

  AuthRepository get authRepository => _authRepository;
  UserSettingsRepository get settingsRepository => _settingsRepository;
  RecommendationRepository get recommendationRepository =>
      _recommendationRepository;
  SleepSessionRepository get sleepSessionRepository => _sleepSessionRepository;
  FeedbackRepository get feedbackRepository => _feedbackRepository;
  SleepCaptureRepository get sleepCaptureRepository => _sleepCaptureRepository;
  NotificationRepository get notificationRepository => _notificationRepository;
  DormRepository get dormRepository => _dormRepository;
  AudioPlaybackController get audioPlaybackController =>
      _audioPlaybackController;

  Future<UserProfile> _currentUserOrEnsureAuthenticated() async {
    if (_authRepository.currentUser.uid.isNotEmpty) {
      return _authRepository.currentUser;
    }
    return _authRepository.ensureAuthenticated();
  }

  Future<void> bootstrap() async {
    await _authRepository.ensureAuthenticated();
    if (_settingsRepository.currentSettings.selectedNightMood != null) {
      await _recommendationRepository.resetForTonight();
    }
    await _recommendationRepository.refreshAudioCatalog();
  }

  Future<void> handleRecommendationTap(
    NightRecommendation recommendation,
  ) async {
    if (recommendation.type == RecommendationType.audio) {
      final bool shouldPause =
          recommendation.executionState == RecommendationExecutionState.playing;
      await _recommendationRepository.setRecommendationState(
        recommendation.id,
        shouldPause
            ? RecommendationExecutionState.idle
            : RecommendationExecutionState.playing,
      );
      if (shouldPause) {
        try {
          if (_audioPlaybackController.isPlaying) {
            await _audioPlaybackController.pause();
          } else {
            await _audioPlaybackController.stop();
          }
        } catch (_) {
          await _recommendationRepository.setRecommendationState(
            recommendation.id,
            RecommendationExecutionState.playing,
          );
        }
        return;
      }
      unawaited(_startRecommendationAudio(recommendation));
      return;
    }

    final RecommendationExecutionState nextState =
        recommendation.executionState == RecommendationExecutionState.selected
        ? RecommendationExecutionState.idle
        : RecommendationExecutionState.selected;

    await _recommendationRepository.setRecommendationState(
      recommendation.id,
      nextState,
    );
  }

  Future<void> toggleSleepAudio({NightRecommendation? recommendation}) async {
    final AudioTrack? currentTrack = _audioPlaybackController.currentTrack;
    final bool hasCurrentSourceUrl =
        currentTrack?.sourceUrl?.trim().isNotEmpty ?? false;
    final bool hasCurrentAssetPath =
        currentTrack?.assetPath?.trim().isNotEmpty ?? false;
    if (currentTrack != null && (hasCurrentSourceUrl || hasCurrentAssetPath)) {
      try {
        await _audioPlaybackController.toggleTrack(currentTrack);
        return;
      } catch (_) {
        // Fall through to refresh and resolve a new playable track.
      }
    }

    AudioTrack? resolvedTrack = await _recommendationRepository
        .resolvePlayableTrack(recommendation: recommendation);
    if (resolvedTrack == null) {
      return;
    }
    try {
      await _audioPlaybackController.toggleTrack(resolvedTrack);
    } catch (_) {
      resolvedTrack = await _recommendationRepository.resolvePlayableTrack(
        recommendation: recommendation,
        forceRefresh: true,
      );
      if (resolvedTrack == null) {
        return;
      }
      await _audioPlaybackController.toggleTrack(resolvedTrack);
    }
  }

  Future<void> _startRecommendationAudio(
    NightRecommendation recommendation,
  ) async {
    try {
      AudioTrack? resolvedTrack = await _recommendationRepository
          .resolvePlayableTrack(recommendation: recommendation);
      if (resolvedTrack == null) {
        throw StateError('No playable track available.');
      }
      await _playResolvedTrack(resolvedTrack);
    } catch (_) {
      try {
        final AudioTrack? resolvedTrack = await _recommendationRepository
            .resolvePlayableTrack(
              recommendation: recommendation,
              forceRefresh: true,
            );
        if (resolvedTrack == null) {
          throw StateError('No playable track available after refresh.');
        }
        await _playResolvedTrack(resolvedTrack);
      } catch (_) {
        await _recommendationRepository.setRecommendationState(
          recommendation.id,
          RecommendationExecutionState.idle,
        );
      }
    }
  }

  Future<void> _playResolvedTrack(AudioTrack track) async {
    final AudioTrack? currentTrack = _audioPlaybackController.currentTrack;
    final bool isSameTrack = currentTrack?.id == track.id;
    if (isSameTrack) {
      switch (_audioPlaybackController.playbackState) {
        case PlaybackState.playing:
          return;
        case PlaybackState.paused:
          await _audioPlaybackController.resume();
          return;
        case PlaybackState.completed:
        case PlaybackState.stopped:
          await _audioPlaybackController.play(track);
          return;
      }
    }
    await _audioPlaybackController.play(track);
  }

  Future<void> enterSleepMode() async {
    final UserProfile user = await _currentUserOrEnsureAuthenticated();
    final List<NightRecommendation> snapshot = _recommendationRepository
        .tonightRecommendations
        .map(
          (NightRecommendation item) => item.copyWith(
            executionState:
                item.executionState == RecommendationExecutionState.idle
                ? RecommendationExecutionState.selected
                : item.executionState,
          ),
        )
        .toList();

    await _sleepSessionRepository.startSleepSession(
      recommendationSnapshot: snapshot,
      dormId: user.dormId,
    );
    await _dormRepository.updateCurrentUserStatus(
      uid: user.uid,
      status: DormMemberStatus.quiet,
      sleepModeActive: true,
      note: '已进入睡眠模式',
    );
  }

  Future<void> exitSleepMode() async {
    final UserProfile user = await _currentUserOrEnsureAuthenticated();
    final SleepSession? activeSession = _sleepSessionRepository.activeSession;
    if (activeSession == null) {
      return;
    }

    await _sleepSessionRepository.updateActiveSession(
      sleepModeActive: false,
      status: SleepSessionStatus.awaitingFeedback,
      endedAt: DateTime.now(),
    );
    await _syncDormStatusAfterSleepExit(user.uid);
    unawaited(_completeSleepExitSideEffects(activeSession));
  }

  Future<void> addNightAwakening({
    required DateTime occurredAt,
    required String trigger,
    required int minutesToSleep,
    required String note,
  }) async {
    await _authRepository.ensureAuthenticated();
    SleepSession? session = _sleepSessionRepository.activeSession;
    session ??= await _sleepSessionRepository.startSleepSession(
      recommendationSnapshot: _recommendationRepository.tonightRecommendations,
      dormId: _authRepository.currentUser.dormId,
    );

    final List<NightAwakeningEntry> entries = <NightAwakeningEntry>[
      ...session.awakenings,
      NightAwakeningEntry(
        id: 'awakening-${session.awakenings.length + 1}',
        occurredAt: occurredAt,
        trigger: trigger,
        minutesToSleep: minutesToSleep,
        note: note,
      ),
    ];

    await _sleepSessionRepository.saveSession(
      session.copyWith(awakenings: entries),
    );
  }

  Future<void> submitMorningFeedback({
    required SleepSession session,
    required MorningSummary summary,
    required List<RecommendationFeedback> feedback,
  }) async {
    await _authRepository.ensureAuthenticated();
    await _feedbackRepository.submitFeedback(
      session: session,
      summary: summary,
      recommendationFeedback: feedback,
    );
    try {
      await _dormRepository.updateCurrentUserStatus(
        uid: _authRepository.currentUser.uid,
        status: DormMemberStatus.quiet,
        sleepModeActive: false,
        note: '已完成晨间反馈',
      );
    } catch (_) {
      // Dorm sync is best-effort and should not block feedback submission.
    }

    final List<NotificationItem> notifications = _notificationRepository
        .notifications
        .where(
          (NotificationItem item) => item.route == AppRoutes.feedbackMorning,
        )
        .toList();
    for (final NotificationItem item in notifications) {
      await _notificationRepository.markRead(item.id);
    }
  }

  Future<void> _syncDormStatusAfterSleepExit(String uid) async {
    try {
      await _dormRepository.updateCurrentUserStatus(
        uid: uid,
        status: DormMemberStatus.quiet,
        sleepModeActive: false,
        note: '等待晨间反馈',
      );
    } catch (_) {
      // Dorm sync is best-effort and should not block leaving sleep mode.
    }
  }

  Future<void> _completeSleepExitSideEffects(SleepSession activeSession) async {
    try {
      await _notificationRepository.upsertNotification(
        NotificationItem(
          id: 'feedback-${activeSession.id}',
          category: NotificationCategory.reminder,
          title: '晨间反馈待完成',
          body: '昨晚的行动建议还没记录效果，花 1 分钟帮我继续优化今晚方案。',
          createdAt: DateTime.now(),
          route: AppRoutes.feedbackMorning,
          readAt: null,
        ),
      );
    } catch (_) {
      // Notification creation is not on the critical path for page navigation.
    }

    try {
      await _pushNotificationGateway.scheduleFeedbackReminder(
        sessionId: activeSession.id,
        when: DateTime.now().add(const Duration(hours: 8)),
      );
    } catch (_) {
      // Keep reminder scheduling as a background best-effort task.
    }

    try {
      await _sleepCaptureRepository.showPendingBannerForSession(
        activeSession.id,
      );
    } catch (_) {
      // Pending memo banner should not block leaving sleep mode.
    }
  }
}
