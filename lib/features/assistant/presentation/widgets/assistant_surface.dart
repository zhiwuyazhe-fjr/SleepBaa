import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/interaction/app_haptics.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class AssistantSurfaceMetrics {
  const AssistantSurfaceMetrics._({required this.scale});

  factory AssistantSurfaceMetrics.fromWidth(double width) {
    final double nextScale = (width / 390).clamp(0.92, 1.0);
    return AssistantSurfaceMetrics._(scale: nextScale);
  }

  final double scale;

  double unit(double designUnit) => designUnit * scale;

  double contentWidth(double maxWidth, {double designWidth = 344}) {
    return math.min(maxWidth, unit(designWidth));
  }
}

class AssistantToolStatus {
  const AssistantToolStatus({
    required this.icon,
    required this.label,
    this.undoCallId,
    this.undoStatus,
    this.navigationRoute,
    this.navigationLabel,
  });

  final IconData icon;
  final String label;
  final String? undoCallId;
  final String? undoStatus;
  final String? navigationRoute;
  final String? navigationLabel;

  bool get canUndo =>
      undoCallId != null && undoCallId!.isNotEmpty && undoStatus == 'available';

  bool get canNavigate =>
      navigationRoute != null && navigationRoute!.trim().isNotEmpty;
}

class AssistantConversationSlice {
  const AssistantConversationSlice({
    required this.visibleMessages,
    required this.latestUser,
    required this.latestAssistant,
  });

  factory AssistantConversationSlice.fromMessages(
    List<AssistantMessage> messages,
  ) {
    final List<AssistantMessage> filtered = messages
        .where(
          (AssistantMessage message) =>
              message.role != AssistantMessageRole.system,
        )
        .toList(growable: false);
    final int firstUserIndex = filtered.indexWhere(
      (AssistantMessage message) => message.role == AssistantMessageRole.user,
    );
    final List<AssistantMessage> visibleMessages = firstUserIndex == -1
        ? const <AssistantMessage>[]
        : List<AssistantMessage>.unmodifiable(filtered.sublist(firstUserIndex));

    AssistantMessage? latestUser;
    AssistantMessage? latestAssistant;
    for (final AssistantMessage message in visibleMessages.reversed) {
      if (latestUser == null && message.role == AssistantMessageRole.user) {
        latestUser = message;
      }
      if (latestAssistant == null &&
          message.role == AssistantMessageRole.assistant) {
        latestAssistant = message;
      }
      if (latestUser != null && latestAssistant != null) {
        break;
      }
    }

    return AssistantConversationSlice(
      visibleMessages: visibleMessages,
      latestUser: latestUser,
      latestAssistant: latestAssistant,
    );
  }

  final List<AssistantMessage> visibleMessages;
  final AssistantMessage? latestUser;
  final AssistantMessage? latestAssistant;

  bool get hasVisibleConversation => visibleMessages.isNotEmpty;
}

class AssistantSurfacePalette {
  const AssistantSurfacePalette({
    required this.headerIcon,
    required this.titleText,
    required this.headlineText,
    required this.bodyText,
    required this.secondaryText,
    required this.mutedText,
    required this.statusText,
    required this.composerFill,
    required this.composerBorder,
    required this.composerShadow,
    required this.composerText,
    required this.composerHint,
    required this.userCardFill,
    required this.userCardBorder,
    required this.userText,
    required this.bottomGlowStart,
    required this.bottomGlowMid,
    required this.bottomGlowCore,
  });

  factory AssistantSurfacePalette.fromMood(NightMoodPalette mood) {
    final Color accent = mood.welcomeAccentColor;
    final Color surface = mood.welcomeSurfaceColor;
    final Color softAccent = Color.lerp(accent, surface, 0.24)!;
    final HSLColor accentHsl = HSLColor.fromColor(accent.withAlpha(0xFF));
    final HSLColor heroEndHsl = HSLColor.fromColor(
      mood.heroGradientEnd.withAlpha(0xFF),
    );
    final HSLColor stripCore = HSLColor.fromAHSL(
      1,
      accentHsl.hue,
      (accentHsl.saturation * 0.92).clamp(0.0, 1.0),
      (heroEndHsl.lightness + 0.06).clamp(0.18, 0.32),
    );
    final HSLColor stripMid = stripCore.withLightness(
      (stripCore.lightness + 0.12).clamp(0.0, 1.0),
    );
    final HSLColor stripTail = HSLColor.fromColor(
      Color.lerp(stripMid.toColor(), softAccent, 0.54)!,
    ).withLightness((stripMid.lightness + 0.24).clamp(0.0, 0.84));
    final Color textBlend = Color.lerp(AppColors.onDark, surface, 0.42)!;

    return AssistantSurfacePalette(
      headerIcon: _alpha(AppColors.onDark, 0.90),
      titleText: _alpha(AppColors.onDark, 0.95),
      headlineText: _alpha(AppColors.onDark, 0.98),
      bodyText: _alpha(textBlend, 0.92),
      secondaryText: _alpha(textBlend, 0.82),
      mutedText: _alpha(textBlend, 0.66),
      statusText: _alpha(textBlend, 0.74),
      composerFill: _alpha(Colors.white, 0.04),
      composerBorder: _alpha(accent, 0.40),
      composerShadow: _alpha(accent, 0.17),
      composerText: _alpha(AppColors.onDark, 0.92),
      composerHint: _alpha(AppColors.onDark, 0.78),
      userCardFill: _alpha(surface, 0.91),
      userCardBorder: _alpha(accent, 0.22),
      userText: _alpha(Color.lerp(AppColors.onDark, surface, 0.18)!, 0.93),
      bottomGlowStart: stripTail.toColor(),
      bottomGlowMid: stripMid.toColor(),
      bottomGlowCore: stripCore.toColor(),
    );
  }

  final Color headerIcon;
  final Color titleText;
  final Color headlineText;
  final Color bodyText;
  final Color secondaryText;
  final Color mutedText;
  final Color statusText;
  final Color composerFill;
  final Color composerBorder;
  final Color composerShadow;
  final Color composerText;
  final Color composerHint;
  final Color userCardFill;
  final Color userCardBorder;
  final Color userText;
  final Color bottomGlowStart;
  final Color bottomGlowMid;
  final Color bottomGlowCore;
}

class AssistantBackgroundGlow extends StatelessWidget {
  const AssistantBackgroundGlow({super.key, required this.palette});

  final AssistantSurfacePalette palette;

  @override
  Widget build(BuildContext context) {
    final Color transparentTail = _alpha(palette.bottomGlowStart, 0);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const DecoratedBox(
          decoration: BoxDecoration(color: AppColors.darkBackground),
        ),
        IgnorePointer(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.68,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: const <double>[0, 0.08, 0.20, 0.38, 0.58, 0.78, 1],
                    colors: <Color>[
                      _alpha(palette.bottomGlowCore, 0.84),
                      _alpha(palette.bottomGlowCore, 0.66),
                      _alpha(palette.bottomGlowMid, 0.48),
                      _alpha(palette.bottomGlowMid, 0.30),
                      _alpha(palette.bottomGlowStart, 0.18),
                      _alpha(palette.bottomGlowStart, 0.06),
                      transparentTail,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              widthFactor: 1.06,
              heightFactor: 0.28,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: const <double>[0, 0.18, 0.42, 0.72, 1],
                    colors: <Color>[
                      _alpha(palette.bottomGlowCore, 0.96),
                      _alpha(palette.bottomGlowMid, 0.58),
                      _alpha(palette.bottomGlowMid, 0.24),
                      _alpha(palette.bottomGlowStart, 0.08),
                      transparentTail,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AssistantShellScaffold extends StatelessWidget {
  const AssistantShellScaffold({
    super.key,
    required this.bodyBuilder,
    required this.composerBuilder,
    required this.onTapAdd,
    required this.onTapMemory,
    required this.onTapHistory,
  });

  final Widget Function(
    BuildContext context,
    AssistantSurfaceMetrics metrics,
    AssistantSurfacePalette palette,
    double bodyBottomOverlayInset,
  )
  bodyBuilder;
  final Widget Function(
    BuildContext context,
    AssistantSurfaceMetrics metrics,
    AssistantSurfacePalette palette,
  )
  composerBuilder;
  final VoidCallback? onTapAdd;
  final VoidCallback? onTapMemory;
  final VoidCallback? onTapHistory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.darkBackground,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final AssistantSurfaceMetrics metrics =
              AssistantSurfaceMetrics.fromWidth(constraints.maxWidth);
          final AssistantSurfacePalette palette =
              AssistantSurfacePalette.fromMood(context.nightMoodPalette);
          final double keyboardInset = MediaQuery.of(context).viewInsets.bottom;
          final double headerHeight = _assistantHeaderHeight(metrics);
          final double bodyBottomOverlayInset =
              _assistantComposerHeight(metrics) + metrics.unit(20);

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              AssistantBackgroundGlow(palette: palette),
              SafeArea(
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.fromLTRB(
                    metrics.unit(20),
                    metrics.unit(8),
                    metrics.unit(20),
                    metrics.unit(8) + keyboardInset,
                  ),
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        top: headerHeight + metrics.unit(12),
                        child: bodyBuilder(
                          context,
                          metrics,
                          palette,
                          bodyBottomOverlayInset,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SizedBox(
                          height: headerHeight,
                          child: AssistantHeader(
                            metrics: metrics,
                            palette: palette,
                            onTapAdd: onTapAdd,
                            onTapMemory: onTapMemory,
                            onTapHistory: onTapHistory,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: composerBuilder(context, metrics, palette),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

double _assistantHeaderHeight(AssistantSurfaceMetrics metrics) {
  return math.max(metrics.unit(22) * 1.56, 36);
}

double _assistantComposerHeight(AssistantSurfaceMetrics metrics) {
  final double contentHeight = math.max(
    metrics.unit(20),
    metrics.unit(15) * 1.28,
  );
  return contentHeight + (metrics.unit(12) * 2) + (metrics.unit(1.5) * 2);
}

class AssistantHeader extends StatelessWidget {
  const AssistantHeader({
    super.key,
    required this.metrics,
    required this.palette,
    required this.onTapAdd,
    required this.onTapMemory,
    required this.onTapHistory,
  });

  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;
  final VoidCallback? onTapAdd;
  final VoidCallback? onTapMemory;
  final VoidCallback? onTapHistory;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _AssistantActionIconButton(
          key: const ValueKey<String>('assistant-header-add'),
          icon: Icons.add,
          size: metrics.unit(22),
          color: palette.headerIcon,
          tooltip: '新对话',
          onTap: onTapAdd,
        ),
        Expanded(
          child: Center(
            child: Text(
              '小眠',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: palette.titleText,
                fontSize: metrics.unit(20),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        _AssistantActionIconButton(
          key: const ValueKey<String>('assistant-header-memory'),
          icon: Icons.psychology_alt_outlined,
          size: metrics.unit(21),
          color: palette.headerIcon,
          tooltip: '记忆与进化',
          onTap: onTapMemory,
        ),
        _AssistantActionIconButton(
          key: const ValueKey<String>('assistant-header-history'),
          icon: Icons.history,
          size: metrics.unit(22),
          color: palette.headerIcon,
          tooltip: '历史对话',
          onTap: onTapHistory,
        ),
      ],
    );
  }
}

class AssistantFloatingMotion extends StatefulWidget {
  const AssistantFloatingMotion({
    super.key,
    required this.child,
    required this.travelDistance,
    this.duration = const Duration(milliseconds: 2600),
    this.transformKey,
  });

  final Widget child;
  final double travelDistance;
  final Duration duration;
  final Key? transformKey;

  @override
  State<AssistantFloatingMotion> createState() =>
      _AssistantFloatingMotionState();
}

class _AssistantFloatingMotionState extends State<AssistantFloatingMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat(reverse: true);
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutSine,
  );

  @override
  void didUpdateWidget(covariant AssistantFloatingMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double offsetY = lerpDouble(
          0,
          -widget.travelDistance,
          _animation.value,
        )!;
        return Transform.translate(
          key: widget.transformKey,
          offset: Offset(0, offsetY),
          child: child,
        );
      },
    );
  }
}

class AssistantLoopingRotation extends StatefulWidget {
  const AssistantLoopingRotation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1200),
  });

  final Widget child;
  final Duration duration;

  @override
  State<AssistantLoopingRotation> createState() =>
      _AssistantLoopingRotationState();
}

class _AssistantLoopingRotationState extends State<AssistantLoopingRotation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(turns: _controller, child: widget.child);
  }
}

class AssistantComposer extends StatelessWidget {
  const AssistantComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.metrics,
    required this.palette,
    required this.hintText,
    required this.isBusy,
    required this.onSubmit,
    this.onTapAdd,
    this.onTapMic,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;
  final String hintText;
  final bool isBusy;
  final VoidCallback onSubmit;
  final VoidCallback? onTapAdd;
  final VoidCallback? onTapMic;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(metrics.unit(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: metrics.unit(16),
          sigmaY: metrics.unit(16),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.composerFill,
            border: Border.all(
              color: palette.composerBorder,
              width: metrics.unit(1.5),
            ),
            borderRadius: BorderRadius.circular(metrics.unit(20)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: palette.composerShadow,
                blurRadius: metrics.unit(16),
                offset: Offset(0, metrics.unit(6)),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: metrics.unit(14),
              vertical: metrics.unit(12),
            ),
            child: ListenableBuilder(
              listenable: controller,
              builder: (BuildContext context, Widget? child) {
                final bool canSubmit =
                    !isBusy && controller.text.trim().isNotEmpty;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    _AssistantActionIconButton(
                      key: const ValueKey<String>('assistant-composer-add'),
                      icon: Icons.add,
                      size: metrics.unit(20),
                      color: palette.headerIcon,
                      onTap: onTapAdd,
                    ),
                    SizedBox(width: metrics.unit(8)),
                    Expanded(
                      child: TextField(
                        key: const ValueKey<String>('assistant-composer-field'),
                        controller: controller,
                        focusNode: focusNode,
                        textInputAction: TextInputAction.send,
                        maxLines: 1,
                        cursorColor: palette.composerText,
                        keyboardAppearance: Brightness.dark,
                        onSubmitted: (_) => onSubmit(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: palette.composerText,
                          fontSize: metrics.unit(15),
                          fontWeight: FontWeight.w500,
                          height: 1.28,
                        ),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: hintText,
                          hintMaxLines: 1,
                          hintStyle: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: palette.composerHint,
                                fontSize: metrics.unit(isBusy ? 14 : 15),
                                fontWeight: FontWeight.w500,
                                height: 1.28,
                              ),
                        ),
                      ),
                    ),
                    SizedBox(width: metrics.unit(6)),
                    _AssistantActionIconButton(
                      key: const ValueKey<String>('assistant-composer-mic'),
                      icon: Icons.mic_none_rounded,
                      size: metrics.unit(20),
                      color: palette.headerIcon,
                      onTap: isBusy ? null : onTapMic,
                    ),
                    SizedBox(width: metrics.unit(1)),
                    _AssistantActionIconButton(
                      key: const ValueKey<String>('assistant-composer-submit'),
                      size: metrics.unit(20),
                      color: palette.headerIcon,
                      onTap: canSubmit ? onSubmit : null,
                      hapticRole: null,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: isBusy
                            ? AssistantLoopingRotation(
                                key: const ValueKey<String>(
                                  'assistant-composer-busy-icon',
                                ),
                                child: Icon(
                                  Icons.autorenew_rounded,
                                  size: metrics.unit(20),
                                  color: palette.headerIcon,
                                ),
                              )
                            : Icon(
                                Icons.arrow_upward_rounded,
                                key: const ValueKey<String>(
                                  'assistant-composer-send-icon',
                                ),
                                size: metrics.unit(20),
                                color: canSubmit
                                    ? palette.headerIcon
                                    : _alpha(palette.headerIcon, 0.34),
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class AssistantPullHint extends StatelessWidget {
  const AssistantPullHint({
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
    return _AssistantPullHintChip(
      metrics: metrics,
      palette: palette,
      text: text,
    );
  }
}

class _AssistantPullHintChip extends StatelessWidget {
  const _AssistantPullHintChip({
    required this.metrics,
    required this.palette,
    required this.text,
  });

  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;
  final String text;

  @override
  Widget build(BuildContext context) {
    final bool isExpandHint = text.contains('下拉');
    return ClipRRect(
      borderRadius: BorderRadius.circular(metrics.unit(999)),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: metrics.unit(14),
          sigmaY: metrics.unit(14),
        ),
        child: DecoratedBox(
          key: const ValueKey<String>('assistant-history-hint'),
          decoration: BoxDecoration(
            color: _alpha(AppColors.darkBackground, 0.48),
            borderRadius: BorderRadius.circular(metrics.unit(999)),
            border: Border.all(
              color: _alpha(palette.composerBorder, 0.72),
              width: metrics.unit(1),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _alpha(palette.bottomGlowMid, 0.24),
                blurRadius: metrics.unit(14),
                offset: Offset(0, metrics.unit(6)),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: metrics.unit(12),
              vertical: metrics.unit(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  isExpandHint
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                  size: metrics.unit(16),
                  color: palette.headerIcon,
                ),
                SizedBox(width: metrics.unit(6)),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.headerIcon,
                    fontSize: metrics.unit(12),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AssistantInlineStatusList extends StatelessWidget {
  const AssistantInlineStatusList({
    super.key,
    required this.statuses,
    required this.metrics,
    required this.palette,
    this.onUndoPressed,
    this.onNavigatePressed,
  });

  final List<AssistantToolStatus> statuses;
  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;
  final ValueChanged<AssistantToolStatus>? onUndoPressed;
  final ValueChanged<AssistantToolStatus>? onNavigatePressed;

  @override
  Widget build(BuildContext context) {
    if (statuses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      key: const ValueKey<String>('assistant-current-status-list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List<Widget>.generate(statuses.length, (int index) {
        final AssistantToolStatus status = statuses[index];
        return Padding(
          padding: EdgeInsets.only(
            bottom: index == statuses.length - 1 ? 0 : metrics.unit(6),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: metrics.unit(2)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  status.icon,
                  size: metrics.unit(14),
                  color: palette.mutedText,
                ),
                SizedBox(width: metrics.unit(8)),
                Flexible(
                  child: Text(
                    status.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: palette.statusText,
                      fontSize: metrics.unit(11),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (status.canUndo && onUndoPressed != null) ...<Widget>[
                  SizedBox(width: metrics.unit(8)),
                  TextButton.icon(
                    key: ValueKey<String>(
                      'assistant-undo-${status.undoCallId}',
                    ),
                    onPressed: () => onUndoPressed!(status),
                    icon: Icon(Icons.undo, size: metrics.unit(13)),
                    label: const Text('撤销'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: Size(metrics.unit(50), metrics.unit(28)),
                      padding: EdgeInsets.symmetric(
                        horizontal: metrics.unit(8),
                        vertical: 0,
                      ),
                    ),
                  ),
                ],
                if (status.canNavigate &&
                    onNavigatePressed != null) ...<Widget>[
                  SizedBox(width: metrics.unit(8)),
                  TextButton.icon(
                    key: ValueKey<String>(
                      'assistant-navigate-${Uri.encodeComponent(status.navigationRoute!)}',
                    ),
                    onPressed: () => onNavigatePressed!(status),
                    icon: Icon(Icons.open_in_new, size: metrics.unit(13)),
                    label: Text(
                      status.navigationLabel?.trim().isNotEmpty == true
                          ? status.navigationLabel!.trim()
                          : '打开',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: Size(metrics.unit(54), metrics.unit(28)),
                      padding: EdgeInsets.symmetric(
                        horizontal: metrics.unit(8),
                        vertical: 0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }
}

class AssistantBulletStatusList extends StatelessWidget {
  const AssistantBulletStatusList({
    super.key,
    required this.statuses,
    required this.metrics,
    required this.palette,
  });

  final List<AssistantToolStatus> statuses;
  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;

  @override
  Widget build(BuildContext context) {
    if (statuses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: statuses
          .map((AssistantToolStatus status) {
            return Padding(
              padding: EdgeInsets.only(bottom: metrics.unit(6)),
              child: Text(
                '· ${status.label}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.statusText,
                  fontSize: metrics.unit(11),
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class AssistantUserCard extends StatelessWidget {
  const AssistantUserCard({
    super.key,
    required this.text,
    required this.metrics,
    required this.palette,
  });

  final String text;
  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(metrics.unit(16)),
      decoration: BoxDecoration(
        color: palette.userCardFill,
        borderRadius: BorderRadius.circular(metrics.unit(20)),
        border: Border.all(
          color: palette.userCardBorder,
          width: metrics.unit(1),
        ),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: palette.userText,
          fontSize: metrics.unit(14),
          fontWeight: FontWeight.w500,
          height: 1.56,
        ),
      ),
    );
  }
}

List<AssistantToolStatus> assistantToolStatusesFromSurfaceIds(
  Iterable<String> surfaceIds,
) {
  final List<AssistantToolStatus> statuses = <AssistantToolStatus>[];
  final Set<String> seenLabels = <String>{};
  for (final String surfaceId in surfaceIds) {
    final AssistantToolStatus? status = _toolStatusForSurfaceId(surfaceId);
    final String seenKey =
        '${status?.label}:${status?.undoCallId ?? ''}:${status?.undoStatus ?? ''}';
    if (status == null || !seenLabels.add(seenKey)) {
      continue;
    }
    statuses.add(status);
  }
  return List<AssistantToolStatus>.unmodifiable(statuses);
}

AssistantToolStatus? _toolStatusForSurfaceId(String surfaceId) {
  final String raw = surfaceId.trim();
  final AssistantToolStatus? undoStatus = _undoToolStatusForSurfaceId(raw);
  if (undoStatus != null) {
    return undoStatus;
  }
  final AssistantToolStatus? navigationStatus =
      _navigationToolStatusForSurfaceId(raw);
  if (navigationStatus != null) {
    return navigationStatus;
  }
  final String normalized = raw.toLowerCase();
  switch (normalized) {
    case 'agent_planning':
      return const AssistantToolStatus(
        icon: Icons.account_tree_outlined,
        label: '小眠已拆解任务',
      );
    case 'agent_tool_context_read':
      return const AssistantToolStatus(
        icon: Icons.manage_search,
        label: '已读取睡眠上下文',
      );
    case 'agent_tool_sleep_records_read':
      return const AssistantToolStatus(
        icon: Icons.bedtime_outlined,
        label: '已检查睡眠记录',
      );
    case 'agent_tool_dream_records_read':
      return const AssistantToolStatus(
        icon: Icons.nights_stay_outlined,
        label: '已检查梦记',
      );
    case 'agent_tool_interference_save_tonight':
      return const AssistantToolStatus(icon: Icons.tune, label: '今晚干扰已更新');
    case 'agent_tool_plan_generate_tonight':
      return const AssistantToolStatus(icon: Icons.route, label: '今晚计划已生成');
    case 'agent_tool_cards_refresh':
      return const AssistantToolStatus(
        icon: Icons.dashboard_customize_outlined,
        label: '页面卡片已刷新',
      );
    case 'agent_tool_dorm_reminder_send':
      return const AssistantToolStatus(
        icon: Icons.record_voice_over_outlined,
        label: '已发送宿舍温和提醒',
      );
    case 'agent_tool_dorm_status_update':
      return const AssistantToolStatus(
        icon: Icons.volume_off,
        label: '宿舍状态已同步',
      );
    case 'agent_tool_dorm_rules_save':
      return const AssistantToolStatus(icon: Icons.rule, label: '宿舍公约已提交');
    case 'agent_tool_notification_write':
      return const AssistantToolStatus(
        icon: Icons.notifications_active,
        label: '通知已写入',
      );
    case 'agent_tool_capture_save':
      return const AssistantToolStatus(icon: Icons.edit_note, label: '记录已收纳');
    case 'agent_tool_navigation_suggest':
      return const AssistantToolStatus(
        icon: Icons.open_in_new,
        label: '已准备跳转入口',
      );
    case 'agent_tool_memory_upsert':
    case 'agent_memory':
      return const AssistantToolStatus(
        icon: Icons.auto_awesome,
        label: '长期记忆已更新',
      );
    case 'agent_tool_failed':
      return const AssistantToolStatus(
        icon: Icons.error_outline,
        label: '有动作未完成',
      );
    case 'agent_done':
      return const AssistantToolStatus(icon: Icons.task_alt, label: '中枢任务已完成');
    case 'alarm':
    case 'sleep_alarm':
    case 'bedtime_alarm':
      return const AssistantToolStatus(icon: Icons.alarm, label: '闹钟已设定 23:00');
    case 'dorm_quiet':
    case 'dorm':
    case 'dorm_status':
    case 'dorm_rules':
      return const AssistantToolStatus(
        icon: Icons.volume_off,
        label: '寝室静音模式已同步',
      );
    case 'bedtime_reminder':
    case 'notification':
    case 'notifications':
      return const AssistantToolStatus(
        icon: Icons.notifications_active,
        label: '晚安提醒已开启',
      );
    case 'sleep_mode':
      return const AssistantToolStatus(icon: Icons.bedtime, label: '睡眠模式已预热');
    case 'assistant_context':
      return const AssistantToolStatus(
        icon: Icons.auto_awesome,
        label: '对话记忆已同步',
      );
    case 'home_pre_sleep':
      return const AssistantToolStatus(icon: Icons.hotel, label: '睡前卡片已刷新');
    case 'profile_report':
      return const AssistantToolStatus(icon: Icons.insights, label: '画像摘要已更新');
    default:
      if (normalized.startsWith('agent_tool_')) {
        return const AssistantToolStatus(
          icon: Icons.extension,
          label: '小眠已调用工具',
        );
      }
      return null;
  }
}

AssistantToolStatus? _navigationToolStatusForSurfaceId(String surfaceId) {
  const String prefix = 'agent_navigation:';
  if (!surfaceId.startsWith(prefix)) {
    return null;
  }
  final String payload = surfaceId.substring(prefix.length);
  final int separator = payload.indexOf(':');
  if (separator <= 0) {
    return null;
  }
  final String route = Uri.decodeComponent(payload.substring(0, separator));
  if (route.trim().isEmpty) {
    return null;
  }
  final String actionLabel = Uri.decodeComponent(
    payload.substring(separator + 1),
  ).trim();
  final String label = actionLabel.isEmpty ? '继续处理' : actionLabel;
  return AssistantToolStatus(
    icon: Icons.open_in_new,
    label: '可跳转：$label',
    navigationRoute: route,
    navigationLabel: label,
  );
}

AssistantToolStatus? _undoToolStatusForSurfaceId(String surfaceId) {
  final List<String> parts = surfaceId.split(':');
  if (parts.length != 2 || parts[1].trim().isEmpty) {
    return null;
  }
  final String callId = parts[1].trim();
  switch (parts[0].trim().toLowerCase()) {
    case 'agent_undo_available':
      return AssistantToolStatus(
        icon: Icons.undo,
        label: '可撤销一项动作',
        undoCallId: callId,
        undoStatus: 'available',
      );
    case 'agent_undo_running':
      return AssistantToolStatus(
        icon: Icons.pending_actions_outlined,
        label: '正在撤销动作',
        undoCallId: callId,
        undoStatus: 'running',
      );
    case 'agent_undo_applied':
      return AssistantToolStatus(
        icon: Icons.task_alt,
        label: '已撤销一项动作',
        undoCallId: callId,
        undoStatus: 'applied',
      );
    case 'agent_undo_failed':
      return AssistantToolStatus(
        icon: Icons.error_outline,
        label: '撤销未完成',
        undoCallId: callId,
        undoStatus: 'failed',
      );
    default:
      return null;
  }
}

class _AssistantActionIconButton extends StatelessWidget {
  const _AssistantActionIconButton({
    super.key,
    required this.size,
    required this.color,
    required this.onTap,
    this.hapticRole = AppHapticRole.selection,
    this.icon,
    this.child,
    this.tooltip,
  });

  final IconData? icon;
  final Widget? child;
  final double size;
  final Color color;
  final VoidCallback? onTap;
  final String? tooltip;
  final AppHapticRole? hapticRole;

  @override
  Widget build(BuildContext context) {
    final double hitSize = math.max(size * 1.56, 36);
    final Widget button = SizedBox(
      width: hitSize,
      height: hitSize,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tight(Size.square(hitSize)),
        splashRadius: hitSize / 2,
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: color,
          disabledForegroundColor: _alpha(color, 0.34),
          overlayColor: _alpha(color, 0.18),
        ),
        onPressed: hapticRole == null
            ? onTap
            : AppHaptics.handler(onTap, role: hapticRole!),
        icon: child ?? Icon(icon, size: size, color: color),
      ),
    );
    if (tooltip == null || tooltip!.trim().isEmpty) {
      return button;
    }
    return Tooltip(message: tooltip!, child: button);
  }
}

Color _alpha(Color color, double opacity) {
  return color.withAlpha((opacity * 255).round().clamp(0, 255));
}
