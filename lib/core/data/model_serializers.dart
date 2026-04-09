import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

abstract final class ModelSerializers {
  static Map<String, dynamic> userProfileToMap(UserProfile profile) {
    return <String, dynamic>{
      'uid': profile.uid,
      'displayName': profile.displayName,
      'tagline': profile.tagline,
      'role': profile.role,
      'dormId': profile.dormId,
      'phoneNumber': profile.phoneNumber,
      'phoneLinkedAt': profile.phoneLinkedAt?.toIso8601String(),
      'avatarPath': profile.avatarPath,
      'avatarUrl': profile.avatarUrl,
      'avatarStoragePath': profile.avatarStoragePath,
      'avatarFallbackSeed': profile.avatarFallbackSeed,
    };
  }

  static UserProfile userProfileFromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      tagline: map['tagline'] as String? ?? '',
      role: map['role'] as String? ?? '',
      dormId: map['dormId'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      phoneLinkedAt: _dateValue(map['phoneLinkedAt']),
      avatarPath: map['avatarPath'] as String?,
      avatarUrl: map['avatarUrl'] as String?,
      avatarStoragePath: map['avatarStoragePath'] as String?,
      avatarFallbackSeed: map['avatarFallbackSeed'] as String?,
    );
  }

  static Map<String, dynamic> userSettingsToMap(UserSettings settings) {
    return <String, dynamic>{
      'sleepGoalHours': settings.sleepGoalHours,
      'bedtimeReminderEnabled': settings.bedtimeReminderEnabled,
      'morningReminderEnabled': settings.morningReminderEnabled,
      'dormAlertsEnabled': settings.dormAlertsEnabled,
      'bedtimeReminder': timeOfDayToMap(settings.bedtimeReminder),
      'preferredTrackTitle': settings.preferredTrackTitle,
      'smartSuggestionsEnabled': settings.smartSuggestionsEnabled,
      'selectedNightMood': settings.selectedNightMood?.name,
    };
  }

  static UserSettings userSettingsFromMap(Map<String, dynamic> map) {
    return UserSettings(
      sleepGoalHours: (map['sleepGoalHours'] as num?)?.toDouble() ?? 7.5,
      bedtimeReminderEnabled:
          map['bedtimeReminderEnabled'] as bool? ?? true,
      morningReminderEnabled:
          map['morningReminderEnabled'] as bool? ?? true,
      dormAlertsEnabled: map['dormAlertsEnabled'] as bool? ?? true,
      bedtimeReminder: timeOfDayFromMap(
        map['bedtimeReminder'] as Map<String, dynamic>? ??
            <String, dynamic>{'hour': 23, 'minute': 10},
      ),
      preferredTrackTitle:
          map['preferredTrackTitle'] as String? ?? '深海海浪',
      smartSuggestionsEnabled:
          map['smartSuggestionsEnabled'] as bool? ?? true,
      selectedNightMood: _nightMoodFromName(map['selectedNightMood'] as String?),
    );
  }

  static Map<String, dynamic> sleepSessionToMap(SleepSession session) {
    return <String, dynamic>{
      'id': session.id,
      'uid': session.uid,
      'startedAt': session.startedAt,
      'endedAt': session.endedAt,
      'status': session.status.name,
      'sleepModeActive': session.sleepModeActive,
      'dormId': session.dormId,
      'recommendations': session.recommendations
          .map(recommendationToMap)
          .toList(growable: false),
      'selectedRecommendationIds': session.selectedRecommendationIds,
      'awakenings': session.awakenings.map(awakeningToMap).toList(growable: false),
      'feedback': session.feedback.map(recommendationFeedbackToMap).toList(growable: false),
      'summary': session.summary == null ? null : morningSummaryToMap(session.summary!),
      'updatedAt': session.updatedAt,
    };
  }

  static SleepSession sleepSessionFromMap(Map<String, dynamic> map) {
    return SleepSession(
      id: map['id'] as String? ?? '',
      uid: map['uid'] as String? ?? 'anon-paul',
      startedAt: _dateValue(map['startedAt']) ?? DateTime.now(),
      endedAt: _dateValue(map['endedAt']),
      status: _sleepStatusFromName(map['status'] as String?) ??
          SleepSessionStatus.drafted,
      sleepModeActive: map['sleepModeActive'] as bool? ?? false,
      dormId: map['dormId'] as String?,
      recommendations: (map['recommendations'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (dynamic item) => recommendationFromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      selectedRecommendationIds: (map['selectedRecommendationIds'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      awakenings: (map['awakenings'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (dynamic item) => awakeningFromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      feedback: (map['feedback'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (dynamic item) => recommendationFeedbackFromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      summary: map['summary'] == null
          ? null
          : morningSummaryFromMap(
              Map<String, dynamic>.from(map['summary'] as Map),
            ),
      updatedAt: _dateValue(map['updatedAt']),
    );
  }

  static Map<String, dynamic> recommendationToMap(NightRecommendation item) {
    return <String, dynamic>{
      'id': item.id,
      'title': item.title,
      'subtitle': item.subtitle,
      'type': item.type.name,
      'icon': iconDataToMap(item.icon),
      'tags': item.tags,
      'executionState': item.executionState.name,
      'track': item.track == null ? null : audioTrackToMap(item.track!),
    };
  }

  static NightRecommendation recommendationFromMap(Map<String, dynamic> map) {
    return NightRecommendation(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String? ?? '',
      type: _recommendationTypeFromName(map['type'] as String?) ??
          RecommendationType.quickAction,
      icon: iconDataFromMap(Map<String, dynamic>.from(map['icon'] as Map? ?? const <String, dynamic>{})),
      tags: (map['tags'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      executionState: _recommendationStateFromName(
            map['executionState'] as String?,
          ) ??
          RecommendationExecutionState.idle,
      track: map['track'] == null
          ? null
          : audioTrackFromMap(Map<String, dynamic>.from(map['track'] as Map)),
    );
  }

  static Map<String, dynamic> audioTrackToMap(AudioTrack track) {
    return <String, dynamic>{
      'id': track.id,
      'title': track.title,
      'subtitle': track.subtitle,
      'durationSeconds': track.duration.inSeconds,
    };
  }

  static AudioTrack audioTrackFromMap(Map<String, dynamic> map) {
    return AudioTrack(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String? ?? '',
      duration: Duration(seconds: map['durationSeconds'] as int? ?? 0),
    );
  }

  static Map<String, dynamic> recommendationFeedbackToMap(
    RecommendationFeedback feedback,
  ) {
    return <String, dynamic>{
      'recommendationId': feedback.recommendationId,
      'status': feedback.status.name,
      'note': feedback.note,
      'submittedAt': feedback.submittedAt,
    };
  }

  static RecommendationFeedback recommendationFeedbackFromMap(
    Map<String, dynamic> map,
  ) {
    return RecommendationFeedback(
      recommendationId: map['recommendationId'] as String? ?? '',
      status: _feedbackStatusFromName(map['status'] as String?) ??
          RecommendationFeedbackStatus.neutral,
      note: map['note'] as String? ?? '',
      submittedAt: _dateValue(map['submittedAt']) ?? DateTime.now(),
    );
  }

  static Map<String, dynamic> awakeningToMap(NightAwakeningEntry awakening) {
    return <String, dynamic>{
      'id': awakening.id,
      'occurredAt': awakening.occurredAt,
      'trigger': awakening.trigger,
      'minutesToSleep': awakening.minutesToSleep,
      'note': awakening.note,
    };
  }

  static NightAwakeningEntry awakeningFromMap(Map<String, dynamic> map) {
    return NightAwakeningEntry(
      id: map['id'] as String? ?? '',
      occurredAt: _dateValue(map['occurredAt']) ?? DateTime.now(),
      trigger: map['trigger'] as String? ?? '',
      minutesToSleep: map['minutesToSleep'] as int? ?? 0,
      note: map['note'] as String? ?? '',
    );
  }

  static Map<String, dynamic> morningSummaryToMap(MorningSummary summary) {
    return <String, dynamic>{
      'sleepQuality': summary.sleepQuality,
      'restedLevel': summary.restedLevel,
      'totalSleepHours': summary.totalSleepHours,
      'awakeningsCount': summary.awakeningsCount,
      'note': summary.note,
    };
  }

  static MorningSummary morningSummaryFromMap(Map<String, dynamic> map) {
    return MorningSummary(
      sleepQuality: map['sleepQuality'] as int? ?? 0,
      restedLevel: map['restedLevel'] as int? ?? 0,
      totalSleepHours: (map['totalSleepHours'] as num?)?.toDouble() ?? 0,
      awakeningsCount: map['awakeningsCount'] as int? ?? 0,
      note: map['note'] as String? ?? '',
    );
  }

  static Map<String, dynamic> dormRulesSettingsToMap(DormRulesSettings settings) {
    return <String, dynamic>{
      'quietHours': settings.quietHours,
      'specialCase': settings.specialCase,
      'lightsOffTime': settings.lightsOffTime,
      'personalLighting': settings.personalLighting,
      'examWeekMode': settings.examWeekMode,
      'blackoutCurtain': settings.blackoutCurtain,
      'vibrationFirst': settings.vibrationFirst,
      'alarmResponseSeconds': settings.alarmResponseSeconds,
      'routineNote': settings.routineNote,
      'routineTags': settings.routineTags,
      'summerTempC': settings.summerTempC,
      'winterTempC': settings.winterTempC,
      'ventilationWindow': settings.ventilationWindow,
      'ventilationMinutes': settings.ventilationMinutes,
    };
  }

  static DormRulesSettings dormRulesSettingsFromMap(Map<String, dynamic> map) {
    return DormRulesSettings(
      quietHours: map['quietHours'] as String? ?? '23:00 - 07:00',
      specialCase: map['specialCase'] as String? ?? '',
      lightsOffTime: map['lightsOffTime'] as String? ?? '',
      personalLighting: map['personalLighting'] as String? ?? '',
      examWeekMode: map['examWeekMode'] as bool? ?? true,
      blackoutCurtain: map['blackoutCurtain'] as bool? ?? true,
      vibrationFirst: map['vibrationFirst'] as bool? ?? true,
      alarmResponseSeconds: map['alarmResponseSeconds'] as int? ?? 60,
      routineNote: map['routineNote'] as String? ?? '',
      routineTags: (map['routineTags'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      summerTempC: (map['summerTempC'] as num?)?.toDouble() ?? 26,
      winterTempC: (map['winterTempC'] as num?)?.toDouble() ?? 22,
      ventilationWindow: map['ventilationWindow'] as String? ?? '早晨',
      ventilationMinutes:
          (map['ventilationMinutes'] as num?)?.toDouble() ?? 30,
    );
  }

  static Map<String, dynamic> dreamEntryToMap(DreamEntry entry) {
    return <String, dynamic>{
      'id': entry.id,
      'userId': entry.userId,
      'title': entry.title,
      'body': entry.body,
      'tags': entry.tags,
      'createdAt': entry.createdAt,
      'emotionLabel': entry.emotionLabel,
      'sessionId': entry.sessionId,
    };
  }

  static DreamEntry dreamEntryFromMap(Map<String, dynamic> map) {
    return DreamEntry(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      tags: (map['tags'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      createdAt: _dateValue(map['createdAt']) ?? DateTime.now(),
      emotionLabel: map['emotionLabel'] as String?,
      sessionId: map['sessionId'] as String?,
    );
  }

  static Map<String, dynamic> sleepCaptureRecordToMap(
    SleepCaptureRecord record,
  ) {
    return <String, dynamic>{
      'id': record.id,
      'type': record.type.name,
      'sessionId': record.sessionId,
      'createdAt': record.createdAt,
      'title': record.title,
      'outline': record.outline,
      'content': record.content,
    };
  }

  static SleepCaptureRecord sleepCaptureRecordFromMap(
    Map<String, dynamic> map,
  ) {
    return SleepCaptureRecord(
      id: map['id'] as String? ?? '',
      type: _sleepCaptureTypeFromName(map['type'] as String?) ??
          SleepCaptureType.memo,
      sessionId: map['sessionId'] as String? ?? '',
      createdAt: _dateValue(map['createdAt']) ?? DateTime.now(),
      title: map['title'] as String? ?? '',
      outline: map['outline'] as String? ?? '',
      content: map['content'] as String? ?? '',
    );
  }

  static Map<String, dynamic> pendingSleepMemoBannerToMap(
    PendingSleepMemoBanner banner,
  ) {
    return <String, dynamic>{
      'title': banner.title,
      'subtitle': banner.subtitle,
      'groups': banner.groups
          .map(pendingSleepMemoGroupToMap)
          .toList(growable: false),
      'createdAt': banner.createdAt,
    };
  }

  static PendingSleepMemoBanner pendingSleepMemoBannerFromMap(
    Map<String, dynamic> map,
  ) {
    return PendingSleepMemoBanner(
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String? ?? '',
      groups: (map['groups'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (dynamic item) => pendingSleepMemoGroupFromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      createdAt: _dateValue(map['createdAt']) ?? DateTime.now(),
    );
  }

  static Map<String, dynamic> pendingSleepMemoGroupToMap(
    PendingSleepMemoGroup group,
  ) {
    return <String, dynamic>{
      'sessionId': group.sessionId,
      'label': group.label,
      'items': group.items,
      'isCarryover': group.isCarryover,
    };
  }

  static PendingSleepMemoGroup pendingSleepMemoGroupFromMap(
    Map<String, dynamic> map,
  ) {
    return PendingSleepMemoGroup(
      sessionId: map['sessionId'] as String? ?? '',
      label: map['label'] as String? ?? '',
      items: (map['items'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      isCarryover: map['isCarryover'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> assistantThreadToMap(AssistantThread thread) {
    return <String, dynamic>{
      'id': thread.id,
      'userId': thread.userId,
      'title': thread.title,
      'createdAt': thread.createdAt,
      'updatedAt': thread.updatedAt,
    };
  }

  static AssistantThread assistantThreadFromMap(Map<String, dynamic> map) {
    return AssistantThread(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      createdAt: _dateValue(map['createdAt']) ?? DateTime.now(),
      updatedAt: _dateValue(map['updatedAt']) ?? DateTime.now(),
    );
  }

  static Map<String, dynamic> assistantProfileToMap(AssistantProfile profile) {
    return <String, dynamic>{
      'userId': profile.userId,
      'assistantName': profile.assistantName,
      'identityPrompt': profile.identityPrompt,
      'tone': profile.tone,
      'relationshipRole': profile.relationshipRole,
      'updatedAt': profile.updatedAt,
    };
  }

  static AssistantProfile assistantProfileFromMap(Map<String, dynamic> map) {
    return AssistantProfile(
      userId: map['userId'] as String? ?? '',
      assistantName: map['assistantName'] as String? ?? '小眠',
      identityPrompt:
          map['identityPrompt'] as String? ??
          '你是小眠，一位温和、低压、不评判的情绪陪伴型睡前助手。',
      tone: map['tone'] as String? ?? '温柔、稳定、共情',
      relationshipRole: map['relationshipRole'] as String? ?? '情绪陪伴助手',
      updatedAt: _dateValue(map['updatedAt']) ?? DateTime.now(),
    );
  }

  static Map<String, dynamic> assistantMessageToMap(AssistantMessage message) {
    return <String, dynamic>{
      'id': message.id,
      'threadId': message.threadId,
      'role': message.role.name,
      'content': message.content,
      'createdAt': message.createdAt,
      'status': message.status.name,
      'sourceMode': message.sourceMode?.name,
      'provider': message.provider,
      'model': message.model,
      'errorMessage': message.errorMessage,
    };
  }

  static AssistantMessage assistantMessageFromMap(Map<String, dynamic> map) {
    return AssistantMessage(
      id: map['id'] as String? ?? '',
      threadId: map['threadId'] as String? ?? '',
      role: _assistantRoleFromName(map['role'] as String?) ??
          AssistantMessageRole.system,
      content: map['content'] as String? ?? '',
      createdAt: _dateValue(map['createdAt']) ?? DateTime.now(),
      status: _assistantStatusFromName(map['status'] as String?) ??
          AssistantMessageStatus.complete,
      sourceMode: _assistantSourceModeFromName(map['sourceMode'] as String?),
      provider: map['provider'] as String?,
      model: map['model'] as String?,
      errorMessage: map['errorMessage'] as String?,
    );
  }

  static Map<String, dynamic> timeOfDayToMap(TimeOfDay time) {
    return <String, dynamic>{'hour': time.hour, 'minute': time.minute};
  }

  static TimeOfDay timeOfDayFromMap(Map<String, dynamic> map) {
    return TimeOfDay(
      hour: map['hour'] as int? ?? 0,
      minute: map['minute'] as int? ?? 0,
    );
  }

  static Map<String, dynamic> iconDataToMap(IconData icon) {
    return <String, dynamic>{
      'codePoint': icon.codePoint,
      'fontFamily': icon.fontFamily,
      'fontPackage': icon.fontPackage,
      'matchTextDirection': icon.matchTextDirection,
    };
  }

  static IconData iconDataFromMap(Map<String, dynamic> map) {
    return IconData(
      map['codePoint'] as int? ?? Icons.circle.codePoint,
      fontFamily: map['fontFamily'] as String? ?? Icons.circle.fontFamily,
      fontPackage: map['fontPackage'] as String?,
      matchTextDirection: map['matchTextDirection'] as bool? ?? false,
    );
  }

  static DateTime? _dateValue(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value.isUtc ? value.toLocal() : value;
    }
    if (value is Map) {
      final dynamic seconds = value['_seconds'] ?? value['seconds'];
      final dynamic nanoseconds = value['_nanoseconds'] ?? value['nanoseconds'];
      if (seconds is num) {
        final int millis = (seconds.toDouble() * 1000).round();
        final int extraMicros = nanoseconds is num
            ? (nanoseconds.toDouble() / 1000).round()
            : 0;
        return DateTime.fromMillisecondsSinceEpoch(
          millis,
          isUtc: true,
        ).add(Duration(microseconds: extraMicros)).toLocal();
      }
    }
    if (value is String) {
      final DateTime? parsed = DateTime.tryParse(value);
      if (parsed == null) {
        return null;
      }
      return parsed.isUtc ? parsed.toLocal() : parsed;
    }
    return null;
  }

  static NightMood? _nightMoodFromName(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return _firstWhereOrNull(
      NightMood.values,
      (NightMood item) => item.name == value,
    );
  }

  static SleepSessionStatus? _sleepStatusFromName(String? value) {
    return _firstWhereOrNull(
      SleepSessionStatus.values,
      (SleepSessionStatus item) => item.name == value,
    );
  }

  static RecommendationType? _recommendationTypeFromName(String? value) {
    return _firstWhereOrNull(
      RecommendationType.values,
      (RecommendationType item) => item.name == value,
    );
  }

  static RecommendationExecutionState? _recommendationStateFromName(
    String? value,
  ) {
    return _firstWhereOrNull(
      RecommendationExecutionState.values,
      (RecommendationExecutionState item) => item.name == value,
    );
  }

  static RecommendationFeedbackStatus? _feedbackStatusFromName(String? value) {
    return _firstWhereOrNull(
      RecommendationFeedbackStatus.values,
      (RecommendationFeedbackStatus item) => item.name == value,
    );
  }

  static SleepCaptureType? _sleepCaptureTypeFromName(String? value) {
    return _firstWhereOrNull(
      SleepCaptureType.values,
      (SleepCaptureType item) => item.name == value,
    );
  }

  static AssistantMessageRole? _assistantRoleFromName(String? value) {
    return _firstWhereOrNull(
      AssistantMessageRole.values,
      (AssistantMessageRole item) => item.name == value,
    );
  }

  static AssistantMessageStatus? _assistantStatusFromName(String? value) {
    return _firstWhereOrNull(
      AssistantMessageStatus.values,
      (AssistantMessageStatus item) => item.name == value,
    );
  }

  static AssistantReplySourceMode? _assistantSourceModeFromName(String? value) {
    return _firstWhereOrNull(
      AssistantReplySourceMode.values,
      (AssistantReplySourceMode item) => item.name == value,
    );
  }

  static T? _firstWhereOrNull<T>(
    Iterable<T> values,
    bool Function(T value) test,
  ) {
    for (final T value in values) {
      if (test(value)) {
        return value;
      }
    }
    return null;
  }
}
