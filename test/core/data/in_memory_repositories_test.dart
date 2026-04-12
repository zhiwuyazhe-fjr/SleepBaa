import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/data/in_memory_repositories.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
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

  test(
    'auth repository supports password login after phone registration',
    () async {
      final InMemoryAuthRepository repository = InMemoryAuthRepository();

      await repository.registerWithPhone(
        phoneNumber: '13800138000',
        verificationId: 'verification-id',
        code: '123456',
        password: 'secret123',
      );

      await repository.signOut();
      await repository.signInWithPassword(
        phoneNumber: '13800138000',
        password: 'secret123',
      );

      expect(repository.currentUser.phoneNumber, '+86 13800138000');
    },
  );

  test(
    'auth repository blocks registration code send for existing phone',
    () async {
      final InMemoryAuthRepository repository = InMemoryAuthRepository();

      await repository.registerWithPhone(
        phoneNumber: '13800138000',
        verificationId: 'verification-id',
        code: '123456',
        password: 'secret123',
      );

      await expectLater(
        () => repository.sendPhoneVerificationCode(
          '13800138000',
          target: PhoneVerificationTarget.newUser,
        ),
        throwsA(
          isA<AuthPhoneTargetMismatchException>().having(
            (AuthPhoneTargetMismatchException error) => error.message,
            'message',
            '该手机号已注册，请直接登录。',
          ),
        ),
      );
    },
  );

  test(
    'auth repository blocks login code send for unregistered phone',
    () async {
      final InMemoryAuthRepository repository = InMemoryAuthRepository();

      await expectLater(
        () => repository.sendPhoneVerificationCode(
          '13900139000',
          target: PhoneVerificationTarget.existingUser,
        ),
        throwsA(
          isA<AuthPhoneTargetMismatchException>().having(
            (AuthPhoneTargetMismatchException error) => error.message,
            'message',
            '未找到该手机号，请先注册。',
          ),
        ),
      );
    },
  );

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

  test(
    'dorm repository invite acceptance adds the current user as member',
    () async {
      final InMemoryDormRepository repository = InMemoryDormRepository(
        currentUserId: 'new-roommate',
        initialDorm: buildDefaultDorm('host-user').copyWith(
          members: <DormMember>[
            DormMember(
              uid: 'host-user',
              name: 'Host',
              status: DormMemberStatus.quiet,
              presenceStatus: DormPresenceStatus.returned,
              sleepModeActive: false,
              lastActiveAt: DateTime(2026, 4, 5, 22),
              note: 'Ready to sleep',
            ),
          ],
          invites: <DormInvite>[
            DormInvite(
              id: 'invite-1',
              dormId: 'dorm-204',
              code: 'DORM-204000',
              createdByUid: 'host-user',
              createdAt: DateTime(2026, 4, 5, 21),
              expiresAt: DateTime(2026, 4, 8, 21),
              status: DormInviteStatus.pending,
            ),
          ],
        ),
      );

      await repository.acceptInvite('DORM-204000');

      expect(
        repository.currentDorm.members.any(
          (DormMember member) => member.uid == 'new-roommate',
        ),
        isTrue,
      );
      expect(
        repository.currentDorm.invites.single.status,
        DormInviteStatus.accepted,
      );
    },
  );

  test('dream repository can save and delete an entry', () async {
    final InMemoryDreamRepository repository = InMemoryDreamRepository(
      userId: 'dream-user',
    );
    final DreamEntry entry = DreamEntry(
      id: 'dream-2',
      userId: 'dream-user',
      title: 'Moonlit station',
      body: 'A train stopped under a blue moon.',
      tags: const <String>['moon', 'train'],
      createdAt: DateTime(2026, 4, 5, 7),
    );

    await repository.saveDreamEntry(entry);
    expect(
      repository.entries.any((DreamEntry item) => item.id == entry.id),
      isTrue,
    );

    await repository.deleteDreamEntry(entry.id);
    expect(
      repository.entries.any((DreamEntry item) => item.id == entry.id),
      isFalse,
    );
  });

  test(
    'assistant repository stores user and assistant messages in order',
    () async {
      final InMemoryAssistantRepository repository =
          InMemoryAssistantRepository(userId: 'assistant-user');

      final AssistantThread thread = await repository.ensureThread(
        title: 'Night support',
      );
      await repository.sendUserMessage(
        threadId: thread.id,
        content: 'It is noisy tonight.',
      );
      await repository.addAssistantMessage(
        threadId: thread.id,
        content: 'Try earplugs and a softer track.',
      );

      final List<AssistantMessage> messages = repository.messagesForThread(
        thread.id,
      );
      expect(messages.last.content, 'Try earplugs and a softer track.');
      expect(messages[messages.length - 2].role, AssistantMessageRole.user);
    },
  );
}
