import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/app_typography.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/utils/formatters.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_detail_page_header.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';

class CalendarCheckinPage extends StatefulWidget {
  const CalendarCheckinPage({super.key, this.initialSelectedDay});

  final DateTime? initialSelectedDay;

  @override
  State<CalendarCheckinPage> createState() => _CalendarCheckinPageState();
}

class _CalendarCheckinPageState extends State<CalendarCheckinPage> {
  late DateTime _visibleMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDay = DateUtils.dateOnly(
      widget.initialSelectedDay ?? now.subtract(const Duration(days: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    final NightMoodPalette palette = context.nightMoodPalette;
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppDetailPageAppBar(
        title: '睡眠打卡日历',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          services.sleepSessionRepository,
          services.settingsRepository,
        ]),
        builder: (BuildContext context, Widget? child) {
          final UserSettings settings =
              services.settingsRepository.currentSettings;
          final List<SleepSession> monthSessions = services
              .sleepSessionRepository
              .sessionsForMonth(_visibleMonth);
          final Map<DateTime, SleepSession> sessionMap =
              <DateTime, SleepSession>{
                for (final SleepSession session in monthSessions)
                  DateUtils.dateOnly(session.sleepDayDate): session,
              };
          final SleepSession? selectedSession = _selectedDay == null
              ? null
              : sessionMap[_selectedDay];
          final int pendingCount = monthSessions
              .where((SleepSession session) => session.summary == null)
              .length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              120,
            ),
            children: <Widget>[
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                borderRadius: AppRadius.surfacePrimary,
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _visibleMonth = DateTime(
                                _visibleMonth.year,
                                _visibleMonth.month - 1,
                              );
                            });
                          },
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: Text(
                            Formatters.formatMonthLabel(_visibleMonth),
                            textAlign: TextAlign.center,
                            style: AppTypography.panelTitle(textTheme),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _visibleMonth = DateTime(
                                _visibleMonth.year,
                                _visibleMonth.month + 1,
                              );
                            });
                          },
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Row(
                      children: <Widget>[
                        _WeekdayLabel('Mon'),
                        _WeekdayLabel('Tue'),
                        _WeekdayLabel('Wed'),
                        _WeekdayLabel('Thu'),
                        _WeekdayLabel('Fri'),
                        _WeekdayLabel('Sat'),
                        _WeekdayLabel('Sun'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _CalendarGrid(
                      month: _visibleMonth,
                      sessionMap: sessionMap,
                      selectedDay: _selectedDay,
                      sleepGoalHours: settings.sleepGoalHours,
                      palette: palette,
                      onSelectDay: (DateTime day) {
                        setState(() => _selectedDay = day);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                color: appColors.surfaceMuted,
                padding: const EdgeInsets.all(AppSpacing.md),
                borderRadius: AppRadius.surfacePrimary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('连续记录', style: AppTypography.cardTitle(textTheme)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${_buildStreak(services.sleepSessionRepository.sessions)} 天连续打卡',
                      style: AppTypography.panelTitle(
                        textTheme,
                      ).copyWith(color: palette.primary),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        _DetailChip(label: '本月记录 ${monthSessions.length} 天'),
                        _DetailChip(label: '待补充 $pendingCount 天'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '同一睡眠日多次退出或再次进入都会累计到同一天，晨间反馈完成后该日时长会锁定。',
                      style: AppTypography.bodyMuted(
                        textTheme,
                      ).copyWith(color: appColors.textSecondary, height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                borderRadius: AppRadius.surfacePrimary,
                child: _SelectedSessionDetail(
                  session: selectedSession,
                  sleepGoalHours: settings.sleepGoalHours,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  int _buildStreak(List<SleepSession> sessions) {
    if (sessions.isEmpty) {
      return 0;
    }
    final List<DateTime> uniqueDays =
        sessions
            .map(
              (SleepSession session) =>
                  DateUtils.dateOnly(session.sleepDayDate),
            )
            .toSet()
            .toList(growable: false)
          ..sort((DateTime a, DateTime b) => b.compareTo(a));
    int streak = 1;
    for (int index = 1; index < uniqueDays.length; index++) {
      final int gap = uniqueDays[index - 1]
          .difference(uniqueDays[index])
          .inDays;
      if (gap == 1) {
        streak += 1;
        continue;
      }
      break;
    }
    return streak;
  }
}

class _SelectedSessionDetail extends StatelessWidget {
  const _SelectedSessionDetail({
    required this.session,
    required this.sleepGoalHours,
  });

  final SleepSession? session;
  final double sleepGoalHours;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AppSemanticColors appColors = context.appColors;
    if (session == null) {
      return Text(
        '这一天还没有睡眠记录。',
        style: AppTypography.bodyMuted(
          textTheme,
        ).copyWith(color: appColors.textSecondary),
      );
    }

    final MorningSummary? summary = session!.summary;
    final bool canSupplementFeedback =
        session!.status == SleepSessionStatus.awaitingFeedback &&
        !session!.sleepModeActive &&
        !session!.hasSubmittedFeedback;
    final bool sleepGoalMet =
        _sleepGoalMetForSession(session!, sleepGoalHours) == true;
    final String stageLabel = _sessionStageLabel(session!);
    final Color stageColor = _sessionStageColor(session!, appColors);
    final String durationLabel =
        '${session!.displaySleepHours().toStringAsFixed(1)} h';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                Formatters.formatDateLabel(session!.sleepDayDate),
                style: AppTypography.cardTitle(textTheme),
              ),
            ),
            _StateBadge(label: stageLabel, color: stageColor),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _DetailChip(label: '时长 $durationLabel'),
            if (sleepGoalMet) const _DetailChip(label: '睡眠时长已达标'),
            _DetailChip(label: '夜醒 ${session!.awakenings.length} 次'),
            _DetailChip(
              label: '建议 ${session!.selectedRecommendationIds.length} 项',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text('当晚摘要', style: AppTypography.cardTitle(textTheme)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          summary?.note ?? _summaryFallback(session!),
          style: AppTypography.bodyMuted(
            textTheme,
          ).copyWith(color: appColors.textSecondary, height: 1.5),
        ),
        if (canSupplementFeedback) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: '补充晨间反馈',
            size: PrimaryButtonSize.compact,
            onPressed: () {
              context.push(
                AppRoutes.feedbackMorningLocation(sessionId: session!.id),
              );
            },
          ),
        ],
        if (summary != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _DetailChip(label: '睡眠质量 ${summary.sleepQuality}/5'),
              _DetailChip(label: '恢复感 ${summary.restedLevel}/5'),
              _DetailChip(label: '夜醒统计 ${summary.awakeningsCount} 次'),
            ],
          ),
        ],
      ],
    );
  }

  String _summaryFallback(SleepSession session) {
    return switch (session.status) {
      SleepSessionStatus.active => '已进入睡眠模式，仍在持续记录当晚时长。',
      SleepSessionStatus.paused => '已退出睡眠模式，稍后再次进入仍可继续累计。',
      SleepSessionStatus.awaitingFeedback => '等待晨间反馈补全睡眠质量与恢复感。',
      SleepSessionStatus.completed => '晨间反馈已完成，本日记录已锁定。',
      SleepSessionStatus.drafted => '这条记录还在准备中。',
    };
  }

  String _sessionStageLabel(SleepSession session) {
    if (session.summary != null ||
        session.status == SleepSessionStatus.completed) {
      return '已完成';
    }
    return switch (session.status) {
      SleepSessionStatus.active => '进行中',
      SleepSessionStatus.paused => '已暂停',
      SleepSessionStatus.awaitingFeedback => '待补充',
      SleepSessionStatus.completed => '已完成',
      SleepSessionStatus.drafted => '草稿',
    };
  }

  Color _sessionStageColor(SleepSession session, AppSemanticColors appColors) {
    if (session.summary != null ||
        session.status == SleepSessionStatus.completed) {
      return const Color(0xFF2D9272);
    }
    return switch (session.status) {
      SleepSessionStatus.active => const Color(0xFF4458D8),
      SleepSessionStatus.paused => const Color(0xFF8B7CF6),
      SleepSessionStatus.awaitingFeedback => const Color(0xFFF39A3C),
      SleepSessionStatus.completed => const Color(0xFF2D9272),
      SleepSessionStatus.drafted => appColors.textSecondary,
    };
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: AppTypography.chip(
            Theme.of(context).textTheme,
          ).copyWith(color: appColors.textSecondary),
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.sessionMap,
    required this.selectedDay,
    required this.sleepGoalHours,
    required this.palette,
    required this.onSelectDay,
  });

  final DateTime month;
  final Map<DateTime, SleepSession> sessionMap;
  final DateTime? selectedDay;
  final double sleepGoalHours;
  final NightMoodPalette palette;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final int daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final int leadingEmpty = DateTime(month.year, month.month, 1).weekday - 1;
    final List<Widget> cells = <Widget>[
      for (int index = 0; index < leadingEmpty; index++)
        const SizedBox.shrink(),
      for (int day = 1; day <= daysInMonth; day++)
        _DayCell(
          date: DateTime(month.year, month.month, day),
          session: sessionMap[DateTime(month.year, month.month, day)],
          selected: selectedDay == DateTime(month.year, month.month, day),
          sleepGoalHours: sleepGoalHours,
          palette: palette,
          onTap: onSelectDay,
        ),
    ];

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.xxs,
      crossAxisSpacing: AppSpacing.xxs,
      childAspectRatio: 1,
      children: cells,
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.session,
    required this.selected,
    required this.sleepGoalHours,
    required this.palette,
    required this.onTap,
  });

  final DateTime date;
  final SleepSession? session;
  final bool selected;
  final double sleepGoalHours;
  final NightMoodPalette palette;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final int quality = session?.summary?.sleepQuality ?? 0;
    final bool pending = session != null && session!.summary == null;
    final bool sleepGoalMet =
        session != null &&
        _sleepGoalMetForSession(session!, sleepGoalHours) == true;
    final AppSemanticColors appColors = context.appColors;
    final Color selectedFill = appColors.accent;
    final Color selectedForeground = appColors.textOnAccent;
    final Border cellBorder = selected
        ? Border.all(color: appColors.accentDeep, width: 2)
        : pending
        ? Border.all(color: appColors.accent.withAlpha(180))
        : Border.all(color: appColors.borderSubtle.withAlpha(120));
    final Color fill = switch (quality) {
      5 => palette.primary,
      4 => palette.primarySoft,
      3 => palette.primarySoft.withAlpha(150),
      2 => palette.primarySoft.withAlpha(90),
      1 => palette.primarySoft.withAlpha(50),
      _ => pending ? palette.primarySoft.withAlpha(72) : appColors.surfaceMuted,
    };
    return InkWell(
      key: ValueKey<String>('calendar-day-cell-${date.day}'),
      borderRadius: AppRadius.surfaceSecondary,
      onTap: () {
        final SleepSession? currentSession = session;
        if (currentSession != null &&
            currentSession.status == SleepSessionStatus.awaitingFeedback &&
            !currentSession.sleepModeActive &&
            !currentSession.hasSubmittedFeedback) {
          context.push(
            AppRoutes.feedbackMorningLocation(sessionId: currentSession.id),
          );
          return;
        }
        onTap(date);
      },
      child: Ink(
        decoration: BoxDecoration(
          color: selected ? selectedFill : fill,
          borderRadius: AppRadius.surfaceSecondary,
          border: cellBorder,
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: appColors.accent.withAlpha(70),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: Stack(
          children: <Widget>[
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      '${date.day}',
                      style: AppTypography.meta(Theme.of(context).textTheme)
                          .copyWith(
                            color: selected
                                ? selectedForeground
                                : quality > 3
                                ? appColors.accentDeep
                                : appColors.textPrimary,
                          ),
                    ),
                    if (pending) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        '待',
                        style: AppTypography.chip(Theme.of(context).textTheme)
                            .copyWith(
                              color: selected
                                  ? selectedForeground
                                  : appColors.accentDeep,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (sleepGoalMet)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: selected
                        ? selectedForeground
                        : const Color(0xFF2D9272),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

bool? _sleepGoalMetForSession(SleepSession session, double sleepGoalHours) {
  return session.sleepGoalMet ?? session.deriveSleepGoalMet(sleepGoalHours);
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: appColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.chip(Theme.of(context).textTheme),
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.meta(
          Theme.of(context).textTheme,
        ).copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
