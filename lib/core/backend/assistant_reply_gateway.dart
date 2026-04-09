import 'package:sleep_dorm_app/core/backend/cloudbase_app_api_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_snapshot_store.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class AssistantReplyResult {
  const AssistantReplyResult({
    required this.reply,
    required this.sourceMode,
    this.runId,
    this.intent,
    this.provider,
    this.model,
    this.assistantMessageId,
    this.errorMessage,
    this.updatedSurfaces = const <String>[],
  });

  final String reply;
  final AssistantReplySourceMode sourceMode;
  final String? runId;
  final String? intent;
  final String? provider;
  final String? model;
  final String? assistantMessageId;
  final String? errorMessage;
  final List<String> updatedSurfaces;
}

abstract interface class AssistantReplyGateway {
  Future<AssistantReplyResult> generateReply({
    required String prompt,
    required String threadId,
    required String clientUserMessageId,
    required String clientAssistantMessageId,
    required Dorm dorm,
  });
}

class StubAssistantReplyGateway implements AssistantReplyGateway {
  const StubAssistantReplyGateway();

  @override
  Future<AssistantReplyResult> generateReply({
    required String prompt,
    required String threadId,
    required String clientUserMessageId,
    required String clientAssistantMessageId,
    required Dorm dorm,
  }) async {
    final String normalized = prompt.toLowerCase();
    if (normalized.contains('noise') || normalized.contains('loud')) {
      return AssistantReplyResult(
        reply: '现在宿舍环境大约 ${dorm.noiseDb} dB，先做一点降噪，再慢慢把节奏放下来。',
        sourceMode: AssistantReplySourceMode.fallbackSuccess,
        intent: 'noise_issue',
        provider: 'stub',
        model: 'rules-local',
      );
    }
    if (normalized.contains('sleep') ||
        normalized.contains('can\'t') ||
        normalized.contains('awake')) {
      return const AssistantReplyResult(
        reply: '先别急着逼自己立刻睡着，先把刺激降下来，再做一个最小的放松动作就够了。',
        sourceMode: AssistantReplySourceMode.fallbackSuccess,
        intent: 'sleep_difficulty',
        provider: 'stub',
        model: 'rules-local',
      );
    }
    return const AssistantReplyResult(
      reply: '我已经记下你现在的状态了，今晚会继续陪你把节奏慢慢稳住。',
      sourceMode: AssistantReplySourceMode.fallbackSuccess,
      intent: 'general_support',
      provider: 'stub',
      model: 'rules-local',
    );
  }
}

class CloudBaseAssistantReplyGateway implements AssistantReplyGateway {
  CloudBaseAssistantReplyGateway({
    required CloudBaseAppApiClient appApiClient,
    required CloudBaseSnapshotStore snapshotStore,
  }) : _appApiClient = appApiClient,
       _snapshotStore = snapshotStore;

  final CloudBaseAppApiClient _appApiClient;
  final CloudBaseSnapshotStore _snapshotStore;

  @override
  Future<AssistantReplyResult> generateReply({
    required String prompt,
    required String threadId,
    required String clientUserMessageId,
    required String clientAssistantMessageId,
    required Dorm dorm,
  }) async {
    try {
      final Map<String, dynamic> data = await _appApiClient.post(
        '/api/assistant/reply',
        body: <String, dynamic>{
          'threadId': threadId,
          'prompt': prompt,
          'clientUserMessageId': clientUserMessageId,
          'clientAssistantMessageId': clientAssistantMessageId,
          'dorm': <String, dynamic>{
            'id': dorm.id,
            'noiseDb': dorm.noiseDb,
            'quietLabel': dorm.quietLabel,
            'memberCount': dorm.members.length,
          },
        },
      );
      final String reply = data['reply'] as String? ?? '';
      if (reply.trim().isNotEmpty) {
        try {
          await _snapshotStore.refresh();
        } catch (_) {
          // Keep the remote reply visible even if snapshot refresh fails.
        }
        return AssistantReplyResult(
          reply: reply,
          sourceMode: _sourceModeFromWire(data['sourceMode']),
          runId: data['runId'] as String?,
          intent: data['intent'] as String?,
          provider: data['provider'] as String?,
          model: data['model'] as String?,
          assistantMessageId: data['assistantMessageId'] as String?,
          errorMessage: data['errorMessage'] as String?,
          updatedSurfaces:
              (data['updatedSurfaces'] as List<dynamic>? ?? const <dynamic>[])
                  .map((dynamic item) => item.toString())
                  .toList(growable: false),
        );
      }
      return AssistantReplyResult(
        reply: '暂时没有收到回复，请稍后再试。',
        sourceMode: AssistantReplySourceMode.error,
      );
    } catch (error) {
      return AssistantReplyResult(
        reply: '暂时没有收到回复，请稍后再试。',
        sourceMode: AssistantReplySourceMode.error,
        errorMessage: error.toString(),
      );
    }
  }
}

AssistantReplySourceMode _sourceModeFromWire(dynamic value) {
  return switch (value) {
    'fallbackSuccess' => AssistantReplySourceMode.fallbackSuccess,
    'error' => AssistantReplySourceMode.error,
    _ => AssistantReplySourceMode.remoteSuccess,
  };
}
