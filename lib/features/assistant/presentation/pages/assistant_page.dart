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

class _AssistantPageState extends State<AssistantPage>
    with SingleTickerProviderStateMixin {
  static const Duration _archiveAnimationDuration = Duration(milliseconds: 320);
  static const Duration _archiveHintMemoryDuration = Duration(seconds: 5);

  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late final AnimationController _archiveController = AnimationController(
    vsync: this,
    duration: _archiveAnimationDuration,
  );
  late AssistantCaptureTab _selectedTab;
  Timer? _archiveHintTimer;
  String? _lastHapticAssistantMessageId;
  bool _archiveExpansionArmed = false;
  bool _archiveAtBottom = true;
  double _replyPullExtent = 0;
  double _archiveOverscrollExtent = 0;

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
    _archiveHintTimer?.cancel();
    _archiveController.dispose();
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

    _resetArchiveState();

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
          setState(() {
            _inputController.clear();
          });
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

  Future<void> _handleComposerAddTap() async {
    if (!mounted) {
      return;
    }
    await notifyPassiveToast(context, message: '更多输入能力会在后续版本开放。');
  }

  Future<void> _handleComposerMicTap() async {
    if (!mounted) {
      return;
    }
    await notifyPassiveToast(context, message: '语音输入还在接入中。');
  }

  Future<void> _startNewConversation(AppServices services) async {
    _resetArchiveState();
    setState(() {
      _inputController.clear();
      _lastHapticAssistantMessageId = null;
    });
    _focusNode.unfocus();
    await services.assistantFacade.createThread(
      title: widget.captureModeEnabled
          ? (_activeCaptureType == SleepCaptureType.dream ? '梦记收纳' : '事记收纳')
          : '新对话',
    );
    if (!mounted) {
      return;
    }
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

  void _resetArchiveState() {
    _archiveHintTimer?.cancel();
    _archiveHintTimer = null;
    _archiveExpansionArmed = false;
    _archiveAtBottom = true;
    _replyPullExtent = 0;
    _archiveOverscrollExtent = 0;
    if (_archiveController.value != 0) {
      _archiveController.value = 0;
    }
  }

  void _armArchiveExpansion() {
    _archiveHintTimer?.cancel();
    setState(() {
      _archiveExpansionArmed = true;
      _replyPullExtent = 0;
      _archiveController.value = 0;
    });
    _archiveHintTimer = Timer(_archiveHintMemoryDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _archiveExpansionArmed = false;
        _replyPullExtent = 0;
      });
    });
  }

  void _disarmArchiveExpansion() {
    _archiveHintTimer?.cancel();
    _archiveHintTimer = null;
    _archiveExpansionArmed = false;
  }

  Future<void> _animateArchiveTo(double target) async {
    await _archiveController.animateTo(
      target,
      duration: _archiveAnimationDuration,
      curve: Curves.easeOutCubic,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      if (target == 0) {
        _replyPullExtent = 0;
      }
      _archiveOverscrollExtent = 0;
    });
  }

  double _pullHintOpacity(AssistantSurfaceMetrics metrics) {
    if (_archiveController.value >= 1) {
      return 0;
    }
    if (_archiveExpansionArmed) {
      return (1 - _archiveController.value).clamp(0, 1);
    }
    final double reveal = (_replyPullExtent / metrics.unit(28)).clamp(0, 1);
    return (reveal * (1 - _archiveController.value)).clamp(0, 1);
  }

  void _syncArchiveProgressFromPull(AssistantSurfaceMetrics metrics) {
    final double progress =
        ((_replyPullExtent - metrics.unit(18)) / metrics.unit(96)).clamp(0, 1);
    _archiveController.value = progress;
  }

  void _handleReplyPullUpdate(
    DragUpdateDetails details,
    AssistantSurfaceMetrics metrics,
    _AssistantStageState stageState,
  ) {
    if (stageState != _AssistantStageState.reply ||
        _archiveController.isAnimating) {
      return;
    }
    final double delta = details.primaryDelta ?? 0;
    if (delta <= 0) {
      return;
    }

    setState(() {
      _replyPullExtent = (_replyPullExtent + delta).clamp(0, metrics.unit(180));
      if (_archiveExpansionArmed) {
        _syncArchiveProgressFromPull(metrics);
      }
    });
  }

  void _handleReplyPullEnd(
    DragEndDetails details,
    AssistantSurfaceMetrics metrics,
    _AssistantStageState stageState,
  ) {
    if (stageState != _AssistantStageState.reply) {
      return;
    }

    final double velocity = details.primaryVelocity ?? 0;
    if (!_archiveExpansionArmed) {
      final bool shouldArm =
          _replyPullExtent > metrics.unit(28) || velocity > 420;
      setState(() {
        _replyPullExtent = 0;
      });
      if (shouldArm) {
        _armArchiveExpansion();
      }
      return;
    }

    final bool shouldExpand =
        _archiveController.value > 0.34 ||
        _replyPullExtent > metrics.unit(64) ||
        velocity > 460;

    setState(() {
      _replyPullExtent = 0;
    });
    if (shouldExpand) {
      _disarmArchiveExpansion();
      unawaited(_animateArchiveTo(1));
      return;
    }
    _archiveController.value = 0;
  }

  bool _handleArchiveScrollNotification(
    ScrollNotification notification,
    AssistantSurfaceMetrics metrics,
  ) {
    final bool atArchiveBottom = notification.metrics.extentAfter <= 0.5;
    if (_archiveAtBottom != atArchiveBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _archiveAtBottom == atArchiveBottom) {
          return;
        }
        setState(() {
          _archiveAtBottom = atArchiveBottom;
        });
      });
    }

    return false;
  }

  void _handleArchiveCollapsePullUpdate(
    DragUpdateDetails details,
    AssistantSurfaceMetrics metrics,
  ) {
    if (_archiveController.isAnimating) {
      return;
    }
    final double delta = details.primaryDelta ?? 0;
    if (delta >= 0) {
      return;
    }
    setState(() {
      _archiveOverscrollExtent = (_archiveOverscrollExtent + delta.abs()).clamp(
        0,
        metrics.unit(180),
      );
      final double progress = (_archiveOverscrollExtent / metrics.unit(110))
          .clamp(0, 1);
      _archiveController.value = 1 - progress;
    });
  }

  void _handleArchiveCollapsePullEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    final bool shouldCollapse =
        _archiveController.value < 0.76 || velocity < -420;
    _archiveOverscrollExtent = 0;
    if (shouldCollapse) {
      _disarmArchiveExpansion();
      unawaited(_animateArchiveTo(0));
      return;
    }
    unawaited(_animateArchiveTo(1));
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        services.assistantFacade,
        services.assistantConversationController,
        services.settingsRepository,
      ]),
      builder: (BuildContext context, Widget? child) {
        final AssistantConversationController controller =
            services.assistantConversationController;
        final AssistantConversationSlice slice =
            AssistantConversationSlice.fromMessages(controller.currentMessages);
        final bool isBusy = controller.isBusy;
        final AssistantReplyMotionLevel replyMotionLevel =
            services.profileFacade.currentSettings.assistantReplyMotionLevel;
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
          onTapHistory: () => context.push(AppRoutes.assistantHistory),
          bodyBuilder:
              (
                BuildContext context,
                AssistantSurfaceMetrics metrics,
                AssistantSurfacePalette palette,
              ) {
                return _AssistantStageViewport(
                  metrics: metrics,
                  palette: palette,
                  stageState: stageState,
                  slice: slice,
                  statuses: latestStatuses,
                  controller: controller,
                  replyMotionLevel: replyMotionLevel,
                  archiveController: _archiveController,
                  pullHintOpacity: _pullHintOpacity(metrics),
                  archiveAtBottom: _archiveAtBottom,
                  onReplyPullUpdate: (DragUpdateDetails details) =>
                      _handleReplyPullUpdate(details, metrics, stageState),
                  onReplyPullEnd: (DragEndDetails details) =>
                      _handleReplyPullEnd(details, metrics, stageState),
                  onArchiveCollapsePullUpdate: (DragUpdateDetails details) =>
                      _handleArchiveCollapsePullUpdate(details, metrics),
                  onArchiveCollapsePullEnd: _handleArchiveCollapsePullEnd,
                  onArchiveScrollNotification:
                      (ScrollNotification notification) =>
                          _handleArchiveScrollNotification(
                            notification,
                            metrics,
                          ),
                );
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
                  onTapAdd: _handleComposerAddTap,
                  onTapMic: _handleComposerMicTap,
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

class _AssistantStageViewport extends StatelessWidget {
  const _AssistantStageViewport({
    required this.metrics,
    required this.palette,
    required this.stageState,
    required this.slice,
    required this.statuses,
    required this.controller,
    required this.replyMotionLevel,
    required this.archiveController,
    required this.pullHintOpacity,
    required this.archiveAtBottom,
    required this.onReplyPullUpdate,
    required this.onReplyPullEnd,
    required this.onArchiveCollapsePullUpdate,
    required this.onArchiveCollapsePullEnd,
    required this.onArchiveScrollNotification,
  });

  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;
  final _AssistantStageState stageState;
  final AssistantConversationSlice slice;
  final List<AssistantToolStatus> statuses;
  final AssistantConversationController controller;
  final AssistantReplyMotionLevel replyMotionLevel;
  final AnimationController archiveController;
  final double pullHintOpacity;
  final bool archiveAtBottom;
  final ValueChanged<DragUpdateDetails> onReplyPullUpdate;
  final ValueChanged<DragEndDetails> onReplyPullEnd;
  final ValueChanged<DragUpdateDetails> onArchiveCollapsePullUpdate;
  final ValueChanged<DragEndDetails> onArchiveCollapsePullEnd;
  final bool Function(ScrollNotification notification)
  onArchiveScrollNotification;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: archiveController,
      builder: (BuildContext context, Widget? child) {
        final double archiveProgress = Curves.easeOutCubic.transform(
          archiveController.value,
        );
        final bool showArchive =
            archiveController.value > 0.001 || archiveController.isAnimating;
        final bool canDragReply =
            stageState == _AssistantStageState.reply &&
            archiveController.value < 0.999;

        return GestureDetector(
          key: const ValueKey<String>('assistant-stage-viewport'),
          behavior: HitTestBehavior.translucent,
          onVerticalDragUpdate: canDragReply ? onReplyPullUpdate : null,
          onVerticalDragEnd: canDragReply ? onReplyPullEnd : null,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              IgnorePointer(
                ignoring: archiveProgress > 0.98,
                child: Opacity(
                  opacity: 1 - archiveProgress,
                  child: Transform.translate(
                    offset: Offset(0, metrics.unit(24) * archiveProgress),
                    child: _AssistantPrimaryStage(
                      metrics: metrics,
                      palette: palette,
                      stageState: stageState,
                      latestUserText: slice.latestUser?.content.trim() ?? '',
                      latestAssistantText:
                          slice.latestAssistant?.content.trim() ?? '',
                      statuses: statuses,
                      replyMotionLevel: replyMotionLevel,
                    ),
                  ),
                ),
              ),
              if (showArchive)
                IgnorePointer(
                  ignoring: archiveController.value < 0.98,
                  child: Opacity(
                    opacity: archiveProgress,
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        -metrics.unit(40) * (1 - archiveProgress),
                      ),
                      child: NotificationListener<ScrollNotification>(
                        onNotification: onArchiveScrollNotification,
                        child: _AssistantArchiveStage(
                          metrics: metrics,
                          palette: palette,
                          messages: slice.visibleMessages,
                          controller: controller,
                        ),
                      ),
                    ),
                  ),
                ),
              if (showArchive &&
                  archiveController.value > 0.98 &&
                  archiveAtBottom)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: GestureDetector(
                    key: const ValueKey<String>(
                      'assistant-history-collapse-zone',
                    ),
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: onArchiveCollapsePullUpdate,
                    onVerticalDragEnd: onArchiveCollapsePullEnd,
                    child: SizedBox(
                      width: double.infinity,
                      height: metrics.unit(112),
                    ),
                  ),
                ),
              if (pullHintOpacity > 0.001 &&
                  stageState == _AssistantStageState.reply &&
                  archiveController.value < 0.98)
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: metrics.unit(8)),
                    child: Opacity(
                      opacity: pullHintOpacity,
                      child: AssistantPullHint(
                        metrics: metrics,
                        palette: palette,
                        text: '再次下拉查看对话记录',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AssistantPrimaryStage extends StatelessWidget {
  const _AssistantPrimaryStage({
    required this.metrics,
    required this.palette,
    required this.stageState,
    required this.latestUserText,
    required this.latestAssistantText,
    required this.statuses,
    required this.replyMotionLevel,
  });

  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;
  final _AssistantStageState stageState;
  final String latestUserText;
  final String latestAssistantText;
  final List<AssistantToolStatus> statuses;
  final AssistantReplyMotionLevel replyMotionLevel;

  @override
  Widget build(BuildContext context) {
    final String stageIdentity = switch (stageState) {
      _AssistantStageState.empty => 'empty',
      _AssistantStageState.waiting => 'waiting:$latestUserText',
      _AssistantStageState.reply =>
        'reply:$latestAssistantText:${statuses.map((AssistantToolStatus item) => item.label).join('|')}',
    };
    final Key stageKey = ValueKey<String>('assistant-stage-$stageIdentity');
    final Widget activeStage = switch (stageState) {
      _AssistantStageState.empty => _AssistantEmptyStage(
        key: stageKey,
        metrics: metrics,
        palette: palette,
      ),
      _AssistantStageState.waiting => _AssistantWaitingStage(
        key: stageKey,
        metrics: metrics,
        palette: palette,
        text: latestUserText,
      ),
      _AssistantStageState.reply => _AssistantReplyStage(
        key: stageKey,
        metrics: metrics,
        palette: palette,
        replyText: latestAssistantText,
        statuses: statuses,
        motionLevel: replyMotionLevel,
      ),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 760),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) =>
          Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: <Widget>[
              ...previousChildren,
              if (currentChild case final Widget currentChild) currentChild,
            ],
          ),
      transitionBuilder: (Widget child, Animation<double> animation) {
        final bool isIncoming = child.key == stageKey;
        final Animation<double> stageOpacity;
        final Animation<Offset> stageOffset;
        if (isIncoming) {
          final Animation<double> progress = CurvedAnimation(
            parent: animation,
            curve: const Interval(0.38, 1, curve: Curves.easeOutCubic),
          );
          stageOpacity = progress;
          stageOffset = Tween<Offset>(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(progress);
        } else {
          final Animation<double> progress = CurvedAnimation(
            parent: ReverseAnimation(animation),
            curve: const Interval(0, 0.58, curve: Curves.easeInOutCubic),
          );
          stageOpacity = Tween<double>(begin: 1, end: 0).animate(progress);
          stageOffset = Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(0, -0.12),
          ).animate(progress);
        }

        return FadeTransition(
          opacity: stageOpacity,
          child: SlideTransition(position: stageOffset, child: child),
        );
      },
      child: activeStage,
    );
  }
}

class _AssistantEmptyStage extends StatelessWidget {
  const _AssistantEmptyStage({
    super.key,
    required this.metrics,
    required this.palette,
  });

  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double contentWidth = metrics.contentWidth(constraints.maxWidth);
        return Center(
          child: SizedBox(
            width: contentWidth,
            child: AssistantFloatingMotion(
              transformKey: const ValueKey<String>(
                'assistant-empty-floating-motion',
              ),
              travelDistance: metrics.unit(6),
              duration: const Duration(milliseconds: 3800),
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
          ),
        );
      },
    );
  }
}

class _AssistantEmptyHeadline extends StatelessWidget {
  const _AssistantEmptyHeadline({required this.metrics, required this.palette});

  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;

  @override
  Widget build(BuildContext context) {
    return Text(
      '今晚想聊点什么',
      key: const ValueKey<String>('assistant-empty-headline-text'),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.displaySmall?.copyWith(
        color: palette.headlineText,
        fontSize: metrics.unit(34),
        fontWeight: FontWeight.w700,
        height: 1.02,
      ),
    );
  }
}

class _AssistantWaitingStage extends StatelessWidget {
  const _AssistantWaitingStage({
    super.key,
    required this.metrics,
    required this.palette,
    required this.text,
  });

  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;
  final String text;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double contentWidth = metrics.contentWidth(constraints.maxWidth);
        return Align(
          alignment: const Alignment(0, -0.03),
          child: SizedBox(
            width: contentWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  text,
                  key: const ValueKey<String>('assistant-waiting-user-message'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.secondaryText,
                    fontSize: metrics.unit(14),
                    fontWeight: FontWeight.w500,
                    height: 1.6,
                  ),
                ),
                SizedBox(height: metrics.unit(12)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AssistantLoopingRotation(
                      child: Icon(
                        Icons.autorenew_rounded,
                        size: metrics.unit(14),
                        color: palette.mutedText,
                      ),
                    ),
                    SizedBox(width: metrics.unit(8)),
                    Text(
                      '小眠正在整理你的心绪...',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: palette.mutedText,
                        fontSize: metrics.unit(12),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AssistantReplyStage extends StatelessWidget {
  const _AssistantReplyStage({
    super.key,
    required this.metrics,
    required this.palette,
    required this.replyText,
    required this.statuses,
    required this.motionLevel,
  });

  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;
  final String replyText;
  final List<AssistantToolStatus> statuses;
  final AssistantReplyMotionLevel motionLevel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double contentWidth = metrics.contentWidth(constraints.maxWidth);
        return Align(
          alignment: const Alignment(0, -0.01),
          child: SizedBox(
            width: contentWidth,
            child: Column(
              key: const ValueKey<String>('assistant-page-reply-stage'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AssistantFloatingMotion(
                  transformKey: const ValueKey<String>(
                    'assistant-current-floating-motion',
                  ),
                  duration: const Duration(milliseconds: 3600),
                  travelDistance: _replyFloatingDistance(metrics, motionLevel),
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
                  SizedBox(height: metrics.unit(12)),
                  AssistantInlineStatusList(
                    statuses: statuses,
                    metrics: metrics,
                    palette: palette,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

double _replyFloatingDistance(
  AssistantSurfaceMetrics metrics,
  AssistantReplyMotionLevel level,
) {
  return switch (level) {
    AssistantReplyMotionLevel.low => metrics.unit(4),
    AssistantReplyMotionLevel.medium => metrics.unit(6),
    AssistantReplyMotionLevel.high => metrics.unit(8),
  };
}

class _AssistantArchiveStage extends StatelessWidget {
  const _AssistantArchiveStage({
    required this.metrics,
    required this.palette,
    required this.messages,
    required this.controller,
  });

  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;
  final List<AssistantMessage> messages;
  final AssistantConversationController controller;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const SizedBox.expand();
    }

    AssistantMessage? latestAssistant;
    for (final AssistantMessage message in messages.reversed) {
      if (message.role == AssistantMessageRole.assistant) {
        latestAssistant = message;
        break;
      }
    }
    final int latestAssistantIndex = latestAssistant == null
        ? -1
        : messages.lastIndexOf(latestAssistant);
    final List<AssistantMessage> earlierMessages = latestAssistantIndex <= 0
        ? messages
              .take(latestAssistantIndex == -1 ? messages.length : 0)
              .toList(growable: false)
        : messages.sublist(0, latestAssistantIndex);
    final bool showEarlierLabel = earlierMessages.any(
      (AssistantMessage message) =>
          message.role == AssistantMessageRole.assistant,
    );
    final bool showCurrentLabel =
        latestAssistant != null && earlierMessages.isNotEmpty;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double contentWidth = metrics.contentWidth(constraints.maxWidth);
        return SingleChildScrollView(
          key: const ValueKey<String>('assistant-history-scroll'),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(top: metrics.unit(8)),
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    key: const ValueKey<String>('assistant-history-flow'),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (showEarlierLabel) ...<Widget>[
                        Text(
                          '更早的对话',
                          key: const ValueKey<String>(
                            'assistant-history-earlier',
                          ),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: palette.mutedText,
                                fontSize: metrics.unit(11),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        SizedBox(height: metrics.unit(16)),
                      ],
                      ...earlierMessages.expand<Widget>((
                        AssistantMessage message,
                      ) {
                        if (message.role == AssistantMessageRole.user) {
                          return <Widget>[
                            AssistantUserCard(
                              text: message.content.trim(),
                              metrics: metrics,
                              palette: palette,
                            ),
                            SizedBox(height: metrics.unit(16)),
                          ];
                        }

                        final List<AssistantToolStatus> messageStatuses =
                            assistantToolStatusesFromSurfaceIds(
                              controller.updatedSurfacesForMessage(message.id),
                            );
                        return <Widget>[
                          Text(
                            message.content.trim(),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: palette.bodyText,
                                  fontSize: metrics.unit(13),
                                  fontWeight: FontWeight.w500,
                                  height: 1.58,
                                ),
                          ),
                          if (messageStatuses.isNotEmpty) ...<Widget>[
                            SizedBox(height: metrics.unit(8)),
                            AssistantBulletStatusList(
                              statuses: messageStatuses,
                              metrics: metrics,
                              palette: palette,
                            ),
                          ],
                          SizedBox(height: metrics.unit(16)),
                        ];
                      }),
                      if (showCurrentLabel) ...<Widget>[
                        Text(
                          '刚刚',
                          key: const ValueKey<String>(
                            'assistant-history-current',
                          ),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: palette.mutedText,
                                fontSize: metrics.unit(11),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        SizedBox(height: metrics.unit(16)),
                      ],
                      if (latestAssistant != null) ...<Widget>[
                        Text(
                          latestAssistant.content.trim(),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: palette.headlineText,
                                fontSize: metrics.unit(20),
                                fontWeight: FontWeight.w500,
                                height: 1.62,
                              ),
                        ),
                        SizedBox(height: metrics.unit(12)),
                        AssistantBulletStatusList(
                          statuses: assistantToolStatusesFromSurfaceIds(
                            controller.updatedSurfacesForMessage(
                              latestAssistant.id,
                            ),
                          ),
                          metrics: metrics,
                          palette: palette,
                        ),
                      ] else
                        ...messages
                            .where(
                              (AssistantMessage message) =>
                                  message.role == AssistantMessageRole.user,
                            )
                            .map(
                              (AssistantMessage message) => Padding(
                                padding: EdgeInsets.only(
                                  bottom: metrics.unit(16),
                                ),
                                child: AssistantUserCard(
                                  text: message.content.trim(),
                                  metrics: metrics,
                                  palette: palette,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
