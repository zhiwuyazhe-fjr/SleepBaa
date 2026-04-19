import 'dart:typed_data';

import 'package:flutter/material.dart';

enum HomeMode { preSleep, postSleep }

enum NightMood { happy, sad, calm }

enum RecommendationType { audio, quickAction }

enum RecommendationExecutionState { idle, selected, playing, completed }

enum RecommendationFeedbackStatus { effective, neutral, ineffective, skipped }

enum SleepSessionStatus { drafted, active, paused, awaitingFeedback, completed }

enum NotificationCategory { reminder, session, dorm, system }

enum DormMemberStatus { sleeping, quiet, away, active }

enum DormPresenceStatus { returned, away }

enum DormEventType { memberStatus, ruleUpdate, notification, invite, system }

enum DormInviteStatus { pending, accepted, expired, revoked }

enum DormStatus { active, archived }

enum PlaybackState { stopped, playing, paused, completed }

enum InterferenceFactorType { noise, light, phoneUsage, emotion }

enum InterferenceFactorStatus {
  idle,
  measuring,
  ready,
  denied,
  unavailable,
  unsupported,
  error,
}

enum SleepCaptureType { dream, memo }

enum InsightCategory { interference, report, recommendation, trend }

enum AssistantMessageRole { user, assistant, system }

enum AssistantMessageStatus { pending, complete, error }

enum AssistantReplySourceMode { remoteSuccess, fallbackSuccess, error }

enum PhoneVerificationTarget { any, existingUser, newUser }

class PhoneVerificationChallenge {
  const PhoneVerificationChallenge({
    required this.verificationId,
    required this.expiresIn,
    required this.isExistingUser,
  });

  final String verificationId;
  final int expiresIn;
  final bool isExistingUser;
}

class AuthCaptchaChallenge {
  const AuthCaptchaChallenge({
    required this.token,
    required this.imageData,
    required this.expiresIn,
  });

  final String token;
  final String imageData;
  final int expiresIn;
}

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.tagline,
    required this.role,
    this.earnedBadgeIds = const <String>[],
    this.equippedBadgeId,
    this.showDormPulseBadge = true,
    this.selectedDormBadgeId,
    this.dormId,
    this.phoneNumber,
    this.phoneLinkedAt,
    this.avatarPath,
    this.avatarBytes,
    this.avatarUrl,
    this.avatarStoragePath,
    this.avatarFallbackSeed,
  });

  final String uid;
  final String displayName;
  final String tagline;
  final String role;
  final List<String> earnedBadgeIds;
  final String? equippedBadgeId;
  final bool showDormPulseBadge;
  final String? selectedDormBadgeId;
  final String? dormId;
  final String? phoneNumber;
  final DateTime? phoneLinkedAt;
  final String? avatarPath;
  final Uint8List? avatarBytes;
  final String? avatarUrl;
  final String? avatarStoragePath;
  final String? avatarFallbackSeed;

  String? get latestEarnedBadgeId =>
      earnedBadgeIds.isEmpty ? null : earnedBadgeIds.last;

  String? get displayBadgeId {
    final String? normalizedEquipped = equippedBadgeId?.trim();
    if (normalizedEquipped != null &&
        normalizedEquipped.isNotEmpty &&
        earnedBadgeIds.contains(normalizedEquipped)) {
      return normalizedEquipped;
    }
    return latestEarnedBadgeId;
  }

  bool hasEarnedBadge(String badgeId) => earnedBadgeIds.contains(badgeId);

  String? resolveDormBadgeId(Iterable<String> earnedDormBadgeIds) {
    final String? normalizedSelected = selectedDormBadgeId?.trim();
    if (normalizedSelected != null &&
        normalizedSelected.isNotEmpty &&
        earnedDormBadgeIds.contains(normalizedSelected)) {
      return normalizedSelected;
    }
    if (earnedDormBadgeIds is List<String>) {
      return earnedDormBadgeIds.isEmpty ? null : earnedDormBadgeIds.last;
    }
    String? latestBadgeId;
    for (final String badgeId in earnedDormBadgeIds) {
      latestBadgeId = badgeId;
    }
    return latestBadgeId;
  }

  UserProfile copyWith({
    String? uid,
    String? displayName,
    String? tagline,
    String? role,
    List<String>? earnedBadgeIds,
    String? equippedBadgeId,
    bool? showDormPulseBadge,
    String? selectedDormBadgeId,
    String? dormId,
    String? phoneNumber,
    DateTime? phoneLinkedAt,
    String? avatarPath,
    Uint8List? avatarBytes,
    String? avatarUrl,
    String? avatarStoragePath,
    bool clearEquippedBadge = false,
    bool clearSelectedDormBadgeId = false,
    bool clearAvatar = false,
    bool clearDormId = false,
    bool clearPhoneNumber = false,
    bool clearPhoneLinkedAt = false,
    String? avatarFallbackSeed,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      tagline: tagline ?? this.tagline,
      role: role ?? this.role,
      earnedBadgeIds: earnedBadgeIds ?? this.earnedBadgeIds,
      equippedBadgeId: clearEquippedBadge
          ? null
          : equippedBadgeId ?? this.equippedBadgeId,
      showDormPulseBadge: showDormPulseBadge ?? this.showDormPulseBadge,
      selectedDormBadgeId: clearSelectedDormBadgeId
          ? null
          : selectedDormBadgeId ?? this.selectedDormBadgeId,
      dormId: clearDormId ? null : dormId ?? this.dormId,
      phoneNumber: clearPhoneNumber ? null : phoneNumber ?? this.phoneNumber,
      phoneLinkedAt: clearPhoneLinkedAt
          ? null
          : phoneLinkedAt ?? this.phoneLinkedAt,
      avatarPath: clearAvatar ? null : avatarPath ?? this.avatarPath,
      avatarBytes: clearAvatar ? null : avatarBytes ?? this.avatarBytes,
      avatarUrl: clearAvatar ? null : avatarUrl ?? this.avatarUrl,
      avatarStoragePath: clearAvatar
          ? null
          : avatarStoragePath ?? this.avatarStoragePath,
      avatarFallbackSeed:
          avatarFallbackSeed ?? this.avatarFallbackSeed ?? this.displayName,
    );
  }
}

class HonorBadge {
  const HonorBadge({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
}

class DormHonorBadge {
  const DormHonorBadge({
    required this.id,
    required this.label,
    required this.meaning,
    required this.icon,
  });

  final String id;
  final String label;
  final String meaning;
  final IconData icon;
}

const List<HonorBadge> kHonorBadgeCatalog = <HonorBadge>[
  HonorBadge(
    id: 'first-week',
    label: '首周达成',
    description: '连续完成第一周睡眠打卡。',
    icon: Icons.military_tech_rounded,
  ),
  HonorBadge(
    id: 'early-sleeper',
    label: '早睡先锋',
    description: '多次在目标时间前进入睡前流程。',
    icon: Icons.rocket_launch_rounded,
  ),
  HonorBadge(
    id: 'sleep-master',
    label: '安睡大师',
    description: '保持稳定睡眠节律并减少夜醒。',
    icon: Icons.dark_mode_rounded,
  ),
  HonorBadge(
    id: 'monthly-perfect',
    label: '月度全勤',
    description: '整月坚持完成睡眠记录。',
    icon: Icons.calendar_month_rounded,
  ),
  HonorBadge(
    id: 'quiet-guardian',
    label: '安静守护者',
    description: '持续帮助宿舍维持安静环境。',
    icon: Icons.volume_off_rounded,
  ),
  HonorBadge(
    id: 'sunrise-club',
    label: '早起自律',
    description: '连续多天稳定早起。',
    icon: Icons.wb_sunny_outlined,
  ),
  HonorBadge(
    id: 'exam-support',
    label: '考试周同盟',
    description: '考试周积极配合宿舍共同作息。',
    icon: Icons.menu_book_rounded,
  ),
  HonorBadge(
    id: 'gentle-reminder',
    label: '温柔提醒官',
    description: '多次发送温和提醒并获得积极反馈。',
    icon: Icons.mark_chat_read_rounded,
  ),
  HonorBadge(
    id: 'pulse-observer',
    label: '宿舍脉搏观察员',
    description: '持续关注宿舍状态并及时回应变化。',
    icon: Icons.monitor_heart_rounded,
  ),
  HonorBadge(
    id: 'team-star',
    label: '合住默契星',
    description: '长期维护舒适的共同生活节奏。',
    icon: Icons.groups_rounded,
  ),
];

HonorBadge? honorBadgeById(String? badgeId) {
  if (badgeId == null || badgeId.trim().isEmpty) {
    return null;
  }
  for (final HonorBadge badge in kHonorBadgeCatalog) {
    if (badge.id == badgeId) {
      return badge;
    }
  }
  return null;
}

const List<DormHonorBadge> kDormHonorBadgeCatalog = <DormHonorBadge>[
  DormHonorBadge(
    id: 'no-wake-room',
    label: '不醒人室',
    meaning: '宿舍成员整体睡眠时间长，睡眠状态良好',
    icon: Icons.bedtime_rounded,
  ),
  DormHonorBadge(
    id: 'no-trouble-room',
    label: '无琐事室',
    meaning: '宿舍成员连续一周未发生冲突，关系和谐',
    icon: Icons.handshake_rounded,
  ),
  DormHonorBadge(
    id: 'no-one-home-room',
    label: '若无其室',
    meaning: '该宿舍该周多次存在成员未归寝情况',
    icon: Icons.door_front_door_outlined,
  ),
  DormHonorBadge(
    id: 'noisy-room',
    label: '嘘张声室',
    meaning: '该宿舍较吵闹',
    icon: Icons.campaign_outlined,
  ),
  DormHonorBadge(
    id: 'prison-room',
    label: '实是囚室',
    meaning: '该宿舍关系不和谐，住宿舍跟坐牢一样',
    icon: Icons.heart_broken_outlined,
  ),
];

DormHonorBadge? dormHonorBadgeById(String? badgeId) {
  if (badgeId == null || badgeId.trim().isEmpty) {
    return null;
  }
  for (final DormHonorBadge badge in kDormHonorBadgeCatalog) {
    if (badge.id == badgeId) {
      return badge;
    }
  }
  return null;
}

const Object _unsetEveningEncouragementMoodSnapshot = Object();

class UserSettings {
  const UserSettings({
    required this.sleepGoalHours,
    required this.bedtimeReminderEnabled,
    required this.morningReminderEnabled,
    required this.dormAlertsEnabled,
    required this.bedtimeReminder,
    required this.preferredTrackTitle,
    required this.smartSuggestionsEnabled,
    this.selectedNightMood,
    this.eveningEncouragementPeriodKey,
    this.eveningEncouragementLine,
    this.eveningEncouragementMoodSnapshot,
  });

  final double sleepGoalHours;
  final bool bedtimeReminderEnabled;
  final bool morningReminderEnabled;
  final bool dormAlertsEnabled;
  final TimeOfDay bedtimeReminder;
  final String preferredTrackTitle;
  final bool smartSuggestionsEnabled;
  final NightMood? selectedNightMood;

  /// [eveningPeriodKey] for which [eveningEncouragementLine] was chosen.
  final String? eveningEncouragementPeriodKey;

  /// One persisted encouragement line (quote + attribution) for [eveningEncouragementPeriodKey].
  final String? eveningEncouragementLine;

  /// Mood bucket used when picking the line; `null` means the impatient/unknown quote pool.
  final NightMood? eveningEncouragementMoodSnapshot;

  UserSettings copyWith({
    double? sleepGoalHours,
    bool? bedtimeReminderEnabled,
    bool? morningReminderEnabled,
    bool? dormAlertsEnabled,
    TimeOfDay? bedtimeReminder,
    String? preferredTrackTitle,
    bool? smartSuggestionsEnabled,
    NightMood? selectedNightMood,
    bool clearSelectedNightMood = false,
    String? eveningEncouragementPeriodKey,
    String? eveningEncouragementLine,
    Object? eveningEncouragementMoodSnapshot =
        _unsetEveningEncouragementMoodSnapshot,
    bool clearEveningEncouragement = false,
  }) {
    return UserSettings(
      sleepGoalHours: sleepGoalHours ?? this.sleepGoalHours,
      bedtimeReminderEnabled:
          bedtimeReminderEnabled ?? this.bedtimeReminderEnabled,
      morningReminderEnabled:
          morningReminderEnabled ?? this.morningReminderEnabled,
      dormAlertsEnabled: dormAlertsEnabled ?? this.dormAlertsEnabled,
      bedtimeReminder: bedtimeReminder ?? this.bedtimeReminder,
      preferredTrackTitle: preferredTrackTitle ?? this.preferredTrackTitle,
      smartSuggestionsEnabled:
          smartSuggestionsEnabled ?? this.smartSuggestionsEnabled,
      selectedNightMood: clearSelectedNightMood
          ? null
          : selectedNightMood ?? this.selectedNightMood,
      eveningEncouragementPeriodKey: clearEveningEncouragement
          ? null
          : eveningEncouragementPeriodKey ?? this.eveningEncouragementPeriodKey,
      eveningEncouragementLine: clearEveningEncouragement
          ? null
          : eveningEncouragementLine ?? this.eveningEncouragementLine,
      eveningEncouragementMoodSnapshot: clearEveningEncouragement
          ? null
          : identical(
                  eveningEncouragementMoodSnapshot,
                  _unsetEveningEncouragementMoodSnapshot,
                )
              ? this.eveningEncouragementMoodSnapshot
              : eveningEncouragementMoodSnapshot as NightMood?,
    );
  }
}

class AudioTrack {
  const AudioTrack({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.duration,
    this.assetPath,
    this.sourceUrl,
    this.storageFileId,
  });

  final String id;
  final String title;
  final String subtitle;
  final Duration duration;
  final String? assetPath;
  final String? sourceUrl;
  final String? storageFileId;

  AudioTrack copyWith({
    String? id,
    String? title,
    String? subtitle,
    Duration? duration,
    String? assetPath,
    String? sourceUrl,
    String? storageFileId,
  }) {
    return AudioTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      duration: duration ?? this.duration,
      assetPath: assetPath ?? this.assetPath,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      storageFileId: storageFileId ?? this.storageFileId,
    );
  }
}

class NightRecommendation {
  const NightRecommendation({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.icon,
    required this.tags,
    required this.executionState,
    this.track,
  });

  final String id;
  final String title;
  final String subtitle;
  final RecommendationType type;
  final IconData icon;
  final List<String> tags;
  final RecommendationExecutionState executionState;
  final AudioTrack? track;

  NightRecommendation copyWith({
    String? id,
    String? title,
    String? subtitle,
    RecommendationType? type,
    IconData? icon,
    List<String>? tags,
    RecommendationExecutionState? executionState,
    AudioTrack? track,
  }) {
    return NightRecommendation(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      tags: tags ?? this.tags,
      executionState: executionState ?? this.executionState,
      track: track ?? this.track,
    );
  }
}

class RecommendationFeedback {
  const RecommendationFeedback({
    required this.recommendationId,
    required this.status,
    required this.note,
    required this.submittedAt,
  });

  final String recommendationId;
  final RecommendationFeedbackStatus status;
  final String note;
  final DateTime submittedAt;

  RecommendationFeedback copyWith({
    String? recommendationId,
    RecommendationFeedbackStatus? status,
    String? note,
    DateTime? submittedAt,
  }) {
    return RecommendationFeedback(
      recommendationId: recommendationId ?? this.recommendationId,
      status: status ?? this.status,
      note: note ?? this.note,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }
}

class NightAwakeningEntry {
  const NightAwakeningEntry({
    required this.id,
    required this.occurredAt,
    required this.trigger,
    required this.minutesToSleep,
    required this.note,
  });

  final String id;
  final DateTime occurredAt;
  final String trigger;
  final int minutesToSleep;
  final String note;

  NightAwakeningEntry copyWith({
    String? id,
    DateTime? occurredAt,
    String? trigger,
    int? minutesToSleep,
    String? note,
  }) {
    return NightAwakeningEntry(
      id: id ?? this.id,
      occurredAt: occurredAt ?? this.occurredAt,
      trigger: trigger ?? this.trigger,
      minutesToSleep: minutesToSleep ?? this.minutesToSleep,
      note: note ?? this.note,
    );
  }
}

class MorningSummary {
  const MorningSummary({
    required this.sleepQuality,
    required this.restedLevel,
    required this.totalSleepHours,
    required this.awakeningsCount,
    required this.note,
  });

  final int sleepQuality;
  final int restedLevel;
  final double totalSleepHours;
  final int awakeningsCount;
  final String note;

  MorningSummary copyWith({
    int? sleepQuality,
    int? restedLevel,
    double? totalSleepHours,
    int? awakeningsCount,
    String? note,
  }) {
    return MorningSummary(
      sleepQuality: sleepQuality ?? this.sleepQuality,
      restedLevel: restedLevel ?? this.restedLevel,
      totalSleepHours: totalSleepHours ?? this.totalSleepHours,
      awakeningsCount: awakeningsCount ?? this.awakeningsCount,
      note: note ?? this.note,
    );
  }
}

class SleepSegment {
  const SleepSegment({required this.startedAt, required this.endedAt});

  final DateTime startedAt;
  final DateTime? endedAt;

  bool get isOpen => endedAt == null;

  SleepSegment copyWith({
    DateTime? startedAt,
    DateTime? endedAt,
    bool clearEndedAt = false,
  }) {
    return SleepSegment(
      startedAt: startedAt ?? this.startedAt,
      endedAt: clearEndedAt ? null : endedAt ?? this.endedAt,
    );
  }
}

class SleepSession {
  const SleepSession({
    required this.id,
    this.uid = 'anon-paul',
    required this.startedAt,
    required this.endedAt,
    required this.sleepDayKey,
    required this.status,
    required this.sleepModeActive,
    required this.dormId,
    required this.recommendations,
    required this.selectedRecommendationIds,
    required this.segments,
    required this.trackedDurationMinutes,
    required this.awakenings,
    required this.feedback,
    required this.summary,
    this.sleepGoalMet,
    this.updatedAt,
  });

  final String id;
  final String uid;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String sleepDayKey;
  final SleepSessionStatus status;
  final bool sleepModeActive;
  final String? dormId;
  final List<NightRecommendation> recommendations;
  final List<String> selectedRecommendationIds;
  final List<SleepSegment> segments;
  final int trackedDurationMinutes;
  final List<NightAwakeningEntry> awakenings;
  final List<RecommendationFeedback> feedback;
  final MorningSummary? summary;
  final bool? sleepGoalMet;
  final DateTime? updatedAt;

  bool get hasSubmittedFeedback => summary != null;

  bool get isTrackingLocked => hasSubmittedFeedback;

  SleepSegment? get openSegment {
    for (int index = segments.length - 1; index >= 0; index--) {
      final SleepSegment segment = segments[index];
      if (segment.isOpen) {
        return segment;
      }
    }
    return null;
  }

  DateTime get displayStartAt =>
      segments.isNotEmpty ? segments.first.startedAt : startedAt;

  DateTime? get displayEndAt {
    if (sleepModeActive) {
      return null;
    }
    for (int index = segments.length - 1; index >= 0; index--) {
      final DateTime? segmentEndedAt = segments[index].endedAt;
      if (segmentEndedAt != null) {
        return segmentEndedAt;
      }
    }
    return endedAt;
  }

  DateTime get sleepDayDate {
    final DateTime? parsed = sleepDayDateFromKey(sleepDayKey);
    return parsed ?? DateTime(startedAt.year, startedAt.month, startedAt.day);
  }

  int liveTrackedDurationMinutes({DateTime? now}) {
    if (isTrackingLocked) {
      return trackedDurationMinutes;
    }
    final SleepSegment? currentOpenSegment = openSegment;
    if (!sleepModeActive || currentOpenSegment == null) {
      return trackedDurationMinutes;
    }
    final int extraMinutes = (now ?? DateTime.now())
        .difference(currentOpenSegment.startedAt)
        .inMinutes
        .clamp(0, 24 * 60)
        .toInt();
    return trackedDurationMinutes + extraMinutes;
  }

  double displaySleepHours({DateTime? now}) {
    final MorningSummary? currentSummary = summary;
    if (currentSummary != null) {
      return currentSummary.totalSleepHours;
    }
    return liveTrackedDurationMinutes(now: now) / 60;
  }

  bool? deriveSleepGoalMet(double sleepGoalHours) {
    if (status != SleepSessionStatus.awaitingFeedback &&
        status != SleepSessionStatus.completed) {
      return null;
    }
    if (sleepModeActive) {
      return null;
    }
    return displaySleepHours() >= sleepGoalHours;
  }

  SleepSession copyWith({
    String? id,
    String? uid,
    DateTime? startedAt,
    DateTime? endedAt,
    bool clearEndedAt = false,
    String? sleepDayKey,
    SleepSessionStatus? status,
    bool? sleepModeActive,
    String? dormId,
    List<NightRecommendation>? recommendations,
    List<String>? selectedRecommendationIds,
    List<SleepSegment>? segments,
    int? trackedDurationMinutes,
    List<NightAwakeningEntry>? awakenings,
    List<RecommendationFeedback>? feedback,
    MorningSummary? summary,
    bool clearSummary = false,
    bool? sleepGoalMet,
    bool clearSleepGoalMet = false,
    DateTime? updatedAt,
  }) {
    return SleepSession(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      startedAt: startedAt ?? this.startedAt,
      endedAt: clearEndedAt ? null : endedAt ?? this.endedAt,
      sleepDayKey: sleepDayKey ?? this.sleepDayKey,
      status: status ?? this.status,
      sleepModeActive: sleepModeActive ?? this.sleepModeActive,
      dormId: dormId ?? this.dormId,
      recommendations: recommendations ?? this.recommendations,
      selectedRecommendationIds:
          selectedRecommendationIds ?? this.selectedRecommendationIds,
      segments: segments ?? this.segments,
      trackedDurationMinutes:
          trackedDurationMinutes ?? this.trackedDurationMinutes,
      awakenings: awakenings ?? this.awakenings,
      feedback: feedback ?? this.feedback,
      summary: clearSummary ? null : summary ?? this.summary,
      sleepGoalMet: clearSleepGoalMet
          ? null
          : sleepGoalMet ?? this.sleepGoalMet,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

String sleepDayKeyFromDate(DateTime value) {
  final DateTime shifted = value.add(const Duration(hours: 4));
  final String month = shifted.month.toString().padLeft(2, '0');
  final String day = shifted.day.toString().padLeft(2, '0');
  return '${shifted.year}-$month-$day';
}

DateTime? sleepDayDateFromKey(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse('${value}T00:00:00');
}

int sleepSegmentDurationMinutes(
  SleepSegment segment, {
  DateTime? fallbackEndedAt,
}) {
  final DateTime? effectiveEndedAt = segment.endedAt ?? fallbackEndedAt;
  if (effectiveEndedAt == null) {
    return 0;
  }
  return effectiveEndedAt
      .difference(segment.startedAt)
      .inMinutes
      .clamp(0, 24 * 60)
      .toInt();
}

DateTime? resolveMorningFeedbackSessionEndAt(SleepSession session) {
  if (session.sleepModeActive) {
    return null;
  }
  final DateTime? displayEndAt = session.displayEndAt;
  if (displayEndAt != null) {
    return displayEndAt;
  }
  for (int index = session.segments.length - 1; index >= 0; index--) {
    final DateTime? endedAt = session.segments[index].endedAt;
    if (endedAt != null) {
      return endedAt;
    }
  }
  return session.endedAt;
}

bool canSubmitMorningFeedbackForSession(SleepSession session) {
  if (session.status != SleepSessionStatus.awaitingFeedback ||
      session.sleepModeActive ||
      session.hasSubmittedFeedback) {
    return false;
  }
  if (session.openSegment != null) {
    return false;
  }
  return resolveMorningFeedbackSessionEndAt(session) != null;
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.route,
    required this.readAt,
    this.ownerUid,
  });

  final String id;
  final NotificationCategory category;
  final String title;
  final String body;
  final DateTime createdAt;
  final String route;
  final DateTime? readAt;
  final String? ownerUid;

  bool get isRead => readAt != null;

  NotificationItem copyWith({
    String? id,
    NotificationCategory? category,
    String? title,
    String? body,
    DateTime? createdAt,
    String? route,
    DateTime? readAt,
    String? ownerUid,
    bool clearReadAt = false,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      category: category ?? this.category,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      route: route ?? this.route,
      readAt: clearReadAt ? null : readAt ?? this.readAt,
      ownerUid: ownerUid ?? this.ownerUid,
    );
  }
}

class SleepTrendPoint {
  const SleepTrendPoint({
    required this.dateKey,
    required this.weekdayLabel,
    required this.value,
  });

  final String dateKey;
  final String weekdayLabel;
  final double? value;

  SleepTrendPoint copyWith({
    String? dateKey,
    String? weekdayLabel,
    double? value,
    bool clearValue = false,
  }) {
    return SleepTrendPoint(
      dateKey: dateKey ?? this.dateKey,
      weekdayLabel: weekdayLabel ?? this.weekdayLabel,
      value: clearValue ? null : value ?? this.value,
    );
  }
}

class SleepTrendSeries {
  const SleepTrendSeries({
    required this.metricKey,
    required this.unit,
    required this.points,
  });

  final String metricKey;
  final String unit;
  final List<SleepTrendPoint> points;

  SleepTrendSeries copyWith({
    String? metricKey,
    String? unit,
    List<SleepTrendPoint>? points,
  }) {
    return SleepTrendSeries(
      metricKey: metricKey ?? this.metricKey,
      unit: unit ?? this.unit,
      points: points ?? this.points,
    );
  }
}

class DormRule {
  const DormRule({this.id = '', required this.title, required this.detail});

  final String id;
  final String title;
  final String detail;

  DormRule copyWith({String? id, String? title, String? detail}) {
    return DormRule(
      id: id ?? this.id,
      title: title ?? this.title,
      detail: detail ?? this.detail,
    );
  }
}

class DormRulesSettings {
  const DormRulesSettings({
    required this.quietHours,
    required this.specialCase,
    required this.lightsOffTime,
    required this.personalLighting,
    required this.examWeekMode,
    required this.blackoutCurtain,
    required this.vibrationFirst,
    required this.alarmResponseSeconds,
    required this.routineNote,
    required this.routineTags,
    required this.summerTempC,
    required this.winterTempC,
    required this.ventilationWindow,
    required this.ventilationMinutes,
  });

  factory DormRulesSettings.defaults() {
    return const DormRulesSettings(
      quietHours: '23:00 - 07:00',
      specialCase: '如果有临时讨论或紧急情况，请提前在宿舍群里说明。',
      lightsOffTime: '23:30 后关闭主灯',
      personalLighting: '仅使用个人台灯，避免灯光直射正在休息的室友。',
      examWeekMode: true,
      blackoutCurtain: true,
      vibrationFirst: true,
      alarmResponseSeconds: 60,
      routineNote: '平时起床时间约为 08:30，考试周可能会更早。',
      routineTags: <String>['考试周', '夜猫子', '早起党'],
      summerTempC: 26,
      winterTempC: 22,
      ventilationWindow: '早晨',
      ventilationMinutes: 30,
    );
  }

  final String quietHours;
  final String specialCase;
  final String lightsOffTime;
  final String personalLighting;
  final bool examWeekMode;
  final bool blackoutCurtain;
  final bool vibrationFirst;
  final int alarmResponseSeconds;
  final String routineNote;
  final List<String> routineTags;
  final double summerTempC;
  final double winterTempC;
  final String ventilationWindow;
  final double ventilationMinutes;

  DormRulesSettings copyWith({
    String? quietHours,
    String? specialCase,
    String? lightsOffTime,
    String? personalLighting,
    bool? examWeekMode,
    bool? blackoutCurtain,
    bool? vibrationFirst,
    int? alarmResponseSeconds,
    String? routineNote,
    List<String>? routineTags,
    double? summerTempC,
    double? winterTempC,
    String? ventilationWindow,
    double? ventilationMinutes,
  }) {
    return DormRulesSettings(
      quietHours: quietHours ?? this.quietHours,
      specialCase: specialCase ?? this.specialCase,
      lightsOffTime: lightsOffTime ?? this.lightsOffTime,
      personalLighting: personalLighting ?? this.personalLighting,
      examWeekMode: examWeekMode ?? this.examWeekMode,
      blackoutCurtain: blackoutCurtain ?? this.blackoutCurtain,
      vibrationFirst: vibrationFirst ?? this.vibrationFirst,
      alarmResponseSeconds: alarmResponseSeconds ?? this.alarmResponseSeconds,
      routineNote: routineNote ?? this.routineNote,
      routineTags: routineTags ?? this.routineTags,
      summerTempC: summerTempC ?? this.summerTempC,
      winterTempC: winterTempC ?? this.winterTempC,
      ventilationWindow: ventilationWindow ?? this.ventilationWindow,
      ventilationMinutes: ventilationMinutes ?? this.ventilationMinutes,
    );
  }
}

class DormPendingRuleProposal {
  const DormPendingRuleProposal({
    required this.id,
    required this.proposedSettings,
    required this.proposedRules,
    required this.proposerUid,
    required this.proposerName,
    required this.createdAt,
    required this.reviewerUids,
    required this.approvedUids,
    this.rejectedByUid,
    this.rejectedReason,
    this.resolvedAt,
  });

  final String id;
  final DormRulesSettings proposedSettings;
  final List<DormRule> proposedRules;
  final String proposerUid;
  final String proposerName;
  final DateTime createdAt;
  final List<String> reviewerUids;
  final List<String> approvedUids;
  final String? rejectedByUid;
  final String? rejectedReason;
  final DateTime? resolvedAt;

  List<String> pendingReviewerUids() {
    return reviewerUids
        .where((String uid) => !approvedUids.contains(uid))
        .toList(growable: false);
  }

  bool needsReviewFrom(String uid) {
    return reviewerUids.contains(uid) && !approvedUids.contains(uid);
  }

  DormPendingRuleProposal copyWith({
    String? id,
    DormRulesSettings? proposedSettings,
    List<DormRule>? proposedRules,
    String? proposerUid,
    String? proposerName,
    DateTime? createdAt,
    List<String>? reviewerUids,
    List<String>? approvedUids,
    String? rejectedByUid,
    String? rejectedReason,
    DateTime? resolvedAt,
    bool clearRejectedByUid = false,
    bool clearRejectedReason = false,
    bool clearResolvedAt = false,
  }) {
    return DormPendingRuleProposal(
      id: id ?? this.id,
      proposedSettings: proposedSettings ?? this.proposedSettings,
      proposedRules: proposedRules ?? this.proposedRules,
      proposerUid: proposerUid ?? this.proposerUid,
      proposerName: proposerName ?? this.proposerName,
      createdAt: createdAt ?? this.createdAt,
      reviewerUids: reviewerUids ?? this.reviewerUids,
      approvedUids: approvedUids ?? this.approvedUids,
      rejectedByUid: clearRejectedByUid
          ? null
          : rejectedByUid ?? this.rejectedByUid,
      rejectedReason: clearRejectedReason
          ? null
          : rejectedReason ?? this.rejectedReason,
      resolvedAt: clearResolvedAt ? null : resolvedAt ?? this.resolvedAt,
    );
  }
}

class DormMember {
  const DormMember({
    required this.uid,
    required this.name,
    required this.status,
    required this.presenceStatus,
    required this.sleepModeActive,
    required this.lastActiveAt,
    required this.note,
    this.avatarUrl,
    this.displayBadgeId,
    this.noiseDb,
  });

  final String uid;
  final String name;
  final DormMemberStatus status;
  final DormPresenceStatus presenceStatus;
  final bool sleepModeActive;
  final DateTime lastActiveAt;
  final String note;
  final String? avatarUrl;
  final String? displayBadgeId;

  /// Latest microphone noise level reported for this member (dB), if any.
  final int? noiseDb;

  DormMember copyWith({
    String? uid,
    String? name,
    DormMemberStatus? status,
    DormPresenceStatus? presenceStatus,
    bool? sleepModeActive,
    DateTime? lastActiveAt,
    String? note,
    String? avatarUrl,
    String? displayBadgeId,
    int? noiseDb,
    bool clearNoiseDb = false,
  }) {
    return DormMember(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      status: status ?? this.status,
      presenceStatus: presenceStatus ?? this.presenceStatus,
      sleepModeActive: sleepModeActive ?? this.sleepModeActive,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      note: note ?? this.note,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      displayBadgeId: displayBadgeId ?? this.displayBadgeId,
      noiseDb: clearNoiseDb ? null : (noiseDb ?? this.noiseDb),
    );
  }
}

class DormLocationAnchor {
  const DormLocationAnchor({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.recordedAt,
    required this.recordedByUid,
  });

  final double latitude;
  final double longitude;
  final double radiusMeters;
  final DateTime recordedAt;
  final String recordedByUid;

  DormLocationAnchor copyWith({
    double? latitude,
    double? longitude,
    double? radiusMeters,
    DateTime? recordedAt,
    String? recordedByUid,
  }) {
    return DormLocationAnchor(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      recordedAt: recordedAt ?? this.recordedAt,
      recordedByUid: recordedByUid ?? this.recordedByUid,
    );
  }
}

class DormEvent {
  const DormEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.detail,
    required this.createdAt,
    this.actorUid,
  });

  final String id;
  final DormEventType type;
  final String title;
  final String detail;
  final DateTime createdAt;
  final String? actorUid;

  DormEvent copyWith({
    String? id,
    DormEventType? type,
    String? title,
    String? detail,
    DateTime? createdAt,
    String? actorUid,
  }) {
    return DormEvent(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      createdAt: createdAt ?? this.createdAt,
      actorUid: actorUid ?? this.actorUid,
    );
  }
}

class DormInvite {
  const DormInvite({
    required this.id,
    required this.dormId,
    required this.code,
    required this.createdByUid,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    this.acceptedByUid,
    this.acceptedAt,
  });

  final String id;
  final String dormId;
  final String code;
  final String createdByUid;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DormInviteStatus status;
  final String? acceptedByUid;
  final DateTime? acceptedAt;

  DormInvite copyWith({
    String? id,
    String? dormId,
    String? code,
    String? createdByUid,
    DateTime? createdAt,
    DateTime? expiresAt,
    DormInviteStatus? status,
    String? acceptedByUid,
    DateTime? acceptedAt,
  }) {
    return DormInvite(
      id: id ?? this.id,
      dormId: dormId ?? this.dormId,
      code: code ?? this.code,
      createdByUid: createdByUid ?? this.createdByUid,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
      acceptedByUid: acceptedByUid ?? this.acceptedByUid,
      acceptedAt: acceptedAt ?? this.acceptedAt,
    );
  }
}

class Dorm {
  const Dorm({
    required this.id,
    required this.name,
    required this.overview,
    required this.noiseDb,
    required this.lightLabel,
    required this.quietLabel,
    required this.rules,
    required this.members,
    this.status = DormStatus.active,
    this.archivedAt,
    this.locationAnchor,
    this.rulesSettings = const DormRulesSettings(
      quietHours: '23:00 - 07:00',
      specialCase: '如果有临时讨论或紧急情况，请提前在宿舍群里说明。',
      lightsOffTime: '23:30 后关闭主灯',
      personalLighting: '仅使用个人台灯，避免灯光直射正在休息的室友。',
      examWeekMode: true,
      blackoutCurtain: true,
      vibrationFirst: true,
      alarmResponseSeconds: 60,
      routineNote: '平时起床时间约为 08:30，考试周可能会更早。',
      routineTags: <String>['考试周', '夜猫子', '早起党'],
      summerTempC: 26,
      winterTempC: 22,
      ventilationWindow: '早晨',
      ventilationMinutes: 30,
    ),
    this.events = const <DormEvent>[],
    this.invites = const <DormInvite>[],
    this.pendingRuleProposal,
    this.earnedDormBadgeIds = const <String>['no-trouble-room', 'no-wake-room'],
  });

  final String id;
  final String name;
  final String overview;
  final int noiseDb;
  final String lightLabel;
  final String quietLabel;
  final List<DormRule> rules;
  final List<DormMember> members;
  final DormStatus status;
  final DateTime? archivedAt;
  final DormLocationAnchor? locationAnchor;
  final DormRulesSettings rulesSettings;
  final List<DormEvent> events;
  final List<DormInvite> invites;
  final DormPendingRuleProposal? pendingRuleProposal;
  final List<String> earnedDormBadgeIds;

  bool get hasPendingRuleProposal => pendingRuleProposal != null;

  String? get latestEarnedDormBadgeId =>
      earnedDormBadgeIds.isEmpty ? null : earnedDormBadgeIds.last;

  bool hasEarnedDormBadge(String badgeId) =>
      earnedDormBadgeIds.contains(badgeId);

  Dorm copyWith({
    String? id,
    String? name,
    String? overview,
    int? noiseDb,
    String? lightLabel,
    String? quietLabel,
    List<DormRule>? rules,
    List<DormMember>? members,
    DormStatus? status,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    DormLocationAnchor? locationAnchor,
    bool clearLocationAnchor = false,
    DormRulesSettings? rulesSettings,
    List<DormEvent>? events,
    List<DormInvite>? invites,
    DormPendingRuleProposal? pendingRuleProposal,
    List<String>? earnedDormBadgeIds,
    bool clearPendingRuleProposal = false,
  }) {
    return Dorm(
      id: id ?? this.id,
      name: name ?? this.name,
      overview: overview ?? this.overview,
      noiseDb: noiseDb ?? this.noiseDb,
      lightLabel: lightLabel ?? this.lightLabel,
      quietLabel: quietLabel ?? this.quietLabel,
      rules: rules ?? this.rules,
      members: members ?? this.members,
      status: status ?? this.status,
      archivedAt: clearArchivedAt ? null : archivedAt ?? this.archivedAt,
      locationAnchor: clearLocationAnchor
          ? null
          : locationAnchor ?? this.locationAnchor,
      rulesSettings: rulesSettings ?? this.rulesSettings,
      events: events ?? this.events,
      invites: invites ?? this.invites,
      earnedDormBadgeIds: earnedDormBadgeIds ?? this.earnedDormBadgeIds,
      pendingRuleProposal: clearPendingRuleProposal
          ? null
          : pendingRuleProposal ?? this.pendingRuleProposal,
    );
  }
}

class DreamEntry {
  const DreamEntry({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.tags,
    required this.createdAt,
    this.emotionLabel,
    this.sessionId,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final List<String> tags;
  final DateTime createdAt;
  final String? emotionLabel;
  final String? sessionId;

  DreamEntry copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    List<String>? tags,
    DateTime? createdAt,
    String? emotionLabel,
    String? sessionId,
  }) {
    return DreamEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      emotionLabel: emotionLabel ?? this.emotionLabel,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}

class SleepCaptureRecord {
  const SleepCaptureRecord({
    required this.id,
    required this.type,
    required this.sessionId,
    required this.createdAt,
    required this.title,
    required this.outline,
    required this.content,
  });

  final String id;
  final SleepCaptureType type;
  final String sessionId;
  final DateTime createdAt;
  final String title;
  final String outline;
  final String content;
}

class PendingSleepMemoBanner {
  const PendingSleepMemoBanner({
    required this.title,
    required this.subtitle,
    required this.groups,
    required this.createdAt,
  });

  final String title;
  final String subtitle;
  final List<PendingSleepMemoGroup> groups;
  final DateTime createdAt;
}

class PendingSleepMemoGroup {
  const PendingSleepMemoGroup({
    required this.sessionId,
    required this.label,
    required this.items,
    required this.isCarryover,
  });

  final String sessionId;
  final String label;
  final List<String> items;
  final bool isCarryover;
}

class SleepInsight {
  const SleepInsight({
    required this.id,
    required this.category,
    required this.title,
    required this.summary,
    required this.metricLabel,
    required this.createdAt,
  });

  final String id;
  final InsightCategory category;
  final String title;
  final String summary;
  final String metricLabel;
  final DateTime createdAt;

  SleepInsight copyWith({
    String? id,
    InsightCategory? category,
    String? title,
    String? summary,
    String? metricLabel,
    DateTime? createdAt,
  }) {
    return SleepInsight(
      id: id ?? this.id,
      category: category ?? this.category,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      metricLabel: metricLabel ?? this.metricLabel,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SleepReport {
  const SleepReport({
    required this.title,
    required this.averageSleepHours,
    required this.averageSleepQuality,
    required this.averageRestedLevel,
    required this.calmNights,
    required this.dreamEntriesCount,
    required this.highlights,
    required this.generatedAt,
  });

  final String title;
  final double averageSleepHours;
  final double averageSleepQuality;
  final double averageRestedLevel;
  final int calmNights;
  final int dreamEntriesCount;
  final List<String> highlights;
  final DateTime generatedAt;

  SleepReport copyWith({
    String? title,
    double? averageSleepHours,
    double? averageSleepQuality,
    double? averageRestedLevel,
    int? calmNights,
    int? dreamEntriesCount,
    List<String>? highlights,
    DateTime? generatedAt,
  }) {
    return SleepReport(
      title: title ?? this.title,
      averageSleepHours: averageSleepHours ?? this.averageSleepHours,
      averageSleepQuality: averageSleepQuality ?? this.averageSleepQuality,
      averageRestedLevel: averageRestedLevel ?? this.averageRestedLevel,
      calmNights: calmNights ?? this.calmNights,
      dreamEntriesCount: dreamEntriesCount ?? this.dreamEntriesCount,
      highlights: highlights ?? this.highlights,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }
}

class InterferenceFactorSnapshot {
  const InterferenceFactorSnapshot({
    required this.type,
    required this.title,
    required this.value,
    required this.gradeLabel,
    required this.status,
    required this.detail,
    required this.source,
    this.measuredAt,
    this.numericValue,
    this.score,
  });

  final InterferenceFactorType type;
  final String title;
  final String value;
  final String gradeLabel;
  final InterferenceFactorStatus status;
  final String detail;
  final String source;
  final DateTime? measuredAt;
  final double? numericValue;
  final int? score;

  bool get isFresh {
    if (measuredAt == null) {
      return false;
    }
    return DateTime.now().difference(measuredAt!) < const Duration(minutes: 15);
  }

  InterferenceFactorSnapshot copyWith({
    InterferenceFactorType? type,
    String? title,
    String? value,
    String? gradeLabel,
    InterferenceFactorStatus? status,
    String? detail,
    String? source,
    DateTime? measuredAt,
    bool clearMeasuredAt = false,
    double? numericValue,
    bool clearNumericValue = false,
    int? score,
    bool clearScore = false,
  }) {
    return InterferenceFactorSnapshot(
      type: type ?? this.type,
      title: title ?? this.title,
      value: value ?? this.value,
      gradeLabel: gradeLabel ?? this.gradeLabel,
      status: status ?? this.status,
      detail: detail ?? this.detail,
      source: source ?? this.source,
      measuredAt: clearMeasuredAt ? null : measuredAt ?? this.measuredAt,
      numericValue: clearNumericValue
          ? null
          : numericValue ?? this.numericValue,
      score: clearScore ? null : score ?? this.score,
    );
  }
}

class TonightInterferenceState {
  const TonightInterferenceState({
    required this.noise,
    required this.light,
    required this.phoneUsage,
    required this.emotion,
    required this.updatedAt,
  });

  final InterferenceFactorSnapshot noise;
  final InterferenceFactorSnapshot light;
  final InterferenceFactorSnapshot phoneUsage;
  final InterferenceFactorSnapshot emotion;
  final DateTime updatedAt;

  InterferenceFactorSnapshot factorOf(InterferenceFactorType type) {
    return switch (type) {
      InterferenceFactorType.noise => noise,
      InterferenceFactorType.light => light,
      InterferenceFactorType.phoneUsage => phoneUsage,
      InterferenceFactorType.emotion => emotion,
    };
  }

  List<InterferenceFactorSnapshot> get factors => <InterferenceFactorSnapshot>[
    noise,
    light,
    phoneUsage,
    emotion,
  ];

  TonightInterferenceState replaceFactor(InterferenceFactorSnapshot factor) {
    return switch (factor.type) {
      InterferenceFactorType.noise => copyWith(noise: factor),
      InterferenceFactorType.light => copyWith(light: factor),
      InterferenceFactorType.phoneUsage => copyWith(phoneUsage: factor),
      InterferenceFactorType.emotion => copyWith(emotion: factor),
    };
  }

  TonightInterferenceState copyWith({
    InterferenceFactorSnapshot? noise,
    InterferenceFactorSnapshot? light,
    InterferenceFactorSnapshot? phoneUsage,
    InterferenceFactorSnapshot? emotion,
    DateTime? updatedAt,
  }) {
    return TonightInterferenceState(
      noise: noise ?? this.noise,
      light: light ?? this.light,
      phoneUsage: phoneUsage ?? this.phoneUsage,
      emotion: emotion ?? this.emotion,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AssistantProfile {
  const AssistantProfile({
    required this.userId,
    required this.assistantName,
    required this.identityPrompt,
    required this.tone,
    required this.relationshipRole,
    required this.updatedAt,
  });

  final String userId;
  final String assistantName;
  final String identityPrompt;
  final String tone;
  final String relationshipRole;
  final DateTime updatedAt;

  AssistantProfile copyWith({
    String? userId,
    String? assistantName,
    String? identityPrompt,
    String? tone,
    String? relationshipRole,
    DateTime? updatedAt,
  }) {
    return AssistantProfile(
      userId: userId ?? this.userId,
      assistantName: assistantName ?? this.assistantName,
      identityPrompt: identityPrompt ?? this.identityPrompt,
      tone: tone ?? this.tone,
      relationshipRole: relationshipRole ?? this.relationshipRole,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AssistantThread {
  const AssistantThread({
    required this.id,
    required this.userId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  AssistantThread copyWith({
    String? id,
    String? userId,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AssistantThread(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AssistantMessage {
  const AssistantMessage({
    required this.id,
    required this.threadId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.status = AssistantMessageStatus.complete,
    this.sourceMode,
    this.provider,
    this.model,
    this.errorMessage,
  });

  final String id;
  final String threadId;
  final AssistantMessageRole role;
  final String content;
  final DateTime createdAt;
  final AssistantMessageStatus status;
  final AssistantReplySourceMode? sourceMode;
  final String? provider;
  final String? model;
  final String? errorMessage;

  bool get fromAssistant => role == AssistantMessageRole.assistant;

  AssistantMessage copyWith({
    String? id,
    String? threadId,
    AssistantMessageRole? role,
    String? content,
    DateTime? createdAt,
    AssistantMessageStatus? status,
    AssistantReplySourceMode? sourceMode,
    String? provider,
    String? model,
    String? errorMessage,
  }) {
    return AssistantMessage(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      sourceMode: sourceMode ?? this.sourceMode,
      provider: provider ?? this.provider,
      model: model ?? this.model,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
