import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';

class SleepReportPage extends StatelessWidget {
  const SleepReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return Scaffold(
      appBar: AppBar(title: const Text('睡眠报告')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[
            services.insightsRepository,
            services.sleepSessionRepository,
          ]),
          builder: (BuildContext context, Widget? child) {
            final NightMoodPalette palette = context.nightMoodPalette;
            final SleepReport report = services.insightsFacade.currentReport;
            final List<SleepSession> recent = services.sleepFacade.recentSessions();

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: <Widget>[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        report.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '生成时间 ${report.generatedAt.month}/${report.generatedAt.day} '
                        '${report.generatedAt.hour.toString().padLeft(2, '0')}:'
                        '${report.generatedAt.minute.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: <Widget>[
                          _MetricChip(
                            label: '平均睡眠',
                            value: '${report.averageSleepHours.toStringAsFixed(1)}h',
                            color: palette.primary,
                          ),
                          _MetricChip(
                            label: '睡眠质量',
                            value: report.averageSleepQuality.toStringAsFixed(1),
                            color: const Color(0xFF4458D8),
                          ),
                          _MetricChip(
                            label: '恢复感',
                            value: report.averageRestedLevel.toStringAsFixed(1),
                            color: const Color(0xFF2D9272),
                          ),
                          _MetricChip(
                            label: '安静夜晚',
                            value: '${report.calmNights} 晚',
                            color: const Color(0xFFF39A3C),
                          ),
                          _MetricChip(
                            label: '梦境记录',
                            value: '${report.dreamEntriesCount} 条',
                            color: const Color(0xFF8F63D6),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '本轮观察亮点',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (report.highlights.isEmpty)
                        Text(
                          '继续记录更多夜晚后，这里会总结你的睡眠节律、梦境趋势和晨间恢复状态。',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                          ),
                        )
                      else
                        ...report.highlights.map(
                          (String item) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  '•',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(color: palette.primary),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(height: 1.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '最近记录',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (recent.isEmpty)
                        Text(
                          '还没有新的睡眠记录。',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      else
                        ...recent.take(7).map(
                          (SleepSession session) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _RecentSessionTile(session: session),
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
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
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
        '$label  $value',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RecentSessionTile extends StatelessWidget {
  const _RecentSessionTile({required this.session});

  final SleepSession session;

  @override
  Widget build(BuildContext context) {
    final bool pending = !session.hasSubmittedFeedback;
    final String subtitle = pending
        ? '已记录 ${session.displaySleepHours().toStringAsFixed(1)}h · ${_pendingStateLabel(session)}'
        : '睡眠 ${session.displaySleepHours().toStringAsFixed(1)}h · '
            '质量 ${session.summary!.sleepQuality}';
    final Color badgeColor = pending
        ? const Color(0xFFF39A3C)
        : const Color(0xFF2D9272);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.nightlight_round, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${session.sleepDayDate.month}/${session.sleepDayDate.day}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: badgeColor.withAlpha(18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              pending ? '待补全' : '已完成',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: badgeColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _pendingStateLabel(SleepSession session) {
    switch (session.status) {
      case SleepSessionStatus.drafted:
        return '待开始';
      case SleepSessionStatus.active:
        return '记录中';
      case SleepSessionStatus.paused:
        return '已退出，可继续累计';
      case SleepSessionStatus.awaitingFeedback:
        return '待晨间反馈';
      case SleepSessionStatus.completed:
        return '已完成反馈';
    }
  }
}
