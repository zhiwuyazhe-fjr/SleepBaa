import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/features/assistant/presentation/controllers/assistant_conversation_controller.dart';
import 'package:sleep_dorm_app/features/assistant/presentation/widgets/assistant_surface.dart';

enum AssistantCaptureTab { dream, memo }

class AssistantPage extends StatefulWidget {
  const AssistantPage({
    super.key,
    this.captureModeEnabled = false,
    this.initialCaptureTab = AssistantCaptureTab.dream,
  });

  final bool captureModeEnabled;
  final AssistantCaptureTab initialCaptureTab;

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late AssistantCaptureTab _selectedTab;
  String? _lastHapticAssistantMessageId;

  SleepCaptureType get _activeCaptureType =>
      _selectedTab == AssistantCaptureTab.memo
      ? SleepCaptureType.memo
      : SleepCaptureType.dream;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialCaptureTab;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      await context.appServices.assistantConversationController.bootstrap();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit(AppServices services) async {
    final String prompt = _inputController.text.trim();
    if (prompt.isEmpty) {
      _focusNode.requestFocus();
      return;
    }

    final AssistantConversationController controller =
        services.assistantConversationController;
    final AssistantConversationSubmitResult result = widget.captureModeEnabled
        ? await controller.submitCapturePrompt(
            prompt: prompt,
            captureType: _activeCaptureType,
          )
        : await controller.submitPrompt(prompt);

    switch (result) {
      case AssistantConversationSubmitResult.sent:
        if (mounted) {
          setState(_inputController.clear);
        }
        _focusNode.unfocus();
        break;
      case AssistantConversationSubmitResult.busy:
        if (!mounted) {
          return;
        }
        await notifyPassiveToast(context, message: '上一条还在处理中，请稍后再发');
        break;
      case AssistantConversationSubmitResult.missingActiveSession:
        if (!mounted) {
          return;
        }
        await notifyPassiveToast(context, message: '只有在睡眠模式中，才能使用梦记和事记收纳。');
        break;
      case AssistantConversationSubmitResult.empty:
        _focusNode.requestFocus();
        break;
    }
  }

  Future<void> _startNewConversation(AppServices services) async {
    await services.assistantFacade.createThread(
      title: widget.captureModeEnabled
          ? (_activeCaptureType == SleepCaptureType.dream ? '梦记收纳' : '事记收纳')
          : '新对话',
    );
    if (!mounted) {
      return;
    }
    setState(_inputController.clear);
    _lastHapticAssistantMessageId = null;
    _focusNode.unfocus();
  }

  Future<void> _emitReplyHaptics({required bool hasStatuses}) async {
    await HapticFeedback.lightImpact();
    if (!hasStatuses) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) {
      return;
    }
    await HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        services.assistantFacade,
        services.assistantConversationController,
      ]),
      builder: (BuildContext context, Widget? child) {
        final AssistantConversationController controller =
            services.assistantConversationController;
        final AssistantConversationSlice slice =
            AssistantConversationSlice.fromMessages(controller.currentMessages);
        final bool isBusy = controller.isBusy;
        final _AssistantStageState stageState = _resolveStageState(
          slice: slice,
          isBusy: isBusy,
        );
        final AssistantMessage? latestAssistant = slice.latestAssistant;
        final List<AssistantToolStatus> latestStatuses =
            assistantToolStatusesFromSurfaceIds(
              controller.updatedSurfacesForMessage(latestAssistant?.id),
            );
        final String? latestAssistantMessageId = latestAssistant?.id;
        if (stageState == _AssistantStageState.reply &&
            latestAssistantMessageId != null &&
            latestAssistantMessageId != _lastHapticAssistantMessageId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted ||
                latestAssistantMessageId == _lastHapticAssistantMessageId) {
              return;
            }
            _lastHapticAssistantMessageId = latestAssistantMessageId;
            unawaited(
              _emitReplyHaptics(hasStatuses: latestStatuses.isNotEmpty),
            );
          });
        }

        return AssistantShellScaffold(
          onTapAdd: () => _startNewConversation(services),
          onTapHistory: slice.hasVisibleConversation
              ? () => context.push(AppRoutes.assistantHistory)
              : null,
          bodyBuilder:
              (
                BuildContext context,
                AssistantSurfaceMetrics metrics,
                AssistantSurfacePalette palette,
              ) {
                return switch (stageState) {
                  _AssistantStageState.empty => _AssistantEmptyStage(
                    metrics: metrics,
                    palette: palette,
                  ),
                  _AssistantStageState.waiting => _AssistantWaitingStage(
                    metrics: metrics,
                    palette: palette,
                    text: slice.latestUser?.content.trim() ?? '',
                  ),
                  _AssistantStageState.reply => _AssistantReplyStage(
                    metrics: metrics,
                    palette: palette,
                    replyText: latestAssistant?.content.trim() ?? '',
                    statuses: latestStatuses,
                  ),
                };
              },
          composerBuilder:
              (
                BuildContext context,
                AssistantSurfaceMetrics metrics,
                AssistantSurfacePalette palette,
              ) {
                return AssistantComposer(
                  controller: _inputController,
                  focusNode: _focusNode,
                  metrics: metrics,
                  palette: palette,
                  hintText: isBusy ? '小眠正在整理你的心绪...' : '和小眠说说现在的心情...',
                  isBusy: isBusy,
                  onSubmit: () => _handleSubmit(services),
                );
              },
        );
      },
    );
  }
}

enum _AssistantStageState { empty, waiting, reply }

_AssistantStageState _resolveStageState({
  required AssistantConversationSlice slice,
  required bool isBusy,
}) {
  if (!slice.hasVisibleConversation && !isBusy) {
    return _AssistantStageState.empty;
  }
  if (isBusy ||
      slice.latestAssistant == null ||
      slice.latestAssistant!.status == AssistantMessageStatus.pending) {
    return _AssistantStageState.waiting;
  }
  return _AssistantStageState.reply;
}

class _AssistantEmptyStage extends StatelessWidget {
  const _AssistantEmptyStage({required this.metrics, required this.palette});

  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: metrics.unit(23)),
        child: Column(
          key: const ValueKey<String>('assistant-empty-stage'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '你好，我是小眠',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: palette.secondaryText,
                fontSize: metrics.unit(20),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: metrics.unit(10)),
            _AssistantEmptyHeadline(metrics: metrics, palette: palette),
            SizedBox(height: metrics.unit(10)),
            Text(
              '可以和小眠聊聊睡不着的原因，也可以把脑海里还没放下的念头交给我。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: palette.bodyText,
                fontSize: metrics.unit(14),
                fontWeight: FontWeight.w400,
                height: 1.56,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantEmptyHeadline extends StatelessWidget {
  const _AssistantEmptyHeadline({required this.metrics, required this.palette});

  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;

  @override
  Widget build(BuildContext context) {
    return AssistantFloatingMotion(
      transformKey: const ValueKey<String>('assistant-empty-floating-motion'),
      travelDistance: metrics.unit(4),
      child: Text(
        '今晚想聊点什么',
        key: const ValueKey<String>('assistant-empty-headline-text'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
          color: palette.headlineText,
          fontSize: metrics.unit(34),
          fontWeight: FontWeight.w700,
          height: 1.02,
        ),
      ),
    );
  }
}

class _AssistantWaitingStage extends StatelessWidget {
  const _AssistantWaitingStage({
    required this.metrics,
    required this.palette,
    required this.text,
  });

  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, -0.08),
      child: Text(
        text,
        key: const ValueKey<String>('assistant-waiting-user-message'),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: palette.secondaryText,
          fontSize: metrics.unit(14),
          fontWeight: FontWeight.w500,
          height: 1.6,
        ),
      ),
    );
  }
}

class _AssistantReplyStage extends StatelessWidget {
  const _AssistantReplyStage({
    required this.metrics,
    required this.palette,
    required this.replyText,
    required this.statuses,
  });

  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;
  final String replyText;
  final List<AssistantToolStatus> statuses;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey<String>('assistant-page-reply-stage'),
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(top: metrics.unit(8)),
          child: AssistantPullHint(
            metrics: metrics,
            palette: palette,
            text: '再次上拉查看对话记录',
          ),
        ),
        Expanded(
          child: Align(
            alignment: const Alignment(0, -0.02),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AssistantFloatingMotion(
                  transformKey: const ValueKey<String>(
                    'assistant-current-floating-motion',
                  ),
                  travelDistance: metrics.unit(4),
                  child: Text(
                    replyText,
                    key: const ValueKey<String>(
                      'assistant-current-assistant-message',
                    ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: palette.headlineText,
                      fontSize: metrics.unit(20),
                      fontWeight: FontWeight.w500,
                      height: 1.62,
                    ),
                  ),
                ),
                if (statuses.isNotEmpty) ...<Widget>[
                  SizedBox(height: metrics.unit(14)),
                  AssistantInlineStatusList(
                    statuses: statuses,
                    metrics: metrics,
                    palette: palette,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
