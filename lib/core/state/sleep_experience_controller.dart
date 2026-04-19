import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/app_notification_service.dart';
import 'package:sleep_dorm_app/core/state/audio_playback_controller.dart';

enum FinishSleepModeResult {
  noActiveSession,
  goToFeedback,
  goHomeFeedbackAlreadySubmitted,
}

typedef SleepExperienceClock = DateTime Function();
typedef SleepExperienceTimerFactory =
    Timer Function(Duration duration, void Function() callback);

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
    required AppNotificationService appNotificationService,
    required AudioPlaybackController audioPlaybackController,
    required PushNotificationGateway pushNotificationGateway,
    SleepExperienceClock? clock,
    SleepExperienceTimerFactory? timerFactory,
  }) : _authRepository = authRepository,
       _settingsRepository = settingsRepository,
       _recommendationRepository = recommendationRepository,
       _sleepSessionRepository = sleepSessionRepository,
       _feedbackRepository = feedbackRepository,
       _sleepCaptureRepository = sleepCaptureRepository,
       _notificationRepository = notificationRepository,
       _dormRepository = dormRepository,
       _appNotificationService = appNotificationService,
       _audioPlaybackController = audioPlaybackController,
       _pushNotificationGateway = pushNotificationGateway,
       _clock = clock ?? DateTime.now,
       _timerFactory = timerFactory ?? Timer.new;

  final AuthRepository _authRepository;
  final UserSettingsRepository _settingsRepository;
  final RecommendationRepository _recommendationRepository;
  final SleepSessionRepository _sleepSessionRepository;
  final FeedbackRepository _feedbackRepository;
  final SleepCaptureRepository _sleepCaptureRepository;
  final NotificationRepository _notificationRepository;
  final DormRepository _dormRepository;
  final AppNotificationService _appNotificationService;
  final AudioPlaybackController _audioPlaybackController;
  final PushNotificationGateway _pushNotificationGateway;
  final SleepExperienceClock _clock;
  final SleepExperienceTimerFactory _timerFactory;

  Timer? _sleepDayCutoffTimer;
  Future<void>? _pendingCutoffSync;

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
  DateTime get currentTime => _clock();

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
    await _synchronizePastCutoffSessions(rescheduleTimer: true);
  }

  Future<void> handleAppResumed() async {
    await _synchronizePastCutoffSessions(rescheduleTimer: true);
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
    await _synchronizePastCutoffSessions(rescheduleTimer: true);
    final UserProfile user = await _currentUserOrEnsureAuthenticated();
    final DateTime now = _clock();
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
        .toList(growable: false);

    final String sleepDayKey = sleepDayKeyFromDate(now);
    final SleepSession? existingForToday = _sleepSessionRepository
        .sessionForSleepDayKey(sleepDayKey);
    final bool shouldClearExitArtifacts =
        existingForToday != null && !existingForToday.sleepModeActive;
    final SleepSession session = await _sleepSessionRepository
        .startOrResumeSleepSession(
          recommendationSnapshot: snapshot,
          dormId: user.dormId,
          at: now,
        );
    if (shouldClearExitArtifacts) {
      await _clearSleepExitArtifacts(session.id);
    }
    try {
      await _appNotificationService.showSleepModeNotification(session: session);
    } catch (_) {
      // Notification display is best-effort and should not block entering sleep mode.
    }
    await _dormRepository.updateCurrentUserStatus(
      uid: user.uid,
      status: DormMemberStatus.quiet,
      sleepModeActive: true,
      note: session.hasSubmittedFeedback ? '已进入睡眠模式，今天时长不再累计' : '已进入睡眠模式',
    );
  }

  Future<SleepSession> resumeSleepModeFromFeedbackReturn() async {
    await _synchronizePastCutoffSessions(rescheduleTimer: true);
    final UserProfile user = await _currentUserOrEnsureAuthenticated();
    final DateTime now = _clock();
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
        .toList(growable: false);

    final String sleepDayKey = sleepDayKeyFromDate(now);
    final SleepSession? existingForToday = _sleepSessionRepository
        .sessionForSleepDayKey(sleepDayKey);
    final bool shouldClearExitArtifacts =
        existingForToday != null && !existingForToday.sleepModeActive;
    final SleepSession session = await _sleepSessionRepository
        .startOrResumeSleepSession(
          recommendationSnapshot: snapshot,
          dormId: user.dormId,
          at: now,
        );
    if (shouldClearExitArtifacts) {
      await _clearSleepExitArtifacts(session.id);
    }
    unawaited(
      _completeSleepModeEntrySideEffects(
        uid: user.uid,
        session: session,
      ),
    );
    return session;
  }

  Future<void> pauseSleepMode() async {
    final UserProfile user = await _currentUserOrEnsureAuthenticated();
    try {
      await _appNotificationService.cancelSleepModeNotification();
    } catch (_) {
      // Notification cleanup is best-effort and should not block pausing sleep mode.
    }
    final SleepSession? paused = await _sleepSessionRepository
        .pauseActiveSleepSession(at: _clock());
    if (paused == null) {
      return;
    }
    try {
      await _dormRepository.updateCurrentUserStatus(
        uid: user.uid,
        status: DormMemberStatus.quiet,
        sleepModeActive: false,
        note: paused.hasSubmittedFeedback ? '已退出睡眠模式' : '已暂停睡眠计时，稍后可继续累计',
      );
    } catch (_) {
      // Dorm sync is best-effort and should not block pausing sleep mode.
    }
  }

  Future<FinishSleepModeResult> finishSleepMode() async {
    final UserProfile user = await _currentUserOrEnsureAuthenticated();
    try {
      await _appNotificationService.cancelSleepModeNotification();
    } catch (_) {
      // Notification cleanup is best-effort and should not block leaving sleep mode.
    }
    final SleepSession? finished = await _sleepSessionRepository
        .finishActiveSleepSession(at: _clock());
    if (finished == null) {
      final SleepSession? fallbackSession = _currentSleepDaySession();
      if (fallbackSession != null) {
        await _syncDormStatusAfterSleepExit(
          user.uid,
          hasSubmittedFeedback: fallbackSession.hasSubmittedFeedback,
        );
        if (fallbackSession.hasSubmittedFeedback) {
          await _clearSleepExitArtifacts(fallbackSession.id);
          return FinishSleepModeResult.goHomeFeedbackAlreadySubmitted;
        }
        if (fallbackSession.status == SleepSessionStatus.awaitingFeedback) {
          return FinishSleepModeResult.goToFeedback;
        }
      }
      return FinishSleepModeResult.noActiveSession;
    }

    await _syncDormStatusAfterSleepExit(
      user.uid,
      hasSubmittedFeedback: finished.hasSubmittedFeedback,
    );
    if (finished.hasSubmittedFeedback) {
      await _clearSleepExitArtifacts(finished.id);
      return FinishSleepModeResult.goHomeFeedbackAlreadySubmitted;
    }
    unawaited(_completeSleepExitSideEffects(finished));
    return FinishSleepModeResult.goToFeedback;
  }

  SleepSession? _currentSleepDaySession() {
    return _sleepSessionRepository.sessionForSleepDayKey(
      sleepDayKeyFromDate(_clock()),
    );
  }

  Future<void> exitSleepMode() async {
    await finishSleepMode();
  }

  Future<void> addNightAwakening({
    required DateTime occurredAt,
    required String trigger,
    required int minutesToSleep,
    required String note,
  }) async {
    await _authRepository.ensureAuthenticated();
    SleepSession? session = _sleepSessionRepository.activeSession;
    session ??= await _sleepSessionRepository.startOrResumeSleepSession(
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
        .where((NotificationItem item) => item.id == 'feedback-${session.id}')
        .toList(growable: false);
    for (final NotificationItem item in notifications) {
      await _notificationRepository.markRead(item.id);
    }
    try {
      await _pushNotificationGateway.cancelFeedbackReminder(
        sessionId: session.id,
      );
    } catch (_) {
      // Canceling reminders is best-effort after feedback submission.
    }
    try {
      await _sleepCaptureRepository.clearPendingBanner();
    } catch (_) {
      // Pending banner cleanup should not block feedback submission.
    }
  }

  Future<void> _syncDormStatusAfterSleepExit(
    String uid, {
    required bool hasSubmittedFeedback,
  }) async {
    try {
      await _dormRepository.updateCurrentUserStatus(
        uid: uid,
        status: DormMemberStatus.quiet,
        sleepModeActive: false,
        note: hasSubmittedFeedback ? '已完成晨间反馈' : '等待晨间反馈',
      );
    } catch (_) {
      // Dorm sync is best-effort and should not block leaving sleep mode.
    }
  }

  Future<void> _synchronizePastCutoffSessions({required bool rescheduleTimer}) {
    final Future<void>? inFlight = _pendingCutoffSync;
    if (inFlight != null) {
      return inFlight;
    }
    final Future<void> task =
        _runPastCutoffSync(rescheduleTimer: rescheduleTimer).whenComplete(() {
          _pendingCutoffSync = null;
        });
    _pendingCutoffSync = task;
    return task;
  }

  Future<void> _runPastCutoffSync({required bool rescheduleTimer}) async {
    final DateTime now = _clock();
    final String currentSleepDayKey = sleepDayKeyFromDate(now);
    final bool hadArchivedActiveSession = _sleepSessionRepository.sessions.any(
      (SleepSession session) =>
          session.status == SleepSessionStatus.active &&
          !session.hasSubmittedFeedback &&
          session.sleepDayKey != currentSleepDayKey,
    );
    final List<SleepSession> archivedSessions = await _sleepSessionRepository
        .archivePastCutoffSessions(now: now);
    if (rescheduleTimer) {
      _scheduleNextSleepDayCutoff(now);
    }
    if (archivedSessions.isEmpty) {
      return;
    }
    if (hadArchivedActiveSession) {
      try {
        await _appNotificationService.cancelSleepModeNotification();
      } catch (_) {
        // Notification cleanup is best-effort after automatic cutoff archival.
      }
      final String uid = _authRepository.currentUser.uid;
      if (uid.isNotEmpty) {
        await _syncDormStatusAfterSleepExit(uid, hasSubmittedFeedback: false);
      }
    }
    for (final SleepSession session in archivedSessions) {
      await _completeSleepExitSideEffects(session);
    }
  }

  void _scheduleNextSleepDayCutoff(DateTime now) {
    _sleepDayCutoffTimer?.cancel();
    final DateTime cutoffToday = DateTime(now.year, now.month, now.day, 20);
    final DateTime nextCutoff = now.isBefore(cutoffToday)
        ? cutoffToday
        : cutoffToday.add(const Duration(days: 1));
    _sleepDayCutoffTimer = _timerFactory(nextCutoff.difference(now), () {
      unawaited(_synchronizePastCutoffSessions(rescheduleTimer: true));
    });
  }

  Future<void> _clearSleepExitArtifacts(String sessionId) async {
    final List<NotificationItem> notifications = _notificationRepository
        .notifications
        .where((NotificationItem item) => item.id == 'feedback-$sessionId')
        .toList(growable: false);
    for (final NotificationItem item in notifications) {
      if (!item.isRead) {
        await _notificationRepository.markRead(item.id);
      }
    }
    try {
      await _pushNotificationGateway.cancelFeedbackReminder(
        sessionId: sessionId,
      );
    } catch (_) {
      // Reminder cleanup is best-effort when sleep mode is resumed.
    }
    try {
      await _sleepCaptureRepository.clearPendingBanner();
    } catch (_) {
      // Pending banner cleanup should not block sleep mode resume.
    }
  }

  Future<void> _completeSleepModeEntrySideEffects({
    required String uid,
    required SleepSession session,
  }) async {
    try {
      await _appNotificationService.showSleepModeNotification(session: session);
    } catch (_) {
      // Notification display is best-effort and should not block returning to sleep mode.
    }
    try {
      await _dormRepository.updateCurrentUserStatus(
        uid: uid,
        status: DormMemberStatus.quiet,
        sleepModeActive: true,
        note: session.hasSubmittedFeedback
            ? '已进入睡眠模式，今天时长不再累计'
            : '已进入睡眠模式',
      );
    } catch (_) {
      // Dorm sync is best-effort and should not block returning to sleep mode.
    }
  }

  Future<void> _completeSleepExitSideEffects(SleepSession session) async {
    try {
      await _notificationRepository.upsertNotification(
        NotificationItem(
          id: 'feedback-${session.id}',
          category: NotificationCategory.reminder,
          title: '晨间反馈待完成',
          body: '昨晚的睡眠记录已经保存，醒来后记得补充晨间反馈。',
          createdAt: _clock(),
          route: AppRoutes.feedbackMorningLocation(sessionId: session.id),
          readAt: null,
        ),
      );
    } catch (_) {
      // Notification creation is not on the critical path for page navigation.
    }

    try {
      await _pushNotificationGateway.scheduleFeedbackReminder(
        sessionId: session.id,
        when: _clock().add(const Duration(hours: 8)),
      );
    } catch (_) {
      // Keep reminder scheduling as a background best-effort task.
    }

    try {
      await _sleepCaptureRepository.showPendingBannerForSession(session.id);
    } catch (_) {
      // Pending memo banner should not block leaving sleep mode.
    }
  }

  @override
  void dispose() {
    _sleepDayCutoffTimer?.cancel();
    super.dispose();
  }
}
