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

  test('auth repository persists equipped badge preferences locally', () async {
    final InMemoryAuthRepository repository = InMemoryAuthRepository();

    await repository.updateBadgePreferences(
      earnedBadgeIds: repository.currentUser.earnedBadgeIds,
      equippedBadgeId: 'early-sleeper',
    );

    expect(repository.currentUser.equippedBadgeId, 'early-sleeper');
    expect(repository.currentUser.displayBadgeId, 'early-sleeper');

    await repository.updateBadgePreferences(
      earnedBadgeIds: repository.currentUser.earnedBadgeIds,
      clearEquippedBadge: true,
    );

    expect(repository.currentUser.equippedBadgeId, isNull);
    expect(repository.currentUser.displayBadgeId, 'sleep-master');
  });

  test(
    'auth repository persists dorm pulse badge visibility locally',
    () async {
      final InMemoryAuthRepository repository = InMemoryAuthRepository();

      expect(repository.currentUser.showDormPulseBadge, isTrue);

      await repository.updateDormBadgeVisibility(showDormPulseBadge: false);

      expect(repository.currentUser.showDormPulseBadge, isFalse);
    },
  );

  test('auth repository persists selected dorm badge locally', () async {
    final InMemoryAuthRepository repository = InMemoryAuthRepository();

    await repository.updateDormBadgeSelection(
      selectedDormBadgeId: 'no-trouble-room',
    );

    expect(repository.currentUser.selectedDormBadgeId, 'no-trouble-room');

    await repository.updateDormBadgeSelection(clearSelectedDormBadgeId: true);

    expect(repository.currentUser.selectedDormBadgeId, isNull);
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

    final SleepSession session = await repository.startOrResumeSleepSession(
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

    await repository.finishActiveSleepSession();

    expect(repository.latestAwaitingFeedbackSession?.id, session.id);
  });

  test(
    'sleep session repository lookup readiness is always true in memory',
    () {
      final InMemorySleepSessionRepository repository =
          InMemorySleepSessionRepository();

      expect(repository.isReadyForSessionLookup, isTrue);
    },
  );

  test('sleep day key switches at 20:00 instead of calendar midnight', () {
    expect(sleepDayKeyFromDate(DateTime(2026, 4, 17, 19, 59)), '2026-04-17');
    expect(sleepDayKeyFromDate(DateTime(2026, 4, 17, 20, 0)), '2026-04-18');
    expect(sleepDayKeyFromDate(DateTime(2026, 4, 17, 20, 1)), '2026-04-18');
  });

  test(
    'sleep session repository resumes a paused same-day session and accumulates duration',
    () async {
      final InMemorySleepSessionRepository repository =
          InMemorySleepSessionRepository(
            initialSessions: const <SleepSession>[],
          );
      final DateTime startAt = DateTime(2026, 4, 13, 23, 0);
      final String sleepDayKey = sleepDayKeyFromDate(startAt);

      final SleepSession first = await repository.startOrResumeSleepSession(
        recommendationSnapshot: const <NightRecommendation>[],
        dormId: 'dorm-204',
        at: startAt,
      );
      await repository.pauseActiveSleepSession(at: DateTime(2026, 4, 14, 1, 0));

      final SleepSession resumed = await repository.startOrResumeSleepSession(
        recommendationSnapshot: const <NightRecommendation>[],
        dormId: 'dorm-204',
        at: DateTime(2026, 4, 14, 2, 0),
      );
      await repository.finishActiveSleepSession(
        at: DateTime(2026, 4, 14, 5, 0),
      );

      final SleepSession finished = repository.sessionForSleepDayKey(
        sleepDayKey,
      )!;
      expect(resumed.id, first.id);
      expect(finished.id, first.id);
      expect(finished.status, SleepSessionStatus.awaitingFeedback);
      expect(finished.trackedDurationMinutes, 300);
      expect(finished.segments.length, 2);
    },
  );

  test(
    'sleep session repository resumes a same-day awaiting feedback session until feedback is submitted',
    () async {
      final InMemorySleepSessionRepository repository =
          InMemorySleepSessionRepository(
            initialSessions: const <SleepSession>[],
          );
      final DateTime startAt = DateTime(2026, 4, 13, 23, 0);
      final String sleepDayKey = sleepDayKeyFromDate(startAt);

      final SleepSession first = await repository.startOrResumeSleepSession(
        recommendationSnapshot: const <NightRecommendation>[],
        dormId: 'dorm-204',
        at: startAt,
      );
      await repository.finishActiveSleepSession(
        at: DateTime(2026, 4, 14, 6, 0),
      );

      final SleepSession resumed = await repository.startOrResumeSleepSession(
        recommendationSnapshot: const <NightRecommendation>[],
        dormId: 'dorm-204',
        at: DateTime(2026, 4, 14, 8, 30),
      );
      await repository.finishActiveSleepSession(
        at: DateTime(2026, 4, 14, 9, 0),
      );

      final SleepSession finished = repository.sessionForSleepDayKey(
        sleepDayKey,
      )!;
      expect(resumed.id, first.id);
      expect(finished.id, first.id);
      expect(finished.status, SleepSessionStatus.awaitingFeedback);
      expect(finished.trackedDurationMinutes, 450);
      expect(finished.segments.length, 2);
    },
  );

  test(
    'sleep session repository archives active stale sessions at the sleep-day cutoff',
    () async {
      final InMemorySleepSessionRepository repository =
          InMemorySleepSessionRepository(
            initialSessions: const <SleepSession>[],
          );
      final DateTime startAt = DateTime(2026, 4, 16, 23, 0);
      final String sleepDayKey = sleepDayKeyFromDate(startAt);

      await repository.startOrResumeSleepSession(
        recommendationSnapshot: const <NightRecommendation>[],
        dormId: 'dorm-204',
        at: startAt,
      );

      final List<SleepSession> archived = await repository
          .archivePastCutoffSessions(now: DateTime(2026, 4, 17, 20, 5));

      final SleepSession session = repository.sessionForSleepDayKey(
        sleepDayKey,
      )!;
      expect(archived.map((SleepSession item) => item.id), <String>[
        session.id,
      ]);
      expect(session.status, SleepSessionStatus.awaitingFeedback);
      expect(session.sleepModeActive, isFalse);
      expect(session.displayEndAt, DateTime(2026, 4, 17, 20, 0));
      expect(session.trackedDurationMinutes, 1260);
    },
  );

  test(
    'sleep session repository archives paused stale sessions without changing tracked duration',
    () async {
      final InMemorySleepSessionRepository repository =
          InMemorySleepSessionRepository(
            initialSessions: const <SleepSession>[],
          );
      final DateTime startAt = DateTime(2026, 4, 16, 23, 0);
      final String sleepDayKey = sleepDayKeyFromDate(startAt);

      await repository.startOrResumeSleepSession(
        recommendationSnapshot: const <NightRecommendation>[],
        dormId: 'dorm-204',
        at: startAt,
      );
      await repository.pauseActiveSleepSession(at: DateTime(2026, 4, 17, 7, 0));

      final List<SleepSession> archived = await repository
          .archivePastCutoffSessions(now: DateTime(2026, 4, 17, 20, 5));

      final SleepSession session = repository.sessionForSleepDayKey(
        sleepDayKey,
      )!;
      expect(archived.map((SleepSession item) => item.id), <String>[
        session.id,
      ]);
      expect(session.status, SleepSessionStatus.awaitingFeedback);
      expect(session.sleepModeActive, isFalse);
      expect(session.trackedDurationMinutes, 480);
      expect(session.displayEndAt, DateTime(2026, 4, 17, 7, 0));
    },
  );

  test(
    'sleep session repository prefers the latest archived pending session when multiple old days are normalized',
    () async {
      final InMemorySleepSessionRepository repository =
          InMemorySleepSessionRepository(
            initialSessions: const <SleepSession>[],
          );

      await repository.startOrResumeSleepSession(
        recommendationSnapshot: const <NightRecommendation>[],
        dormId: 'dorm-204',
        at: DateTime(2026, 4, 14, 23, 0),
      );
      await repository.pauseActiveSleepSession(at: DateTime(2026, 4, 15, 6, 0));
      await repository.startOrResumeSleepSession(
        recommendationSnapshot: const <NightRecommendation>[],
        dormId: 'dorm-204',
        at: DateTime(2026, 4, 15, 23, 0),
      );
      await repository.pauseActiveSleepSession(
        at: DateTime(2026, 4, 16, 6, 30),
      );

      final List<SleepSession> archived = await repository
          .archivePastCutoffSessions(now: DateTime(2026, 4, 17, 20, 5));

      expect(archived, hasLength(2));
      expect(archived.first.sleepDayDate, DateTime(2026, 4, 15));
      expect(archived.last.sleepDayDate, DateTime(2026, 4, 16));
      expect(
        repository.latestAwaitingFeedbackSession?.sleepDayDate,
        DateTime(2026, 4, 16),
      );
    },
  );

  test(
    'sleep session repository keeps tracked duration locked after morning feedback is submitted',
    () async {
      final InMemorySleepSessionRepository sessions =
          InMemorySleepSessionRepository(
            initialSessions: const <SleepSession>[],
          );
      final InMemoryFeedbackRepository feedbackRepository =
          InMemoryFeedbackRepository(sleepSessionRepository: sessions);
      final DateTime startAt = DateTime(2026, 4, 13, 23, 30);
      final String sleepDayKey = sleepDayKeyFromDate(startAt);

      await sessions.startOrResumeSleepSession(
        recommendationSnapshot: const <NightRecommendation>[],
        dormId: 'dorm-204',
        at: startAt,
      );
      await sessions.finishActiveSleepSession(at: DateTime(2026, 4, 14, 6, 30));

      final SleepSession awaiting = sessions.sessionForSleepDayKey(
        sleepDayKey,
      )!;
      await feedbackRepository.submitFeedback(
        session: awaiting,
        summary: const MorningSummary(
          sleepQuality: 4,
          restedLevel: 4,
          totalSleepHours: 7,
          awakeningsCount: 0,
          note: 'locked',
        ),
        recommendationFeedback: const <RecommendationFeedback>[],
      );

      final SleepSession completed = sessions.sessionForSleepDayKey(
        sleepDayKey,
      )!;
      final int lockedMinutes = completed.trackedDurationMinutes;

      await sessions.startOrResumeSleepSession(
        recommendationSnapshot: const <NightRecommendation>[],
        dormId: 'dorm-204',
        at: DateTime(2026, 4, 14, 9, 0),
      );
      await sessions.finishActiveSleepSession(at: DateTime(2026, 4, 14, 10, 0));

      final SleepSession locked = sessions.sessionForSleepDayKey(sleepDayKey)!;
      expect(locked.status, SleepSessionStatus.completed);
      expect(locked.trackedDurationMinutes, lockedMinutes);
      expect(locked.hasSubmittedFeedback, isTrue);
    },
  );

  test('feedback repository marks session completed', () async {
    final InMemorySleepSessionRepository sessions =
        InMemorySleepSessionRepository();
    final InMemoryFeedbackRepository feedbackRepository =
        InMemoryFeedbackRepository(sleepSessionRepository: sessions);

    final SleepSession session = await sessions.startOrResumeSleepSession(
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

  test('default dorm exposes the latest earned dorm badge', () {
    final Dorm dorm = buildDefaultDorm('tester');

    expect(dorm.earnedDormBadgeIds, <String>[
      'no-trouble-room',
      'no-wake-room',
    ]);
    expect(dorm.latestEarnedDormBadgeId, 'no-wake-room');
  });

  test(
    'dorm rules create a pending proposal before all roommates agree',
    () async {
      final InMemoryDormRepository repository = InMemoryDormRepository(
        currentUserId: 'host-user',
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
            DormMember(
              uid: 'roommate-a',
              name: 'Roommate A',
              status: DormMemberStatus.quiet,
              presenceStatus: DormPresenceStatus.returned,
              sleepModeActive: false,
              lastActiveAt: DateTime(2026, 4, 5, 21, 50),
              note: 'Reading',
            ),
          ],
        ),
      );

      await repository.saveRules(
        repository.currentDorm.rulesSettings.copyWith(
          quietHours: '22:30 - 07:00',
          routineTags: const <String>['考试周', '夜猫子'],
        ),
      );

      final DormPendingRuleProposal? proposal =
          repository.currentDorm.pendingRuleProposal;
      expect(proposal, isNotNull);
      expect(proposal!.proposerUid, 'host-user');
      expect(proposal.approvedUids, contains('host-user'));
      expect(proposal.pendingReviewerUids(), contains('roommate-a'));
      expect(
        repository.currentDorm.rulesSettings.quietHours,
        isNot('22:30 - 07:00'),
      );
    },
  );

  test('rejecting a pending dorm rule keeps the existing rules', () async {
    final Dorm initialDorm = buildDefaultDorm('host-user').copyWith(
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
        DormMember(
          uid: 'roommate-a',
          name: 'Roommate A',
          status: DormMemberStatus.quiet,
          presenceStatus: DormPresenceStatus.returned,
          sleepModeActive: false,
          lastActiveAt: DateTime(2026, 4, 5, 21, 50),
          note: 'Reading',
        ),
      ],
    );
    final InMemoryDormRepository proposerRepository = InMemoryDormRepository(
      currentUserId: 'host-user',
      initialDorm: initialDorm,
    );

    await proposerRepository.saveRules(
      initialDorm.rulesSettings.copyWith(quietHours: '22:00 - 07:00'),
    );

    final InMemoryDormRepository reviewerRepository = InMemoryDormRepository(
      currentUserId: 'roommate-a',
      initialDorm: proposerRepository.currentDorm,
    );

    await reviewerRepository.rejectPendingRules(reason: '周末还需要晚点讨论作业');

    expect(reviewerRepository.currentDorm.pendingRuleProposal, isNull);
    expect(
      reviewerRepository.currentDorm.rulesSettings.quietHours,
      initialDorm.rulesSettings.quietHours,
    );
    expect(
      reviewerRepository.currentDorm.events.first.detail,
      contains('周末还需要晚点讨论作业'),
    );
  });

  test(
    'dorm gentle reminder switches between anonymous and nickname modes',
    () async {
      final InMemoryDormRepository repository = InMemoryDormRepository(
        currentUserId: 'anon-paul',
      );

      await repository.sendGentleReminder(
        targetUid: 'roommate-a',
        anonymous: true,
        message: '如果方便的话，今晚一起把宿舍的环境再放轻一点',
      );
      expect(repository.currentDorm.events.first.detail, contains('您的舍友'));

      await repository.sendGentleReminder(
        targetUid: 'roommate-a',
        anonymous: false,
        message: '被月亮绑架了？该回地球了，宿舍要关门啦～',
      );
      expect(repository.currentDorm.events.first.detail, contains('Paul'));
    },
  );

  test('updating current user status marks the member as sleeping', () async {
    final InMemoryDormRepository repository = InMemoryDormRepository(
      currentUserId: 'anon-paul',
    );

    await repository.updateCurrentUserStatus(
      uid: 'anon-paul',
      status: DormMemberStatus.sleeping,
      sleepModeActive: true,
      note: '已进入睡眠模式',
    );

    final DormMember currentMember = repository.currentDorm.members.firstWhere(
      (DormMember member) => member.uid == 'anon-paul',
    );
    expect(currentMember.status, DormMemberStatus.sleeping);
    expect(currentMember.sleepModeActive, isTrue);
    expect(
      repository.currentDorm.members
          .where((DormMember member) => member.sleepModeActive)
          .length,
      greaterThanOrEqualTo(1),
    );
  });

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

  test('notification repository marks every unread item as read', () async {
    final InMemoryNotificationRepository repository =
        InMemoryNotificationRepository();

    expect(repository.unreadNotifications(), isNotEmpty);

    await repository.markAllRead();

    expect(repository.unreadNotifications(), isEmpty);
    expect(
      repository.notifications.every((NotificationItem item) => item.isRead),
      isTrue,
    );
  });
}
