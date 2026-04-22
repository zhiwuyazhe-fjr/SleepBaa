import 'dart:async';
import 'dart:convert';

import 'package:sleep_dorm_app/core/backend/cloudbase_app_api_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_snapshot_store.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

const String assistantThreadTurnBusyCode = 'THREAD_TURN_BUSY';
const String assistantReplyTimeoutCode = 'ASSISTANT_REPLY_TIMEOUT';

String assistantErrorContentForCode(String? errorCode) {
  switch (errorCode) {
    case assistantThreadTurnBusyCode:
      return '上一条还在处理中，请等它结束后再发。';
    case assistantReplyTimeoutCode:
      return '这次回复超时了，请重试。';
    default:
      return '暂时没有收到回复，请稍后再试。';
  }
}

String assistantErrorHintForCode(String? errorCode) {
  switch (errorCode) {
    case assistantThreadTurnBusyCode:
      return '请等它结束后再发。';
    case assistantReplyTimeoutCode:
      return '这次回复超时了，请直接重试上一条消息。';
    default:
      return '请直接重试上一条消息。';
  }
}

String? assistantErrorCodeFromException(Object error) {
  if (error is CloudBaseAppApiException) {
    return error.code;
  }
  final String text = error.toString();
  if (text.contains(assistantThreadTurnBusyCode)) {
    return assistantThreadTurnBusyCode;
  }
  if (text.contains(assistantReplyTimeoutCode)) {
    return assistantReplyTimeoutCode;
  }
  return null;
}

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
    this.errorCode,
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
  final String? errorCode;
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

enum AssistantStreamEventType {
  ack,
  messageDelta,
  messageCompleted,
  surfacePatch,
  captureRecord,
  memorySynced,
  done,
  error,
}

class AssistantStreamEvent {
  const AssistantStreamEvent({
    required this.type,
    this.delta,
    this.reply,
    this.runId,
    this.intent,
    this.provider,
    this.model,
    this.assistantMessageId,
    this.errorMessage,
    this.errorCode,
    this.sourceMode,
    this.updatedSurfaces = const <String>[],
    this.patch,
    this.record,
    this.count,
    this.backgroundSyncPending,
    this.reconcileAfterMs,
  });

  final AssistantStreamEventType type;
  final String? delta;
  final String? reply;
  final String? runId;
  final String? intent;
  final String? provider;
  final String? model;
  final String? assistantMessageId;
  final String? errorMessage;
  final String? errorCode;
  final AssistantReplySourceMode? sourceMode;
  final List<String> updatedSurfaces;
  final Map<String, dynamic>? patch;
  final SleepCaptureRecord? record;
  final int? count;
  final bool? backgroundSyncPending;
  final int? reconcileAfterMs;
}

abstract interface class AssistantReplyGateway {
  Stream<AssistantStreamEvent> streamReply({
    required String prompt,
    required String threadId,
    required String clientUserMessageId,
    required String clientAssistantMessageId,
    required Dorm dorm,
  });

  Stream<AssistantStreamEvent> streamCapture({
    required String prompt,
    required String threadId,
    required String sessionId,
    required SleepCaptureType captureType,
    required String clientUserMessageId,
    required String clientAssistantMessageId,
    required Dorm dorm,
  });

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
  Stream<AssistantStreamEvent> streamReply({
    required String prompt,
    required String threadId,
    required String clientUserMessageId,
    required String clientAssistantMessageId,
    required Dorm dorm,
  }) async* {
    final AssistantReplyResult result = await generateReply(
      prompt: prompt,
      threadId: threadId,
      clientUserMessageId: clientUserMessageId,
      clientAssistantMessageId: clientAssistantMessageId,
      dorm: dorm,
    );
    yield AssistantStreamEvent(
      type: AssistantStreamEventType.ack,
      assistantMessageId: clientAssistantMessageId,
    );
    yield AssistantStreamEvent(
      type: AssistantStreamEventType.messageDelta,
      delta: result.reply,
    );
    yield AssistantStreamEvent(
      type: AssistantStreamEventType.messageCompleted,
      reply: result.reply,
      runId: result.runId,
      intent: result.intent,
      provider: result.provider,
      model: result.model,
      assistantMessageId: result.assistantMessageId ?? clientAssistantMessageId,
      errorMessage: result.errorMessage,
      sourceMode: result.sourceMode,
      updatedSurfaces: result.updatedSurfaces,
    );
    if (result.updatedSurfaces.isNotEmpty) {
      yield AssistantStreamEvent(
        type: AssistantStreamEventType.surfacePatch,
        updatedSurfaces: result.updatedSurfaces,
      );
    }
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
    final AssistantCaptureResult result = await generateCapture(
      prompt: prompt,
      threadId: threadId,
      sessionId: sessionId,
      captureType: captureType,
      clientUserMessageId: clientUserMessageId,
      clientAssistantMessageId: clientAssistantMessageId,
      dorm: dorm,
    );
    yield AssistantStreamEvent(
      type: AssistantStreamEventType.ack,
      assistantMessageId: clientAssistantMessageId,
    );
    yield AssistantStreamEvent(
      type: AssistantStreamEventType.messageDelta,
      delta: result.reply,
    );
    yield AssistantStreamEvent(
      type: AssistantStreamEventType.messageCompleted,
      reply: result.reply,
      runId: result.runId,
      intent: result.intent,
      provider: result.provider,
      model: result.model,
      assistantMessageId: result.assistantMessageId ?? clientAssistantMessageId,
      errorMessage: result.errorMessage,
      sourceMode: result.sourceMode,
      updatedSurfaces: result.updatedSurfaces,
    );
    if (result.updatedSurfaces.isNotEmpty) {
      yield AssistantStreamEvent(
        type: AssistantStreamEventType.surfacePatch,
        updatedSurfaces: result.updatedSurfaces,
      );
    }
    yield AssistantStreamEvent(
      type: AssistantStreamEventType.captureRecord,
      record: result.record,
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
    final String normalized = prompt.toLowerCase();
    if (normalized.contains('noise') ||
        normalized.contains('loud') ||
        prompt.contains('吵') ||
        prompt.contains('噪')) {
      return AssistantReplyResult(
        reply: '现在宿舍环境大约 ${dorm.noiseDb} dB，先做一点降噪，再慢慢把节奏放下来。',
        sourceMode: AssistantReplySourceMode.fallbackSuccess,
        intent: 'noise_issue',
        provider: 'stub',
        model: 'rules-local',
        updatedSurfaces: const <String>['dorm_quiet', 'sleep_mode'],
      );
    }
    if (normalized.contains('sleep') ||
        normalized.contains('can\'t') ||
        normalized.contains('awake') ||
        prompt.contains('睡不着') ||
        prompt.contains('失眠') ||
        prompt.contains('停不下来') ||
        prompt.contains('累')) {
      return const AssistantReplyResult(
        reply: '先别急着逼自己立刻睡着，先把刺激降下来，再做一个最小的放松动作就够了。',
        sourceMode: AssistantReplySourceMode.fallbackSuccess,
        intent: 'sleep_difficulty',
        provider: 'stub',
        model: 'rules-local',
        updatedSurfaces: <String>['alarm', 'dorm_quiet', 'bedtime_reminder'],
      );
    }
    return const AssistantReplyResult(
      reply: '我已经记下你现在的状态了，今晚会继续陪你把节奏慢慢稳住。',
      sourceMode: AssistantReplySourceMode.fallbackSuccess,
      intent: 'general_support',
      provider: 'stub',
      model: 'rules-local',
      updatedSurfaces: <String>['assistant_context'],
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
      updatedSurfaces: const <String>['assistant_context'],
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
  bool _reconcileQueued = false;
  bool _reconcileInFlight = false;

  @override
  Stream<AssistantStreamEvent> streamReply({
    required String prompt,
    required String threadId,
    required String clientUserMessageId,
    required String clientAssistantMessageId,
    required Dorm dorm,
  }) async* {
    final Map<String, dynamic> requestBody = <String, dynamic>{
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
    };

    for (int attempt = 0; attempt < 2; attempt += 1) {
      bool sawReplyPayload = false;
      AssistantStreamEvent? completedEvent;
      try {
        final Stream<CloudBaseSseFrame> frames = await _appApiClient.postSse(
          '/api/assistant/reply/stream',
          body: requestBody,
        );

        await for (final CloudBaseSseFrame frame in frames) {
          final AssistantStreamEvent event = _assistantEventFromFrame(frame);
          if (event.type == AssistantStreamEventType.messageDelta ||
              event.type == AssistantStreamEventType.messageCompleted) {
            sawReplyPayload = true;
          }
          if (event.type == AssistantStreamEventType.messageCompleted) {
            completedEvent = event;
          }
          if (event.type == AssistantStreamEventType.surfacePatch &&
              event.patch != null) {
            _snapshotStore.applyAssistantSurfacePatch(event.patch!);
          }
          if (event.type == AssistantStreamEventType.done) {
            if (event.backgroundSyncPending == true) {
              _scheduleBackgroundReconcileAttempts(
                _replyReconcileBackoffs(event.reconcileAfterMs),
              );
            }
          }
          yield event;
          if (event.type == AssistantStreamEventType.error ||
              event.type == AssistantStreamEventType.done) {
            return;
          }
        }
        if (completedEvent != null) {
          final AssistantStreamEvent syntheticDone = AssistantStreamEvent(
            type: AssistantStreamEventType.done,
            runId: completedEvent.runId,
            assistantMessageId: completedEvent.assistantMessageId,
            backgroundSyncPending: true,
            reconcileAfterMs: 1500,
          );
          _scheduleBackgroundReconcileAttempts(
            _replyReconcileBackoffs(syntheticDone.reconcileAfterMs),
          );
          yield syntheticDone;
        }
        return;
      } catch (error) {
        if (error is CloudBaseAppApiException &&
            (error.code == assistantThreadTurnBusyCode ||
                error.code == assistantReplyTimeoutCode)) {
          yield AssistantStreamEvent(
            type: AssistantStreamEventType.error,
            errorCode: error.code,
            errorMessage: error.message,
            sourceMode: AssistantReplySourceMode.error,
          );
          return;
        }
        if (completedEvent != null) {
          final AssistantStreamEvent syntheticDone = AssistantStreamEvent(
            type: AssistantStreamEventType.done,
            runId: completedEvent.runId,
            assistantMessageId: completedEvent.assistantMessageId,
            backgroundSyncPending: true,
            reconcileAfterMs: 1500,
          );
          _scheduleBackgroundReconcileAttempts(
            _replyReconcileBackoffs(syntheticDone.reconcileAfterMs),
          );
          yield syntheticDone;
          return;
        }
        final bool canRetry =
            attempt == 0 &&
            !sawReplyPayload &&
            _isRetryableAssistantStreamError(error);
        if (!canRetry) {
          rethrow;
        }
      }
    }
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
    final Map<String, dynamic> requestBody = <String, dynamic>{
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
    };

    for (int attempt = 0; attempt < 2; attempt += 1) {
      bool sawSurfacePatch = false;
      bool sawReplyPayload = false;
      try {
        final Stream<CloudBaseSseFrame> frames = await _appApiClient.postSse(
          '/api/assistant/capture/stream',
          body: requestBody,
        );

        await for (final CloudBaseSseFrame frame in frames) {
          final AssistantStreamEvent event = _assistantEventFromFrame(
            frame,
            fallbackCaptureType: captureType,
            fallbackSessionId: sessionId,
          );
          if (event.type == AssistantStreamEventType.messageDelta ||
              event.type == AssistantStreamEventType.messageCompleted) {
            sawReplyPayload = true;
          }
          if (event.type == AssistantStreamEventType.surfacePatch &&
              event.patch != null) {
            sawSurfacePatch = true;
            _snapshotStore.applyAssistantSurfacePatch(event.patch!);
          }
          if (event.type == AssistantStreamEventType.captureRecord &&
              event.record != null) {
            _snapshotStore.upsertSleepCaptureRecord(
              _sleepCaptureRecordToMap(event.record!),
            );
          }
          if (event.type == AssistantStreamEventType.done) {
            _scheduleBackgroundReconcile(
              delay: sawSurfacePatch
                  ? const Duration(milliseconds: 1600)
                  : const Duration(milliseconds: 250),
            );
          }
          yield event;
          if (event.type == AssistantStreamEventType.error ||
              event.type == AssistantStreamEventType.done) {
            return;
          }
        }
        return;
      } catch (error) {
        if (error is CloudBaseAppApiException &&
            error.code == 'THREAD_TURN_BUSY') {
          yield AssistantStreamEvent(
            type: AssistantStreamEventType.error,
            errorCode: error.code,
            errorMessage: error.message,
            sourceMode: AssistantReplySourceMode.error,
          );
          return;
        }
        final bool canRetry =
            attempt == 0 &&
            !sawReplyPayload &&
            _isRetryableAssistantStreamError(error);
        if (!canRetry) {
          rethrow;
        }
      }
    }
  }

  @override
  Future<AssistantReplyResult> generateReply({
    required String prompt,
    required String threadId,
    required String clientUserMessageId,
    required String clientAssistantMessageId,
    required Dorm dorm,
  }) async {
    String replyBuffer = '';
    AssistantReplyResult? completed;

    await for (final AssistantStreamEvent event in streamReply(
      prompt: prompt,
      threadId: threadId,
      clientUserMessageId: clientUserMessageId,
      clientAssistantMessageId: clientAssistantMessageId,
      dorm: dorm,
    )) {
      switch (event.type) {
        case AssistantStreamEventType.messageDelta:
          replyBuffer += event.delta ?? '';
          break;
        case AssistantStreamEventType.messageCompleted:
          completed = AssistantReplyResult(
            reply: event.reply ?? replyBuffer,
            sourceMode:
                event.sourceMode ?? AssistantReplySourceMode.remoteSuccess,
            runId: event.runId,
            intent: event.intent,
            provider: event.provider,
            model: event.model,
            assistantMessageId: event.assistantMessageId,
            errorMessage: event.errorMessage,
            errorCode: event.errorCode,
            updatedSurfaces: event.updatedSurfaces,
          );
          break;
        case AssistantStreamEventType.error:
          return AssistantReplyResult(
            reply: assistantErrorContentForCode(event.errorCode),
            sourceMode: AssistantReplySourceMode.error,
            errorMessage: event.errorMessage,
            errorCode: event.errorCode,
          );
        case AssistantStreamEventType.ack:
        case AssistantStreamEventType.surfacePatch:
        case AssistantStreamEventType.captureRecord:
        case AssistantStreamEventType.memorySynced:
        case AssistantStreamEventType.done:
          break;
      }
    }

    return completed ??
        AssistantReplyResult(
          reply: replyBuffer.isEmpty
              ? assistantErrorContentForCode(null)
              : replyBuffer,
          sourceMode: AssistantReplySourceMode.error,
          errorMessage: 'reply stream ended before completion',
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
    String replyBuffer = '';
    AssistantCaptureResult? completed;
    SleepCaptureRecord? record;

    await for (final AssistantStreamEvent event in streamCapture(
      prompt: prompt,
      threadId: threadId,
      sessionId: sessionId,
      captureType: captureType,
      clientUserMessageId: clientUserMessageId,
      clientAssistantMessageId: clientAssistantMessageId,
      dorm: dorm,
    )) {
      switch (event.type) {
        case AssistantStreamEventType.messageDelta:
          replyBuffer += event.delta ?? '';
          break;
        case AssistantStreamEventType.messageCompleted:
          completed = AssistantCaptureResult(
            reply: event.reply ?? replyBuffer,
            sourceMode:
                event.sourceMode ?? AssistantReplySourceMode.remoteSuccess,
            record:
                record ??
                SleepCaptureRecord(
                  id: '',
                  type: captureType,
                  sessionId: sessionId,
                  createdAt: DateTime.now(),
                  title: '',
                  outline: '',
                  content: prompt.trim(),
                ),
            recordPersistedRemotely: record != null,
            runId: event.runId,
            intent: event.intent,
            provider: event.provider,
            model: event.model,
            assistantMessageId: event.assistantMessageId,
            errorMessage: event.errorMessage,
            updatedSurfaces: event.updatedSurfaces,
          );
          break;
        case AssistantStreamEventType.captureRecord:
          record = event.record;
          if (completed != null && record != null) {
            completed = AssistantCaptureResult(
              reply: completed.reply,
              sourceMode: completed.sourceMode,
              record: record,
              recordPersistedRemotely: true,
              runId: completed.runId,
              intent: completed.intent,
              provider: completed.provider,
              model: completed.model,
              assistantMessageId: completed.assistantMessageId,
              errorMessage: completed.errorMessage,
              updatedSurfaces: completed.updatedSurfaces,
            );
          }
          break;
        case AssistantStreamEventType.error:
          return AssistantCaptureResult(
            reply: '暂时没有收到整理结果，请稍后再试。',
            sourceMode: AssistantReplySourceMode.error,
            errorMessage: event.errorMessage,
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
        case AssistantStreamEventType.ack:
        case AssistantStreamEventType.surfacePatch:
        case AssistantStreamEventType.memorySynced:
        case AssistantStreamEventType.done:
          break;
      }
    }

    return completed ??
        AssistantCaptureResult(
          reply: replyBuffer.isEmpty ? '暂时没有收到整理结果，请稍后再试。' : replyBuffer,
          sourceMode: AssistantReplySourceMode.error,
          errorMessage: 'capture stream ended before completion',
          record:
              record ??
              SleepCaptureRecord(
                id: '',
                type: captureType,
                sessionId: sessionId,
                createdAt: DateTime.now(),
                title: '',
                outline: '',
                content: prompt.trim(),
              ),
          recordPersistedRemotely: record != null,
        );
  }

  void _scheduleBackgroundReconcile({required Duration delay}) {
    unawaited(
      Future<void>.delayed(delay, () async {
        _reconcileQueued = true;
        await _backgroundReconcile();
      }),
    );
  }

  void _scheduleBackgroundReconcileAttempts(List<Duration> delays) {
    for (final Duration delay in delays) {
      _scheduleBackgroundReconcile(delay: delay);
    }
  }

  Future<void> _backgroundReconcile() async {
    if (_reconcileInFlight) {
      return;
    }
    _reconcileInFlight = true;
    try {
      while (_reconcileQueued) {
        _reconcileQueued = false;
        try {
          await _snapshotStore.refresh();
        } catch (_) {
          // Keep the streamed UI visible even if background reconcile fails.
        }
      }
    } finally {
      _reconcileInFlight = false;
    }
  }
}

List<Duration> _replyReconcileBackoffs(int? firstDelayMs) {
  final int initialMs = firstDelayMs != null && firstDelayMs > 0
      ? firstDelayMs
      : 1500;
  return <Duration>[
    Duration(milliseconds: initialMs),
    const Duration(milliseconds: 4000),
    const Duration(milliseconds: 8000),
  ];
}

AssistantStreamEvent _assistantEventFromFrame(
  CloudBaseSseFrame frame, {
  SleepCaptureType? fallbackCaptureType,
  String? fallbackSessionId,
}) {
  final Map<String, dynamic> data = _decodeStreamPayload(frame.data);
  switch (frame.event) {
    case 'ack':
      return AssistantStreamEvent(
        type: AssistantStreamEventType.ack,
        assistantMessageId: data['assistantMessageId'] as String?,
      );
    case 'message_delta':
      return AssistantStreamEvent(
        type: AssistantStreamEventType.messageDelta,
        delta: data['delta'] as String? ?? '',
      );
    case 'message_completed':
      return AssistantStreamEvent(
        type: AssistantStreamEventType.messageCompleted,
        reply: data['reply'] as String?,
        runId: data['runId'] as String?,
        intent: data['intent'] as String?,
        provider: data['provider'] as String?,
        model: data['model'] as String?,
        assistantMessageId: data['assistantMessageId'] as String?,
        errorMessage: data['errorMessage'] as String?,
        sourceMode: _sourceModeFromWire(data['sourceMode']),
        updatedSurfaces: _stringList(data['updatedSurfaces']),
      );
    case 'surface_patch':
      return AssistantStreamEvent(
        type: AssistantStreamEventType.surfacePatch,
        patch: _mapOf(data['patch']),
        updatedSurfaces: _stringList(data['updatedSurfaces']),
      );
    case 'capture_record':
      return AssistantStreamEvent(
        type: AssistantStreamEventType.captureRecord,
        record: _sleepCaptureRecordFromMap(
          _mapOf(data['record']),
          fallbackCaptureType: fallbackCaptureType,
          fallbackSessionId: fallbackSessionId,
        ),
      );
    case 'memory_synced':
      return AssistantStreamEvent(
        type: AssistantStreamEventType.memorySynced,
        count: (data['count'] as num?)?.toInt(),
      );
    case 'done':
      return AssistantStreamEvent(
        type: AssistantStreamEventType.done,
        runId: data['runId'] as String?,
        assistantMessageId: data['assistantMessageId'] as String?,
        backgroundSyncPending: data['backgroundSyncPending'] as bool?,
        reconcileAfterMs: (data['reconcileAfterMs'] as num?)?.toInt(),
      );
    case 'error':
      return AssistantStreamEvent(
        type: AssistantStreamEventType.error,
        errorCode: data['code'] as String?,
        errorMessage:
            data['message'] as String? ??
            data['error'] as String? ??
            frame.data,
        sourceMode: AssistantReplySourceMode.error,
      );
    default:
      return AssistantStreamEvent(
        type: AssistantStreamEventType.error,
        errorMessage: 'unknown stream event: ${frame.event}',
        sourceMode: AssistantReplySourceMode.error,
      );
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

Map<String, dynamic> _decodeStreamPayload(String data) {
  if (data.trim().isEmpty) {
    return <String, dynamic>{};
  }
  try {
    final Object? decoded = jsonDecode(data);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return <String, dynamic>{'value': decoded};
  } catch (_) {
    return <String, dynamic>{'message': data};
  }
}

bool _isRetryableAssistantStreamError(Object error) {
  if (error is TimeoutException) {
    return true;
  }
  if (error is CloudBaseAppApiException) {
    final int? statusCode = error.statusCode;
    if (statusCode != null &&
        (statusCode == 408 ||
            statusCode == 425 ||
            statusCode == 429 ||
            statusCode >= 500)) {
      return true;
    }
  }
  final String message = error.toString().toLowerCase();
  return message.contains('aborted') ||
      message.contains('connection closed') ||
      message.contains('connection reset') ||
      message.contains('socket') ||
      message.contains('broken pipe') ||
      message.contains('eof') ||
      message.contains('http/2') ||
      message.contains('clientexception');
}

Map<String, dynamic> _mapOf(dynamic value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

List<String> _stringList(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }
  return value.map((dynamic item) => item.toString()).toList(growable: false);
}

SleepCaptureRecord _sleepCaptureRecordFromMap(
  Map<String, dynamic> map, {
  SleepCaptureType? fallbackCaptureType,
  String? fallbackSessionId,
}) {
  return SleepCaptureRecord(
    id: map['id'] as String? ?? '',
    type: _captureTypeFromWire(map['type'], fallbackCaptureType),
    sessionId: map['sessionId'] as String? ?? fallbackSessionId ?? '',
    createdAt: _dateFromWire(map['createdAt']) ?? DateTime.now(),
    title: map['title'] as String? ?? '',
    outline: map['outline'] as String? ?? '',
    content: map['content'] as String? ?? '',
  );
}

SleepCaptureType _captureTypeFromWire(
  dynamic value,
  SleepCaptureType? fallback,
) {
  return switch (value) {
    'memo' => SleepCaptureType.memo,
    'dream' => SleepCaptureType.dream,
    _ => fallback ?? SleepCaptureType.memo,
  };
}

Map<String, dynamic> _sleepCaptureRecordToMap(SleepCaptureRecord record) {
  return <String, dynamic>{
    'id': record.id,
    'type': record.type.name,
    'sessionId': record.sessionId,
    'createdAt': record.createdAt.toIso8601String(),
    'title': record.title,
    'outline': record.outline,
    'content': record.content,
  };
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
