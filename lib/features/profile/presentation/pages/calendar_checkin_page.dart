import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/utils/formatters.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';

class CalendarCheckinPage extends StatefulWidget {
  const CalendarCheckinPage({super.key});

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
    _selectedDay = DateUtils.dateOnly(now.subtract(const Duration(days: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    final NightMoodPalette palette = context.nightMoodPalette;
    return Scaffold(
      appBar: AppBar(title: const Text('睡眠打卡日历')),
      body: ListenableBuilder(
        listenable: services.sleepSessionRepository,
        builder: (BuildContext context, Widget? child) {
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
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: <Widget>[
              AppCard(
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
                            style: Theme.of(context).textTheme.headlineSmall,
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
                      palette: palette,
                      onSelectDay: (DateTime day) {
                        setState(() => _selectedDay = day);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                color: AppColors.surfaceMuted,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('连续记录', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${_buildStreak(services.sleepSessionRepository.sessions)} 天连续打卡',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: palette.primary),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        _DetailChip(label: '本月记录 ${monthSessions.length} 天'),
                        _DetailChip(label: '待补全 $pendingCount 天'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '同一睡眠日多次退出或再次进入都会累计到同一天，晨间反馈完成后该日时长会锁定。',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppCard(child: _SelectedSessionDetail(session: selectedSession)),
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
  const _SelectedSessionDetail({required this.session});

  final SleepSession? session;

  @override
  Widget build(BuildContext context) {
    if (session == null) {
      return const Text('这一天还没有睡眠记录。');
    }

    final MorningSummary? summary = session!.summary;
    final bool canSupplementFeedback =
        session!.status == SleepSessionStatus.awaitingFeedback &&
        !session!.sleepModeActive &&
        !session!.hasSubmittedFeedback;
    final String stageLabel = _sessionStageLabel(session!);
    final Color stageColor = _sessionStageColor(session!);
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
                style: Theme.of(context).textTheme.titleLarge,
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
            _DetailChip(label: '夜醒 ${session!.awakenings.length} 次'),
            _DetailChip(
              label: '建议 ${session!.selectedRecommendationIds.length} 项',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('当晚摘要', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          summary?.note ?? _summaryFallback(session!),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        if (canSupplementFeedback) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: '补充晨间反馈',
            onPressed: () {
              context.push(
                AppRoutes.feedbackMorningLocation(sessionId: session!.id),
              );
            },
          ),
        ],
        if (summary != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
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
      SleepSessionStatus.awaitingFeedback => '待补全',
      SleepSessionStatus.completed => '已完成',
      SleepSessionStatus.drafted => '草稿',
    };
  }

  Color _sessionStageColor(SleepSession session) {
    if (session.summary != null ||
        session.status == SleepSessionStatus.completed) {
      return const Color(0xFF2D9272);
    }
    return switch (session.status) {
      SleepSessionStatus.active => const Color(0xFF4458D8),
      SleepSessionStatus.paused => const Color(0xFF8B7CF6),
      SleepSessionStatus.awaitingFeedback => const Color(0xFFF39A3C),
      SleepSessionStatus.completed => const Color(0xFF2D9272),
      SleepSessionStatus.drafted => AppColors.textSecondary,
    };
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
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
    required this.palette,
    required this.onSelectDay,
  });

  final DateTime month;
  final Map<DateTime, SleepSession> sessionMap;
  final DateTime? selectedDay;
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
          palette: palette,
          onTap: onSelectDay,
        ),
    ];

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.xs,
      crossAxisSpacing: AppSpacing.xs,
      children: cells,
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.session,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final DateTime date;
  final SleepSession? session;
  final bool selected;
  final NightMoodPalette palette;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final int quality = session?.summary?.sleepQuality ?? 0;
    final bool pending = session != null && session!.summary == null;
    final Color fill = switch (quality) {
      5 => palette.primary,
      4 => palette.primarySoft,
      3 => palette.primarySoft.withAlpha(150),
      2 => palette.primarySoft.withAlpha(90),
      1 => palette.primarySoft.withAlpha(50),
      _ => pending ? palette.primarySoft.withAlpha(72) : AppColors.surfaceSoft,
    };
    return InkWell(
      borderRadius: BorderRadius.circular(14),
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
          color: selected ? AppColors.darkSurface : fill,
          borderRadius: BorderRadius.circular(14),
          border: pending
              ? Border.all(
                  color: palette.primary.withAlpha(selected ? 255 : 180),
                )
              : null,
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  '${date.day}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected
                        ? AppColors.onDark
                        : quality > 3
                        ? palette.primaryDeep
                        : AppColors.textPrimary,
                  ),
                ),
                if (pending) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    '待',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected ? AppColors.onDark : palette.primaryDeep,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
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
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
