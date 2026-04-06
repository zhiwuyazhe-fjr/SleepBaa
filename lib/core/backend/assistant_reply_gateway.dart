import 'package:cloud_functions/cloud_functions.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

abstract interface class AssistantReplyGateway {
  Future<String> generateReply({
    required String prompt,
    required String threadId,
    required Dorm dorm,
  });
}

class StubAssistantReplyGateway implements AssistantReplyGateway {
  const StubAssistantReplyGateway();

  @override
  Future<String> generateReply({
    required String prompt,
    required String threadId,
    required Dorm dorm,
  }) async {
    final String normalized = prompt.toLowerCase();
    final bool asksAboutNoise =
        normalized.contains('noise') ||
        normalized.contains('loud') ||
        prompt.contains('吵') ||
        prompt.contains('噪') ||
        prompt.contains('声音');
    if (asksAboutNoise) {
      return '宿舍当前大约是 ${dorm.noiseDb} dB。今晚最快的稳定组合还是耳塞加低音量助眠音频，先把环境刺激降下来。';
    }
    final bool asksAboutSleep =
        normalized.contains('sleep') ||
        normalized.contains('can\'t') ||
        normalized.contains('awake') ||
        prompt.contains('睡') ||
        prompt.contains('失眠') ||
        prompt.contains('醒');
    if (asksAboutSleep) {
      return '先把注意力带回呼吸，不要反复看时间。如果大约 20 分钟后还是睡不着，就换成一个短暂的重置仪式，不要硬逼自己入睡。';
    }
    return '我已经把这条记录保存到你的助眠对话里了。结合今晚宿舍状态，下一步最重要的是继续降低刺激，慢慢回到稳定的睡前节奏。';
  }
}

class FirebaseCallableAssistantReplyGateway implements AssistantReplyGateway {
  FirebaseCallableAssistantReplyGateway({
    required FirebaseFunctions functions,
    required AssistantReplyGateway fallback,
  }) : _functions = functions,
       _fallback = fallback;

  final FirebaseFunctions _functions;
  final AssistantReplyGateway _fallback;

  @override
  Future<String> generateReply({
    required String prompt,
    required String threadId,
    required Dorm dorm,
  }) async {
    try {
      final HttpsCallableResult<dynamic> result = await _functions
          .httpsCallable('assistantReply')
          .call(<String, dynamic>{
            'threadId': threadId,
            'prompt': prompt,
            'dorm': <String, dynamic>{
              'id': dorm.id,
              'noiseDb': dorm.noiseDb,
              'quietLabel': dorm.quietLabel,
              'memberCount': dorm.members.length,
            },
          });
      final dynamic data = result.data;
      if (data is Map && data['reply'] is String) {
        final String reply = data['reply'] as String;
        if (reply.trim().isNotEmpty) {
          return reply;
        }
      }
    } catch (_) {
      // Callable integration is optional during local development.
    }
    return _fallback.generateReply(
      prompt: prompt,
      threadId: threadId,
      dorm: dorm,
    );
  }
}
