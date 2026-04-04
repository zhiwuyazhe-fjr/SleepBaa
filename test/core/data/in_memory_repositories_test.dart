import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/data/in_memory_repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

void main() {
  test('auth repository updates avatar state locally', () async {
    final InMemoryAuthRepository repository = InMemoryAuthRepository();

    await repository.updateAvatar(
      avatarPath: '/mock/avatar.png',
      avatarBytes: Uint8List.fromList(<int>[1, 2, 3]),
    );

    expect(repository.currentUser.avatarPath, '/mock/avatar.png');
    expect(repository.currentUser.avatarBytes, isNotNull);
  });

  test('sleep session repository can start and persist a session', () async {
    final InMemorySleepSessionRepository repository =
        InMemorySleepSessionRepository();

    final SleepSession session = await repository.startSleepSession(
      recommendationSnapshot: const <NightRecommendation>[
        NightRecommendation(
          id: 'audio',
          title: 'Audio',
          subtitle: 'Track',
          type: RecommendationType.audio,
          icon: Icons.music_note_rounded,
          tags: <String>['15 min'],
          executionState: RecommendationExecutionState.selected,
        ),
      ],
      dormId: 'dorm-204',
    );

    expect(repository.activeSession?.id, session.id);

    await repository.updateActiveSession(
      sleepModeActive: false,
      status: SleepSessionStatus.awaitingFeedback,
      endedAt: DateTime.now(),
    );

    expect(repository.latestAwaitingFeedbackSession?.id, session.id);
  });

  test('feedback repository marks session completed', () async {
    final InMemorySleepSessionRepository sessions =
        InMemorySleepSessionRepository();
    final InMemoryFeedbackRepository feedbackRepository =
        InMemoryFeedbackRepository(sleepSessionRepository: sessions);

    final SleepSession session = await sessions.startSleepSession(
      recommendationSnapshot: const <NightRecommendation>[],
      dormId: 'dorm-204',
    );

    await feedbackRepository.submitFeedback(
      session: session,
      summary: const MorningSummary(
        sleepQuality: 4,
        restedLevel: 4,
        totalSleepHours: 7.2,
        awakeningsCount: 1,
        note: 'Felt okay',
      ),
      recommendationFeedback: <RecommendationFeedback>[
        RecommendationFeedback(
          recommendationId: 'audio',
          status: RecommendationFeedbackStatus.effective,
          note: 'Worked well',
          submittedAt: DateTime(2026, 4, 4),
        ),
      ],
    );

    final SleepSession updated = sessions.sessions.lastWhere(
      (SleepSession item) => item.id == session.id,
    );
    expect(updated.status, SleepSessionStatus.completed);
    expect(updated.summary?.sleepQuality, 4);
    expect(updated.feedback.length, 1);
  });

  test('user settings repository persists selected night mood', () async {
    final InMemoryUserSettingsRepository repository =
        InMemoryUserSettingsRepository();

    await repository.saveSettings(
      repository.currentSettings.copyWith(selectedNightMood: NightMood.happy),
    );

    expect(repository.currentSettings.selectedNightMood, NightMood.happy);

    await repository.saveSettings(
      repository.currentSettings.copyWith(clearSelectedNightMood: true),
    );

    expect(repository.currentSettings.selectedNightMood, isNull);
  });
}
