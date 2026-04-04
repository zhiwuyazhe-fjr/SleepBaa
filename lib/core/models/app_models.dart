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

enum PlaybackState { stopped, playing, paused, completed }

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.tagline,
    required this.role,
    this.dormId,
    this.avatarPath,
    this.avatarBytes,
    this.avatarFallbackSeed,
  });

  final String uid;
  final String displayName;
  final String tagline;
  final String role;
  final String? dormId;
  final String? avatarPath;
  final Uint8List? avatarBytes;
  final String? avatarFallbackSeed;

  UserProfile copyWith({
    String? uid,
    String? displayName,
    String? tagline,
    String? role,
    String? dormId,
    String? avatarPath,
    Uint8List? avatarBytes,
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
}

class SleepSession {
  const SleepSession({
    required this.id,
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
  });

  final String id;
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

  SleepSession copyWith({
    String? id,
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
  }) {
    return SleepSession(
      id: id ?? this.id,
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
  });

  final String id;
  final NotificationCategory category;
  final String title;
  final String body;
  final DateTime createdAt;
  final String route;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  NotificationItem copyWith({
    String? id,
    NotificationCategory? category,
    String? title,
    String? body,
    DateTime? createdAt,
    String? route,
    DateTime? readAt,
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
    );
  }
}

class DormRule {
  const DormRule({required this.title, required this.detail});

  final String title;
  final String detail;
}

class DormMember {
  const DormMember({
    required this.uid,
    required this.name,
    required this.status,
    required this.sleepModeActive,
    required this.lastActiveAt,
    required this.note,
  });

  final String uid;
  final String name;
  final DormMemberStatus status;
  final bool sleepModeActive;
  final DateTime lastActiveAt;
  final String note;

  DormMember copyWith({
    String? uid,
    String? name,
    DormMemberStatus? status,
    bool? sleepModeActive,
    DateTime? lastActiveAt,
    String? note,
  }) {
    return DormMember(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      status: status ?? this.status,
      sleepModeActive: sleepModeActive ?? this.sleepModeActive,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      note: note ?? this.note,
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
  });

  final String id;
  final String name;
  final String overview;
  final int noiseDb;
  final String lightLabel;
  final String quietLabel;
  final List<DormRule> rules;
  final List<DormMember> members;

  Dorm copyWith({
    String? id,
    String? name,
    String? overview,
    int? noiseDb,
    String? lightLabel,
    String? quietLabel,
    List<DormRule>? rules,
    List<DormMember>? members,
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
    );
  }
}
