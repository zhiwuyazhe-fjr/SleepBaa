import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/backend/assistant_reply_gateway.dart';
import 'package:sleep_dorm_app/core/data/in_memory_repositories.dart';
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
          InMemorySleepSessionRepository(initialUid: 'assistant-user');
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
}

Future<void> _drainAsyncWork() async {
  for (int i = 0; i < 6; i += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}
