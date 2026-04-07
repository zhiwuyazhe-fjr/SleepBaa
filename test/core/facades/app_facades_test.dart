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
  Future<AssistantReplyResult> generateReply({
    required String prompt,
    required String threadId,
    required Dorm dorm,
  }) async {
    return const AssistantReplyResult(
      reply: 'Backend reply',
      runId: 'run-1',
      intent: 'general_support',
      updatedSurfaces: <String>['assistant_context'],
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
      final AssistantFacade facade = AssistantFacade(
        authRepository: authRepository,
        assistantRepository: assistantRepository,
        dormRepository: dormRepository,
        assistantReplyGateway: _FakeAssistantGateway(),
      );

      await facade.sendPrompt('Can you help me settle down?');

      final AssistantThread? thread = assistantRepository.currentThread;
      expect(thread, isNotNull);
      final List<AssistantMessage> messages = assistantRepository
          .messagesForThread(thread!.id);
      expect(messages.last.content, 'Backend reply');
      expect(messages.last.role, AssistantMessageRole.assistant);
      facade.dispose();
      authRepository.dispose();
      assistantRepository.dispose();
      dormRepository.dispose();
    },
  );
}
