import 'package:flutter/foundation.dart';
import 'package:sleep_dorm_app/core/backend/assistant_reply_gateway.dart';
import 'package:sleep_dorm_app/core/data/cloudbase_repositories.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/state/audio_playback_controller.dart';
import 'package:sleep_dorm_app/core/state/sleep_experience_controller.dart';
import 'package:sleep_dorm_app/core/utils/id_generator.dart';

class ProfileFacade extends ChangeNotifier {
  ProfileFacade({
    required AuthRepository authRepository,
    required UserSettingsRepository settingsRepository,
    RecommendationRepository? recommendationRepository,
  }) : _authRepository = authRepository,
       _settingsRepository = settingsRepository,
       _recommendationRepository = recommendationRepository {
    _authRepository.addListener(notifyListeners);
    _settingsRepository.addListener(notifyListeners);
  }

  final AuthRepository _authRepository;
  final UserSettingsRepository _settingsRepository;
  final RecommendationRepository? _recommendationRepository;

  UserProfile get currentUser => _authRepository.currentUser;
  UserSettings get currentSettings => _settingsRepository.currentSettings;

  Future<void> saveProfile({
    required String displayName,
    required String tagline,
    required String role,
    required UserSettings settings,
  }) async {
    final UserSettings previousSettings = currentSettings;
    final UserProfile nextProfile = currentUser.copyWith(
      displayName: displayName,
      tagline: tagline,
      role: role,
      avatarFallbackSeed: displayName,
    );
    if (_authRepository case final CloudBaseAuthRepository cloudAuth) {
      if (_settingsRepository
          case final CloudBaseUserSettingsRepository cloudSettings) {
        cloudSettings.replaceLocalSettings(settings);
      }
      await cloudAuth.saveProfileBundle(
        profile: nextProfile,
        settings: settings,
      );
    } else {
      await _authRepository.updateProfile(
        displayName: displayName,
        tagline: tagline,
        role: role,
      );
      await _settingsRepository.saveSettings(settings);
    }
    if (_shouldRefreshRecommendations(previousSettings, settings)) {
      await _recommendationRepository?.resetForTonight();
    }
  }

  Future<void> saveNightMood(NightMood? mood) async {
    await _settingsRepository.saveSettings(
      mood == null
          ? currentSettings.copyWith(clearSelectedNightMood: true)
          : currentSettings.copyWith(selectedNightMood: mood),
    );
    await _recommendationRepository?.resetForTonight();
  }

  Future<void> updateAvatar({
    required String? avatarPath,
    required Uint8List? avatarBytes,
  }) {
    return _authRepository.updateAvatar(
      avatarPath: avatarPath,
      avatarBytes: avatarBytes,
    );
  }

  Future<PhoneVerificationChallenge> sendPhoneVerificationCode(
    String phoneNumber,
  ) {
    return _authRepository.sendPhoneVerificationCode(phoneNumber);
  }

  Future<void> recoverWithPhone({
    required String phoneNumber,
    required String verificationId,
    required String code,
  }) {
    return _authRepository.recoverWithPhone(
      phoneNumber: phoneNumber,
      verificationId: verificationId,
      code: code,
    );
  }

  bool _shouldRefreshRecommendations(
    UserSettings previous,
    UserSettings next,
  ) {
    if (!next.smartSuggestionsEnabled) {
      return false;
    }
    return previous.sleepGoalHours != next.sleepGoalHours ||
        previous.preferredTrackTitle != next.preferredTrackTitle ||
        previous.selectedNightMood != next.selectedNightMood ||
        previous.smartSuggestionsEnabled != next.smartSuggestionsEnabled;
  }

  @override
  void dispose() {
    _authRepository.removeListener(notifyListeners);
    _settingsRepository.removeListener(notifyListeners);
    super.dispose();
  }
}

class SleepFacade extends ChangeNotifier {
  SleepFacade({
    required SleepExperienceController experienceController,
    required RecommendationRepository recommendationRepository,
    required SleepSessionRepository sleepSessionRepository,
    required AudioPlaybackController audioPlaybackController,
  }) : _experienceController = experienceController,
       _recommendationRepository = recommendationRepository,
       _sleepSessionRepository = sleepSessionRepository,
       _audioPlaybackController = audioPlaybackController {
    _recommendationRepository.addListener(notifyListeners);
    _sleepSessionRepository.addListener(notifyListeners);
    _audioPlaybackController.addListener(notifyListeners);
  }

  final SleepExperienceController _experienceController;
  final RecommendationRepository _recommendationRepository;
  final SleepSessionRepository _sleepSessionRepository;
  final AudioPlaybackController _audioPlaybackController;

  List<NightRecommendation> get tonightRecommendations =>
      _recommendationRepository.tonightRecommendations;
  SleepSession? get activeSession => _sleepSessionRepository.activeSession;
  SleepSession? get latestAwaitingFeedbackSession =>
      _sleepSessionRepository.latestAwaitingFeedbackSession;
  List<SleepSession> get sessions => _sleepSessionRepository.sessions;
  List<SleepSession> recentSessions({int count = 7}) =>
      _sleepSessionRepository.recentSessions(count: count);
  List<SleepSession> sessionsForMonth(DateTime month) =>
      _sleepSessionRepository.sessionsForMonth(month);
  AudioPlaybackController get audioPlaybackController =>
      _audioPlaybackController;

  Future<void> handleRecommendationTap(NightRecommendation recommendation) {
    return _experienceController.handleRecommendationTap(recommendation);
  }

  Future<void> enterSleepMode() => _experienceController.enterSleepMode();

  Future<void> exitSleepMode() => _experienceController.exitSleepMode();

  Future<void> addNightAwakening({
    required DateTime occurredAt,
    required String trigger,
    required int minutesToSleep,
    required String note,
  }) {
    return _experienceController.addNightAwakening(
      occurredAt: occurredAt,
      trigger: trigger,
      minutesToSleep: minutesToSleep,
      note: note,
    );
  }

  Future<void> submitMorningFeedback({
    required SleepSession session,
    required MorningSummary summary,
    required List<RecommendationFeedback> feedback,
  }) {
    return _experienceController.submitMorningFeedback(
      session: session,
      summary: summary,
      feedback: feedback,
    );
  }

  @override
  void dispose() {
    _recommendationRepository.removeListener(notifyListeners);
    _sleepSessionRepository.removeListener(notifyListeners);
    _audioPlaybackController.removeListener(notifyListeners);
    super.dispose();
  }
}

class DormFacade extends ChangeNotifier {
  DormFacade({
    required AuthRepository authRepository,
    required DormRepository dormRepository,
  }) : _authRepository = authRepository,
       _dormRepository = dormRepository {
    _authRepository.addListener(notifyListeners);
    _dormRepository.addListener(notifyListeners);
  }

  final AuthRepository _authRepository;
  final DormRepository _dormRepository;

  Dorm get currentDorm => _dormRepository.currentDorm;
  String get currentUserId => _authRepository.currentUser.uid;

  Future<void> createDorm({
    required String name,
    String? overview,
    DormRulesSettings? rulesSettings,
  }) {
    return _dormRepository.createDorm(
      name: name,
      overview: overview,
      rulesSettings: rulesSettings,
    );
  }

  Future<void> updateCurrentUserStatus({
    required DormMemberStatus status,
    required bool sleepModeActive,
    required String note,
  }) {
    return _dormRepository.updateCurrentUserStatus(
      uid: currentUserId,
      status: status,
      sleepModeActive: sleepModeActive,
      note: note,
    );
  }

  Future<void> saveRules(DormRulesSettings settings) {
    return _dormRepository.saveRules(settings);
  }

  Future<DormInvite> createInvite() => _dormRepository.createInvite();

  Future<void> acceptInvite(String inviteCode) {
    return _dormRepository.acceptInvite(inviteCode);
  }

  Future<void> renameDorm(String name) => _dormRepository.renameDorm(name);

  Future<void> leaveDorm() => _dormRepository.leaveDorm();

  @override
  void dispose() {
    _authRepository.removeListener(notifyListeners);
    _dormRepository.removeListener(notifyListeners);
    super.dispose();
  }
}

class NotificationFacade extends ChangeNotifier {
  NotificationFacade({required NotificationRepository notificationRepository})
    : _notificationRepository = notificationRepository {
    _notificationRepository.addListener(notifyListeners);
  }

  final NotificationRepository _notificationRepository;

  List<NotificationItem> get notifications =>
      _notificationRepository.notifications;
  int get unreadCount => _notificationRepository.unreadNotifications().length;

  Future<void> markRead(String notificationId) {
    return _notificationRepository.markRead(notificationId);
  }

  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) {
    return _notificationRepository.registerDeviceToken(
      token: token,
      platform: platform,
    );
  }

  @override
  void dispose() {
    _notificationRepository.removeListener(notifyListeners);
    super.dispose();
  }
}

class DreamFacade extends ChangeNotifier {
  DreamFacade({
    required AuthRepository authRepository,
    required DreamRepository dreamRepository,
  }) : _authRepository = authRepository,
       _dreamRepository = dreamRepository {
    _dreamRepository.addListener(notifyListeners);
  }

  final AuthRepository _authRepository;
  final DreamRepository _dreamRepository;

  List<DreamEntry> get entries => _dreamRepository.entries;
  DreamEntry? get latestEntry => _dreamRepository.latestEntry;

  Future<void> saveDraft({
    required String userId,
    required String title,
    required String body,
    required List<String> tags,
    String? emotionLabel,
    String? sessionId,
  }) async {
    final UserProfile profile = await _authRepository.ensureAuthenticated();
    return _dreamRepository.saveDreamEntry(
      DreamEntry(
        id: IdGenerator.next('dream'),
        userId: userId.isEmpty ? profile.uid : userId,
        title: title,
        body: body,
        tags: tags,
        createdAt: DateTime.now(),
        emotionLabel: emotionLabel,
        sessionId: sessionId,
      ),
    );
  }

  Future<void> deleteEntry(String entryId) {
    return _dreamRepository.deleteDreamEntry(entryId);
  }

  @override
  void dispose() {
    _dreamRepository.removeListener(notifyListeners);
    super.dispose();
  }
}

class InsightsFacade extends ChangeNotifier {
  InsightsFacade({required InsightsRepository insightsRepository})
    : _insightsRepository = insightsRepository {
    _insightsRepository.addListener(notifyListeners);
  }

  final InsightsRepository _insightsRepository;

  List<SleepInsight> get interferenceInsights =>
      _insightsRepository.interferenceInsights;
  SleepReport get currentReport => _insightsRepository.currentReport;

  Future<void> refresh() => _insightsRepository.refresh();

  @override
  void dispose() {
    _insightsRepository.removeListener(notifyListeners);
    super.dispose();
  }
}

class AssistantFacade extends ChangeNotifier {
  AssistantFacade({
    required AuthRepository authRepository,
    required AssistantRepository assistantRepository,
    required DormRepository dormRepository,
    required AssistantReplyGateway assistantReplyGateway,
  }) : _authRepository = authRepository,
       _assistantRepository = assistantRepository,
       _dormRepository = dormRepository,
       _assistantReplyGateway = assistantReplyGateway {
    _assistantRepository.addListener(notifyListeners);
  }

  final AuthRepository _authRepository;
  final AssistantRepository _assistantRepository;
  final DormRepository _dormRepository;
  final AssistantReplyGateway _assistantReplyGateway;

  AssistantThread? get currentThread => _assistantRepository.currentThread;
  List<AssistantThread> get threads => _assistantRepository.threads;
  List<AssistantMessage> get currentMessages {
    final AssistantThread? thread = currentThread;
    if (thread == null) {
      return const <AssistantMessage>[];
    }
    return _assistantRepository.messagesForThread(thread.id);
  }

  Future<AssistantThread> createThread({String? title}) {
    return _assistantRepository.createThread(title: title);
  }

  Future<void> renameThread({
    required String threadId,
    required String title,
  }) {
    return _assistantRepository.renameThread(threadId: threadId, title: title);
  }

  Future<void> deleteThread(String threadId) {
    return _assistantRepository.deleteThread(threadId);
  }

  Future<void> selectMostRecentThread() {
    return _assistantRepository.selectMostRecentThread();
  }

  Future<void> sendPrompt(String prompt) async {
    final String normalizedPrompt = prompt.trim();
    if (normalizedPrompt.isEmpty) {
      return;
    }
    await _authRepository.ensureAuthenticated();
    final AssistantThread thread = await _assistantRepository.ensureThread(
      title: '今晚睡前聊聊',
    );
    await _assistantRepository.setCurrentThread(thread.id);
    await _assistantRepository.sendUserMessage(
      threadId: thread.id,
      content: normalizedPrompt,
    );
    try {
      final AssistantReplyResult reply = await _assistantReplyGateway
          .generateReply(
            prompt: normalizedPrompt,
            threadId: thread.id,
            dorm: _dormRepository.currentDorm,
          );
      final List<AssistantMessage> existingMessages = _assistantRepository
          .messagesForThread(thread.id);
      final bool alreadySynced =
          existingMessages.isNotEmpty &&
          existingMessages.last.role == AssistantMessageRole.assistant &&
          existingMessages.last.content == reply.reply;
      if (!alreadySynced) {
        await _assistantRepository.addAssistantMessage(
          threadId: thread.id,
          content: reply.reply,
        );
      }
    } catch (_) {
      await _assistantRepository.addAssistantMessage(
        threadId: thread.id,
        content: '暂时没有收到回复，请稍后再试。',
        status: AssistantMessageStatus.error,
      );
    }
  }

  @override
  void dispose() {
    _assistantRepository.removeListener(notifyListeners);
    super.dispose();
  }
}
