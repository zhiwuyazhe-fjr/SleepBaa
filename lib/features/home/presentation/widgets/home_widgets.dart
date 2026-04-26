import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/utils/formatters.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/icon_badge.dart';

class SleepRiskCard extends StatelessWidget {
  const SleepRiskCard({
    super.key,
    required this.riskLabel,
    required this.primaryValue,
  });

  final String riskLabel;
  final String primaryValue;

  @override
  Widget build(BuildContext context) {
    final palette = context.nightMoodPalette;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: EdgeInsets.zero,
      borderRadius: AppRadius.surfacePrimary,
      boxShadow: AppColors.floatingShadow,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: AppRadius.surfacePrimary,
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: <Color>[
              palette.welcomeAccentColor,
              palette.primarySoft,
              palette.primary,
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
              style: textTheme.titleLarge?.copyWith(
                color: AppColors.onDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            Row(
              children: <Widget>[
                _CardMetaPill(
                  label: riskLabel,
                  backgroundColor: palette.primaryDeep,
                  foregroundColor: AppColors.onDark,
                ),
                const SizedBox(width: AppSpacing.xs),
                _CardMetaPill(
                  label: primaryValue,
                  backgroundColor: palette.primaryDeep,
                  foregroundColor: AppColors.onDark,
                ),
              ],
            ),
          ],
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
    final palette = context.nightMoodPalette;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: EdgeInsets.zero,
      borderRadius: AppRadius.surfacePrimary,
      border: Border.all(color: AppColors.cardBorderSubtle),
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
              style: textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: AppRadius.surfaceSecondary,
                  ),
                  child: Text(
                    isAudioReady ? '音频已同步' : '轻触进入',
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.welcomeAccentColor,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.dark_mode_rounded,
                    color: palette.welcomeTextOnAccent,
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
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class HomeActionCard extends StatelessWidget {
  const HomeActionCard({
    super.key,
    required this.recommendation,
    required this.onTap,
  });

  final NightRecommendation recommendation;
  final VoidCallback onTap;

  bool get _isAudio => recommendation.type == RecommendationType.audio;

  @override
  Widget build(BuildContext context) {
    final palette = context.nightMoodPalette;
    final bool selected =
        recommendation.executionState != RecommendationExecutionState.idle;
    final bool highlight = selected;
    final Color cardColor = highlight
        ? palette.welcomeAccentColor
        : AppColors.surface;
    final Color foreground = highlight
        ? palette.welcomeTextOnAccent
        : AppColors.textPrimary;
    final Color borderColor = highlight
        ? palette.primary.withAlpha(84)
        : AppColors.divider;
    final Color chipBackground = highlight
        ? Colors.white.withAlpha(170)
        : AppColors.background;
    final Color chipForeground = highlight
        ? palette.welcomeTextOnAccent
        : AppColors.textSecondary;

    return AppCard(
      padding: EdgeInsets.zero,
      borderRadius: AppRadius.stripCard,
      color: cardColor,
      border: _isAudio ? null : Border.all(color: borderColor),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: highlight
                    ? Colors.white.withAlpha(208)
                    : AppColors.background,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                recommendation.icon,
                size: 20,
                color: highlight
                    ? palette.welcomeTextOnAccent
                    : palette.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    recommendation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: recommendation.tags
                        .take(2)
                        .map(
                          (String tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: chipBackground,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              tag,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: chipForeground,
                                    fontWeight: FontWeight.w400,
                                  ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: highlight
                      ? Colors.white.withAlpha(220)
                      : AppColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: highlight
                        ? palette.primary
                        : AppColors.surfaceBorder,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _trailingIcon(selected),
                  size: 22,
                  color: highlight
                      ? palette.welcomeTextOnAccent
                      : palette.primary,
                ),
              ),
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
}

class SupportToolCard extends StatelessWidget {
  const SupportToolCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
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
  });

  final AudioTrack? track;
  final PlaybackState playbackState;
  final Duration position;
  final VoidCallback onToggle;

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
                  Text(
                    '${effectiveTrack.subtitle} · ${Formatters.formatDuration(position)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onDark.withAlpha(140),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onToggle,
              icon: Icon(
                playbackState == PlaybackState.playing
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_fill_rounded,
                color: palette.primarySoft,
                size: 34,
              ),
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
