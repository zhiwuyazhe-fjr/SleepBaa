import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/user_avatar.dart';
import 'package:sleep_dorm_app/features/profile/data/profile_badges.dart';

class ProfileHeaderSection extends StatelessWidget {
  const ProfileHeaderSection({
    super.key,
    required this.profile,
    required this.onAvatarTap,
  });

  final UserProfile profile;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final NightMoodPalette palette = context.nightMoodPalette;

    return Column(
      children: <Widget>[
        UserAvatar(
          profile: profile,
          size: 96,
          editable: true,
          onTap: onAvatarTap,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          profile.displayName,
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          profile.tagline,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        if (profile.role.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: palette.primaryHighlight,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Text(
              profile.role,
              style: textTheme.labelMedium?.copyWith(
                color: palette.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class ProfileQuoteCard extends StatelessWidget {
  const ProfileQuoteCard({super.key, required this.quote});

  final String quote;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      color: palette.primarySoft,
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: palette.primaryDeep,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              Icons.format_quote_rounded,
              color: palette.primaryHighlight,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              quote,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: palette.primaryDeep),
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
    required this.sessions,
    required this.heatmapValues,
    required this.onHeatmapTap,
  });

  final List<SleepSession> sessions;
  final List<int> heatmapValues;
  final VoidCallback onHeatmapTap;

  @override
  State<ProfileDataCarousel> createState() => _ProfileDataCarouselState();
}

class _ProfileDataCarouselState extends State<ProfileDataCarousel> {
  late final PageController _controller;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        AspectRatio(
          key: const ValueKey<String>('profile-data-carousel'),
          aspectRatio: 1.62,
          child: PageView(
            clipBehavior: Clip.none,
            controller: _controller,
            padEnds: false,
            onPageChanged: (int index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: _SleepQualityCard(sessions: widget.sessions),
              ),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: _SleepDurationCard(sessions: widget.sessions),
              ),
              _CheckInHeatmapCard(
                heatmapValues: widget.heatmapValues,
                onTap: widget.onHeatmapTap,
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
                    : AppColors.surfaceBorder,
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
  final List<ProfileBadgeMeta> badges;
  final VoidCallback onReportTap;
  final VoidCallback onDreamTap;
  final VoidCallback onThoughtTap;
  final VoidCallback onBadgeOverviewTap;
  final ValueChanged<ProfileBadgeMeta> onBadgeTap;

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
    return AppCard(
      key: const ValueKey<String>('profile-settings-card'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Column(
        children: <Widget>[
          _ProfileMenuRow(
            icon: Icons.settings_outlined,
            title: '设置',
            onTap: onSettingsTap,
          ),
          _ProfileMenuRow(
            icon: Icons.help_outline_rounded,
            title: '常见问题',
            onTap: onFaqTap,
          ),
        ],
      ),
    );
  }
}

class _SleepQualityCard extends StatelessWidget {
  const _SleepQualityCard({required this.sessions});

  final List<SleepSession> sessions;

  @override
  Widget build(BuildContext context) {
    final List<_ChartValue> points = sessions.map(_qualityChartValue).toList();
    final int bestIndex = _bestPointIndex(points);
    final int latestIndex = _latestPointIndex(points);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '睡眠质量(分)',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                const double axisWidth = 28;
                const double xAxisHeight = 24;
                final double plotWidth = constraints.maxWidth - axisWidth;
                final double plotHeight = constraints.maxHeight - xAxisHeight;
                final List<Offset> offsets = _chartOffsets(
                  points,
                  plotWidth,
                  plotHeight,
                );

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
                                    ),
                                  ),
                                ),
                                if (offsets.isNotEmpty) ...<Widget>[
                                  _ChartBadgeMarker(
                                    offset: offsets[bestIndex],
                                    label: '平静',
                                    color: context.nightMoodPalette.primary,
                                  ),
                                  _ChartBadgeMarker(
                                    offset: offsets[latestIndex],
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
                              children: sessions
                                  .map(
                                    (SleepSession session) => Text(
                                      _weekdayLabel(session.startedAt),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(color: AppColors.textHint),
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
  const _SleepDurationCard({required this.sessions});

  final List<SleepSession> sessions;

  @override
  Widget build(BuildContext context) {
    final List<double> hours = sessions.map(_durationHours).toList();
    final double maxHours = hours.isEmpty
        ? 8
        : math.max(8, hours.reduce(math.max));

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '睡眠时长(小时)',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (
                  int index = 0;
                  index < sessions.length;
                  index++
                ) ...<Widget>[
                  Expanded(
                    child: _DurationBar(
                      hours: hours[index],
                      maxHours: maxHours,
                      label: _weekdayLabel(sessions[index].startedAt),
                    ),
                  ),
                  if (index != sessions.length - 1)
                    const SizedBox(width: AppSpacing.xs),
                ],
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
    final List<int> cells = heatmapValues;
    final int rowCount = math.max(1, (cells.length / 7).ceil());

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '本月打卡热力',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint,
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
            child: Column(
              children: <Widget>[
                for (int row = 0; row < rowCount; row++) ...<Widget>[
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        for (int column = 0; column < 7; column++) ...<Widget>[
                          Expanded(
                            child: Container(
                              margin: EdgeInsets.only(
                                right: column == 6 ? 0 : AppSpacing.xs / 2,
                                bottom: row == rowCount - 1
                                    ? 0
                                    : AppSpacing.xs / 2,
                              ),
                              decoration: BoxDecoration(
                                color: _heatColor(
                                  context.nightMoodPalette,
                                  cells[row * 7 + column],
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xs,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (row != rowCount - 1)
                    const SizedBox(height: AppSpacing.xs / 2),
                ],
              ],
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
    final NightMoodPalette palette = context.nightMoodPalette;
    final String summary = report.highlights.isNotEmpty
        ? report.highlights.first
        : '洞察你的睡眠习惯变化';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: BorderRadius.circular(AppRadius.sm),
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
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
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
              color: palette.primaryHighlight,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Text(
              '查看本周结论',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: palette.primaryDeep),
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
    final NightMoodPalette palette = context.nightMoodPalette;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      borderRadius: BorderRadius.circular(AppRadius.sm),
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
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(icon, color: palette.primaryDeep),
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

  final List<ProfileBadgeMeta> badges;
  final VoidCallback onOverviewTap;
  final ValueChanged<ProfileBadgeMeta> onBadgeTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      borderRadius: BorderRadius.circular(AppRadius.lg),
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
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textHint,
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
  const _BadgePreviewItem({required this.badge, required this.onTap});

  final ProfileBadgeMeta badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
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
                      ? palette.primaryHighlight
                      : AppColors.surfaceSoft,
                  border: Border.all(
                    color: badge.unlocked
                        ? palette.primarySoft
                        : AppColors.surfaceBorder,
                    width: 2,
                  ),
                ),
                child: Icon(
                  badge.icon,
                  color: badge.unlocked
                      ? palette.primaryDeep
                      : AppColors.textHint,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                badge.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: badge.unlocked
                      ? AppColors.textPrimary
                      : AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, color: palette.primaryDeep),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint,
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

  final double hours;
  final double maxHours;
  final String label;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    final double factor = maxHours == 0
        ? 0
        : (hours / maxHours).clamp(0.14, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Text(
          hours.toStringAsFixed(1),
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: factor,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: <Color>[palette.primary, palette.primarySoft],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
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
          ).textTheme.labelSmall?.copyWith(color: AppColors.textHint),
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
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: AppColors.textHint),
    );
  }
}

class _WeekdayChip extends StatelessWidget {
  const _WeekdayChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: AppColors.textHint),
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

    return Positioned(
      left: left,
      top: top,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
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
              ).textTheme.labelSmall?.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepQualityChartPainter extends CustomPainter {
  const _SleepQualityChartPainter({
    required this.points,
    required this.palette,
  });

  final List<Offset> points;
  final NightMoodPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;
    for (final double factor in const <double>[0, 0.5, 1]) {
      final double y = size.height * factor;
      canvas.drawLine(
        Offset.zero.translate(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    if (points.isEmpty) {
      return;
    }

    final Path linePath = _smoothPath(points);
    final Path fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          palette.primarySoft.withAlpha(140),
          palette.primarySoft.withAlpha(10),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fillPath, fillPaint);

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
    canvas.drawPath(linePath, linePaint);

    final Paint dotPaint = Paint()..color = palette.primary;
    for (final Offset point in points) {
      canvas.drawCircle(point, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SleepQualityChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.palette != palette;
  }
}

class _ChartValue {
  const _ChartValue({required this.label, required this.value});

  final String label;
  final double value;
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

List<Offset> _chartOffsets(
  List<_ChartValue> values,
  double width,
  double height,
) {
  if (values.isEmpty || width <= 0 || height <= 0) {
    return const <Offset>[];
  }

  final double step = values.length == 1 ? 0 : width / (values.length - 1);
  return List<Offset>.generate(values.length, (int index) {
    final double x = step * index;
    final double normalized = (values[index].value / 100).clamp(0.0, 1.0);
    final double y = height - (height * normalized);
    return Offset(x, y);
  });
}

_ChartValue _qualityChartValue(SleepSession session) {
  final MorningSummary? summary = session.summary;
  if (summary == null) {
    return _ChartValue(label: _weekdayLabel(session.startedAt), value: 0);
  }
  final double raw = summary.sleepQuality.toDouble();
  final double normalized = raw <= 5 ? raw * 20 : raw;
  return _ChartValue(
    label: _weekdayLabel(session.startedAt),
    value: normalized.clamp(0, 100),
  );
}

int _bestPointIndex(List<_ChartValue> values) {
  if (values.isEmpty) {
    return 0;
  }
  int bestIndex = 0;
  double bestValue = values.first.value;
  for (int index = 1; index < values.length; index++) {
    if (values[index].value >= bestValue) {
      bestValue = values[index].value;
      bestIndex = index;
    }
  }
  return bestIndex;
}

int _latestPointIndex(List<_ChartValue> values) {
  if (values.isEmpty) {
    return 0;
  }
  for (int index = values.length - 1; index >= 0; index--) {
    if (values[index].value > 0) {
      return index;
    }
  }
  return values.length - 1;
}

double _durationHours(SleepSession session) {
  final MorningSummary? summary = session.summary;
  if (summary != null) {
    return summary.totalSleepHours;
  }
  final DateTime? endedAt = session.endedAt;
  if (endedAt == null) {
    return 0;
  }
  return endedAt.difference(session.startedAt).inMinutes / 60;
}

String _weekdayLabel(DateTime date) {
  const List<String> labels = <String>['一', '二', '三', '四', '五', '六', '日'];
  return labels[date.weekday - 1];
}

Color _heatColor(NightMoodPalette palette, int intensity) {
  return switch (intensity) {
    <= 0 => AppColors.surfaceSubtle,
    1 => palette.primarySoft.withAlpha(70),
    2 => palette.primarySoft.withAlpha(130),
    _ => palette.primary,
  };
}
