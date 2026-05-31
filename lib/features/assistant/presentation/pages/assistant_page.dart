import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/interaction/app_haptics.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/features/assistant/presentation/controllers/assistant_conversation_controller.dart';
import 'package:sleep_dorm_app/features/assistant/presentation/widgets/assistant_surface.dart';

const Duration _assistantStageTransitionDuration = Duration(milliseconds: 2000);

enum AssistantCaptureTab { dream, memo }

enum _AssistantFlowHintMode { none, expand, collapse }

enum _AssistantArchivePhase { collapsed, expanding, expanded, collapsing }

class AssistantPage extends StatefulWidget {
  const AssistantPage({
    super.key,
    this.captureModeEnabled = false,
    this.initialCaptureTab = AssistantCaptureTab.dream,
    this.captureSessionId,
    this.allowCaptureSessionRepair = false,
  });

  final bool captureModeEnabled;
  final AssistantCaptureTab initialCaptureTab;
  final String? captureSessionId;
  final bool allowCaptureSessionRepair;

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage>
    with SingleTickerProviderStateMixin {
  static const Duration _archiveHintMemoryDuration = Duration(seconds: 5);
  static const double _replyPullTriggerZoneDesignHeight = 156;

  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _primaryStageScrollController = ScrollController();

  late final AnimationController _archiveController = AnimationController(
    vsync: this,
    duration: _assistantStageTransitionDuration,
  );
  late AssistantCaptureTab _selectedTab;
  Timer? _archiveHintTimer;
  Timer? _archiveCollapseHintTimer;
  String? _lastHapticAssistantMessageId;
  _AssistantArchivePhase _archivePhase = _AssistantArchivePhase.collapsed;
  bool _archiveExpansionArmed = false;
  bool _archiveCollapseArmed = false;
  bool _archiveCollapseHintPrimedFromEntry = false;
  bool _archiveAtBottom = true;
  bool _primaryStageAtTop = true;
  int? _replyPullPointerId;
  double? _replyPullLastLocalDy;
  double _replyPullExtent = 0;
  double _archiveOverscrollExtent = 0;
  _AssistantFlowHintMode _flowHintMode = _AssistantFlowHintMode.none;

  SleepCaptureType get _activeCaptureType =>
      _selectedTab == AssistantCaptureTab.memo
      ? SleepCaptureType.memo
      : SleepCaptureType.dream;

  _AssistantCaptureCopy get _captureCopy =>
      _AssistantCaptureCopy.forTab(_selectedTab);

  bool get _archiveTransitioning =>
      _archivePhase == _AssistantArchivePhase.expanding ||
      _archivePhase == _AssistantArchivePhase.collapsing;

  bool get _archiveExpanded => _archivePhase == _AssistantArchivePhase.expanded;

  String? _flowHintText() {
    return switch (_flowHintMode) {
      _AssistantFlowHintMode.expand => '再次下拉查看对话记录',
      _AssistantFlowHintMode.collapse =>
        _archiveCollapseHintPrimedFromEntry ? '上拉返回当前回复' : '再次上拉返回当前回复',
      _AssistantFlowHintMode.none => null,
    };
  }

  bool _shouldShowFlowHint() {
    return switch (_flowHintMode) {
      _AssistantFlowHintMode.none => false,
      _AssistantFlowHintMode.expand =>
        _archiveExpansionArmed &&
            _replyPullExtent <= 0.001 &&
            !_archiveTransitioning &&
            _archivePhase == _AssistantArchivePhase.collapsed,
      _AssistantFlowHintMode.collapse =>
        _archiveCollapseArmed &&
            _archiveOverscrollExtent <= 0.001 &&
            !_archiveTransitioning &&
            _archivePhase == _AssistantArchivePhase.expanded,
    };
  }

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialCaptureTab;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final AssistantConversationController controller =
          context.appServices.assistantConversationController;
      await controller.bootstrap();
      if (!mounted || !widget.captureModeEnabled) {
        return;
      }
      await controller.startNewConversation(
        title: widget.initialCaptureTab == AssistantCaptureTab.dream
            ? '梦记收纳'
            : '事记收纳',
      );
    });
  }

  @override
  void dispose() {
    _archiveHintTimer?.cancel();
    _archiveCollapseHintTimer?.cancel();
    _archiveController.dispose();
    _primaryStageScrollController.dispose();
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
            preferredSessionId: widget.captureSessionId,
            allowSessionRepair: widget.allowCaptureSessionRepair,
          )
        : await controller.submitPrompt(prompt);

    switch (result) {
      case AssistantConversationSubmitResult.sent:
        unawaited(AppHaptics.messageSend());
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
    await services.assistantConversationController.startNewConversation(
      title: widget.captureModeEnabled
          ? (_activeCaptureType == SleepCaptureType.dream ? '梦记收纳' : '事记收纳')
          : '新对话',
    );
    if (!mounted) {
      return;
    }
  }

  Future<void> _emitReplyHaptics({required bool hasStatuses}) async {
    await AppHaptics.tap();
    if (!hasStatuses) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) {
      return;
    }
    await AppHaptics.selection();
  }

  void _resetArchiveState() {
    _archiveHintTimer?.cancel();
    _archiveCollapseHintTimer?.cancel();
    _archiveHintTimer = null;
    _archiveCollapseHintTimer = null;
    _archiveController.stop();
    _archiveController.value = 0;
    _archivePhase = _AssistantArchivePhase.collapsed;
    _archiveExpansionArmed = false;
    _archiveCollapseArmed = false;
    _archiveCollapseHintPrimedFromEntry = false;
    _archiveAtBottom = true;
    _primaryStageAtTop = true;
    _replyPullPointerId = null;
    _replyPullLastLocalDy = null;
    _replyPullExtent = 0;
    _archiveOverscrollExtent = 0;
    _flowHintMode = _AssistantFlowHintMode.none;
    if (_primaryStageScrollController.hasClients) {
      _primaryStageScrollController.jumpTo(0);
    }
  }

  void _armArchiveExpansion() {
    _archiveHintTimer?.cancel();
    _archiveCollapseHintTimer?.cancel();
    setState(() {
      _archiveExpansionArmed = true;
      _archiveCollapseArmed = false;
      _flowHintMode = _AssistantFlowHintMode.expand;
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
        if (!_archiveCollapseArmed) {
          _flowHintMode = _AssistantFlowHintMode.none;
        }
      });
    });
  }

  void _disarmArchiveExpansion() {
    _archiveHintTimer?.cancel();
    _archiveHintTimer = null;
    _archiveExpansionArmed = false;
    if (!_archiveCollapseArmed) {
      _flowHintMode = _AssistantFlowHintMode.none;
    }
  }

  void _armArchiveCollapse({bool primedFromEntry = false}) {
    _archiveCollapseHintTimer?.cancel();
    setState(() {
      _archiveCollapseArmed = true;
      _archiveCollapseHintPrimedFromEntry = primedFromEntry;
      _flowHintMode = _AssistantFlowHintMode.collapse;
      _archiveOverscrollExtent = 0;
      _archiveController.value = 1;
    });
    _archiveCollapseHintTimer = Timer(_archiveHintMemoryDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _archiveCollapseArmed = false;
        _archiveCollapseHintPrimedFromEntry = false;
        _archiveOverscrollExtent = 0;
        if (!_archiveExpansionArmed) {
          _flowHintMode = _AssistantFlowHintMode.none;
        }
      });
    });
  }

  void _disarmArchiveCollapse() {
    _archiveCollapseHintTimer?.cancel();
    _archiveCollapseHintTimer = null;
    _archiveCollapseArmed = false;
    _archiveCollapseHintPrimedFromEntry = false;
    if (!_archiveExpansionArmed) {
      _flowHintMode = _AssistantFlowHintMode.none;
    }
  }

  Future<void> _playArchiveTransition(_AssistantArchivePhase nextPhase) async {
    if (_archiveTransitioning) {
      return;
    }
    setState(() {
      _archivePhase = nextPhase;
      _archiveExpansionArmed = false;
      _archiveCollapseArmed = false;
      _replyPullExtent = 0;
      _archiveOverscrollExtent = 0;
      _flowHintMode = _AssistantFlowHintMode.none;
    });
    await _archiveController.forward(from: 0);
    if (!mounted) {
      return;
    }
    setState(() {
      _archivePhase = nextPhase == _AssistantArchivePhase.expanding
          ? _AssistantArchivePhase.expanded
          : _AssistantArchivePhase.collapsed;
      if (_archivePhase == _AssistantArchivePhase.collapsed) {
        _archiveAtBottom = true;
      }
      _replyPullExtent = 0;
      _archiveOverscrollExtent = 0;
    });
    if (_archivePhase == _AssistantArchivePhase.expanded) {
      _armArchiveCollapse(primedFromEntry: true);
    }
    if (_archivePhase == _AssistantArchivePhase.collapsed) {
      _archiveController.value = 0;
    }
  }

  void _handleReplyPullUpdate(
    double delta,
    AssistantSurfaceMetrics metrics,
    _AssistantStageState stageState,
  ) {
    if (stageState != _AssistantStageState.reply ||
        _archiveTransitioning ||
        _archivePhase != _AssistantArchivePhase.collapsed) {
      return;
    }
    if (delta <= 0) {
      return;
    }

    setState(() {
      _replyPullExtent = (_replyPullExtent + delta).clamp(0, metrics.unit(180));
    });
  }

  void _handleReplyPullEnd(
    double velocity,
    AssistantSurfaceMetrics metrics,
    _AssistantStageState stageState, {
    required bool allowVelocityOnly,
  }) {
    if (stageState != _AssistantStageState.reply) {
      return;
    }

    if (!_archiveExpansionArmed) {
      final bool shouldArm =
          _replyPullExtent > metrics.unit(28) ||
          (allowVelocityOnly && velocity > 420);
      setState(() {
        _replyPullExtent = 0;
      });
      if (shouldArm) {
        _armArchiveExpansion();
      }
      return;
    }

    final bool shouldExpand =
        _replyPullExtent > metrics.unit(64) ||
        (allowVelocityOnly && velocity > 460);

    setState(() {
      _replyPullExtent = 0;
    });
    if (shouldExpand) {
      _disarmArchiveExpansion();
      unawaited(_playArchiveTransition(_AssistantArchivePhase.expanding));
      return;
    }
  }

  void _handleReplyPullPointerDown(PointerDownEvent event) {
    _replyPullPointerId = event.pointer;
    _replyPullLastLocalDy = event.localPosition.dy;
  }

  void _handleReplyPullPointerMove(
    PointerMoveEvent event,
    AssistantSurfaceMetrics metrics,
    _AssistantStageState stageState,
  ) {
    if (event.pointer != _replyPullPointerId || _replyPullLastLocalDy == null) {
      return;
    }
    final double delta = event.localPosition.dy - _replyPullLastLocalDy!;
    _replyPullLastLocalDy = event.localPosition.dy;
    _handleReplyPullUpdate(delta, metrics, stageState);
  }

  void _handleReplyPullPointerUp(
    PointerEvent event,
    AssistantSurfaceMetrics metrics,
    _AssistantStageState stageState,
  ) {
    if (event.pointer != _replyPullPointerId) {
      return;
    }
    _replyPullPointerId = null;
    _replyPullLastLocalDy = null;
    _handleReplyPullEnd(0, metrics, stageState, allowVelocityOnly: false);
  }

  bool _handlePrimaryStageScrollNotification(ScrollNotification notification) {
    final bool atPrimaryTop =
        notification.metrics.pixels <=
        notification.metrics.minScrollExtent + 0.5;
    if (_primaryStageAtTop != atPrimaryTop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _primaryStageAtTop == atPrimaryTop) {
          return;
        }
        setState(() {
          _primaryStageAtTop = atPrimaryTop;
        });
      });
    }
    return false;
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
    if (_archiveTransitioning || !_archiveExpanded) {
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
    });
  }

  void _handleArchiveCollapsePullEnd(
    DragEndDetails details,
    AssistantSurfaceMetrics metrics,
  ) {
    final double velocity = details.primaryVelocity ?? 0;
    if (!_archiveCollapseArmed) {
      final bool shouldArm =
          _archiveOverscrollExtent > metrics.unit(28) || velocity < -420;
      setState(() {
        _archiveOverscrollExtent = 0;
      });
      if (shouldArm) {
        _armArchiveCollapse();
      }
      return;
    }

    final bool shouldCollapse =
        _archiveOverscrollExtent > metrics.unit(70) || velocity < -520;
    setState(() {
      _archiveOverscrollExtent = 0;
    });
    if (shouldCollapse) {
      _disarmArchiveCollapse();
      _disarmArchiveExpansion();
      unawaited(_playArchiveTransition(_AssistantArchivePhase.collapsing));
      return;
    }
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
                double bodyBottomOverlayInset,
              ) {
                return _AssistantStageViewport(
                  metrics: metrics,
                  palette: palette,
                  stageState: stageState,
                  slice: slice,
                  statuses: latestStatuses,
                  controller: controller,
                  replyMotionLevel: replyMotionLevel,
                  captureModeEnabled: widget.captureModeEnabled,
                  selectedCaptureTab: _selectedTab,
                  onCaptureTabChanged: (AssistantCaptureTab tab) {
                    setState(() {
                      _selectedTab = tab;
                    });
                  },
                  archiveController: _archiveController,
                  archivePhase: _archivePhase,
                  flowHintText: _shouldShowFlowHint() ? _flowHintText() : null,
                  archiveAtBottom: _archiveAtBottom,
                  primaryStageAtTop: _primaryStageAtTop,
                  primaryStageScrollController: _primaryStageScrollController,
                  bodyBottomOverlayInset: bodyBottomOverlayInset,
                  replyPullTriggerZoneHeight: metrics.unit(
                    _replyPullTriggerZoneDesignHeight,
                  ),
                  onReplyPullPointerDown: _handleReplyPullPointerDown,
                  onReplyPullPointerMove: (PointerMoveEvent event) =>
                      _handleReplyPullPointerMove(event, metrics, stageState),
                  onReplyPullPointerUp: (PointerEvent event) =>
                      _handleReplyPullPointerUp(event, metrics, stageState),
                  onPrimaryStageScrollNotification:
                      (ScrollNotification notification) =>
                          _handlePrimaryStageScrollNotification(notification),
                  onArchiveCollapsePullUpdate: (DragUpdateDetails details) =>
                      _handleArchiveCollapsePullUpdate(details, metrics),
                  onArchiveCollapsePullEnd: (DragEndDetails details) =>
                      _handleArchiveCollapsePullEnd(details, metrics),
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
                  hintText: isBusy
                      ? '小眠正在整理你的心绪...'
                      : widget.captureModeEnabled
                      ? _captureCopy.inputHint
                      : '和小眠说说现在的心情...',
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
    required this.captureModeEnabled,
    required this.selectedCaptureTab,
    required this.onCaptureTabChanged,
    required this.archiveController,
    required this.archivePhase,
    required this.flowHintText,
    required this.archiveAtBottom,
    required this.primaryStageAtTop,
    required this.primaryStageScrollController,
    required this.bodyBottomOverlayInset,
    required this.replyPullTriggerZoneHeight,
    required this.onReplyPullPointerDown,
    required this.onReplyPullPointerMove,
    required this.onReplyPullPointerUp,
    required this.onPrimaryStageScrollNotification,
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
  final bool captureModeEnabled;
  final AssistantCaptureTab selectedCaptureTab;
  final ValueChanged<AssistantCaptureTab> onCaptureTabChanged;
  final AnimationController archiveController;
  final _AssistantArchivePhase archivePhase;
  final String? flowHintText;
  final bool archiveAtBottom;
  final bool primaryStageAtTop;
  final ScrollController primaryStageScrollController;
  final double bodyBottomOverlayInset;
  final double replyPullTriggerZoneHeight;
  final ValueChanged<PointerDownEvent> onReplyPullPointerDown;
  final ValueChanged<PointerMoveEvent> onReplyPullPointerMove;
  final ValueChanged<PointerEvent> onReplyPullPointerUp;
  final bool Function(ScrollNotification notification)
  onPrimaryStageScrollNotification;
  final ValueChanged<DragUpdateDetails> onArchiveCollapsePullUpdate;
  final ValueChanged<DragEndDetails> onArchiveCollapsePullEnd;
  final bool Function(ScrollNotification notification)
  onArchiveScrollNotification;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: archiveController,
      builder: (BuildContext context, Widget? child) {
        final double archiveProgress = archiveController.value.clamp(0, 1);
        final Widget primaryStage = NotificationListener<ScrollNotification>(
          onNotification: onPrimaryStageScrollNotification,
          child: _AssistantPrimaryStage(
            metrics: metrics,
            palette: palette,
            stageState: stageState,
            latestUserText: slice.latestUser?.content.trim() ?? '',
            latestAssistantText: slice.latestAssistant?.content.trim() ?? '',
            statuses: statuses,
            replyMotionLevel: replyMotionLevel,
            captureModeEnabled: captureModeEnabled,
            selectedCaptureTab: selectedCaptureTab,
            onCaptureTabChanged: onCaptureTabChanged,
            scrollController: primaryStageScrollController,
            bodyBottomOverlayInset: bodyBottomOverlayInset,
          ),
        );
        final Widget archiveStage = NotificationListener<ScrollNotification>(
          onNotification: onArchiveScrollNotification,
          child: IgnorePointer(
            ignoring: archivePhase != _AssistantArchivePhase.expanded,
            child: _AssistantArchiveStage(
              metrics: metrics,
              palette: palette,
              messages: slice.visibleMessages,
              controller: controller,
              bottomOverlayInset: bodyBottomOverlayInset,
            ),
          ),
        );

        final Widget viewportBody = switch (archivePhase) {
          _AssistantArchivePhase.collapsed => primaryStage,
          _AssistantArchivePhase.expanded => archiveStage,
          _AssistantArchivePhase.expanding => Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _AssistantFlowMotionLayer(
                metrics: metrics,
                progress: archiveProgress,
                mode: _AssistantFlowMotionMode.outgoing,
                child: primaryStage,
              ),
              _AssistantFlowMotionLayer(
                metrics: metrics,
                progress: archiveProgress,
                mode: _AssistantFlowMotionMode.incoming,
                child: archiveStage,
              ),
            ],
          ),
          _AssistantArchivePhase.collapsing => Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _AssistantFlowMotionLayer(
                metrics: metrics,
                progress: archiveProgress,
                mode: _AssistantFlowMotionMode.outgoing,
                child: archiveStage,
              ),
              _AssistantFlowMotionLayer(
                metrics: metrics,
                progress: archiveProgress,
                mode: _AssistantFlowMotionMode.incoming,
                child: primaryStage,
              ),
            ],
          ),
        };

        return SizedBox.expand(
          key: const ValueKey<String>('assistant-stage-viewport'),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned.fill(child: viewportBody),
              if (archivePhase == _AssistantArchivePhase.collapsed &&
                  stageState == _AssistantStageState.reply &&
                  primaryStageAtTop)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Listener(
                    key: const ValueKey<String>('assistant-stage-pull-zone'),
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: onReplyPullPointerDown,
                    onPointerMove: onReplyPullPointerMove,
                    onPointerUp: onReplyPullPointerUp,
                    onPointerCancel: onReplyPullPointerUp,
                    child: SizedBox(height: replyPullTriggerZoneHeight),
                  ),
                ),
              if (archivePhase == _AssistantArchivePhase.expanded &&
                  archiveAtBottom)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: bodyBottomOverlayInset - metrics.unit(28),
                    ),
                    child: GestureDetector(
                      key: const ValueKey<String>(
                        'assistant-history-collapse-zone',
                      ),
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: onArchiveCollapsePullUpdate,
                      onVerticalDragEnd: onArchiveCollapsePullEnd,
                      child: SizedBox(
                        width: double.infinity,
                        height: metrics.unit(144),
                      ),
                    ),
                  ),
                ),
              IgnorePointer(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bodyBottomOverlayInset),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      reverseDuration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder:
                          (Widget child, Animation<double> animation) =>
                              FadeTransition(opacity: animation, child: child),
                      child: flowHintText == null
                          ? const SizedBox(
                              key: ValueKey<String>(
                                'assistant-history-hint-hidden',
                              ),
                            )
                          : AssistantPullHint(
                              key: ValueKey<String>(
                                'assistant-history-hint-$flowHintText',
                              ),
                              metrics: metrics,
                              palette: palette,
                              text: flowHintText!,
                            ),
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

enum _AssistantFlowMotionMode { incoming, outgoing }

class _AssistantFlowMotionLayer extends StatelessWidget {
  const _AssistantFlowMotionLayer({
    required this.metrics,
    required this.progress,
    required this.mode,
    required this.child,
  });

  final AssistantSurfaceMetrics metrics;
  final double progress;
  final _AssistantFlowMotionMode mode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double easedProgress = switch (mode) {
      _AssistantFlowMotionMode.incoming => Curves.easeOutCubic.transform(
        const Interval(0.34, 1).transform(progress),
      ),
      _AssistantFlowMotionMode.outgoing => Curves.easeInOutCubic.transform(
        const Interval(0, 0.64).transform(progress),
      ),
    };
    final double opacity = switch (mode) {
      _AssistantFlowMotionMode.incoming => easedProgress,
      _AssistantFlowMotionMode.outgoing => 1 - easedProgress,
    };
    final double translateY = switch (mode) {
      _AssistantFlowMotionMode.incoming => lerpDouble(
        metrics.unit(136),
        0,
        easedProgress,
      )!,
      _AssistantFlowMotionMode.outgoing => lerpDouble(
        0,
        -metrics.unit(228),
        easedProgress,
      )!,
    };

    return IgnorePointer(
      ignoring: true,
      child: Opacity(
        opacity: opacity.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, translateY), child: child),
      ),
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
    required this.captureModeEnabled,
    required this.selectedCaptureTab,
    required this.onCaptureTabChanged,
    required this.scrollController,
    required this.bodyBottomOverlayInset,
  });

  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;
  final _AssistantStageState stageState;
  final String latestUserText;
  final String latestAssistantText;
  final List<AssistantToolStatus> statuses;
  final AssistantReplyMotionLevel replyMotionLevel;
  final bool captureModeEnabled;
  final AssistantCaptureTab selectedCaptureTab;
  final ValueChanged<AssistantCaptureTab> onCaptureTabChanged;
  final ScrollController scrollController;
  final double bodyBottomOverlayInset;

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
        motionLevel: replyMotionLevel,
        captureModeEnabled: captureModeEnabled,
        selectedCaptureTab: selectedCaptureTab,
        onCaptureTabChanged: onCaptureTabChanged,
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
    final double stageTopInset = switch (stageState) {
      _AssistantStageState.empty =>
        captureModeEnabled ? metrics.unit(40) : metrics.unit(124),
      _AssistantStageState.waiting => metrics.unit(108),
      _AssistantStageState.reply => metrics.unit(92),
    };

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double contentWidth = metrics.contentWidth(constraints.maxWidth);
        return SingleChildScrollView(
          key: const ValueKey<String>('assistant-primary-scroll'),
          controller: scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              top: stageTopInset,
              bottom: bodyBottomOverlayInset,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                child: AnimatedSwitcher(
                  duration: _assistantStageTransitionDuration,
                  switchInCurve: Curves.linear,
                  switchOutCurve: Curves.linear,
                  layoutBuilder:
                      (Widget? currentChild, List<Widget> previousChildren) =>
                          Stack(
                            alignment: Alignment.topCenter,
                            children: <Widget>[
                              ...previousChildren,
                              if (currentChild case final Widget currentChild)
                                currentChild,
                            ],
                          ),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        final bool isIncoming = child.key == stageKey;
                        final Animation<double> stageOpacity;
                        final Animation<double> stageProgress;
                        final double beginDy;
                        final double endDy;
                        if (isIncoming) {
                          stageProgress = CurvedAnimation(
                            parent: animation,
                            curve: const Interval(
                              0.60,
                              1,
                              curve: Curves.easeOutCubic,
                            ),
                          );
                          stageOpacity = stageProgress;
                          beginDy = metrics.unit(136);
                          endDy = 0;
                        } else {
                          stageProgress = CurvedAnimation(
                            parent: ReverseAnimation(animation),
                            curve: const Interval(
                              0,
                              0.40,
                              curve: Curves.easeInOutCubic,
                            ),
                          );
                          stageOpacity = Tween<double>(
                            begin: 1,
                            end: 0,
                          ).animate(stageProgress);
                          beginDy = 0;
                          endDy = -metrics.unit(228);
                        }

                        return AnimatedBuilder(
                          animation: stageProgress,
                          child: child,
                          builder: (BuildContext context, Widget? child) {
                            final double translateY = lerpDouble(
                              beginDy,
                              endDy,
                              stageProgress.value,
                            )!;
                            return Opacity(
                              opacity: stageOpacity.value.clamp(0, 1),
                              child: Transform.translate(
                                offset: Offset(0, translateY),
                                child: child,
                              ),
                            );
                          },
                        );
                      },
                  child: activeStage,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AssistantEmptyStage extends StatelessWidget {
  const _AssistantEmptyStage({
    super.key,
    required this.metrics,
    required this.palette,
    required this.motionLevel,
    required this.captureModeEnabled,
    required this.selectedCaptureTab,
    required this.onCaptureTabChanged,
  });

  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;
  final AssistantReplyMotionLevel motionLevel;
  final bool captureModeEnabled;
  final AssistantCaptureTab selectedCaptureTab;
  final ValueChanged<AssistantCaptureTab> onCaptureTabChanged;

  @override
  Widget build(BuildContext context) {
    if (captureModeEnabled) {
      return _AssistantCaptureEmptyStage(
        metrics: metrics,
        palette: palette,
        motionLevel: motionLevel,
        selectedTab: selectedCaptureTab,
        onTabChanged: onCaptureTabChanged,
      );
    }

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
              travelDistance: _replyFloatingDistance(metrics, motionLevel),
              duration: _replyFloatingDuration(motionLevel),
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

class _AssistantCaptureEmptyStage extends StatelessWidget {
  const _AssistantCaptureEmptyStage({
    required this.metrics,
    required this.palette,
    required this.motionLevel,
    required this.selectedTab,
    required this.onTabChanged,
  });

  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;
  final AssistantReplyMotionLevel motionLevel;
  final AssistantCaptureTab selectedTab;
  final ValueChanged<AssistantCaptureTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final _AssistantCaptureCopy copy = _AssistantCaptureCopy.forTab(
      selectedTab,
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double contentWidth = metrics.contentWidth(constraints.maxWidth);
        return Center(
          child: SizedBox(
            width: contentWidth,
            child: AssistantFloatingMotion(
              transformKey: const ValueKey<String>(
                'assistant-capture-empty-floating-motion',
              ),
              travelDistance: _replyFloatingDistance(metrics, motionLevel),
              duration: _replyFloatingDuration(motionLevel),
              child: Column(
                key: const ValueKey<String>('assistant-capture-empty-stage'),
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _AssistantCaptureOrb(metrics: metrics, palette: palette),
                  SizedBox(height: metrics.unit(24)),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: Text(
                      copy.headline,
                      key: ValueKey<String>('capture-headline-${copy.typeKey}'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: palette.headlineText,
                            fontSize: metrics.unit(25),
                            fontWeight: FontWeight.w800,
                            height: 1.18,
                          ),
                    ),
                  ),
                  SizedBox(height: metrics.unit(10)),
                  Text(
                    copy.subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.bodyText,
                      fontSize: metrics.unit(14),
                      fontWeight: FontWeight.w500,
                      height: 1.55,
                    ),
                  ),
                  SizedBox(height: metrics.unit(24)),
                  _AssistantCaptureTabSwitch(
                    metrics: metrics,
                    palette: palette,
                    selectedTab: selectedTab,
                    onTabChanged: onTabChanged,
                  ),
                  SizedBox(height: metrics.unit(22)),
                  _AssistantCapturePromptPanel(
                    metrics: metrics,
                    palette: palette,
                    copy: copy,
                  ),
                  SizedBox(height: metrics.unit(12)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      copy.saveTip,
                      key: ValueKey<String>('capture-save-tip-${copy.typeKey}'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: palette.mutedText,
                        fontSize: metrics.unit(12),
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
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

class _AssistantCaptureOrb extends StatelessWidget {
  const _AssistantCaptureOrb({required this.metrics, required this.palette});

  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _assistantAlpha(palette.bottomGlowCore, 0.16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _assistantAlpha(palette.bottomGlowMid, 0.22),
            blurRadius: metrics.unit(26),
            spreadRadius: metrics.unit(6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(metrics.unit(18)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _assistantAlpha(palette.bottomGlowCore, 0.62),
            border: Border.all(
              color: _assistantAlpha(palette.headerIcon, 0.28),
              width: metrics.unit(1.5),
            ),
          ),
          child: SizedBox.square(
            dimension: metrics.unit(50),
            child: Icon(
              Icons.nightlight_round,
              color: _assistantAlpha(palette.headlineText, 0.82),
              size: metrics.unit(24),
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantCaptureTabSwitch extends StatelessWidget {
  const _AssistantCaptureTabSwitch({
    required this.metrics,
    required this.palette,
    required this.selectedTab,
    required this.onTabChanged,
  });

  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;
  final AssistantCaptureTab selectedTab;
  final ValueChanged<AssistantCaptureTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _assistantAlpha(Colors.black, 0.18),
        borderRadius: BorderRadius.circular(metrics.unit(999)),
        border: Border.all(
          color: _assistantAlpha(palette.composerBorder, 0.34),
          width: metrics.unit(1),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(metrics.unit(4)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _AssistantCaptureTabButton(
              metrics: metrics,
              palette: palette,
              label: '梦记',
              selected: selectedTab == AssistantCaptureTab.dream,
              onTap: () => onTabChanged(AssistantCaptureTab.dream),
            ),
            _AssistantCaptureTabButton(
              metrics: metrics,
              palette: palette,
              label: '事记',
              selected: selectedTab == AssistantCaptureTab.memo,
              onTap: () => onTabChanged(AssistantCaptureTab.memo),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantCaptureTabButton extends StatelessWidget {
  const _AssistantCaptureTabButton({
    required this.metrics,
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(metrics.unit(999)),
        onTap: selected ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: metrics.unit(88),
          padding: EdgeInsets.symmetric(vertical: metrics.unit(10)),
          decoration: BoxDecoration(
            color: selected
                ? _assistantAlpha(palette.bottomGlowMid, 0.86)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(metrics.unit(999)),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: _assistantAlpha(palette.bottomGlowMid, 0.20),
                      blurRadius: metrics.unit(12),
                      offset: Offset(0, metrics.unit(4)),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? palette.headlineText : palette.bodyText,
              fontSize: metrics.unit(15),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantCapturePromptPanel extends StatelessWidget {
  const _AssistantCapturePromptPanel({
    required this.metrics,
    required this.palette,
    required this.copy,
  });

  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;
  final _AssistantCaptureCopy copy;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: DecoratedBox(
        key: ValueKey<String>('capture-prompt-${copy.typeKey}'),
        decoration: BoxDecoration(
          color: _assistantAlpha(const Color(0xFF0A2D5C), 0.72),
          borderRadius: BorderRadius.circular(metrics.unit(14)),
          border: Border.all(
            color: _assistantAlpha(palette.headerIcon, 0.08),
            width: metrics.unit(1),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: _assistantAlpha(Colors.black, 0.18),
              blurRadius: metrics.unit(18),
              offset: Offset(0, metrics.unit(8)),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: metrics.unit(18),
            vertical: metrics.unit(18),
          ),
          child: Text(
            copy.prompt,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _assistantAlpha(Colors.white, 0.90),
              fontSize: metrics.unit(15),
              fontWeight: FontWeight.w700,
              height: 1.58,
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantCaptureCopy {
  const _AssistantCaptureCopy({
    required this.typeKey,
    required this.headline,
    required this.subtitle,
    required this.prompt,
    required this.saveTip,
    required this.inputHint,
  });

  factory _AssistantCaptureCopy.forTab(AssistantCaptureTab tab) {
    return switch (tab) {
      AssistantCaptureTab.dream => const _AssistantCaptureCopy(
        typeKey: 'dream',
        headline: '把梦先轻轻记下来',
        subtitle: '不用一次写完整，先把还记得的画面、人物、颜色或一句话留住就好。',
        prompt: '如果刚醒来还模糊，可以先从“我看到了什么”“我当时什么感觉”“有没有一句特别清楚的话”开始写，我会帮你把梦记轻轻收好。',
        saveTip: '会保存到“我的 / 梦境记录”。',
        inputHint: '例如：我梦见自己站在很高的桥上...',
      ),
      AssistantCaptureTab.memo => const _AssistantCaptureCopy(
        typeKey: 'memo',
        headline: '把事也先安放下来',
        subtitle: '怕睡前突然想到的事明早忘掉，就先在这里交给我保管。',
        prompt: '你可以写下明天要做的事、突然想到的人名任务，或者一句不想忘记的话。我会先帮你整理成简短提要，让你今晚不用一直惦记着它。',
        saveTip: '会保存到“我的 / 事记仓库”，结束睡眠模式后，首页会给整理提醒。',
        inputHint: '例如：明早要给导师发材料，还要记得问室友借充电器...',
      ),
    };
  }

  final String typeKey;
  final String headline;
  final String subtitle;
  final String prompt;
  final String saveTip;
  final String inputHint;
}

Color _assistantAlpha(Color color, double opacity) {
  return color.withAlpha((opacity * 255).round().clamp(0, 255));
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
                  duration: _replyFloatingDuration(motionLevel),
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
    AssistantReplyMotionLevel.low => metrics.unit(5),
    AssistantReplyMotionLevel.medium => metrics.unit(14),
    AssistantReplyMotionLevel.high => metrics.unit(26),
  };
}

Duration _replyFloatingDuration(AssistantReplyMotionLevel level) {
  return switch (level) {
    AssistantReplyMotionLevel.low => const Duration(milliseconds: 5200),
    AssistantReplyMotionLevel.medium => const Duration(milliseconds: 3000),
    AssistantReplyMotionLevel.high => const Duration(milliseconds: 1800),
  };
}

class _AssistantArchiveStage extends StatefulWidget {
  const _AssistantArchiveStage({
    required this.metrics,
    required this.palette,
    required this.messages,
    required this.controller,
    required this.bottomOverlayInset,
  });

  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;
  final List<AssistantMessage> messages;
  final AssistantConversationController controller;
  final double bottomOverlayInset;

  @override
  State<_AssistantArchiveStage> createState() => _AssistantArchiveStageState();
}

class _AssistantArchiveStageState extends State<_AssistantArchiveStage> {
  final ScrollController _scrollController = ScrollController();
  bool _hasAnchoredToLatest = false;

  @override
  void initState() {
    super.initState();
    _scheduleAnchorToLatest();
  }

  @override
  void didUpdateWidget(covariant _AssistantArchiveStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messages.length == widget.messages.length) {
      return;
    }
    final bool shouldStayPinned =
        !_scrollController.hasClients ||
        (_scrollController.position.maxScrollExtent -
                _scrollController.position.pixels) <=
            widget.metrics.unit(28);
    if (shouldStayPinned) {
      _scheduleAnchorToLatest(animated: _hasAnchoredToLatest);
    }
  }

  void _scheduleAnchorToLatest({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final double target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(target);
      }
      _hasAnchoredToLatest = true;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) {
      return const SizedBox.expand();
    }

    AssistantMessage? latestAssistant;
    for (final AssistantMessage message in widget.messages.reversed) {
      if (message.role == AssistantMessageRole.assistant) {
        latestAssistant = message;
        break;
      }
    }
    final int latestAssistantIndex = latestAssistant == null
        ? -1
        : widget.messages.lastIndexOf(latestAssistant);
    final List<AssistantMessage> earlierMessages = latestAssistantIndex <= 0
        ? widget.messages
              .take(latestAssistantIndex == -1 ? widget.messages.length : 0)
              .toList(growable: false)
        : widget.messages.sublist(0, latestAssistantIndex);
    final bool showEarlierLabel = earlierMessages.any(
      (AssistantMessage message) =>
          message.role == AssistantMessageRole.assistant,
    );
    final bool showCurrentLabel =
        latestAssistant != null && earlierMessages.isNotEmpty;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double contentWidth = widget.metrics.contentWidth(
          constraints.maxWidth,
        );
        return SingleChildScrollView(
          controller: _scrollController,
          key: const ValueKey<String>('assistant-history-scroll'),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  top: widget.metrics.unit(8),
                  bottom: widget.bottomOverlayInset,
                ),
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
                                color: widget.palette.mutedText,
                                fontSize: widget.metrics.unit(11),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        SizedBox(height: widget.metrics.unit(16)),
                      ],
                      ...earlierMessages.expand<Widget>((
                        AssistantMessage message,
                      ) {
                        if (message.role == AssistantMessageRole.user) {
                          return <Widget>[
                            AssistantUserCard(
                              text: message.content.trim(),
                              metrics: widget.metrics,
                              palette: widget.palette,
                            ),
                            SizedBox(height: widget.metrics.unit(16)),
                          ];
                        }

                        final List<AssistantToolStatus> messageStatuses =
                            assistantToolStatusesFromSurfaceIds(
                              widget.controller.updatedSurfacesForMessage(
                                message.id,
                              ),
                            );
                        return <Widget>[
                          Text(
                            message.content.trim(),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: widget.palette.bodyText,
                                  fontSize: widget.metrics.unit(13),
                                  fontWeight: FontWeight.w500,
                                  height: 1.58,
                                ),
                          ),
                          if (messageStatuses.isNotEmpty) ...<Widget>[
                            SizedBox(height: widget.metrics.unit(8)),
                            AssistantBulletStatusList(
                              statuses: messageStatuses,
                              metrics: widget.metrics,
                              palette: widget.palette,
                            ),
                          ],
                          SizedBox(height: widget.metrics.unit(16)),
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
                                color: widget.palette.mutedText,
                                fontSize: widget.metrics.unit(11),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        SizedBox(height: widget.metrics.unit(16)),
                      ],
                      if (latestAssistant != null) ...<Widget>[
                        Text(
                          latestAssistant.content.trim(),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: widget.palette.headlineText,
                                fontSize: widget.metrics.unit(20),
                                fontWeight: FontWeight.w500,
                                height: 1.62,
                              ),
                        ),
                        SizedBox(height: widget.metrics.unit(12)),
                        AssistantBulletStatusList(
                          statuses: assistantToolStatusesFromSurfaceIds(
                            widget.controller.updatedSurfacesForMessage(
                              latestAssistant.id,
                            ),
                          ),
                          metrics: widget.metrics,
                          palette: widget.palette,
                        ),
                      ] else
                        ...widget.messages
                            .where(
                              (AssistantMessage message) =>
                                  message.role == AssistantMessageRole.user,
                            )
                            .map(
                              (AssistantMessage message) => Padding(
                                padding: EdgeInsets.only(
                                  bottom: widget.metrics.unit(16),
                                ),
                                child: AssistantUserCard(
                                  text: message.content.trim(),
                                  metrics: widget.metrics,
                                  palette: widget.palette,
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
