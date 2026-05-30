import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/app_typography.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_menu_group_card.dart';
import 'package:sleep_dorm_app/core/widgets/user_avatar.dart';
import 'package:sleep_dorm_app/features/profile/presentation/widgets/profile_badge_support.dart';

class ProfileHeaderSection extends StatelessWidget {
  const ProfileHeaderSection({
    super.key,
    required this.profile,
    required this.onProfileTap,
  });

  final UserProfile profile;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AppSemanticColors appColors = context.appColors;

    return Material(
      key: const ValueKey<String>('profile-header-section'),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.surfacePrimary,
        onTap: onProfileTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: <Widget>[
              UserAvatar(profile: profile, size: 68),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.sectionTitle(
                        textTheme,
                      ).copyWith(color: appColors.textPrimary),
                    ),
                    if (profile.tagline.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        profile.tagline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMuted(
                          textTheme,
                        ).copyWith(color: appColors.textSecondary),
                      ),
                    ],
                    if (profile.role.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      _ProfileRoleChip(role: profile.role),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                color: appColors.textSecondary.withAlpha(150),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileRoleChip extends StatelessWidget {
  const _ProfileRoleChip({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AppSemanticColors appColors = context.appColors;

    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: appColors.accentSoft,
        borderRadius: AppRadius.pill,
      ),
      child: Text(
        role,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.chip(
          textTheme,
        ).copyWith(color: appColors.accentDeep, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class ProfileQuoteCard extends StatelessWidget {
  const ProfileQuoteCard({super.key, required this.quote});

  final String quote;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final NightMoodPalette palette = context.nightMoodPalette;
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      borderRadius: AppRadius.surfacePrimary,
      color: palette.primary,
      boxShadow: const <BoxShadow>[],
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.onDark.withAlpha(48),
              borderRadius: AppRadius.iconContainer,
            ),
            child: Icon(
              Icons.format_quote_rounded,
              size: 20,
              color: AppColors.onDark,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              quote,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(textTheme).copyWith(
                color: AppColors.onDark,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileDataCarousel extends StatefulWidget {
  const ProfileDataCarousel({
    super.key,
    required this.durationTrend,
    required this.qualityTrend,
    required this.heatmapValues,
    required this.onHeatmapTap,
  });

  final SleepTrendSeries durationTrend;
  final SleepTrendSeries qualityTrend;
  final List<int> heatmapValues;
  final VoidCallback onHeatmapTap;

  @override
  State<ProfileDataCarousel> createState() => _ProfileDataCarouselState();
}

class _ProfileDataCarouselState extends State<ProfileDataCarousel> {
  static const double _carouselViewportFraction = 0.92;

  late final PageController _controller;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: _carouselViewportFraction);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return Column(
      children: <Widget>[
        AspectRatio(
          key: const ValueKey<String>('profile-data-carousel'),
          aspectRatio: 1.82,
          child: PageView(
            clipBehavior: Clip.none,
            controller: _controller,
            padEnds: true,
            onPageChanged: (int index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: <Widget>[
              for (final Widget card in <Widget>[
                _SleepQualityCard(series: widget.qualityTrend),
                _SleepDurationCard(series: widget.durationTrend),
                _CheckInHeatmapCard(
                  heatmapValues: widget.heatmapValues,
                  onTap: widget.onHeatmapTap,
                ),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: card,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          key: const ValueKey<String>('profile-carousel-indicators'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(3, (int index) {
            final bool active = index == _currentPage;
            return AnimatedContainer(
              key: ValueKey<String>('profile-carousel-dot-$index'),
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? context.nightMoodPalette.primary
                    : appColors.borderSubtle,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class ProfileInsightBlock extends StatelessWidget {
  const ProfileInsightBlock({
    super.key,
    required this.report,
    required this.badges,
    required this.onReportTap,
    required this.onDreamTap,
    required this.onThoughtTap,
    required this.onBadgeOverviewTap,
    required this.onBadgeTap,
  });

  final SleepReport report;
  final List<ProfileBadgeStatusData> badges;
  final VoidCallback onReportTap;
  final VoidCallback onDreamTap;
  final VoidCallback onThoughtTap;
  final VoidCallback onBadgeOverviewTap;
  final ValueChanged<ProfileBadgeStatusData> onBadgeTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double cardHeight = math.max(
              156,
              constraints.maxWidth * 0.44,
            );
            return SizedBox(
              height: cardHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: _ReportInsightCard(
                      key: const ValueKey<String>('profile-report-card'),
                      report: report,
                      onTap: onReportTap,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      key: const ValueKey<String>(
                        'profile-insight-side-column',
                      ),
                      children: <Widget>[
                        Expanded(
                          child: _MiniInsightCard(
                            title: '梦记',
                            subtitle: '记录片段',
                            icon: Icons.menu_book_outlined,
                            onTap: onDreamTap,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Expanded(
                          child: _MiniInsightCard(
                            title: '事记仓库',
                            subtitle: '灵感待办',
                            icon: Icons.inventory_2_outlined,
                            onTap: onThoughtTap,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _BadgePreviewCard(
          badges: badges,
          onOverviewTap: onBadgeOverviewTap,
          onBadgeTap: onBadgeTap,
        ),
      ],
    );
  }
}

class ProfileSettingsCard extends StatelessWidget {
  const ProfileSettingsCard({
    super.key,
    required this.onSettingsTap,
    required this.onFaqTap,
  });

  final VoidCallback onSettingsTap;
  final VoidCallback onFaqTap;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;

    return AppMenuGroupCard(
      cardKey: const ValueKey<String>('profile-settings-card'),
      items: <AppMenuGroupCardItem>[
        AppMenuGroupCardItem(
          icon: Icons.settings_outlined,
          iconColor: appColors.accentDeep,
          title: '设置',
          titleStyle: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          onTap: onSettingsTap,
        ),
        AppMenuGroupCardItem(
          icon: Icons.help_outline_rounded,
          iconColor: appColors.accentDeep,
          title: '常见问题',
          titleStyle: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          onTap: onFaqTap,
        ),
      ],
    );
  }
}

class _SleepQualityCard extends StatelessWidget {
  const _SleepQualityCard({required this.series});

  final SleepTrendSeries series;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AppSemanticColors appColors = context.appColors;
    final List<_ChartPoint> points = series.points
        .map(
          (SleepTrendPoint point) => _ChartPoint(
            label: point.weekdayLabel,
            value: point.value?.clamp(0, 100),
          ),
        )
        .toList(growable: false);
    final bool hasAnyValue = points.any(
      (_ChartPoint point) => point.value != null,
    );

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      borderRadius: AppRadius.surfacePrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '睡眠质量(分)',
            style: AppTypography.meta(
              textTheme,
            ).copyWith(color: appColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                const double axisWidth = 28;
                const double xAxisHeight = 24;
                final double plotWidth = constraints.maxWidth - axisWidth;
                final double plotHeight = constraints.maxHeight - xAxisHeight;
                final List<Offset?> offsets = _chartOffsets(
                  points,
                  plotWidth,
                  plotHeight,
                );
                final int? bestIndex = _bestPointIndex(points);
                final int? latestIndex = _latestPointIndex(points);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      width: axisWidth,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const <Widget>[
                          _AxisLabel('100'),
                          _AxisLabel('50'),
                          _AxisLabel('0'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: <Widget>[
                          Expanded(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: <Widget>[
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _SleepQualityChartPainter(
                                      points: offsets,
                                      palette: context.nightMoodPalette,
                                      gridColor: appColors.borderSubtle,
                                    ),
                                  ),
                                ),
                                if (!hasAnyValue)
                                  Positioned.fill(child: _TrendEmptyState()),
                                if (bestIndex != null &&
                                    latestIndex != null &&
                                    offsets[bestIndex] != null &&
                                    offsets[latestIndex] != null) ...<Widget>[
                                  _ChartBadgeMarker(
                                    offset: offsets[bestIndex]!,
                                    label: '平静',
                                    color: context.nightMoodPalette.primary,
                                  ),
                                  _ChartBadgeMarker(
                                    offset: offsets[latestIndex]!,
                                    label: '愉悦',
                                    color: AppColors.calmBlue,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          SizedBox(
                            height: xAxisHeight,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: series.points
                                  .map(
                                    (SleepTrendPoint point) => Text(
                                      point.weekdayLabel,
                                      style: AppTypography.chip(textTheme)
                                          .copyWith(
                                            color: appColors.textSecondary
                                                .withAlpha(150),
                                          ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SleepDurationCard extends StatelessWidget {
  const _SleepDurationCard({required this.series});

  final SleepTrendSeries series;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AppSemanticColors appColors = context.appColors;
    final List<double> hours = series.points
        .map((SleepTrendPoint point) => point.value ?? 0)
        .where((double value) => value > 0)
        .toList(growable: false);
    final double maxHours = hours.isEmpty
        ? 8
        : math.max(8, hours.reduce(math.max));
    final bool hasAnyValue = series.points.any(
      (SleepTrendPoint point) => point.value != null,
    );

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      borderRadius: AppRadius.surfacePrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '睡眠时长(小时)',
            style: AppTypography.meta(
              textTheme,
            ).copyWith(color: appColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: Stack(
              children: <Widget>[
                if (!hasAnyValue)
                  const Positioned.fill(child: _TrendEmptyState()),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    for (
                      int index = 0;
                      index < series.points.length;
                      index++
                    ) ...<Widget>[
                      Expanded(
                        child: _DurationBar(
                          hours: series.points[index].value,
                          maxHours: maxHours,
                          label: series.points[index].weekdayLabel,
                        ),
                      ),
                      if (index != series.points.length - 1)
                        const SizedBox(width: AppSpacing.xs),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckInHeatmapCard extends StatelessWidget {
  const _CheckInHeatmapCard({required this.heatmapValues, required this.onTap});

  final List<int> heatmapValues;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AppSemanticColors appColors = context.appColors;
    final List<int> cells = heatmapValues;
    final int rowCount = math.max(1, (cells.length / 7).ceil());

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: AppRadius.surfacePrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  '本月打卡热力',
                  style: AppTypography.meta(
                    textTheme,
                  ).copyWith(color: appColors.textSecondary),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: AppSpacing.md,
                color: appColors.textSecondary.withAlpha(150),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const <Widget>[
              _WeekdayChip('一'),
              _WeekdayChip('二'),
              _WeekdayChip('三'),
              _WeekdayChip('四'),
              _WeekdayChip('五'),
              _WeekdayChip('六'),
              _WeekdayChip('日'),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                const double gap = AppSpacing.xs / 2;
                final double cellWidth = (constraints.maxWidth - gap * 6) / 7;
                final double cellHeight =
                    (constraints.maxHeight - gap * math.max(0, rowCount - 1)) /
                    rowCount;

                return SizedBox.expand(
                  key: const ValueKey<String>('profile-heatmap-grid'),
                  child: Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: <Widget>[
                      for (int index = 0; index < cells.length; index++)
                        SizedBox(
                          key: ValueKey<String>('profile-heatmap-cell-$index'),
                          width: cellWidth,
                          height: cellHeight,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _heatColor(
                                context.nightMoodPalette,
                                appColors,
                                cells[index],
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.xs),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportInsightCard extends StatelessWidget {
  const _ReportInsightCard({
    super.key,
    required this.report,
    required this.onTap,
  });

  final SleepReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AppSemanticColors appColors = context.appColors;
    final String summary = report.highlights.isNotEmpty
        ? report.highlights.first
        : '洞察你的睡眠习惯变化';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: AppRadius.surfacePrimary,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '实验报告',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            summary,
            style: AppTypography.meta(
              textTheme,
            ).copyWith(color: appColors.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: appColors.accentSoft,
              borderRadius: AppRadius.surfaceSecondary,
            ),
            child: Text(
              '查看本周结论',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: appColors.accentDeep),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInsightCard extends StatelessWidget {
  const _MiniInsightCard({
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
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AppSemanticColors appColors = context.appColors;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      borderRadius: AppRadius.surfacePrimary,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  style: AppTypography.meta(
                    textTheme,
                  ).copyWith(color: appColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(icon, color: appColors.accentDeep),
        ],
      ),
    );
  }
}

class _BadgePreviewCard extends StatelessWidget {
  const _BadgePreviewCard({
    required this.badges,
    required this.onOverviewTap,
    required this.onBadgeTap,
  });

  final List<ProfileBadgeStatusData> badges;
  final VoidCallback onOverviewTap;
  final ValueChanged<ProfileBadgeStatusData> onBadgeTap;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      borderRadius: AppRadius.surfacePrimary,
      onTap: onOverviewTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                '我的勋章',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '全部',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: appColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: appColors.textSecondary.withAlpha(150),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              for (int index = 0; index < badges.length; index++) ...<Widget>[
                Expanded(
                  child: _BadgePreviewItem(
                    badge: badges[index],
                    index: index,
                    onTap: () => onBadgeTap(badges[index]),
                  ),
                ),
                if (index != badges.length - 1)
                  const SizedBox(width: AppSpacing.xs),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgePreviewItem extends StatelessWidget {
  const _BadgePreviewItem({
    required this.badge,
    required this.index,
    required this.onTap,
  });

  final ProfileBadgeStatusData badge;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    final AppSemanticColors appColors = context.appColors;
    return Material(
      key: ValueKey<String>('profile-badge-preview-slot-$index'),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.surfaceSecondary,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Column(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: badge.unlocked
                      ? badge.selected
                            ? appColors.accentSoft
                            : appColors.accentSoft.withAlpha(96)
                      : appColors.surfaceMuted,
                  border: Border.all(
                    color: badge.selected
                        ? palette.primary
                        : badge.unlocked
                        ? appColors.accentSoft
                        : appColors.borderSubtle,
                    width: badge.selected ? 2.5 : 2,
                  ),
                ),
                child: Icon(
                  badge.unlocked ? badge.badge.icon : Icons.lock_rounded,
                  color: badge.unlocked
                      ? appColors.accentDeep
                      : appColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                badge.badge.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: badge.unlocked
                      ? appColors.textPrimary
                      : appColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DurationBar extends StatelessWidget {
  const _DurationBar({
    required this.hours,
    required this.maxHours,
    required this.label,
  });

  final double? hours;
  final double maxHours;
  final String label;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    final AppSemanticColors appColors = context.appColors;
    final bool hasValue = hours != null;
    final double value = hours ?? 0;
    final double factor = hasValue
        ? (maxHours == 0 ? 0 : (value / maxHours).clamp(0.14, 1.0))
        : 0.18;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Text(
          hasValue ? value.toStringAsFixed(1) : '--',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: hasValue ? appColors.textPrimary : appColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: factor,
              child: Container(
                decoration: BoxDecoration(
                  gradient: hasValue
                      ? LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: <Color>[palette.primary, palette.primarySoft],
                        )
                      : LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: <Color>[
                            appColors.borderSubtle,
                            appColors.surfaceMuted,
                          ],
                        ),
                  borderRadius: AppRadius.pill,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: appColors.textSecondary),
        ),
      ],
    );
  }
}

class _AxisLabel extends StatelessWidget {
  const _AxisLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: appColors.textSecondary),
    );
  }
}

class _WeekdayChip extends StatelessWidget {
  const _WeekdayChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: appColors.textSecondary),
    );
  }
}

class _ChartBadgeMarker extends StatelessWidget {
  const _ChartBadgeMarker({
    required this.offset,
    required this.label,
    required this.color,
  });

  final Offset offset;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double left = (offset.dx - 18).clamp(0, double.infinity);
    final double top = (offset.dy - 32).clamp(0, double.infinity);
    final AppSemanticColors appColors = context.appColors;

    return Positioned(
      left: left,
      top: top,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: appColors.surface,
          borderRadius: AppRadius.surfaceSecondary,
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: appColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendEmptyState extends StatelessWidget {
  const _TrendEmptyState();

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: appColors.surface.withAlpha(220),
          borderRadius: AppRadius.surfaceSecondary,
        ),
        child: Text(
          '待录入',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: appColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SleepQualityChartPainter extends CustomPainter {
  const _SleepQualityChartPainter({
    required this.points,
    required this.palette,
    required this.gridColor,
  });

  final List<Offset?> points;
  final NightMoodPalette palette;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final double factor in const <double>[0, 0.5, 1]) {
      final double y = size.height * factor;
      canvas.drawLine(
        Offset.zero.translate(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    final List<Offset> plotted = points.whereType<Offset>().toList(
      growable: false,
    );
    if (plotted.isEmpty) {
      return;
    }

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          palette.primarySoft.withAlpha(140),
          palette.primarySoft.withAlpha(10),
        ],
      ).createShader(Offset.zero & size);
    final Paint linePaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          AppColors.calmBlue,
          palette.primary,
          palette.primaryDeep,
        ],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3;
    final Paint dotPaint = Paint()..color = palette.primary;
    for (final List<Offset> segment in _chartSegments(points)) {
      if (segment.isEmpty) {
        continue;
      }
      if (segment.length >= 2) {
        final Path linePath = _smoothPath(segment);
        final Path fillPath = Path.from(linePath)
          ..lineTo(segment.last.dx, size.height)
          ..lineTo(segment.first.dx, size.height)
          ..close();
        canvas.drawPath(fillPath, fillPaint);
        canvas.drawPath(linePath, linePaint);
      }
      for (final Offset point in segment) {
        canvas.drawCircle(point, 3, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SleepQualityChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.palette != palette ||
        oldDelegate.gridColor != gridColor;
  }
}

class _ChartPoint {
  const _ChartPoint({required this.label, required this.value});

  final String label;
  final double? value;
}

Path _smoothPath(List<Offset> points) {
  if (points.length < 2) {
    return Path()..addOval(Rect.fromCircle(center: points.first, radius: 1));
  }

  final Path path = Path()..moveTo(points.first.dx, points.first.dy);
  for (int index = 1; index < points.length; index++) {
    final Offset previous = points[index - 1];
    final Offset current = points[index];
    final Offset mid = Offset(
      (previous.dx + current.dx) / 2,
      (previous.dy + current.dy) / 2,
    );
    path.quadraticBezierTo(previous.dx, previous.dy, mid.dx, mid.dy);
    if (index == points.length - 1) {
      path.quadraticBezierTo(current.dx, current.dy, current.dx, current.dy);
    }
  }
  return path;
}

List<Offset?> _chartOffsets(
  List<_ChartPoint> values,
  double width,
  double height,
) {
  if (values.isEmpty || width <= 0 || height <= 0) {
    return const <Offset?>[];
  }

  final double step = values.length == 1 ? 0 : width / (values.length - 1);
  return List<Offset?>.generate(values.length, (int index) {
    final double x = step * index;
    final double? value = values[index].value;
    if (value == null) {
      return null;
    }
    final double normalized = (value / 100).clamp(0.0, 1.0);
    final double y = height - (height * normalized);
    return Offset(x, y);
  });
}

List<List<Offset>> _chartSegments(List<Offset?> points) {
  final List<List<Offset>> segments = <List<Offset>>[];
  List<Offset> current = <Offset>[];
  for (final Offset? point in points) {
    if (point == null) {
      if (current.isNotEmpty) {
        segments.add(current);
        current = <Offset>[];
      }
      continue;
    }
    current.add(point);
  }
  if (current.isNotEmpty) {
    segments.add(current);
  }
  return segments;
}

int? _bestPointIndex(List<_ChartPoint> values) {
  if (values.isEmpty) {
    return null;
  }
  int? bestIndex;
  double bestValue = -1;
  for (int index = 0; index < values.length; index++) {
    final double? value = values[index].value;
    if (value != null && value >= bestValue) {
      bestValue = value;
      bestIndex = index;
    }
  }
  return bestIndex;
}

int? _latestPointIndex(List<_ChartPoint> values) {
  if (values.isEmpty) {
    return null;
  }
  for (int index = values.length - 1; index >= 0; index--) {
    if (values[index].value != null) {
      return index;
    }
  }
  return null;
}

Color _heatColor(
  NightMoodPalette palette,
  AppSemanticColors appColors,
  int intensity,
) {
  return switch (intensity) {
    <= 0 => appColors.surfaceMuted,
    1 => palette.primarySoft.withAlpha(70),
    2 => palette.primarySoft.withAlpha(130),
    _ => palette.primary,
  };
}
