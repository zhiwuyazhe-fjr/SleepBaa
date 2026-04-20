import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/backend/assistant_reply_gateway.dart';
import 'package:sleep_dorm_app/core/data/in_memory_repositories.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/facades/app_facades.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class _RecordingRecommendationRepository extends ChangeNotifier
    implements RecommendationRepository {
  bool resetCalled = false;
  List<NightRecommendation> _recommendations = buildDefaultRecommendations();

  @override
  List<NightRecommendation> get tonightRecommendations => _recommendations;

  @override
  Future<void> resetForTonight() async {
    resetCalled = true;
  }

  @override
  Future<void> refreshAudioCatalog() async {}

  @override
  Future<AudioTrack?> resolvePlayableTrack({
    NightRecommendation? recommendation,
    bool forceRefresh = false,
  }) async {
    return recommendation?.track;
  }

  @override
  Future<void> setRecommendationState(
    String recommendationId,
    RecommendationExecutionState state,
  ) async {
    _recommendations = _recommendations
        .map(
          (NightRecommendation item) => item.id == recommendationId
              ? item.copyWith(executionState: state)
              : item,
        )
        .toList(growable: false);
  }
}

class _FakeAssistantGateway implements AssistantReplyGateway {
  @override
  Stream<AssistantStreamEvent> streamReply({
    required String prompt,
    required String threadId,
    required String clientUserMessageId,
    required String clientAssistantMessageId,
    required Dorm dorm,
  }) async* {
    yield AssistantStreamEvent(
      type: AssistantStreamEventType.ack,
      assistantMessageId: clientAssistantMessageId,
    );
    yield const AssistantStreamEvent(
      type: AssistantStreamEventType.messageDelta,
      delta: 'Backend reply',
    );
    yield AssistantStreamEvent(
      type: AssistantStreamEventType.messageCompleted,
      reply: 'Backend reply',
      sourceMode: AssistantReplySourceMode.remoteSuccess,
      runId: 'run-1',
      intent: 'general_support',
      provider: 'xai_responses',
      model: 'grok-4-1-fast-reasoning',
      assistantMessageId: clientAssistantMessageId,
      updatedSurfaces: const <String>['assistant_context'],
    );
    yield const AssistantStreamEvent(type: AssistantStreamEventType.done);
  }

  @override
  Stream<AssistantStreamEvent> streamCapture({
    required String prompt,
    required String threadId,
    required String sessionId,
    required SleepCaptureType captureType,
    required String clientUserMessageId,
    required String clientAssistantMessageId,
    required Dorm dorm,
  }) async* {
    final SleepCaptureRecord record = SleepCaptureRecord(
      id: 'capture-1',
      type: captureType,
      sessionId: sessionId,
      createdAt: DateTime(2026, 1, 1),
      title: 'Capture title',
      outline: 'Capture outline',
      content: prompt,
    );
    yield AssistantStreamEvent(
      type: AssistantStreamEventType.ack,
      assistantMessageId: clientAssistantMessageId,
    );
    yield const AssistantStreamEvent(
      type: AssistantStreamEventType.messageDelta,
      delta: 'Capture reply',
    );
    yield AssistantStreamEvent(
      type: AssistantStreamEventType.messageCompleted,
      reply: 'Capture reply',
      sourceMode: AssistantReplySourceMode.remoteSuccess,
      provider: 'xai_responses',
      model: 'grok-4-1-fast-reasoning',
      assistantMessageId: clientAssistantMessageId,
      updatedSurfaces: const <String>['assistant_context'],
    );
    yield AssistantStreamEvent(
      type: AssistantStreamEventType.captureRecord,
      record: record,
    );
    yield const AssistantStreamEvent(type: AssistantStreamEventType.done);
  }

  @override
  Future<AssistantReplyResult> generateReply({
    required String prompt,
    required String threadId,
    required String clientUserMessageId,
    required String clientAssistantMessageId,
    required Dorm dorm,
  }) async {
    return AssistantReplyResult(
      reply: 'Backend reply',
      sourceMode: AssistantReplySourceMode.remoteSuccess,
      runId: 'run-1',
      intent: 'general_support',
      provider: 'xai_responses',
      model: 'grok-4-1-fast-reasoning',
      assistantMessageId: clientAssistantMessageId,
      updatedSurfaces: const <String>['assistant_context'],
    );
  }

  @override
  Future<AssistantCaptureResult> generateCapture({
    required String prompt,
    required String threadId,
    required String sessionId,
    required SleepCaptureType captureType,
    required String clientUserMessageId,
    required String clientAssistantMessageId,
    required Dorm dorm,
  }) async {
    return AssistantCaptureResult(
      reply: 'Capture reply',
      sourceMode: AssistantReplySourceMode.remoteSuccess,
      record: SleepCaptureRecord(
        id: 'capture-1',
        type: captureType,
        sessionId: sessionId,
        createdAt: DateTime(2026, 1, 1),
        title: 'Capture title',
        outline: 'Capture outline',
        content: prompt,
      ),
      recordPersistedRemotely: true,
      provider: 'xai_responses',
      model: 'grok-4-1-fast-reasoning',
      assistantMessageId: clientAssistantMessageId,
      updatedSurfaces: const <String>['assistant_context'],
    );
  }
}

class _ErrorAssistantGateway implements AssistantReplyGateway {
  @override
  Stream<AssistantStreamEvent> streamReply({
    required String prompt,
    required String threadId,
    required String clientUserMessageId,
    required String clientAssistantMessageId,
    required Dorm dorm,
  }) async* {
    yield const AssistantStreamEvent(
      type: AssistantStreamEventType.error,
      errorMessage: 'gateway failure',
      sourceMode: AssistantReplySourceMode.error,
    );
  }

  @override
  Stream<AssistantStreamEvent> streamCapture({
    required String prompt,
    required String threadId,
    required String sessionId,
    required SleepCaptureType captureType,
    required String clientUserMessageId,
    required String clientAssistantMessageId,
    required Dorm dorm,
  }) async* {
    yield const AssistantStreamEvent(
      type: AssistantStreamEventType.error,
      errorMessage: 'gateway failure',
      sourceMode: AssistantReplySourceMode.error,
    );
  }

  @override
  Future<AssistantReplyResult> generateReply({
    required String prompt,
    required String threadId,
    required String clientUserMessageId,
    required String clientAssistantMessageId,
    required Dorm dorm,
  }) async {
    return const AssistantReplyResult(
      reply: '暂时没有收到回复，请稍后再试。',
      sourceMode: AssistantReplySourceMode.error,
      errorMessage: 'gateway failure',
    );
  }

  @override
  Future<AssistantCaptureResult> generateCapture({
    required String prompt,
    required String threadId,
    required String sessionId,
    required SleepCaptureType captureType,
    required String clientUserMessageId,
    required String clientAssistantMessageId,
    required Dorm dorm,
  }) async {
    return AssistantCaptureResult(
      reply: '暂时没有收到整理结果，请稍后再试。',
      sourceMode: AssistantReplySourceMode.error,
      errorMessage: 'gateway failure',
      record: SleepCaptureRecord(
        id: '',
        type: captureType,
        sessionId: sessionId,
        createdAt: DateTime(2026, 1, 1),
        title: '',
        outline: '',
        content: prompt,
      ),
      recordPersistedRemotely: false,
    );
  }
}

class _TimeoutAssistantGateway implements AssistantReplyGateway {
  @override
  Stream<AssistantStreamEvent> streamReply({
    required String prompt,
    required String threadId,
    required String clientUserMessageId,
    required String clientAssistantMessageId,
    required Dorm dorm,
  }) async* {
    yield const AssistantStreamEvent(
      type: AssistantStreamEventType.error,
      errorCode: assistantReplyTimeoutCode,
      errorMessage:
          'Assistant reply timed out before completion. Please try again.',
      sourceMode: AssistantReplySourceMode.error,
    );
  }

  @override
  Stream<AssistantStreamEvent> streamCapture({
    required String prompt,
    required String threadId,
    required String sessionId,
    required SleepCaptureType captureType,
    required String clientUserMessageId,
    required String clientAssistantMessageId,
    required Dorm dorm,
  }) async* {
    yield const AssistantStreamEvent(
      type: AssistantStreamEventType.error,
      errorCode: assistantReplyTimeoutCode,
      errorMessage:
          'Assistant reply timed out before completion. Please try again.',
      sourceMode: AssistantReplySourceMode.error,
    );
  }

  @override
  Future<AssistantReplyResult> generateReply({
    required String prompt,
    required String threadId,
    required String clientUserMessageId,
    required String clientAssistantMessageId,
    required Dorm dorm,
  }) async {
    return const AssistantReplyResult(
      reply: '这次回复超时了，请重试。',
      sourceMode: AssistantReplySourceMode.error,
      errorMessage:
          'Assistant reply timed out before completion. Please try again.',
      errorCode: assistantReplyTimeoutCode,
    );
  }

  @override
  Future<AssistantCaptureResult> generateCapture({
    required String prompt,
    required String threadId,
    required String sessionId,
    required SleepCaptureType captureType,
    required String clientUserMessageId,
    required String clientAssistantMessageId,
    required Dorm dorm,
  }) async {
    return AssistantCaptureResult(
      reply: '暂时没有收到整理结果，请稍后再试。',
      sourceMode: AssistantReplySourceMode.error,
      errorMessage:
          'Assistant reply timed out before completion. Please try again.',
      record: SleepCaptureRecord(
        id: '',
        type: captureType,
        sessionId: sessionId,
        createdAt: DateTime(2026, 1, 1),
        title: '',
        outline: '',
        content: prompt,
      ),
      recordPersistedRemotely: false,
    );
  }
}

void main() {
  test(
    'profile facade refreshes tonight plan after saving night mood',
    () async {
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository();
      final InMemoryUserSettingsRepository settingsRepository =
          InMemoryUserSettingsRepository();
      final _RecordingRecommendationRepository recommendationRepository =
          _RecordingRecommendationRepository();
      final ProfileFacade facade = ProfileFacade(
        authRepository: authRepository,
        settingsRepository: settingsRepository,
        recommendationRepository: recommendationRepository,
        dormRepository: InMemoryDormRepository(),
      );

      await facade.saveNightMood(NightMood.calm);

      expect(
        settingsRepository.currentSettings.selectedNightMood,
        NightMood.calm,
      );
      expect(recommendationRepository.resetCalled, isTrue);
      facade.dispose();
      authRepository.dispose();
      settingsRepository.dispose();
    },
  );

  test(
    'profile facade syncs equipped badge to local dorm member card',
    () async {
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository();
      final InMemoryUserSettingsRepository settingsRepository =
          InMemoryUserSettingsRepository();
      final InMemoryDormRepository dormRepository = InMemoryDormRepository(
        currentUserId: authRepository.currentUser.uid,
      );
      final ProfileFacade facade = ProfileFacade(
        authRepository: authRepository,
        settingsRepository: settingsRepository,
        dormRepository: dormRepository,
      );

      await facade.saveEquippedBadge('early-sleeper');

      final DormMember currentMember = dormRepository.currentDorm.members
          .firstWhere(
            (DormMember member) => member.uid == authRepository.currentUser.uid,
          );
      expect(currentMember.displayBadgeId, 'early-sleeper');
      expect(authRepository.currentUser.displayBadgeId, 'early-sleeper');

      facade.dispose();
      dormRepository.dispose();
      authRepository.dispose();
      settingsRepository.dispose();
    },
  );

  test(
    'profile facade syncs updated avatar to local dorm member card',
    () async {
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository();
      final InMemoryUserSettingsRepository settingsRepository =
          InMemoryUserSettingsRepository();
      final InMemoryDormRepository dormRepository = InMemoryDormRepository(
        currentUserId: authRepository.currentUser.uid,
      );
      final ProfileFacade facade = ProfileFacade(
        authRepository: authRepository,
        settingsRepository: settingsRepository,
        dormRepository: dormRepository,
      );

      await facade.updateAvatar(
        avatarPath: '/mock/new-avatar.png',
        avatarBytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
      );

      final DormMember currentMember = dormRepository.currentDorm.members
          .firstWhere(
            (DormMember member) => member.uid == authRepository.currentUser.uid,
          );
      expect(authRepository.currentUser.avatarPath, '/mock/new-avatar.png');
      expect(currentMember.avatarUrl, '/mock/new-avatar.png');

      facade.dispose();
      dormRepository.dispose();
      authRepository.dispose();
      settingsRepository.dispose();
    },
  );

  test(
    'profile facade updates dorm pulse badge visibility preference',
    () async {
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository();
      final InMemoryUserSettingsRepository settingsRepository =
          InMemoryUserSettingsRepository();
      final ProfileFacade facade = ProfileFacade(
        authRepository: authRepository,
        settingsRepository: settingsRepository,
        dormRepository: InMemoryDormRepository(
          currentUserId: authRepository.currentUser.uid,
        ),
      );

      await facade.setDormPulseBadgeVisibility(false);

      expect(authRepository.currentUser.showDormPulseBadge, isFalse);

      facade.dispose();
      authRepository.dispose();
      settingsRepository.dispose();
    },
  );

  test(
    'profile facade saves dorm badge selection without changing personal badge sync',
    () async {
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository();
      final InMemoryUserSettingsRepository settingsRepository =
          InMemoryUserSettingsRepository();
      final InMemoryDormRepository dormRepository = InMemoryDormRepository(
        currentUserId: authRepository.currentUser.uid,
      );
      final ProfileFacade facade = ProfileFacade(
        authRepository: authRepository,
        settingsRepository: settingsRepository,
        dormRepository: dormRepository,
      );

      await facade.saveEquippedBadge('early-sleeper');
      await facade.saveDormBadgeSelection('no-trouble-room');

      final DormMember currentMember = dormRepository.currentDorm.members
          .firstWhere(
            (DormMember member) => member.uid == authRepository.currentUser.uid,
          );
      expect(authRepository.currentUser.selectedDormBadgeId, 'no-trouble-room');
      expect(authRepository.currentUser.displayBadgeId, 'early-sleeper');
      expect(currentMember.displayBadgeId, 'early-sleeper');

      facade.dispose();
      dormRepository.dispose();
      authRepository.dispose();
      settingsRepository.dispose();
    },
  );

  test(
    'assistant facade stores structured gateway reply as assistant message',
    () async {
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository(
        initialProfile: buildDefaultUserProfile().copyWith(
          uid: 'assistant-user',
        ),
      );
      final InMemoryAssistantRepository assistantRepository =
          InMemoryAssistantRepository(userId: 'assistant-user');
      final InMemoryDormRepository dormRepository = InMemoryDormRepository(
        currentUserId: 'assistant-user',
      );
      final InMemorySleepCaptureRepository sleepCaptureRepository =
          InMemorySleepCaptureRepository();
      final AssistantFacade facade = AssistantFacade(
        assistantRepository: assistantRepository,
        sleepCaptureRepository: sleepCaptureRepository,
        dormRepository: dormRepository,
        assistantReplyGateway: _FakeAssistantGateway(),
      );

      await facade.sendPrompt('Can you help me settle down?');

      final AssistantThread? thread = assistantRepository.currentThread;
      expect(thread, isNotNull);
      final List<AssistantMessage> messages = assistantRepository
          .messagesForThread(thread!.id);
      expect(messages, hasLength(3));
      expect(messages.last.content, 'Backend reply');
      expect(messages.last.role, AssistantMessageRole.assistant);
      expect(messages.last.sourceMode, AssistantReplySourceMode.remoteSuccess);
      expect(messages.last.provider, 'xai_responses');
      expect(messages.last.model, 'grok-4-1-fast-reasoning');
      facade.dispose();
      authRepository.dispose();
      assistantRepository.dispose();
      sleepCaptureRepository.dispose();
      dormRepository.dispose();
    },
  );

  test(
    'assistant facade preserves gateway error state instead of inventing a fallback reply',
    () async {
      final InMemoryAuthRepository authRepository = InMemoryAuthRepository(
        initialProfile: buildDefaultUserProfile().copyWith(
          uid: 'assistant-user',
        ),
      );
      final InMemoryAssistantRepository assistantRepository =
          InMemoryAssistantRepository(userId: 'assistant-user');
      final InMemoryDormRepository dormRepository = InMemoryDormRepository(
        currentUserId: 'assistant-user',
      );
      final InMemorySleepCaptureRepository sleepCaptureRepository =
          InMemorySleepCaptureRepository();
      final AssistantFacade facade = AssistantFacade(
        assistantRepository: assistantRepository,
        sleepCaptureRepository: sleepCaptureRepository,
        dormRepository: dormRepository,
        assistantReplyGateway: _ErrorAssistantGateway(),
      );

      await facade.sendPrompt('Can you help me settle down?');

      final AssistantThread? thread = assistantRepository.currentThread;
      expect(thread, isNotNull);
      final AssistantMessage latest = assistantRepository
          .messagesForThread(thread!.id)
          .last;
      expect(latest.status, AssistantMessageStatus.error);
      expect(latest.sourceMode, AssistantReplySourceMode.error);
      expect(latest.errorMessage, '请直接重试上一条消息。');
      expect(latest.content, '暂时没有收到回复，请稍后再试。');
      facade.dispose();
      authRepository.dispose();
      assistantRepository.dispose();
      sleepCaptureRepository.dispose();
      dormRepository.dispose();
    },
  );

  test('assistant facade preserves timeout-specific assistant copy', () async {
    final InMemoryAuthRepository authRepository = InMemoryAuthRepository(
      initialProfile: buildDefaultUserProfile().copyWith(uid: 'assistant-user'),
    );
    final InMemoryAssistantRepository assistantRepository =
        InMemoryAssistantRepository(userId: 'assistant-user');
    final InMemoryDormRepository dormRepository = InMemoryDormRepository(
      currentUserId: 'assistant-user',
    );
    final InMemorySleepCaptureRepository sleepCaptureRepository =
        InMemorySleepCaptureRepository();
    final AssistantFacade facade = AssistantFacade(
      assistantRepository: assistantRepository,
      sleepCaptureRepository: sleepCaptureRepository,
      dormRepository: dormRepository,
      assistantReplyGateway: _TimeoutAssistantGateway(),
    );

    await facade.sendPrompt('Can you help me settle down?');

    final AssistantThread? thread = assistantRepository.currentThread;
    expect(thread, isNotNull);
    final AssistantMessage latest = assistantRepository
        .messagesForThread(thread!.id)
        .last;
    expect(latest.status, AssistantMessageStatus.error);
    expect(latest.sourceMode, AssistantReplySourceMode.error);
    expect(latest.errorMessage, '这次回复超时了，请直接重试上一条消息。');
    expect(latest.content, '这次回复超时了，请重试。');
    facade.dispose();
    authRepository.dispose();
    assistantRepository.dispose();
    sleepCaptureRepository.dispose();
    dormRepository.dispose();
  });
}
