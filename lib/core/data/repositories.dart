import 'package:flutter/foundation.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class AuthFlowException implements Exception {
  const AuthFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthCaptchaRequiredException extends AuthFlowException {
  const AuthCaptchaRequiredException([super.message = '需要先完成图片验证码验证。']);
}

class AuthPhoneTargetMismatchException extends AuthFlowException {
  const AuthPhoneTargetMismatchException(super.message);
}

abstract interface class AuthRepository implements Listenable {
  UserProfile get currentUser;
  bool get isAuthenticated;
  bool get hasVerifiedPhoneIdentity;
  bool get isAuthenticating;
  bool get hasCompletedInitialAuthBootstrap;
  String? get lastAuthError;
  Future<UserProfile> signInAnonymously();
  Future<UserProfile> ensureAuthenticated();
  Future<UserProfile> retryAuthentication();
  Future<void> signOut();
  Future<void> updateProfile({
    required String displayName,
    required String tagline,
    required String role,
  });
  Future<void> updateBadgePreferences({
    required List<String> earnedBadgeIds,
    String? equippedBadgeId,
    bool clearEquippedBadge = false,
  });
  Future<void> updateDormBadgeVisibility({required bool showDormPulseBadge});
  Future<void> updateDormBadgeSelection({
    String? selectedDormBadgeId,
    bool clearSelectedDormBadgeId = false,
  });
  Future<void> updateAvatar({
    required String? avatarPath,
    required Uint8List? avatarBytes,
  });
  Future<PhoneVerificationChallenge> sendPhoneVerificationCode(
    String phoneNumber, {
    PhoneVerificationTarget target = PhoneVerificationTarget.any,
    String? captchaToken,
  });
  Future<PhoneVerificationProof> verifyPhoneCode({
    required String verificationId,
    required String code,
  });
  Future<AuthCaptchaChallenge> createCaptchaChallenge();
  Future<String> verifyCaptchaChallenge({
    required String token,
    required String code,
  });
  Future<void> signInWithPassword({
    required String phoneNumber,
    required String password,
    String? captchaToken,
  });
  Future<void> signInWithPhoneCode({
    required String phoneNumber,
    required String verificationId,
    required String code,
    String? captchaToken,
  });
  Future<void> registerWithPhone({
    required String phoneNumber,
    required String verificationId,
    required String code,
    required String password,
  });
  Future<void> resetPasswordWithPhone({
    required String phoneNumber,
    required String verificationId,
    required String code,
    required String newPassword,
  });
  Future<void> resetPasswordWithVerificationToken({
    required String phoneNumber,
    required String verificationToken,
    required String newPassword,
  });
  Future<void> authenticateWithPhone({
    required String phoneNumber,
    required String verificationId,
    required String code,
    required bool isExistingUser,
  });
}

abstract interface class UserSettingsRepository implements Listenable {
  UserSettings get currentSettings;

  /// Updates in-memory settings and notifies listeners immediately (no I/O).
  void replaceLocalSettings(UserSettings settings);

  Future<void> saveSettings(UserSettings settings);
}

abstract interface class RecommendationRepository implements Listenable {
  List<NightRecommendation> get tonightRecommendations;
  Future<void> resetForTonight();
  Future<void> refreshAudioCatalog();
  Future<AudioTrack?> resolvePlayableTrack({
    NightRecommendation? recommendation,
    bool forceRefresh = false,
  });
  Future<void> setRecommendationState(
    String recommendationId,
    RecommendationExecutionState state,
  );
}

abstract interface class SleepSessionRepository implements Listenable {
  SleepSession? get activeSession;
  List<SleepSession> get sessions;
  bool get isReadyForSessionLookup;
  SleepSession? get latestAwaitingFeedbackSession;
  List<SleepSession> recentSessions({int count = 7});
  List<SleepSession> sessionsForMonth(DateTime month);
  SleepSession? sessionForSleepDayKey(String sleepDayKey);
  Future<List<SleepSession>> archivePastCutoffSessions({required DateTime now});

  Future<SleepSession> startOrResumeSleepSession({
    required List<NightRecommendation> recommendationSnapshot,
    required String? dormId,
    DateTime? at,
  });

  Future<SleepSession?> pauseActiveSleepSession({DateTime? at});

  Future<SleepSession?> finishActiveSleepSession({DateTime? at});

  Future<void> saveSession(SleepSession session, {bool syncRemote = true});
}

abstract interface class FeedbackRepository implements Listenable {
  Future<void> submitFeedback({
    required SleepSession session,
    required MorningSummary summary,
    required List<RecommendationFeedback> recommendationFeedback,
  });
}

abstract interface class SleepCaptureRepository implements Listenable {
  List<SleepCaptureRecord> recordsByType(SleepCaptureType type);
  List<SleepCaptureRecord> recordsForSession(String sessionId);
  PendingSleepMemoBanner? get pendingSleepMemoBanner;
  Future<SleepCaptureRecord> addRecord({
    required SleepCaptureType type,
    required String sessionId,
    required String content,
    String? recordId,
    String? title,
    String? outline,
    DateTime? createdAt,
  });
  Future<void> showPendingBannerForSession(String sessionId);
  Future<void> clearPendingBanner();
}

abstract interface class NotificationRepository implements Listenable {
  List<NotificationItem> get notifications;
  List<NotificationItem> unreadNotifications();
  Future<void> markRead(String notificationId);
  Future<void> upsertNotification(NotificationItem notification);
}

abstract interface class DormRepository implements Listenable {
  Dorm get currentDorm;
  Stream<Dorm> watchDorm();
  Stream<List<DormMember>> watchMembers();
  Stream<List<DormRule>> watchRules();
  Stream<List<DormEvent>> watchEvents();
  Future<void> createDorm({
    required String name,
    String? overview,
    DormRulesSettings? rulesSettings,
    DormLocationAnchor? locationAnchor,
  });
  Future<void> updateCurrentUserStatus({
    required String uid,
    DormMemberStatus? status,
    DormPresenceStatus? presenceStatus,
    bool? sleepModeActive,
    String? note,
  });
  void hydrateCurrentDormLocationAnchor(DormLocationAnchor anchor);
  Future<void> saveDormLocationAnchor(DormLocationAnchor anchor);
  Future<void> updateDormEnvironment({
    int? noiseDb,
    String? lightLabel,
    String? quietLabel,
  });
  Future<void> saveRules(DormRulesSettings settings);
  Future<void> approvePendingRules();
  Future<void> rejectPendingRules({required String reason});
  Future<DormInvite> createInvite();
  Future<void> acceptInvite(String inviteCode);
  Future<void> renameDorm(String name);
  Future<void> leaveDorm();
  Future<void> sendGentleReminder({
    required String targetUid,
    bool anonymous = true,
    required String message,
  });

  /// Pulls latest dorm snapshot from the server (no-op for in-memory).
  Future<void> refreshDormSnapshot();
}

abstract interface class DreamRepository implements Listenable {
  List<DreamEntry> get entries;
  DreamEntry? get latestEntry;
  Future<void> saveDreamEntry(DreamEntry entry);
  Future<void> deleteDreamEntry(String entryId);
}

abstract interface class InsightsRepository implements Listenable {
  List<SleepInsight> get interferenceInsights;
  SleepReport get currentReport;
  SleepTrendSeries get profileSleepDurationTrend;
  SleepTrendSeries get profileSleepQualityTrend;
  Future<void> refresh();
}

abstract interface class AssistantRepository implements Listenable {
  List<AssistantThread> get threads;
  AssistantThread? get currentThread;
  AssistantProfile get assistantProfile;
  List<AssistantMessage> messagesForThread(String threadId);
  Future<AssistantThread> createThread({String? title});
  Future<void> renameThread({required String threadId, required String title});
  Future<void> deleteThread(String threadId);
  Future<void> selectMostRecentThread();
  Future<AssistantThread> ensureThread({String? title});
  Future<void> sendUserMessage({
    required String threadId,
    required String content,
    String? messageId,
  });
  Future<void> addAssistantMessage({
    required String threadId,
    required String content,
    String? messageId,
    AssistantMessageStatus status,
    AssistantReplySourceMode? sourceMode,
    String? provider,
    String? model,
    String? errorMessage,
  });
  Future<void> updateAssistantMessage({
    required String threadId,
    required String messageId,
    String? content,
    AssistantMessageStatus? status,
    AssistantReplySourceMode? sourceMode,
    String? provider,
    String? model,
    String? errorMessage,
  });
  Future<void> setCurrentThread(String threadId);
  Future<void> updateAssistantProfileName(String assistantName);
}

abstract interface class PushNotificationGateway {
  Future<void> scheduleFeedbackReminder({
    required String sessionId,
    required DateTime when,
  });

  Future<void> cancelFeedbackReminder({required String sessionId});
}
