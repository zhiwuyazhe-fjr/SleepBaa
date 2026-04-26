import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sleep_dorm_app/core/backend/assistant_reply_gateway.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/utils/id_generator.dart';

enum AssistantConversationSubmitResult {
  sent,
  empty,
  busy,
  missingActiveSession,
}

class AssistantConversationController extends ChangeNotifier {
  AssistantConversationController({
    required AssistantRepository assistantRepository,
    required SleepCaptureRepository sleepCaptureRepository,
    required SleepSessionRepository sleepSessionRepository,
    required DormRepository dormRepository,
    required AssistantReplyGateway assistantReplyGateway,
  }) : _assistantRepository = assistantRepository,
       _sleepCaptureRepository = sleepCaptureRepository,
       _sleepSessionRepository = sleepSessionRepository,
       _dormRepository = dormRepository,
       _assistantReplyGateway = assistantReplyGateway {
    _assistantRepository.addListener(_relayState);
  }

  final AssistantRepository _assistantRepository;
  final SleepCaptureRepository _sleepCaptureRepository;
  final SleepSessionRepository _sleepSessionRepository;
  final DormRepository _dormRepository;
  final AssistantReplyGateway _assistantReplyGateway;
  final Map<String, List<String>> _updatedSurfacesByMessageId =
      <String, List<String>>{};

  AssistantThread? get currentThread => _assistantRepository.currentThread;

  List<AssistantMessage> get currentMessages {
    final AssistantThread? thread = currentThread;
    if (thread == null) {
      return const <AssistantMessage>[];
    }
    return _assistantRepository.messagesForThread(thread.id);
  }

  AssistantThreadTurnState? get turnState {
    final AssistantThread? thread = currentThread;
    if (thread == null) {
      return null;
    }
    return _assistantRepository.turnStateForThread(thread.id);
  }

  bool get isBusy =>
      turnState != null && turnState!.status != AssistantThreadTurnStatus.idle;

  List<String> updatedSurfacesForMessage(String? messageId) {
    if (messageId == null || messageId.trim().isEmpty) {
      return const <String>[];
    }
    return List<String>.unmodifiable(
      _updatedSurfacesByMessageId[messageId] ?? const <String>[],
    );
  }

  String? get latestUserPrompt {
    for (final AssistantMessage message in currentMessages.reversed) {
      if (message.role == AssistantMessageRole.user &&
          message.content.trim().isNotEmpty) {
        return message.content;
      }
    }
    return null;
  }

  Future<void> bootstrap() => _assistantRepository.selectMostRecentThread();

  Future<void> setCurrentThread(String threadId) {
    return _assistantRepository.setCurrentThread(threadId);
  }

  Future<AssistantConversationSubmitResult> submitPrompt(String prompt) async {
    final String normalizedPrompt = prompt.trim();
    if (normalizedPrompt.isEmpty) {
      return AssistantConversationSubmitResult.empty;
    }

    final _PreparedThreadTurn? prepared = await _prepareThreadTurn(
      title: '今晚睡前聊聊',
    );
    if (prepared == null) {
      return AssistantConversationSubmitResult.busy;
    }

    unawaited(
      _sendReplyStream(
        selectedThread: prepared.thread,
        turnId: prepared.turnId,
        prompt: normalizedPrompt,
      ),
    );
    return AssistantConversationSubmitResult.sent;
  }

  Future<AssistantConversationSubmitResult> submitCapturePrompt({
    required String prompt,
    required SleepCaptureType captureType,
    String? preferredSessionId,
    bool allowSessionRepair = false,
  }) async {
    final String normalizedPrompt = prompt.trim();
    if (normalizedPrompt.isEmpty) {
      return AssistantConversationSubmitResult.empty;
    }

    final SleepSession? activeSleepModeSession = _resolveActiveSleepModeSession(
      preferredSessionId: preferredSessionId,
    );
    final String? activeSessionId =
        activeSleepModeSession?.id ??
        _normalizedSessionId(preferredSessionId) ??
        await _repairSleepModeSessionIdIfAllowed(allowSessionRepair);
    if (activeSessionId == null || activeSessionId.isEmpty) {
      return AssistantConversationSubmitResult.missingActiveSession;
    }

    final _PreparedThreadTurn? prepared = await _prepareThreadTurn(
      title: captureType == SleepCaptureType.dream ? '梦记收纳' : '事记收纳',
    );
    if (prepared == null) {
      return AssistantConversationSubmitResult.busy;
    }

    unawaited(
      _sendCaptureStream(
        selectedThread: prepared.thread,
        turnId: prepared.turnId,
        prompt: normalizedPrompt,
        captureType: captureType,
        sessionId: activeSessionId,
      ),
    );
    return AssistantConversationSubmitResult.sent;
  }

  SleepSession? _resolveActiveSleepModeSession({String? preferredSessionId}) {
    final String? normalizedPreferredSessionId = _normalizedSessionId(
      preferredSessionId,
    );
    final SleepSession? activeSession = _sleepSessionRepository.activeSession;
    if (_canCaptureIntoSleepModeSession(
      activeSession,
      preferredSessionId: normalizedPreferredSessionId,
    )) {
      return activeSession;
    }

    for (final SleepSession session
        in _sleepSessionRepository.sessions.reversed) {
      if (_canCaptureIntoSleepModeSession(
        session,
        preferredSessionId: normalizedPreferredSessionId,
      )) {
        return session;
      }
    }
    return null;
  }

  bool _canCaptureIntoSleepModeSession(
    SleepSession? session, {
    String? preferredSessionId,
  }) {
    if (session == null) {
      return false;
    }
    if (preferredSessionId != null && session.id != preferredSessionId) {
      return false;
    }
    return session.status == SleepSessionStatus.active &&
        session.sleepModeActive &&
        session.endedAt == null;
  }

  String? _normalizedSessionId(String? sessionId) {
    final String normalized = sessionId?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  Future<String?> _repairSleepModeSessionIdIfAllowed(bool allowRepair) async {
    if (!allowRepair) {
      return null;
    }
    final SleepSession repaired = await _sleepSessionRepository
        .startOrResumeSleepSession(
          recommendationSnapshot: const <NightRecommendation>[],
          dormId: _dormRepository.currentDorm.id,
        );
    return repaired.id.trim().isEmpty ? null : repaired.id;
  }

  Future<AssistantConversationSubmitResult> retryLatestPrompt({
    required bool captureModeEnabled,
    required SleepCaptureType captureType,
  }) async {
    final String? prompt = latestUserPrompt;
    if (prompt == null || prompt.trim().isEmpty) {
      return AssistantConversationSubmitResult.empty;
    }
    if (!captureModeEnabled) {
      return submitPrompt(prompt);
    }
    return submitCapturePrompt(prompt: prompt, captureType: captureType);
  }

  Future<_PreparedThreadTurn?> _prepareThreadTurn({
    required String title,
  }) async {
    final AssistantThread thread = await _assistantRepository.ensureThread(
      title: title,
    );
    await _assistantRepository.setCurrentThread(thread.id);
    final String turnId = IdGenerator.next('assistant-turn');
    final bool started = await _assistantRepository.tryStartThreadTurn(
      threadId: thread.id,
      turnId: turnId,
    );
    if (!started) {
      return null;
    }
    return _PreparedThreadTurn(thread: thread, turnId: turnId);
  }

  Future<void> _sendReplyStream({
    required AssistantThread selectedThread,
    required String turnId,
    required String prompt,
  }) async {
    final String clientUserMessageId = IdGenerator.next('assistant-msg-user');
    final String clientAssistantMessageId = IdGenerator.next(
      'assistant-msg-assistant',
    );
    await _assistantRepository.sendUserMessage(
      threadId: selectedThread.id,
      content: prompt,
      messageId: clientUserMessageId,
    );
    await _assistantRepository.addAssistantMessage(
      threadId: selectedThread.id,
      content: '小眠正在整理回复...',
      messageId: clientAssistantMessageId,
      status: AssistantMessageStatus.pending,
    );

    bool turnFinished = false;

    Future<void> finishTurn() async {
      if (turnFinished) {
        return;
      }
      turnFinished = true;
      await _assistantRepository.finishThreadTurn(
        threadId: selectedThread.id,
        turnId: turnId,
      );
    }

    try {
      String bufferedReply = '';
      bool completed = false;
      String resolvedAssistantMessageId = clientAssistantMessageId;
      await for (final AssistantStreamEvent event
          in _assistantReplyGateway.streamReply(
            prompt: prompt,
            threadId: selectedThread.id,
            clientUserMessageId: clientUserMessageId,
            clientAssistantMessageId: clientAssistantMessageId,
            dorm: _dormRepository.currentDorm,
          )) {
        switch (event.type) {
          case AssistantStreamEventType.messageDelta:
            bufferedReply += event.delta ?? '';
            await _assistantRepository.updateAssistantMessage(
              threadId: selectedThread.id,
              messageId: clientAssistantMessageId,
              content: bufferedReply,
              status: AssistantMessageStatus.pending,
            );
            break;
          case AssistantStreamEventType.messageCompleted:
            completed = true;
            await _assistantRepository.markThreadTurnFinalizing(
              threadId: selectedThread.id,
              turnId: turnId,
            );
            resolvedAssistantMessageId = await _upsertAssistantReply(
              threadId: selectedThread.id,
              defaultMessageId: clientAssistantMessageId,
              reply: event.reply ?? bufferedReply,
              sourceMode:
                  event.sourceMode ?? AssistantReplySourceMode.remoteSuccess,
              provider: event.provider,
              model: event.model,
              errorMessage: event.errorMessage,
              assistantMessageId:
                  event.assistantMessageId ?? clientAssistantMessageId,
            );
            _recordUpdatedSurfaces(
              messageIds: <String?>[
                resolvedAssistantMessageId,
                clientAssistantMessageId,
                event.assistantMessageId,
              ],
              surfaceIds: event.updatedSurfaces,
            );
            break;
          case AssistantStreamEventType.error:
            completed = true;
            await _setAssistantError(
              threadId: selectedThread.id,
              messageId: clientAssistantMessageId,
              error: event.errorMessage ?? 'stream error',
              errorCode: event.errorCode,
            );
            await finishTurn();
            break;
          case AssistantStreamEventType.ack:
          case AssistantStreamEventType.captureRecord:
          case AssistantStreamEventType.memorySynced:
            break;
          case AssistantStreamEventType.surfacePatch:
            _recordUpdatedSurfaces(
              messageIds: <String?>[
                resolvedAssistantMessageId,
                clientAssistantMessageId,
              ],
              surfaceIds: event.updatedSurfaces,
            );
            break;
          case AssistantStreamEventType.done:
            await finishTurn();
            break;
        }
      }

      if (!completed) {
        await _setAssistantError(
          threadId: selectedThread.id,
          messageId: clientAssistantMessageId,
          error: 'reply stream ended before completion',
        );
      }
    } catch (error) {
      await _setAssistantError(
        threadId: selectedThread.id,
        messageId: clientAssistantMessageId,
        error: error,
        errorCode: assistantErrorCodeFromException(error),
      );
    } finally {
      await finishTurn();
    }
  }

  Future<void> _sendCaptureStream({
    required AssistantThread selectedThread,
    required String turnId,
    required String prompt,
    required SleepCaptureType captureType,
    required String sessionId,
  }) async {
    final String clientUserMessageId = IdGenerator.next('assistant-msg-user');
    final String clientAssistantMessageId = IdGenerator.next(
      'assistant-msg-assistant',
    );
    await _assistantRepository.sendUserMessage(
      threadId: selectedThread.id,
      content: prompt,
      messageId: clientUserMessageId,
    );
    await _assistantRepository.addAssistantMessage(
      threadId: selectedThread.id,
      content: '小眠正在整理这段记录...',
      messageId: clientAssistantMessageId,
      status: AssistantMessageStatus.pending,
    );

    bool turnFinished = false;

    Future<void> finishTurn() async {
      if (turnFinished) {
        return;
      }
      turnFinished = true;
      await _assistantRepository.finishThreadTurn(
        threadId: selectedThread.id,
        turnId: turnId,
      );
    }

    try {
      String bufferedReply = '';
      SleepCaptureRecord? streamedRecord;
      bool completed = false;
      String resolvedAssistantMessageId = clientAssistantMessageId;
      await for (final AssistantStreamEvent event
          in _assistantReplyGateway.streamCapture(
            prompt: prompt,
            threadId: selectedThread.id,
            sessionId: sessionId,
            captureType: captureType,
            clientUserMessageId: clientUserMessageId,
            clientAssistantMessageId: clientAssistantMessageId,
            dorm: _dormRepository.currentDorm,
          )) {
        switch (event.type) {
          case AssistantStreamEventType.messageDelta:
            bufferedReply += event.delta ?? '';
            await _assistantRepository.updateAssistantMessage(
              threadId: selectedThread.id,
              messageId: clientAssistantMessageId,
              content: bufferedReply,
              status: AssistantMessageStatus.pending,
            );
            break;
          case AssistantStreamEventType.captureRecord:
            streamedRecord = event.record;
            break;
          case AssistantStreamEventType.messageCompleted:
            completed = true;
            await _assistantRepository.markThreadTurnFinalizing(
              threadId: selectedThread.id,
              turnId: turnId,
            );
            streamedRecord ??= await _sleepCaptureRepository.addRecord(
              type: captureType,
              sessionId: sessionId,
              content: prompt,
            );
            resolvedAssistantMessageId = await _upsertAssistantReply(
              threadId: selectedThread.id,
              defaultMessageId: clientAssistantMessageId,
              reply: event.reply ?? bufferedReply,
              sourceMode:
                  event.sourceMode ?? AssistantReplySourceMode.remoteSuccess,
              provider: event.provider,
              model: event.model,
              errorMessage: event.errorMessage,
              assistantMessageId:
                  event.assistantMessageId ?? clientAssistantMessageId,
            );
            _recordUpdatedSurfaces(
              messageIds: <String?>[
                resolvedAssistantMessageId,
                clientAssistantMessageId,
                event.assistantMessageId,
              ],
              surfaceIds: event.updatedSurfaces,
            );
            break;
          case AssistantStreamEventType.error:
            completed = true;
            await _setAssistantError(
              threadId: selectedThread.id,
              messageId: clientAssistantMessageId,
              error: event.errorMessage ?? 'stream error',
              errorCode: event.errorCode,
            );
            await finishTurn();
            break;
          case AssistantStreamEventType.ack:
          case AssistantStreamEventType.memorySynced:
            break;
          case AssistantStreamEventType.surfacePatch:
            _recordUpdatedSurfaces(
              messageIds: <String?>[
                resolvedAssistantMessageId,
                clientAssistantMessageId,
              ],
              surfaceIds: event.updatedSurfaces,
            );
            break;
          case AssistantStreamEventType.done:
            await finishTurn();
            break;
        }
      }

      if (!completed) {
        await _setAssistantError(
          threadId: selectedThread.id,
          messageId: clientAssistantMessageId,
          error: 'capture stream ended before completion',
        );
      }
    } catch (error) {
      await _setAssistantError(
        threadId: selectedThread.id,
        messageId: clientAssistantMessageId,
        error: error,
        errorCode: assistantErrorCodeFromException(error),
      );
    } finally {
      await finishTurn();
    }
  }

  Future<String> _upsertAssistantReply({
    required String threadId,
    required String defaultMessageId,
    required String reply,
    required AssistantReplySourceMode sourceMode,
    required String? provider,
    required String? model,
    required String? errorMessage,
    String? assistantMessageId,
  }) async {
    final List<AssistantMessage> existingMessages = _assistantRepository
        .messagesForThread(threadId);
    final String? remoteMessageId = assistantMessageId;
    final bool hasRemoteMessage =
        remoteMessageId != null &&
        existingMessages.any(
          (AssistantMessage item) => item.id == remoteMessageId,
        );
    final bool hasDefaultMessage = existingMessages.any(
      (AssistantMessage item) => item.id == defaultMessageId,
    );
    final String nextMessageId;
    if (remoteMessageId != null && hasRemoteMessage) {
      nextMessageId = remoteMessageId;
    } else if (hasDefaultMessage) {
      nextMessageId = defaultMessageId;
    } else {
      nextMessageId = remoteMessageId ?? defaultMessageId;
    }
    final String? nextErrorMessage =
        sourceMode == AssistantReplySourceMode.error
        ? '请直接重试上一条消息。'
        : errorMessage;
    if (existingMessages.any(
      (AssistantMessage item) => item.id == nextMessageId,
    )) {
      await _assistantRepository.updateAssistantMessage(
        threadId: threadId,
        messageId: nextMessageId,
        content: reply,
        status: sourceMode == AssistantReplySourceMode.error
            ? AssistantMessageStatus.error
            : AssistantMessageStatus.complete,
        sourceMode: sourceMode,
        provider: provider,
        model: model,
        errorMessage: nextErrorMessage,
      );
      return nextMessageId;
    }
    await _assistantRepository.addAssistantMessage(
      threadId: threadId,
      content: reply,
      messageId: nextMessageId,
      status: sourceMode == AssistantReplySourceMode.error
          ? AssistantMessageStatus.error
          : AssistantMessageStatus.complete,
      sourceMode: sourceMode,
      provider: provider,
      model: model,
      errorMessage: nextErrorMessage,
    );
    return nextMessageId;
  }

  Future<void> _setAssistantError({
    required String threadId,
    required String messageId,
    required Object error,
    String? errorCode,
  }) async {
    final String? normalizedErrorCode =
        errorCode ?? assistantErrorCodeFromException(error);
    final String errorContent = assistantErrorContentForCode(
      normalizedErrorCode,
    );
    final String errorHint = assistantErrorHintForCode(normalizedErrorCode);
    if (_assistantRepository
        .messagesForThread(threadId)
        .any((AssistantMessage item) => item.id == messageId)) {
      await _assistantRepository.updateAssistantMessage(
        threadId: threadId,
        messageId: messageId,
        content: errorContent,
        status: AssistantMessageStatus.error,
        sourceMode: AssistantReplySourceMode.error,
        errorMessage: errorHint,
      );
      return;
    }
    await _assistantRepository.addAssistantMessage(
      threadId: threadId,
      content: errorContent,
      status: AssistantMessageStatus.error,
      sourceMode: AssistantReplySourceMode.error,
      errorMessage: errorHint,
    );
  }

  void _recordUpdatedSurfaces({
    required Iterable<String?> messageIds,
    required Iterable<String> surfaceIds,
  }) {
    final List<String> normalizedSurfaces = <String>[];
    final Set<String> seenSurfaces = <String>{};
    for (final String surfaceId in surfaceIds) {
      final String normalized = surfaceId.trim();
      if (normalized.isEmpty || !seenSurfaces.add(normalized)) {
        continue;
      }
      normalizedSurfaces.add(normalized);
    }
    if (normalizedSurfaces.isEmpty) {
      return;
    }

    bool changed = false;
    final Set<String> handledMessageIds = <String>{};
    for (final String? messageId in messageIds) {
      final String normalizedMessageId = messageId?.trim() ?? '';
      if (normalizedMessageId.isEmpty ||
          !handledMessageIds.add(normalizedMessageId)) {
        continue;
      }
      final List<String> current =
          _updatedSurfacesByMessageId[normalizedMessageId] ?? const <String>[];
      final List<String> merged = List<String>.from(current);
      for (final String surfaceId in normalizedSurfaces) {
        if (!merged.contains(surfaceId)) {
          merged.add(surfaceId);
        }
      }
      if (merged.length == current.length) {
        continue;
      }
      _updatedSurfacesByMessageId[normalizedMessageId] = merged;
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  void _relayState() {
    notifyListeners();
  }

  @override
  void dispose() {
    _assistantRepository.removeListener(_relayState);
    super.dispose();
  }
}

class _PreparedThreadTurn {
  const _PreparedThreadTurn({required this.thread, required this.turnId});

  final AssistantThread thread;
  final String turnId;
}
