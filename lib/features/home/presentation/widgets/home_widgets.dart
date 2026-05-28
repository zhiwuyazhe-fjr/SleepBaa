import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/app_typography.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/utils/formatters.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/icon_badge.dart';

class SleepRiskCard extends StatefulWidget {
  const SleepRiskCard({
    super.key,
    required this.riskLabel,
    required this.primaryValue,
    this.onTap,
  });

  final String riskLabel;
  final String primaryValue;
  final VoidCallback? onTap;

  @override
  State<SleepRiskCard> createState() => _SleepRiskCardState();
}

class _SleepRiskCardState extends State<SleepRiskCard> {
  bool _pressed = false;
  bool _minimumPressElapsed = false;
  Timer? _minimumPressTimer;
  Timer? _releaseFeedbackTimer;

  static const Duration _releaseFeedbackDuration = Duration(milliseconds: 140);

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() {
      _pressed = value;
    });
  }

  void _handlePointerDown(PointerDownEvent event) {
    _minimumPressTimer?.cancel();
    _releaseFeedbackTimer?.cancel();
    _releaseFeedbackTimer = null;
    _minimumPressElapsed = false;
    _minimumPressTimer = Timer(_releaseFeedbackDuration, () {
      _minimumPressElapsed = true;
    });
    _setPressed(true);
  }

  void _handlePointerUp(PointerUpEvent event) {
    _holdFeedbackAfterRelease();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _holdFeedbackAfterRelease();
  }

  void _holdFeedbackAfterRelease() {
    _minimumPressTimer?.cancel();
    _releaseFeedbackTimer?.cancel();
    if (_minimumPressElapsed) {
      _setPressed(false);
      return;
    }
    _releaseFeedbackTimer = Timer(_releaseFeedbackDuration, () {
      if (mounted) {
        _setPressed(false);
      }
    });
  }

  @override
  void dispose() {
    _minimumPressTimer?.cancel();
    _releaseFeedbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isActive = _pressed;
    final double scale = isActive ? 0.93 : 1;
    return Semantics(
      button: true,
      label: '睡眠风险',
      onTap: widget.onTap,
      child: Listener(
        key: const ValueKey<String>('home-sleep-risk-feedback-surface'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: _handlePointerDown,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: scale,
            duration: Duration(milliseconds: isActive ? 90 : 280),
            curve: isActive ? Curves.easeOutBack : Curves.elasticOut,
            child: AppCard(
              padding: EdgeInsets.zero,
              borderRadius: AppRadius.surfacePrimary,
              boxShadow: isActive
                  ? AppColors.floatingShadow
                  : AppColors.cardShadow,
              child: AnimatedOpacity(
                opacity: isActive ? 0.9 : 1,
                duration: Duration(milliseconds: isActive ? 70 : 180),
                curve: Curves.easeOutCubic,
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.surfacePrimary,
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: <Color>[
                        appColors.heroStart,
                        appColors.heroMid,
                        appColors.heroEnd,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        '睡眠风险',
                        style: AppTypography.panelTitle(
                          textTheme,
                        ).copyWith(color: AppColors.onDark),
                      ),
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: _CardMetaPill(
                              label: widget.riskLabel,
                              backgroundColor: appColors.accentDeep,
                              foregroundColor: AppColors.onDark,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: _CardMetaPill(
                              label: widget.primaryValue,
                              backgroundColor: appColors.accentDeep,
                              foregroundColor: AppColors.onDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StartSleepModeCard extends StatelessWidget {
  const StartSleepModeCard({
    super.key,
    required this.onTap,
    required this.isAudioReady,
  });

  final VoidCallback onTap;
  final bool isAudioReady;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: EdgeInsets.zero,
      borderRadius: AppRadius.surfacePrimary,
      color: appColors.surface,
      border: Border.all(color: appColors.borderSubtle),
      boxShadow: AppColors.cardShadow,
      onTap: onTap,
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              '开启睡眠模式',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.panelTitle(
                textTheme,
              ).copyWith(color: appColors.textPrimary),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                if (isAudioReady)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: appColors.surfaceMuted,
                        borderRadius: AppRadius.surfaceSecondary,
                      ),
                      child: Text(
                        '音频已同步',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.chip(
                          textTheme,
                        ).copyWith(color: appColors.textSecondary),
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (isAudioReady) const SizedBox(width: AppSpacing.sm),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: appColors.accent,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.dark_mode_rounded,
                    color: appColors.accentDeep,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardMetaPill extends StatelessWidget {
  const _CardMetaPill({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.chip(
          Theme.of(context).textTheme,
        ).copyWith(color: foregroundColor),
      ),
    );
  }
}

class HomeActionCard extends StatelessWidget {
  const HomeActionCard({
    super.key,
    required this.recommendation,
    required this.onTap,
    this.onPlayToggle,
    this.onPreviousAudio,
    this.onNextAudio,
    this.displayTitle,
    this.showAudioTransport = false,
  });

  final NightRecommendation recommendation;
  final VoidCallback onTap;
  final VoidCallback? onPlayToggle;
  final VoidCallback? onPreviousAudio;
  final VoidCallback? onNextAudio;
  final String? displayTitle;
  final bool showAudioTransport;

  bool get _isAudio => recommendation.type == RecommendationType.audio;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool selected =
        recommendation.executionState != RecommendationExecutionState.idle;
    final bool highlight = selected;
    final Color cardColor = highlight ? appColors.accent : appColors.surface;
    final Color foreground = highlight
        ? appColors.textOnAccent
        : appColors.textPrimary;
    final Color borderColor = highlight
        ? appColors.accent.withAlpha(84)
        : appColors.borderSubtle;
    final Color chipBackground = highlight
        ? Colors.white.withAlpha(170)
        : appColors.pageBackground;
    final Color chipForeground = highlight
        ? appColors.textOnAccent
        : appColors.textSecondary;
    final String title = displayTitle?.trim().isNotEmpty ?? false
        ? displayTitle!.trim()
        : recommendation.title;
    final bool showTransportControls =
        _isAudio &&
        showAudioTransport &&
        recommendation.executionState == RecommendationExecutionState.playing;

    return AppCard(
      padding: EdgeInsets.zero,
      borderRadius: AppRadius.stripCard,
      color: cardColor,
      border: Border.all(color: borderColor),
      onTap: _isAudio ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _isAudio ? onTap : null,
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: highlight
                            ? Colors.white.withAlpha(208)
                            : appColors.pageBackground,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        recommendation.icon,
                        size: 20,
                        color: highlight
                            ? appColors.textOnAccent
                            : appColors.accentDeep,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Builder(
                            builder: (BuildContext context) {
                              final TextStyle titleStyle =
                                  AppTypography.cardTitle(
                                    textTheme,
                                  ).copyWith(color: foreground);
                              if (showTransportControls) {
                                return _AutoScrollingText(
                                  text: title,
                                  style: titleStyle,
                                );
                              }
                              return Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: titleStyle,
                              );
                            },
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _buildTags(
                            context,
                            chipBackground,
                            chipForeground,
                            showTransportControls,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (showTransportControls)
                  _AudioTransportIcon(
                    icon: Icons.skip_previous_rounded,
                    onTap: onPreviousAudio,
                    color: highlight
                        ? appColors.textOnAccent
                        : appColors.accentDeep,
                  ),
                InkWell(
                  onTap: onPlayToggle ?? onTap,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: highlight
                          ? Colors.white.withAlpha(220)
                          : appColors.pageBackground,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: highlight
                            ? appColors.accentDeep
                            : appColors.borderSubtle,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      _trailingIcon(selected),
                      size: 22,
                      color: highlight
                          ? appColors.textOnAccent
                          : appColors.accentDeep,
                    ),
                  ),
                ),
                if (showTransportControls)
                  _AudioTransportIcon(
                    icon: Icons.skip_next_rounded,
                    onTap: onNextAudio,
                    color: highlight
                        ? appColors.textOnAccent
                        : appColors.accentDeep,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _trailingIcon(bool selected) {
    if (_isAudio) {
      return recommendation.executionState ==
              RecommendationExecutionState.playing
          ? Icons.pause_rounded
          : Icons.play_arrow_rounded;
    }
    return selected ? Icons.check_rounded : Icons.east_rounded;
  }

  Widget _buildTags(
    BuildContext context,
    Color backgroundColor,
    Color foregroundColor,
    bool showTransportControls,
  ) {
    final List<String> tags = recommendation.tags
        .take(2)
        .toList(growable: false);
    if (showTransportControls) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int index = 0; index < tags.length; index++) ...<Widget>[
              if (index > 0) const SizedBox(width: AppSpacing.xs),
              _RecommendationTagChip(
                tag: tags[index],
                backgroundColor: backgroundColor,
                foregroundColor: foregroundColor,
              ),
            ],
          ],
        ),
      );
    }

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: tags
          .map(
            (String tag) => _RecommendationTagChip(
              tag: tag,
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _RecommendationTagChip extends StatelessWidget {
  const _RecommendationTagChip({
    required this.tag,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String tag;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tag,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.chip(
          Theme.of(context).textTheme,
        ).copyWith(color: foregroundColor),
      ),
    );
  }
}

class _AudioTransportIcon extends StatelessWidget {
  const _AudioTransportIcon({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: Icon(icon, size: 22, color: color),
    );
  }
}

class _AutoScrollingText extends StatefulWidget {
  const _AutoScrollingText({required this.text, required this.style});

  final String text;
  final TextStyle? style;

  @override
  State<_AutoScrollingText> createState() => _AutoScrollingTextState();
}

class _AutoScrollingTextState extends State<_AutoScrollingText> {
  final ScrollController _controller = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant _AutoScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      if (_controller.hasClients) {
        _controller.jumpTo(0);
      }
      _schedule();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) {
        return;
      }
      final double max = _controller.position.maxScrollExtent;
      if (max <= 0) {
        return;
      }
      _timer = Timer(const Duration(milliseconds: 900), () async {
        if (!mounted || !_controller.hasClients) {
          return;
        }
        await _controller.animateTo(
          max,
          duration: const Duration(milliseconds: 2400),
          curve: Curves.easeInOutCubic,
        );
        if (!mounted || !_controller.hasClients) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (!mounted || !_controller.hasClients) {
          return;
        }
        await _controller.animateTo(
          0,
          duration: const Duration(milliseconds: 1600),
          curve: Curves.easeInOutCubic,
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Text(
          widget.text,
          maxLines: 1,
          softWrap: false,
          style: widget.style,
        ),
      ),
    );
  }
}

class SupportToolCard extends StatelessWidget {
  const SupportToolCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle = '',
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.nightMoodPalette;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      color: AppColors.darkGlass,
      borderRadius: AppRadius.compactCard,
      border: Border.all(color: AppColors.darkBorder),
      boxShadow: const <BoxShadow>[],
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: palette.primarySoft, size: 20),
          const SizedBox(height: AppSpacing.xs),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.onDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.onDark.withAlpha(140),
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SessionAudioCard extends StatelessWidget {
  const SessionAudioCard({
    super.key,
    required this.track,
    required this.playbackState,
    required this.position,
    required this.onToggle,
    required this.onPrevious,
    required this.onNext,
  });

  final AudioTrack? track;
  final PlaybackState playbackState;
  final Duration position;
  final VoidCallback onToggle;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final palette = context.nightMoodPalette;
    final AudioTrack effectiveTrack =
        track ??
        const AudioTrack(
          id: 'deep-ocean',
          title: '深海海浪',
          subtitle: '低刺激白噪音 · 45 分钟',
          duration: Duration(minutes: 45),
        );
    final bool hasKnownDuration = effectiveTrack.duration > Duration.zero;
    final String progressText = hasKnownDuration
        ? '${Formatters.formatDuration(position)} / ${Formatters.formatDuration(effectiveTrack.duration)}'
        : Formatters.formatDuration(position);
    final String trimmedSubtitle = effectiveTrack.subtitle.trim();
    final bool hideCloudSubtitle =
        effectiveTrack.sourceUrl != null &&
        trimmedSubtitle.toLowerCase().contains('cloudbase');
    final String? detailText = hideCloudSubtitle
        ? (hasKnownDuration ? progressText : null)
        : trimmedSubtitle.isEmpty
        ? (hasKnownDuration ? progressText : null)
        : hasKnownDuration
        ? '$trimmedSubtitle · $progressText'
        : trimmedSubtitle;

    return AppCard(
      padding: EdgeInsets.zero,
      color: palette.primarySoft.withAlpha(10),
      borderRadius: AppRadius.compactCard,
      border: Border.all(color: palette.primarySoft.withAlpha(28)),
      boxShadow: const <BoxShadow>[],
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: <Widget>[
            IconBadge(
              icon: Icons.waves_rounded,
              backgroundColor: palette.primary.withAlpha(52),
              iconColor: palette.primarySoft,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    effectiveTrack.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.onDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (detailText != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      detailText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onDark.withAlpha(140),
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  tooltip: '上一首',
                  onPressed: onPrevious,
                  icon: Icon(
                    Icons.skip_previous_rounded,
                    color: palette.primarySoft,
                  ),
                ),
                IconButton(
                  tooltip: playbackState == PlaybackState.playing ? '暂停' : '播放',
                  onPressed: onToggle,
                  icon: Icon(
                    playbackState == PlaybackState.playing
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: palette.primarySoft,
                    size: 34,
                  ),
                ),
                IconButton(
                  tooltip: '下一首',
                  onPressed: onNext,
                  icon: Icon(
                    Icons.skip_next_rounded,
                    color: palette.primarySoft,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SleepModeMoon extends StatefulWidget {
  const SleepModeMoon({super.key, this.size = 264});

  final double size;

  @override
  State<SleepModeMoon> createState() => _SleepModeMoonState();
}

class _SleepModeMoonState extends State<SleepModeMoon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.nightMoodPalette;
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double progress = Curves.easeInOut.transform(_controller.value);
        final double offsetY = (progress - 0.5) * 16;
        final double haloScale = 0.96 + (progress * 0.18);

        return Transform.translate(
          offset: Offset(0, offsetY),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Transform.scale(
                  scale: haloScale,
                  child: Container(
                    width: widget.size * (212 / 264),
                    height: widget.size * (212 / 264),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.primary.withAlpha(34),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: palette.primarySoft.withAlpha(120),
                          blurRadius: 70,
                          spreadRadius: 26,
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: widget.size * (128 / 264),
                  height: widget.size * (128 / 264),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        palette.moonGradientStart,
                        palette.moonGradientMid,
                        palette.moonGradientEnd,
                      ],
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: palette.primarySoft.withAlpha(80),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Transform.rotate(
                    angle: math.pi / 10,
                    child: Icon(
                      Icons.dark_mode_rounded,
                      color: AppColors.onDark,
                      size: widget.size * (62 / 264),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
