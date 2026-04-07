import 'package:flutter/foundation.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

abstract interface class AuthRepository implements Listenable {
  UserProfile get currentUser;
  bool get isAuthenticated;
  bool get isAuthenticating;
  String? get lastAuthError;
  Future<UserProfile> signInAnonymously();
  Future<UserProfile> ensureAuthenticated();
  Future<UserProfile> retryAuthentication();
  Future<void> updateProfile({
    required String displayName,
    required String tagline,
    required String role,
  });
  Future<void> updateAvatar({
    required String? avatarPath,
    required Uint8List? avatarBytes,
  });
  Future<PhoneVerificationChallenge> sendPhoneVerificationCode(
    String phoneNumber,
  );
  Future<void> recoverWithPhone({
    required String phoneNumber,
    required String verificationId,
    required String code,
  });
}

abstract interface class UserSettingsRepository implements Listenable {
  UserSettings get currentSettings;
  Future<void> saveSettings(UserSettings settings);
}

abstract interface class RecommendationRepository implements Listenable {
  List<NightRecommendation> get tonightRecommendations;
  Future<void> resetForTonight();
  Future<void> setRecommendationState(
    String recommendationId,
    RecommendationExecutionState state,
  );
}

abstract interface class SleepSessionRepository implements Listenable {
  SleepSession? get activeSession;
  List<SleepSession> get sessions;
  SleepSession? get latestAwaitingFeedbackSession;
  List<SleepSession> recentSessions({int count = 7});
  List<SleepSession> sessionsForMonth(DateTime month);

  Future<SleepSession> startSleepSession({
    required List<NightRecommendation> recommendationSnapshot,
    required String? dormId,
  });

  Future<void> updateActiveSession({
    bool? sleepModeActive,
    SleepSessionStatus? status,
    DateTime? endedAt,
    List<String>? selectedRecommendationIds,
  });

  Future<void> saveSession(SleepSession session);
}

abstract interface class FeedbackRepository implements Listenable {
  Future<void> submitFeedback({
    required SleepSession session,
    required MorningSummary summary,
    required List<RecommendationFeedback> recommendationFeedback,
  });
}

abstract interface class NotificationRepository implements Listenable {
  List<NotificationItem> get notifications;
  List<NotificationItem> unreadNotifications();
  Future<void> markRead(String notificationId);
  Future<void> upsertNotification(NotificationItem notification);
  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  });
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
  });
  Future<void> updateCurrentUserStatus({
    required String uid,
    required DormMemberStatus status,
    required bool sleepModeActive,
    required String note,
  });
  Future<void> saveRules(DormRulesSettings settings);
  Future<DormInvite> createInvite();
  Future<void> acceptInvite(String inviteCode);
  Future<void> renameDorm(String name);
  Future<void> leaveDorm();
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
  Future<void> refresh();
}

abstract interface class AssistantRepository implements Listenable {
  List<AssistantThread> get threads;
  AssistantThread? get currentThread;
  List<AssistantMessage> messagesForThread(String threadId);
  Future<AssistantThread> createThread({String? title});
  Future<void> renameThread({
    required String threadId,
    required String title,
  });
  Future<void> deleteThread(String threadId);
  Future<void> selectMostRecentThread();
  Future<AssistantThread> ensureThread({String? title});
  Future<void> sendUserMessage({
    required String threadId,
    required String content,
  });
  Future<void> addAssistantMessage({
    required String threadId,
    required String content,
    AssistantMessageStatus status,
  });
  Future<void> setCurrentThread(String threadId);
}

abstract interface class PushNotificationGateway {
  Future<void> scheduleFeedbackReminder({
    required String sessionId,
    required DateTime when,
  });
}
