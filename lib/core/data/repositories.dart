import 'package:flutter/foundation.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

abstract interface class AuthRepository implements Listenable {
  UserProfile get currentUser;
  Future<UserProfile> signInAnonymously();
  Future<void> updateProfile({
    required String displayName,
    required String tagline,
    required String role,
  });
  Future<void> updateAvatar({
    required String? avatarPath,
    required Uint8List? avatarBytes,
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

abstract interface class SleepCaptureRepository implements Listenable {
  List<SleepCaptureRecord> recordsByType(SleepCaptureType type);
  List<SleepCaptureRecord> recordsForSession(String sessionId);
  PendingSleepMemoBanner? get pendingSleepMemoBanner;
  Future<SleepCaptureRecord> addRecord({
    required SleepCaptureType type,
    required String sessionId,
    required String content,
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
  Future<void> updateCurrentUserStatus({
    required String uid,
    required DormMemberStatus status,
    required bool sleepModeActive,
    required String note,
  });
}

abstract interface class PushNotificationGateway {
  Future<void> scheduleFeedbackReminder({
    required String sessionId,
    required DateTime when,
  });
}
