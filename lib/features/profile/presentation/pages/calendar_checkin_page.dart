import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/utils/formatters.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';

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
                  DateUtils.dateOnly(session.startedAt): session,
              };
          final SleepSession? selectedSession = _selectedDay == null
              ? null
              : sessionMap[_selectedDay];

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
                      '${_buildStreak(services.sleepSessionRepository.sessions)} 天稳定入睡',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: AppColors.primary),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('选中某一天即可查看当天的入睡、夜醒和执行建议摘要。'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                child: selectedSession == null
                    ? const Text('这一天还没有睡眠记录。')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            Formatters.formatDateLabel(
                              selectedSession.startedAt,
                            ),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: <Widget>[
                              _DetailChip(
                                label:
                                    '总时长 ${selectedSession.summary?.totalSleepHours.toStringAsFixed(1) ?? '--'} h',
                              ),
                              _DetailChip(
                                label:
                                    '夜醒 ${selectedSession.awakenings.length} 次',
                              ),
                              _DetailChip(
                                label:
                                    '建议 ${selectedSession.selectedRecommendationIds.length} 项',
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            '当天摘要',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            selectedSession.summary?.note ?? '这一天还没有主观反馈。',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  int _buildStreak(List<SleepSession> sessions) {
    final List<SleepSession> ordered = List<SleepSession>.from(sessions)
      ..sort(
        (SleepSession a, SleepSession b) => b.startedAt.compareTo(a.startedAt),
      );
    int streak = 0;
    DateTime cursor = DateUtils.dateOnly(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    for (final SleepSession session in ordered) {
      final DateTime day = DateUtils.dateOnly(session.startedAt);
      if (day == cursor) {
        streak += 1;
        cursor = cursor.subtract(const Duration(days: 1));
      }
    }
    return streak;
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
    required this.onSelectDay,
  });

  final DateTime month;
  final Map<DateTime, SleepSession> sessionMap;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final int daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final int leadingEmpty = DateTime(month.year, month.month, 1).weekday - 1;
    final List<Widget> cells = <Widget>[
      for (int i = 0; i < leadingEmpty; i++) const SizedBox.shrink(),
      for (int day = 1; day <= daysInMonth; day++)
        _DayCell(
          date: DateTime(month.year, month.month, day),
          session: sessionMap[DateTime(month.year, month.month, day)],
          selected: selectedDay == DateTime(month.year, month.month, day),
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
    required this.onTap,
  });

  final DateTime date;
  final SleepSession? session;
  final bool selected;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final int quality = session?.summary?.sleepQuality ?? 0;
    final Color fill = switch (quality) {
      5 => AppColors.primary,
      4 => AppColors.primarySoft,
      3 => AppColors.primarySoft.withAlpha(150),
      2 => AppColors.primarySoft.withAlpha(90),
      1 => AppColors.primarySoft.withAlpha(50),
      _ => AppColors.surfaceSoft,
    };
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onTap(date),
      child: Ink(
        decoration: BoxDecoration(
          color: selected ? AppColors.darkSurface : fill,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            '${date.day}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected
                  ? AppColors.onDark
                  : quality > 3
                  ? AppColors.primaryDeep
                  : AppColors.textPrimary,
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
