import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/utils/avatar_picker.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/icon_badge.dart';
import 'package:sleep_dorm_app/core/widgets/mini_calendar_grid.dart';
import 'package:sleep_dorm_app/core/widgets/section_title.dart';
import 'package:sleep_dorm_app/core/widgets/user_avatar.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const ValueKey<String> monthPreviewGridKey = ValueKey<String>(
    'profile-month-preview-grid',
  );

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        services.authRepository,
        services.settingsRepository,
        services.sleepSessionRepository,
        services.sleepCaptureRepository,
        services.insightsRepository,
      ]),
      builder: (BuildContext context, Widget? child) {
        final NightMoodPalette palette = context.nightMoodPalette;
        final UserProfile profile = services.authRepository.currentUser;
        final UserSettings settings =
            services.settingsRepository.currentSettings;
        final List<SleepSession> weekly = services.sleepSessionRepository
            .recentSessions();
        final SleepReport report = services.insightsFacade.currentReport;
        final DateTime now = DateTime.now();
        final DateTime currentMonth = DateTime(now.year, now.month);
        final List<SleepSession> monthSessions = services.sleepSessionRepository
            .sessionsForMonth(currentMonth);
        final List<SleepSession> completed = weekly
            .where((SleepSession item) => item.summary != null)
            .toList(growable: false);
        final int pendingCount = weekly
            .where((SleepSession item) => item.summary == null)
            .length;
        final HonorBadge? activeBadge = honorBadgeById(profile.displayBadgeId);
        final double averageSleep = completed.isEmpty
            ? 0
            : completed.fold<double>(
                    0,
                    (double sum, SleepSession item) =>
                        sum + item.summary!.totalSleepHours,
                  ) /
                  completed.length;
        final int score = completed.isEmpty
            ? 0
            : ((averageSleep / settings.sleepGoalHours) * 100)
                  .clamp(0, 100)
                  .round();

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              128,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    UserAvatar(
                      profile: profile,
                      editable: true,
                      onTap: () => pickAndSaveAvatar(context),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            profile.displayName,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            profile.tagline,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            profile.role,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: palette.primary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => context.push(AppRoutes.profileSettings),
                      icon: const Icon(Icons.settings_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                AppCard(
                  borderRadius: AppRadius.card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  '我的连续 7 天',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  '本周目标 ${settings.sleepGoalHours.toStringAsFixed(1)} h',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(color: palette.primary),
                                ),
                              ],
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              style: Theme.of(context).textTheme.headlineMedium,
                              children: <InlineSpan>[
                                TextSpan(text: '$score'),
                                TextSpan(
                                  text: '/100',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ClipRRect(
                        borderRadius: AppRadius.pill,
                        child: LinearProgressIndicator(
                          minHeight: 10,
                          value: score / 100,
                          backgroundColor: AppColors.surfaceSoft,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            palette.primarySoft,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: <Widget>[
                          _StatPill(
                            label: '平均睡眠',
                            value: averageSleep == 0
                                ? '--'
                                : '${averageSleep.toStringAsFixed(1)}h',
                          ),
                          _StatPill(
                            label: '已完成反馈',
                            value: '${completed.length} 夜',
                          ),
                          _StatPill(
                            label: '待补全',
                            value: '$pendingCount 夜',
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        children: <Widget>[
                          Text(
                            '7 日睡眠趋势',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          const Spacer(),
                          Text(
                            '平均 ${averageSleep.toStringAsFixed(1)} 小时',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: palette.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _WeeklyTrendChart(sessions: weekly),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SectionTitle(
                  title: '入睡打卡日历',
                  actionLabel: '完整日历',
                  onAction: () => context.push(AppRoutes.profileCalendar),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  borderRadius: AppRadius.card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '本月打卡热力预览',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      MiniCalendarGrid(
                        key: monthPreviewGridKey,
                        weekdays: const <String>[
                          'Mon',
                          'Tue',
                          'Wed',
                          'Thu',
                          'Fri',
                          'Sat',
                          'Sun',
                        ],
                        intensity: _buildMonthPreviewIntensity(
                          month: currentMonth,
                          sessions: monthSessions,
                        ),
                        showWeekdays: false,
                        childAspectRatio: 1.2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SectionTitle(
                  title: '睡眠实验报告',
                  actionLabel: '查看报告',
                  onAction: () => context.push(AppRoutes.profileReport),
                ),
                const SizedBox(height: AppSpacing.md),
                ..._buildReportCards(context, weekly, report),
                const SizedBox(height: AppSpacing.xl),
                AppCard(
                  borderRadius: AppRadius.card,
                  border: Border.all(color: palette.primarySoft.withAlpha(70)),
                  onTap: () => context.push(AppRoutes.dreamJournal),
                  child: Row(
                    children: <Widget>[
                      IconBadge(
                        icon: Icons.auto_stories_rounded,
                        backgroundColor: palette.primarySoft.withAlpha(20),
                        iconColor: palette.primary,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '梦境记录',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '记录昨夜梦境片段、醒来后的情绪和关键词。',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      const Icon(
                        Icons.east_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  borderRadius: AppRadius.card,
                  border: Border.all(color: palette.primarySoft.withAlpha(50)),
                  onTap: () => context.push(AppRoutes.profileThoughtVault),
                  child: Row(
                    children: <Widget>[
                      IconBadge(
                        icon: Icons.inventory_2_rounded,
                        backgroundColor: palette.primaryHighlight.withAlpha(
                          180,
                        ),
                        iconColor: palette.primaryDeep,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '事记仓库',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '收好睡眠模式里记下的待办、念头与夜间灵感。',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      const Icon(
                        Icons.east_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: <Widget>[
                    Text(
                      '专属荣誉勋章',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.profileBadges),
                      child: const Text('查看全部'),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${profile.earnedBadgeIds.length} / ${kHonorBadgeCatalog.length}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        activeBadge == null
                            ? '当前默认展示最新获得的勋章'
                            : '当前展示：${activeBadge.label}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: profile.equippedBadgeId == null
                          ? null
                          : () async {
                              await services.profileFacade.saveEquippedBadge(
                                null,
                              );
                            },
                      child: const Text('恢复最新获得'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.md,
                  children: kHonorBadgeCatalog
                      .map((HonorBadge badge) {
                        final bool unlocked = profile.hasEarnedBadge(badge.id);
                        final bool selected =
                            profile.displayBadgeId == badge.id;
                        return SizedBox(
                          width: 98,
                          child: _BadgeTile(
                            badge: badge,
                            unlocked: unlocked,
                            selected: selected,
                            onTap: !unlocked
                                ? null
                                : () async {
                                    await services.profileFacade
                                        .saveEquippedBadge(
                                          selected ? null : badge.id,
                                        );
                                  },
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ignore: unused_element
  List<Widget> _buildExperimentCards(
    BuildContext context,
    List<SleepSession> weekly,
  ) {
    final int calmNights = weekly
        .where((SleepSession item) => item.awakenings.isEmpty)
        .length;
    final List<_ExperimentCardData> cards = <_ExperimentCardData>[
      _ExperimentCardData(
        icon: Icons.coffee_rounded,
        title: '咖啡因耐受测试',
        insight: '过去 7 晚里，下午 3 点前停止咖啡因摄入的夜晚更稳定。',
        status: '有效',
        accent: context.nightMoodPalette.primary,
      ),
      _ExperimentCardData(
        icon: Icons.nights_stay_rounded,
        title: '宿舍安静观察',
        insight: '最近 7 晚里有 $calmNights 晚没有夜醒，安静环境的帮助很明显。',
        status: '持续跟进',
        accent: AppColors.textSecondary,
      ),
    ];

    return cards
        .map(
          (_ExperimentCardData report) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppCard(
              borderRadius: AppRadius.card,
              border: Border.all(color: report.accent.withAlpha(70)),
              child: Row(
                children: <Widget>[
                  IconBadge(
                    icon: report.icon,
                    backgroundColor: report.accent.withAlpha(20),
                    iconColor: report.accent,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          report.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          report.insight,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    report.status,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: report.accent),
                  ),
                ],
              ),
            ),
          ),
        )
        .toList();
  }

  List<Widget> _buildReportCards(
    BuildContext context,
    List<SleepSession> weekly,
    SleepReport report,
  ) {
    final List<SleepSession> pending = weekly
        .where((SleepSession item) => item.summary == null)
        .toList(growable: false);
    final List<_InsightCardData> cards = <_InsightCardData>[
      _InsightCardData(
        icon: Icons.insights_rounded,
        title: report.title,
        detail:
            '平均睡眠 ${report.averageSleepHours.toStringAsFixed(1)}h，质量 ${report.averageSleepQuality.toStringAsFixed(1)}，恢复感 ${report.averageRestedLevel.toStringAsFixed(1)}。',
        badge: '已同步',
        accent: context.nightMoodPalette.primary,
      ),
      _InsightCardData(
        icon: Icons.task_alt_rounded,
        title: '晨间反馈进度',
        detail: pending.isEmpty
            ? '最近的睡眠记录都已补全晨间反馈。'
            : '还有 ${pending.length} 夜等待晨间反馈，补全后会同步到日历和趋势分析里。',
        badge: pending.isEmpty ? '已完成' : '待处理',
        accent: AppColors.textSecondary,
      ),
      _InsightCardData(
        icon: Icons.auto_graph_rounded,
        title: '节律观察',
        detail: report.highlights.isEmpty
            ? '继续记录更多夜晚后，这里会总结你的睡眠节律、宿舍安静度与晨间恢复感。'
            : report.highlights.take(2).join(' '),
        badge: '多夜趋势',
        accent: context.nightMoodPalette.primaryDeep,
      ),
    ];

    return cards
        .map(
          (_InsightCardData card) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppCard(
              borderRadius: AppRadius.card,
              border: Border.all(color: card.accent.withAlpha(70)),
              child: Row(
                children: <Widget>[
                  IconBadge(
                    icon: card.icon,
                    backgroundColor: card.accent.withAlpha(20),
                    iconColor: card.accent,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          card.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          card.detail,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    card.badge,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: card.accent),
                  ),
                ],
              ),
            ),
          ),
        )
        .toList(growable: false);
  }

  List<int> _buildMonthPreviewIntensity({
    required DateTime month,
    required List<SleepSession> sessions,
  }) {
    final Map<DateTime, int> qualityByDay = <DateTime, int>{
      for (final SleepSession session in sessions)
        DateUtils.dateOnly(session.startedAt):
            (session.summary?.sleepQuality ?? 0).clamp(0, 5),
    };
    final int daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final int leadingEmpty = DateTime(month.year, month.month, 1).weekday - 1;
    final int trailingEmpty = (7 - ((leadingEmpty + daysInMonth) % 7)) % 7;

    return <int>[
      ...List<int>.filled(leadingEmpty, 0),
      for (int day = 1; day <= daysInMonth; day++)
        qualityByDay[DateTime(month.year, month.month, day)] ?? 0,
      ...List<int>.filled(trailingEmpty, 0),
    ];
  }
}

class _WeeklyTrendChart extends StatelessWidget {
  const _WeeklyTrendChart({required this.sessions});

  final List<SleepSession> sessions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 176,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: sessions.map((SleepSession session) {
          final double hours = session.summary?.totalSleepHours ?? 0;
          final double heightFactor = (hours / 9).clamp(0.2, 1.0);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Text(
                    hours.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: heightFactor,
                        child: Container(
                          decoration: BoxDecoration(
                            color: hours >= 7.5
                                ? context.nightMoodPalette.primarySoft
                                : AppColors.surfaceBorder,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${session.startedAt.month}/${session.startedAt.day}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.badge,
    required this.unlocked,
    required this.selected,
    this.onTap,
  });

  final HonorBadge badge;
  final bool unlocked;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    return Tooltip(
      message: badge.description,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unlocked
                      ? palette.primary.withAlpha(selected ? 28 : 18)
                      : AppColors.surfaceSoft,
                  border: Border.all(
                    color: selected
                        ? palette.primary
                        : unlocked
                        ? palette.primarySoft
                        : AppColors.divider,
                    width: selected ? 2.5 : 1.5,
                  ),
                ),
                child: Icon(
                  unlocked ? badge.icon : Icons.lock_rounded,
                  color: unlocked
                      ? palette.primary
                      : AppColors.textSecondary.withAlpha(110),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                badge.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textPrimary.withAlpha(unlocked ? 255 : 120),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                selected
                    ? '当前佩戴'
                    : unlocked
                    ? '点击佩戴'
                    : '未获得',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? palette.primary : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.pill,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExperimentCardData {
  const _ExperimentCardData({
    required this.icon,
    required this.title,
    required this.insight,
    required this.status,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String insight;
  final String status;
  final Color accent;
}

class _InsightCardData {
  const _InsightCardData({
    required this.icon,
    required this.title,
    required this.detail,
    required this.badge,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String badge;
  final Color accent;
}
