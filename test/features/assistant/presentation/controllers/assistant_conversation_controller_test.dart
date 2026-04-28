import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/backend/assistant_reply_gateway.dart';
import 'package:sleep_dorm_app/core/data/in_memory_repositories.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/features/assistant/presentation/controllers/assistant_conversation_controller.dart';

class _CaptureWithoutRecordGateway implements AssistantReplyGateway {
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
      delta: 'Reply',
    );
    yield AssistantStreamEvent(
      type: AssistantStreamEventType.messageCompleted,
      reply: 'Reply',
      sourceMode: AssistantReplySourceMode.remoteSuccess,
      assistantMessageId: clientAssistantMessageId,
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
      assistantMessageId: clientAssistantMessageId,
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
    throw UnimplementedError();
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
    throw UnimplementedError();
  }
}

void main() {
  test('submitPrompt streams assistant reply and resets turn state', () async {
    final InMemoryAssistantRepository assistantRepository =
        InMemoryAssistantRepository(userId: 'assistant-user');
    final AssistantConversationController controller =
        AssistantConversationController(
          assistantRepository: assistantRepository,
          sleepCaptureRepository: InMemorySleepCaptureRepository(),
          sleepSessionRepository: InMemorySleepSessionRepository(
            initialUid: 'assistant-user',
          ),
          dormRepository: InMemoryDormRepository(
            currentUserId: 'assistant-user',
          ),
          assistantReplyGateway: const StubAssistantReplyGateway(),
        );

    await controller.bootstrap();

    final AssistantConversationSubmitResult result = await controller
        .submitPrompt('I cannot sleep tonight');
    await _drainAsyncWork();

    expect(result, AssistantConversationSubmitResult.sent);
    expect(controller.currentThread, isNotNull);
    expect(controller.turnState?.status, AssistantThreadTurnStatus.idle);
    expect(
      controller.currentMessages.last.role,
      AssistantMessageRole.assistant,
    );
    expect(
      controller.currentMessages.last.status,
      AssistantMessageStatus.complete,
    );
  });

  test('startNewConversation reuses an existing blank thread', () async {
    final InMemoryAssistantRepository assistantRepository =
        InMemoryAssistantRepository(userId: 'assistant-user');
    final AssistantConversationController controller =
        AssistantConversationController(
          assistantRepository: assistantRepository,
          sleepCaptureRepository: InMemorySleepCaptureRepository(),
          sleepSessionRepository: InMemorySleepSessionRepository(
            initialUid: 'assistant-user',
          ),
          dormRepository: InMemoryDormRepository(
            currentUserId: 'assistant-user',
          ),
          assistantReplyGateway: const StubAssistantReplyGateway(),
        );

    await controller.bootstrap();
    final AssistantThread first = await controller.startNewConversation(
      title: '新对话',
    );
    final AssistantThread second = await controller.startNewConversation(
      title: '新对话',
    );

    expect(second.id, first.id);
    expect(
      assistantRepository.threads
          .where(
            (AssistantThread thread) =>
                assistantRepository.messagesForThread(thread.id).isEmpty,
          )
          .length,
      1,
    );
  });

  test('startNewConversation reuses dream and memo blank threads separately', () async {
    final InMemoryAssistantRepository assistantRepository =
        InMemoryAssistantRepository(userId: 'assistant-user');
    final AssistantConversationController controller =
        AssistantConversationController(
          assistantRepository: assistantRepository,
          sleepCaptureRepository: InMemorySleepCaptureRepository(),
          sleepSessionRepository: InMemorySleepSessionRepository(
            initialUid: 'assistant-user',
          ),
          dormRepository: InMemoryDormRepository(
            currentUserId: 'assistant-user',
          ),
          assistantReplyGateway: const StubAssistantReplyGateway(),
        );

    await controller.bootstrap();
    final AssistantThread dreamFirst = await controller.startNewConversation(
      title: '梦记收纳',
    );
    final AssistantThread dreamSecond = await controller.startNewConversation(
      title: '梦记收纳',
    );
    final AssistantThread memoFirst = await controller.startNewConversation(
      title: '事记收纳',
    );
    final AssistantThread memoSecond = await controller.startNewConversation(
      title: '事记收纳',
    );
    final AssistantThread dreamAgain = await controller.startNewConversation(
      title: '梦记收纳',
    );

    expect(dreamSecond.id, dreamFirst.id);
    expect(memoSecond.id, memoFirst.id);
    expect(memoFirst.id, isNot(dreamFirst.id));
    expect(dreamAgain.id, dreamFirst.id);

    await assistantRepository.sendUserMessage(
      threadId: memoFirst.id,
      content: '明早记得带伞',
    );
    final AssistantThread memoAfterMessage = await controller
        .startNewConversation(title: '事记收纳');

    expect(memoAfterMessage.id, isNot(memoFirst.id));
    expect(
      assistantRepository.threads
          .where(
            (AssistantThread thread) =>
                thread.title == '梦记收纳' &&
                assistantRepository.messagesForThread(thread.id).isEmpty,
          )
          .length,
      1,
    );
    expect(
      assistantRepository.threads
          .where(
            (AssistantThread thread) =>
                thread.title == '事记收纳' &&
                assistantRepository.messagesForThread(thread.id).isEmpty,
          )
          .length,
      1,
    );
  });

  test(
    'submitPrompt returns busy when the active thread is already streaming',
    () async {
      final InMemoryAssistantRepository assistantRepository =
          InMemoryAssistantRepository(userId: 'assistant-user');
      final AssistantThread thread = await assistantRepository.ensureThread(
        title: 'Tonight',
      );
      await assistantRepository.tryStartThreadTurn(
        threadId: thread.id,
        turnId: 'existing-turn',
      );
      final AssistantConversationController controller =
          AssistantConversationController(
            assistantRepository: assistantRepository,
            sleepCaptureRepository: InMemorySleepCaptureRepository(),
            sleepSessionRepository: InMemorySleepSessionRepository(
              initialUid: 'assistant-user',
            ),
            dormRepository: InMemoryDormRepository(
              currentUserId: 'assistant-user',
            ),
            assistantReplyGateway: const StubAssistantReplyGateway(),
          );

      await controller.bootstrap();

      final AssistantConversationSubmitResult result = await controller
          .submitPrompt('hello');

      expect(result, AssistantConversationSubmitResult.busy);
    },
  );

  test(
    'submitCapturePrompt persists a local capture record when stream does not provide one',
    () async {
      final InMemoryAssistantRepository assistantRepository =
          InMemoryAssistantRepository(userId: 'assistant-user');
      final InMemorySleepCaptureRepository sleepCaptureRepository =
          InMemorySleepCaptureRepository();
      final InMemorySleepSessionRepository sleepSessionRepository =
          InMemorySleepSessionRepository(
            initialUid: 'assistant-user',
            initialSessions: const <SleepSession>[],
          );
      await sleepSessionRepository.startOrResumeSleepSession(
        recommendationSnapshot: const <NightRecommendation>[],
        dormId: 'dorm-204',
        at: DateTime(2026, 4, 22, 23, 0),
      );
      final AssistantConversationController controller =
          AssistantConversationController(
            assistantRepository: assistantRepository,
            sleepCaptureRepository: sleepCaptureRepository,
            sleepSessionRepository: sleepSessionRepository,
            dormRepository: InMemoryDormRepository(
              currentUserId: 'assistant-user',
            ),
            assistantReplyGateway: _CaptureWithoutRecordGateway(),
          );

      await controller.bootstrap();

      final AssistantConversationSubmitResult result = await controller
          .submitCapturePrompt(
            prompt: 'Need to remember this for tomorrow morning',
            captureType: SleepCaptureType.memo,
          );
      await _drainAsyncWork();

      expect(result, AssistantConversationSubmitResult.sent);
      expect(
        sleepCaptureRepository.recordsByType(SleepCaptureType.memo),
        hasLength(1),
      );
      expect(
        sleepCaptureRepository
            .recordsByType(SleepCaptureType.memo)
            .single
            .content,
        'Need to remember this for tomorrow morning',
      );
    },
  );

  test(
    'submitCapturePrompt falls back to active sleep mode session from session list',
    () async {
      final InMemoryAssistantRepository assistantRepository =
          InMemoryAssistantRepository(userId: 'assistant-user');
      final InMemorySleepCaptureRepository sleepCaptureRepository =
          InMemorySleepCaptureRepository();
      final SleepSession session = _sleepModeSession(id: 'session-from-list');
      final AssistantConversationController controller =
          AssistantConversationController(
            assistantRepository: assistantRepository,
            sleepCaptureRepository: sleepCaptureRepository,
            sleepSessionRepository: _ListOnlySleepSessionRepository(session),
            dormRepository: InMemoryDormRepository(
              currentUserId: 'assistant-user',
            ),
            assistantReplyGateway: _CaptureWithoutRecordGateway(),
          );

      await controller.bootstrap();

      final AssistantConversationSubmitResult result = await controller
          .submitCapturePrompt(
            prompt: 'I saw a blue room in the dream',
            captureType: SleepCaptureType.dream,
          );
      await _drainAsyncWork();

      expect(result, AssistantConversationSubmitResult.sent);
      expect(
        sleepCaptureRepository.recordsByType(SleepCaptureType.dream).single,
        isA<SleepCaptureRecord>().having(
          (SleepCaptureRecord record) => record.sessionId,
          'sessionId',
          'session-from-list',
        ),
      );
    },
  );

  test(
    'submitCapturePrompt uses preferred session id when repository lookup is stale',
    () async {
      final InMemoryAssistantRepository assistantRepository =
          InMemoryAssistantRepository(userId: 'assistant-user');
      final InMemorySleepCaptureRepository sleepCaptureRepository =
          InMemorySleepCaptureRepository();
      final AssistantConversationController controller =
          AssistantConversationController(
            assistantRepository: assistantRepository,
            sleepCaptureRepository: sleepCaptureRepository,
            sleepSessionRepository: InMemorySleepSessionRepository(
              initialUid: 'assistant-user',
              initialSessions: const <SleepSession>[],
            ),
            dormRepository: InMemoryDormRepository(
              currentUserId: 'assistant-user',
            ),
            assistantReplyGateway: _CaptureWithoutRecordGateway(),
          );

      await controller.bootstrap();

      final AssistantConversationSubmitResult result = await controller
          .submitCapturePrompt(
            prompt: 'Remember this before I fall asleep',
            captureType: SleepCaptureType.memo,
            preferredSessionId: 'session-from-sleep-mode-route',
          );
      await _drainAsyncWork();

      expect(result, AssistantConversationSubmitResult.sent);
      expect(
        sleepCaptureRepository.recordsByType(SleepCaptureType.memo).single,
        isA<SleepCaptureRecord>().having(
          (SleepCaptureRecord record) => record.sessionId,
          'sessionId',
          'session-from-sleep-mode-route',
        ),
      );
    },
  );

  test(
    'submitCapturePrompt repairs sleep mode session when allowed by sleep mode route',
    () async {
      final InMemoryAssistantRepository assistantRepository =
          InMemoryAssistantRepository(userId: 'assistant-user');
      final InMemorySleepCaptureRepository sleepCaptureRepository =
          InMemorySleepCaptureRepository();
      final InMemorySleepSessionRepository sleepSessionRepository =
          InMemorySleepSessionRepository(
            initialUid: 'assistant-user',
            initialSessions: const <SleepSession>[],
          );
      final AssistantConversationController controller =
          AssistantConversationController(
            assistantRepository: assistantRepository,
            sleepCaptureRepository: sleepCaptureRepository,
            sleepSessionRepository: sleepSessionRepository,
            dormRepository: InMemoryDormRepository(
              currentUserId: 'assistant-user',
            ),
            assistantReplyGateway: _CaptureWithoutRecordGateway(),
          );

      await controller.bootstrap();

      final AssistantConversationSubmitResult result = await controller
          .submitCapturePrompt(
            prompt: 'I need this saved while sleep mode is open',
            captureType: SleepCaptureType.memo,
            allowSessionRepair: true,
          );
      await _drainAsyncWork();

      expect(result, AssistantConversationSubmitResult.sent);
      expect(sleepSessionRepository.activeSession, isNotNull);
      expect(
        sleepCaptureRepository.recordsByType(SleepCaptureType.memo).single,
        isA<SleepCaptureRecord>().having(
          (SleepCaptureRecord record) => record.sessionId,
          'sessionId',
          sleepSessionRepository.activeSession!.id,
        ),
      );
    },
  );
}

Future<void> _drainAsyncWork() async {
  for (int i = 0; i < 6; i += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

SleepSession _sleepModeSession({required String id}) {
  final DateTime startedAt = DateTime(2026, 4, 26, 23, 10);
  return SleepSession(
    id: id,
    uid: 'assistant-user',
    startedAt: startedAt,
    endedAt: null,
    sleepDayKey: '2026-04-26',
    status: SleepSessionStatus.active,
    sleepModeActive: true,
    dormId: 'dorm-204',
    recommendations: const <NightRecommendation>[],
    selectedRecommendationIds: const <String>[],
    segments: <SleepSegment>[SleepSegment(startedAt: startedAt, endedAt: null)],
    trackedDurationMinutes: 0,
    awakenings: const <NightAwakeningEntry>[],
    feedback: const <RecommendationFeedback>[],
    summary: null,
    updatedAt: startedAt,
  );
}

class _ListOnlySleepSessionRepository extends ChangeNotifier
    implements SleepSessionRepository {
  _ListOnlySleepSessionRepository(this._session);

  final SleepSession _session;

  @override
  SleepSession? get activeSession => null;

  @override
  List<SleepSession> get sessions => <SleepSession>[_session];

  @override
  bool get isReadyForSessionLookup => true;

  @override
  SleepSession? get latestAwaitingFeedbackSession => null;

  @override
  Future<List<SleepSession>> archivePastCutoffSessions({
    required DateTime now,
  }) async => const <SleepSession>[];

  @override
  Future<SleepSession?> finishActiveSleepSession({DateTime? at}) async => null;

  @override
  Future<SleepSession?> pauseActiveSleepSession({DateTime? at}) async => null;

  @override
  List<SleepSession> recentSessions({int count = 7}) => sessions;

  @override
  Future<void> saveSession(
    SleepSession session, {
    bool syncRemote = true,
  }) async {}

  @override
  SleepSession? sessionForSleepDayKey(String sleepDayKey) =>
      _session.sleepDayKey == sleepDayKey ? _session : null;

  @override
  List<SleepSession> sessionsForMonth(DateTime month) => sessions;

  @override
  Future<SleepSession> startOrResumeSleepSession({
    required List<NightRecommendation> recommendationSnapshot,
    required String? dormId,
    DateTime? at,
  }) async => _session;
}
