import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/utils/formatters.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/icon_badge.dart';

class SleepRiskCard extends StatelessWidget {
  const SleepRiskCard({
    super.key,
    required this.riskLabel,
    required this.primaryValue,
    required this.secondaryValue,
  });

  final String riskLabel;
  final String primaryValue;
  final String secondaryValue;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: EdgeInsets.zero,
      boxShadow: AppColors.floatingShadow,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF204F96),
              Color(0xFF163E7E),
              Color(0xFF0F2D61),
            ],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Stack(
          children: <Widget>[
            Positioned(
              right: -4,
              top: -6,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(34),
                  gradient: RadialGradient(
                    center: const Alignment(0.25, -0.1),
                    radius: 0.9,
                    colors: <Color>[
                      Colors.white.withAlpha(28),
                      Colors.white.withAlpha(8),
                      Colors.white.withAlpha(0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 34,
              top: 26,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primarySoft.withAlpha(16),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  '睡眠风险',
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.onDark.withAlpha(196),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  riskLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.headlineMedium?.copyWith(
                    color: AppColors.onDark,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                Row(
                  children: <Widget>[
                    _CardMetaPill(
                      label: primaryValue,
                      backgroundColor: Colors.white.withAlpha(18),
                      foregroundColor: AppColors.onDark,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _CardMetaPill(
                      label: secondaryValue,
                      backgroundColor: AppColors.primarySoft.withAlpha(16),
                      foregroundColor: AppColors.onDark.withAlpha(210),
                    ),
                  ],
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
    final TextTheme textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: EdgeInsets.zero,
      border: Border.all(color: AppColors.divider),
      boxShadow: AppColors.cardShadow,
      onTap: onTap,
      child: Container(
        height: 120,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Stack(
          children: <Widget>[
            Positioned(
              right: -18,
              bottom: -18,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primarySoft.withAlpha(12),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: <Color>[
                            Color(0xFFC9F7FF),
                            Color(0xFF7FD8F2),
                            Color(0xFF1787A6),
                          ],
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.primarySoft.withAlpha(150),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.nightlight_round,
                        color: AppColors.onDark,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '开启睡眠模式',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: <Widget>[
                    _CardMetaPill(
                      label: isAudioReady ? '音频已同步' : '准备开始',
                      backgroundColor: AppColors.primarySoft.withAlpha(20),
                      foregroundColor: AppColors.primaryDeep,
                    ),
                    const Spacer(),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.primarySoft.withAlpha(120),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: AppColors.primaryDeep,
                        size: 22,
                      ),
                    ),
                  ],
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
          fontWeight: FontWeight.w800,
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
    final bool selected =
        recommendation.executionState != RecommendationExecutionState.idle;
    final Color foreground = _isAudio
        ? AppColors.primaryDeep
        : AppColors.textPrimary;

    return AppCard(
      padding: EdgeInsets.zero,
      color: _isAudio ? AppColors.primaryHighlight : AppColors.surface,
      border: _isAudio ? null : Border.all(color: AppColors.divider),
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _isAudio
                    ? Colors.white.withAlpha(188)
                    : AppColors.primary.withAlpha(12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                recommendation.icon,
                size: 18,
                color: _isAudio ? AppColors.primaryDeep : AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    recommendation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    recommendation.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _isAudio
                          ? AppColors.primaryDeep.withAlpha(180)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(_isAudio ? 255 : 0),
                  shape: BoxShape.circle,
                  border: !_isAudio
                      ? Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.surfaceBorder,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: Icon(
                  _trailingIcon(selected),
                  size: 22,
                  color: selected ? AppColors.primary : foreground,
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
      return recommendation.executionState == RecommendationExecutionState.playing
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
    return AppCard(
      color: AppColors.darkGlass,
      border: Border.all(color: AppColors.darkBorder),
      boxShadow: const <BoxShadow>[],
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: AppColors.primarySoft, size: 24),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.onDark),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.onDark.withAlpha(140),
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
      color: AppColors.primarySoft.withAlpha(10),
      border: Border.all(color: AppColors.primarySoft.withAlpha(28)),
      boxShadow: const <BoxShadow>[],
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Row(
          children: <Widget>[
            const IconBadge(
              icon: Icons.waves_rounded,
              backgroundColor: Color(0x3300697A),
              iconColor: AppColors.primarySoft,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    effectiveTrack.title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: AppColors.onDark),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${effectiveTrack.subtitle} · ${Formatters.formatDuration(position)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onDark.withAlpha(140),
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
                color: AppColors.primarySoft,
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
  const SleepModeMoon({super.key});

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
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double progress = Curves.easeInOut.transform(_controller.value);
        final double offsetY = (progress - 0.5) * 16;
        final double haloScale = 0.96 + (progress * 0.18);

        return Transform.translate(
          offset: Offset(0, offsetY),
          child: SizedBox(
            width: 264,
            height: 264,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Transform.scale(
                  scale: haloScale,
                  child: Container(
                    width: 212,
                    height: 212,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withAlpha(34),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.primarySoft.withAlpha(120),
                          blurRadius: 70,
                          spreadRadius: 26,
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: <Color>[
                        AppColors.primarySoft,
                        AppColors.calmBlue,
                        AppColors.primary,
                      ],
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.primarySoft.withAlpha(80),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Transform.rotate(
                    angle: math.pi / 10,
                    child: const Icon(
                      Icons.dark_mode_rounded,
                      color: AppColors.onDark,
                      size: 62,
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
