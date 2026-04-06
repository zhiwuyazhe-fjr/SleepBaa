import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/data/model_serializers.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

void main() {
  test('user profile serializer keeps avatar url fields', () {
    const UserProfile profile = UserProfile(
      uid: 'user-1',
      displayName: 'Kai',
      tagline: 'Dorm sync owner',
      role: 'Backend',
      dormId: 'dorm-204',
      avatarPath: '/tmp/avatar.png',
      avatarUrl: 'https://example.com/avatar.png',
      avatarFallbackSeed: 'Kai',
    );

    final Map<String, dynamic> map = ModelSerializers.userProfileToMap(profile);
    final UserProfile restored = ModelSerializers.userProfileFromMap(map);

    expect(restored.uid, profile.uid);
    expect(restored.avatarUrl, profile.avatarUrl);
    expect(restored.dormId, profile.dormId);
  });

  test('sleep session serializer keeps nested awakenings and feedback', () {
    final SleepSession session = SleepSession(
      id: 'session-1',
      uid: 'user-1',
      startedAt: DateTime(2026, 4, 5, 23),
      endedAt: DateTime(2026, 4, 6, 7),
      status: SleepSessionStatus.completed,
      sleepModeActive: false,
      dormId: 'dorm-204',
      recommendations: const <NightRecommendation>[
        NightRecommendation(
          id: 'audio',
          title: 'Play audio',
          subtitle: 'Ocean',
          type: RecommendationType.audio,
          icon: Icons.music_note_rounded,
          tags: <String>['calm'],
          executionState: RecommendationExecutionState.completed,
        ),
      ],
      selectedRecommendationIds: const <String>['audio'],
      awakenings: <NightAwakeningEntry>[
        NightAwakeningEntry(
          id: 'wake-1',
          occurredAt: DateTime(2026, 4, 6, 3, 14),
          trigger: 'Noise',
          minutesToSleep: 8,
          note: 'Recovered quickly',
        ),
      ],
      feedback: <RecommendationFeedback>[
        RecommendationFeedback(
          recommendationId: 'audio',
          status: RecommendationFeedbackStatus.effective,
          note: 'Worked well',
          submittedAt: DateTime(2026, 4, 6, 7, 30),
        ),
      ],
      summary: const MorningSummary(
        sleepQuality: 4,
        restedLevel: 4,
        totalSleepHours: 7.6,
        awakeningsCount: 1,
        note: 'Solid night',
      ),
      updatedAt: DateTime(2026, 4, 6, 7, 30),
    );

    final Map<String, dynamic> map = ModelSerializers.sleepSessionToMap(session);
    final SleepSession restored = ModelSerializers.sleepSessionFromMap(map);

    expect(restored.uid, session.uid);
    expect(restored.awakenings.single.trigger, 'Noise');
    expect(restored.feedback.single.status, RecommendationFeedbackStatus.effective);
    expect(restored.summary?.sleepQuality, 4);
    expect(restored.updatedAt, session.updatedAt);
  });

  test('assistant message serializer keeps role and status', () {
    final AssistantMessage message = AssistantMessage(
      id: 'msg-1',
      threadId: 'thread-1',
      role: AssistantMessageRole.assistant,
      content: 'Try a slower breathing pattern.',
      createdAt: DateTime(2026, 4, 5, 23, 30),
      status: AssistantMessageStatus.complete,
    );

    final Map<String, dynamic> map =
        ModelSerializers.assistantMessageToMap(message);
    final AssistantMessage restored =
        ModelSerializers.assistantMessageFromMap(map);

    expect(restored.threadId, message.threadId);
    expect(restored.role, AssistantMessageRole.assistant);
    expect(restored.status, AssistantMessageStatus.complete);
  });
}
