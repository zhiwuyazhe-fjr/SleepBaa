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

class AssistantCaptureResult {
  const AssistantCaptureResult({
    required this.reply,
    required this.sourceMode,
    required this.record,
    required this.recordPersistedRemotely,
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
  final SleepCaptureRecord record;
  final bool recordPersistedRemotely;
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

  Future<AssistantCaptureResult> generateCapture({
    required String prompt,
    required String threadId,
    required String sessionId,
    required SleepCaptureType captureType,
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
    final DateTime now = DateTime.now();
    final String normalized = prompt.trim();
    final String outline = _localCaptureOutline(captureType, normalized);
    return AssistantCaptureResult(
      reply: captureType == SleepCaptureType.dream
          ? '我轻轻帮你收好了这段梦境，等你清醒些时可以再回来补充。'
          : '这段事记我先替你稳稳放好了，之后可以去事记仓库继续整理。',
      sourceMode: AssistantReplySourceMode.fallbackSuccess,
      provider: 'stub',
      model: 'rules-local',
      intent: 'general_support',
      recordPersistedRemotely: false,
      record: SleepCaptureRecord(
        id: 'capture-${now.microsecondsSinceEpoch}',
        type: captureType,
        sessionId: sessionId,
        createdAt: now,
        title: _localCaptureTitle(captureType, now, normalized),
        outline: outline,
        content: normalized,
      ),
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
    try {
      final Map<String, dynamic> data = await _appApiClient.post(
        '/api/assistant/capture',
        body: <String, dynamic>{
          'threadId': threadId,
          'prompt': prompt,
          'sessionId': sessionId,
          'captureType': captureType.name,
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
      final Map<String, dynamic> recordMap = Map<String, dynamic>.from(
        (data['record'] as Map?) ?? const <String, dynamic>{},
      );
      if (reply.trim().isNotEmpty && recordMap.isNotEmpty) {
        try {
          await _snapshotStore.refresh();
        } catch (_) {
          // Keep the remote capture visible even if snapshot refresh fails.
        }
        return AssistantCaptureResult(
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
          record: SleepCaptureRecord(
            id: recordMap['id'] as String? ?? '',
            type: captureType,
            sessionId: recordMap['sessionId'] as String? ?? sessionId,
            createdAt: _dateFromWire(recordMap['createdAt']) ?? DateTime.now(),
            title: recordMap['title'] as String? ?? '',
            outline: recordMap['outline'] as String? ?? '',
            content: recordMap['content'] as String? ?? prompt.trim(),
          ),
          recordPersistedRemotely: true,
        );
      }
      return AssistantCaptureResult(
        reply: '暂时没有收到整理结果，请稍后再试。',
        sourceMode: AssistantReplySourceMode.error,
        errorMessage: data['errorMessage'] as String?,
        record: SleepCaptureRecord(
          id: '',
          type: captureType,
          sessionId: sessionId,
          createdAt: DateTime.now(),
          title: '',
          outline: '',
          content: prompt.trim(),
        ),
        recordPersistedRemotely: false,
      );
    } catch (error) {
      return AssistantCaptureResult(
        reply: '暂时没有收到整理结果，请稍后再试。',
        sourceMode: AssistantReplySourceMode.error,
        errorMessage: error.toString(),
        record: SleepCaptureRecord(
          id: '',
          type: captureType,
          sessionId: sessionId,
          createdAt: DateTime.now(),
          title: '',
          outline: '',
          content: prompt.trim(),
        ),
        recordPersistedRemotely: false,
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

DateTime? _dateFromWire(dynamic value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  if (value is Map) {
    final dynamic seconds = value['_seconds'] ?? value['seconds'];
    final dynamic nanoseconds = value['_nanoseconds'] ?? value['nanoseconds'];
    if (seconds is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        (seconds.toDouble() * 1000).round(),
        isUtc: true,
      ).add(
        Duration(
          microseconds: nanoseconds is num
              ? (nanoseconds.toDouble() / 1000).round()
              : 0,
        ),
      );
    }
  }
  return null;
}

String _localCaptureTitle(
  SleepCaptureType captureType,
  DateTime now,
  String content,
) {
  final String prefix = captureType == SleepCaptureType.dream ? '梦记' : '事记';
  final String hh = now.hour.toString().padLeft(2, '0');
  final String mm = now.minute.toString().padLeft(2, '0');
  final String seed = _truncate(_firstFragment(content), 10);
  return '$prefix $hh:$mm · ${seed.isEmpty ? '新的记录' : seed}';
}

String _localCaptureOutline(SleepCaptureType captureType, String content) {
  final String lead = _truncate(_firstFragment(content), 22);
  if (lead.isEmpty) {
    return captureType == SleepCaptureType.dream
        ? '记录了一段尚待补充的梦境片段。'
        : '记录了一段待整理的夜间事记。';
  }
  return captureType == SleepCaptureType.dream
      ? 'AI整理：梦里重点出现了“$lead”，适合稍后回看情绪和场景。'
      : 'AI整理：这段事记主要围绕“$lead”，可在清醒后继续展开。';
}

String _firstFragment(String content) {
  final List<String> fragments = content
      .split(RegExp(r'[，。！？\n]'))
      .map((String item) => item.trim())
      .where((String item) => item.isNotEmpty)
      .toList(growable: false);
  return fragments.isEmpty ? '' : fragments.first;
}

String _truncate(String text, int maxLength) {
  if (text.length <= maxLength) {
    return text;
  }
  return '${text.substring(0, maxLength)}...';
}
