import 'dart:typed_data';

import 'package:flutter/material.dart';

enum HomeMode { preSleep, postSleep }

enum NightMood { happy, sad, calm }

enum RecommendationType { audio, quickAction }

enum RecommendationExecutionState { idle, selected, playing, completed }

enum RecommendationFeedbackStatus { effective, neutral, ineffective, skipped }

enum SleepSessionStatus { drafted, active, awaitingFeedback, completed }

enum NotificationCategory { reminder, session, dorm, system }

enum DormMemberStatus { sleeping, quiet, away, active }

enum DormEventType { memberStatus, ruleUpdate, notification, invite, system }

enum DormInviteStatus { pending, accepted, expired, revoked }

enum PlaybackState { stopped, playing, paused, completed }

enum InsightCategory { interference, report, recommendation, trend }

enum AssistantMessageRole { user, assistant, system }

enum AssistantMessageStatus { pending, complete, error }

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.tagline,
    required this.role,
    this.dormId,
    this.avatarPath,
    this.avatarBytes,
    this.avatarUrl,
    this.avatarFallbackSeed,
  });

  final String uid;
  final String displayName;
  final String tagline;
  final String role;
  final String? dormId;
  final String? avatarPath;
  final Uint8List? avatarBytes;
  final String? avatarUrl;
  final String? avatarFallbackSeed;

  UserProfile copyWith({
    String? uid,
    String? displayName,
    String? tagline,
    String? role,
    String? dormId,
    String? avatarPath,
    Uint8List? avatarBytes,
    String? avatarUrl,
    bool clearAvatar = false,
    String? avatarFallbackSeed,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      tagline: tagline ?? this.tagline,
      role: role ?? this.role,
      dormId: dormId ?? this.dormId,
      avatarPath: clearAvatar ? null : avatarPath ?? this.avatarPath,
      avatarBytes: clearAvatar ? null : avatarBytes ?? this.avatarBytes,
      avatarUrl: clearAvatar ? null : avatarUrl ?? this.avatarUrl,
      avatarFallbackSeed:
          avatarFallbackSeed ?? this.avatarFallbackSeed ?? this.displayName,
    );
  }
}

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
  });

  final double sleepGoalHours;
  final bool bedtimeReminderEnabled;
  final bool morningReminderEnabled;
  final bool dormAlertsEnabled;
  final TimeOfDay bedtimeReminder;
  final String preferredTrackTitle;
  final bool smartSuggestionsEnabled;
  final NightMood? selectedNightMood;

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
    );
  }
}

class AudioTrack {
  const AudioTrack({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.duration,
  });

  final String id;
  final String title;
  final String subtitle;
  final Duration duration;

  AudioTrack copyWith({
    String? id,
    String? title,
    String? subtitle,
    Duration? duration,
  }) {
    return AudioTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      duration: duration ?? this.duration,
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

class SleepSession {
  const SleepSession({
    required this.id,
    this.uid = 'anon-paul',
    required this.startedAt,
    required this.endedAt,
    required this.status,
    required this.sleepModeActive,
    required this.dormId,
    required this.recommendations,
    required this.selectedRecommendationIds,
    required this.awakenings,
    required this.feedback,
    required this.summary,
    this.updatedAt,
  });

  final String id;
  final String uid;
  final DateTime startedAt;
  final DateTime? endedAt;
  final SleepSessionStatus status;
  final bool sleepModeActive;
  final String? dormId;
  final List<NightRecommendation> recommendations;
  final List<String> selectedRecommendationIds;
  final List<NightAwakeningEntry> awakenings;
  final List<RecommendationFeedback> feedback;
  final MorningSummary? summary;
  final DateTime? updatedAt;

  SleepSession copyWith({
    String? id,
    String? uid,
    DateTime? startedAt,
    DateTime? endedAt,
    bool clearEndedAt = false,
    SleepSessionStatus? status,
    bool? sleepModeActive,
    String? dormId,
    List<NightRecommendation>? recommendations,
    List<String>? selectedRecommendationIds,
    List<NightAwakeningEntry>? awakenings,
    List<RecommendationFeedback>? feedback,
    MorningSummary? summary,
    bool clearSummary = false,
    DateTime? updatedAt,
  }) {
    return SleepSession(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      startedAt: startedAt ?? this.startedAt,
      endedAt: clearEndedAt ? null : endedAt ?? this.endedAt,
      status: status ?? this.status,
      sleepModeActive: sleepModeActive ?? this.sleepModeActive,
      dormId: dormId ?? this.dormId,
      recommendations: recommendations ?? this.recommendations,
      selectedRecommendationIds:
          selectedRecommendationIds ?? this.selectedRecommendationIds,
      awakenings: awakenings ?? this.awakenings,
      feedback: feedback ?? this.feedback,
      summary: clearSummary ? null : summary ?? this.summary,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
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

class DormRule {
  const DormRule({
    this.id = '',
    required this.title,
    required this.detail,
  });

  final String id;
  final String title;
  final String detail;

  DormRule copyWith({
    String? id,
    String? title,
    String? detail,
  }) {
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
      specialCase:
          '如果有临时讨论或紧急情况，请提前在宿舍群里说明。',
      lightsOffTime: '23:30 后关闭主灯',
      personalLighting:
          '仅使用个人台灯，避免灯光直射正在休息的室友。',
      examWeekMode: true,
      blackoutCurtain: true,
      vibrationFirst: true,
      alarmResponseSeconds: 60,
      routineNote:
          '平时起床时间约为 08:30，考试周可能会更早。',
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
      alarmResponseSeconds:
          alarmResponseSeconds ?? this.alarmResponseSeconds,
      routineNote: routineNote ?? this.routineNote,
      routineTags: routineTags ?? this.routineTags,
      summerTempC: summerTempC ?? this.summerTempC,
      winterTempC: winterTempC ?? this.winterTempC,
      ventilationWindow: ventilationWindow ?? this.ventilationWindow,
      ventilationMinutes: ventilationMinutes ?? this.ventilationMinutes,
    );
  }
}

class DormMember {
  const DormMember({
    required this.uid,
    required this.name,
    required this.status,
    required this.sleepModeActive,
    required this.lastActiveAt,
    required this.note,
    this.avatarUrl,
  });

  final String uid;
  final String name;
  final DormMemberStatus status;
  final bool sleepModeActive;
  final DateTime lastActiveAt;
  final String note;
  final String? avatarUrl;

  DormMember copyWith({
    String? uid,
    String? name,
    DormMemberStatus? status,
    bool? sleepModeActive,
    DateTime? lastActiveAt,
    String? note,
    String? avatarUrl,
  }) {
    return DormMember(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      status: status ?? this.status,
      sleepModeActive: sleepModeActive ?? this.sleepModeActive,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      note: note ?? this.note,
      avatarUrl: avatarUrl ?? this.avatarUrl,
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
  });

  final String id;
  final String name;
  final String overview;
  final int noiseDb;
  final String lightLabel;
  final String quietLabel;
  final List<DormRule> rules;
  final List<DormMember> members;
  final DormRulesSettings rulesSettings;
  final List<DormEvent> events;
  final List<DormInvite> invites;

  Dorm copyWith({
    String? id,
    String? name,
    String? overview,
    int? noiseDb,
    String? lightLabel,
    String? quietLabel,
    List<DormRule>? rules,
    List<DormMember>? members,
    DormRulesSettings? rulesSettings,
    List<DormEvent>? events,
    List<DormInvite>? invites,
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
      rulesSettings: rulesSettings ?? this.rulesSettings,
      events: events ?? this.events,
      invites: invites ?? this.invites,
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
      averageSleepQuality:
          averageSleepQuality ?? this.averageSleepQuality,
      averageRestedLevel: averageRestedLevel ?? this.averageRestedLevel,
      calmNights: calmNights ?? this.calmNights,
      dreamEntriesCount: dreamEntriesCount ?? this.dreamEntriesCount,
      highlights: highlights ?? this.highlights,
      generatedAt: generatedAt ?? this.generatedAt,
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
  });

  final String id;
  final String threadId;
  final AssistantMessageRole role;
  final String content;
  final DateTime createdAt;
  final AssistantMessageStatus status;

  bool get fromAssistant => role == AssistantMessageRole.assistant;

  AssistantMessage copyWith({
    String? id,
    String? threadId,
    AssistantMessageRole? role,
    String? content,
    DateTime? createdAt,
    AssistantMessageStatus? status,
  }) {
    return AssistantMessage(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }
}
