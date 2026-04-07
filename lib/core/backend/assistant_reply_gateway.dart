import 'package:sleep_dorm_app/core/backend/cloudbase_app_api_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_snapshot_store.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class AssistantReplyResult {
  const AssistantReplyResult({
    required this.reply,
    this.runId,
    this.intent,
    this.provider,
    this.model,
    this.updatedSurfaces = const <String>[],
  });

  final String reply;
  final String? runId;
  final String? intent;
  final String? provider;
  final String? model;
  final List<String> updatedSurfaces;
}

abstract interface class AssistantReplyGateway {
  Future<AssistantReplyResult> generateReply({
    required String prompt,
    required String threadId,
    required Dorm dorm,
  });
}

class StubAssistantReplyGateway implements AssistantReplyGateway {
  const StubAssistantReplyGateway();

  @override
  Future<AssistantReplyResult> generateReply({
    required String prompt,
    required String threadId,
    required Dorm dorm,
  }) async {
    final String normalized = prompt.toLowerCase();
    if (normalized.contains('noise') || normalized.contains('loud')) {
      return AssistantReplyResult(
        reply: '现在宿舍环境大约 ${dorm.noiseDb} dB，先戴上耳塞，再配合一段低刺激的助眠音频，不要急着强迫自己马上睡着。',
        intent: 'noise_issue',
        provider: 'stub',
        model: 'rules-local',
      );
    }
    if (normalized.contains('sleep') ||
        normalized.contains('can\'t') ||
        normalized.contains('awake')) {
      return const AssistantReplyResult(
        reply: '先别逼自己立刻睡着，尽量远离时间压力，把刺激降下来，再从今晚建议里挑一个最小动作重新收束节奏。',
        intent: 'sleep_difficulty',
        provider: 'stub',
        model: 'rules-local',
      );
    }
    return const AssistantReplyResult(
      reply: '我已经记下你的情况，今晚会继续围绕低刺激、可重复执行的小步骤来陪你推进。',
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
    required AssistantReplyGateway fallback,
  }) : _appApiClient = appApiClient,
       _snapshotStore = snapshotStore,
       _fallback = fallback;

  final CloudBaseAppApiClient _appApiClient;
  final CloudBaseSnapshotStore _snapshotStore;
  final AssistantReplyGateway _fallback;

  @override
  Future<AssistantReplyResult> generateReply({
    required String prompt,
    required String threadId,
    required Dorm dorm,
  }) async {
    try {
      final Map<String, dynamic> data = await _appApiClient.post(
        '/api/assistant/reply',
        body: <String, dynamic>{
          'threadId': threadId,
          'prompt': prompt,
          'dorm': <String, dynamic>{
            'id': dorm.id,
            'noiseDb': dorm.noiseDb,
            'quietLabel': dorm.quietLabel,
            'memberCount': dorm.members.length,
          },
        },
      );
      if (data['reply'] is String) {
        final String reply = data['reply'] as String;
        if (reply.trim().isNotEmpty) {
          await _snapshotStore.refresh();
          return AssistantReplyResult(
            reply: reply,
            runId: data['runId'] as String?,
            intent: data['intent'] as String?,
            provider: data['provider'] as String?,
            model: data['model'] as String?,
            updatedSurfaces:
                (data['updatedSurfaces'] as List<dynamic>? ?? const <dynamic>[])
                    .map((dynamic item) => item.toString())
                    .toList(growable: false),
          );
        }
      }
    } catch (_) {
      // CloudBase assistant integration is optional during local development.
    }
    return _fallback.generateReply(
      prompt: prompt,
      threadId: threadId,
      dorm: dorm,
    );
  }
}
