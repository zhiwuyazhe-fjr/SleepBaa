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
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_detail_page_header.dart';

class SleepReportPage extends StatelessWidget {
  const SleepReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return Scaffold(
      appBar: AppDetailPageAppBar(
        title: '睡眠报告',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[
            services.insightsRepository,
            services.sleepSessionRepository,
          ]),
          builder: (BuildContext context, Widget? child) {
            final NightMoodPalette palette = context.nightMoodPalette;
            final AppSemanticColors appColors = context.appColors;
            final TextTheme textTheme = Theme.of(context).textTheme;
            final SleepReport report = services.insightsFacade.currentReport;
            final List<SleepSession> recent = services.sleepFacade
                .recentSessions();

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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        report.title,
                        style: AppTypography.panelTitle(textTheme),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '生成时间 ${report.generatedAt.month}/${report.generatedAt.day} '
                        '${report.generatedAt.hour.toString().padLeft(2, '0')}:'
                        '${report.generatedAt.minute.toString().padLeft(2, '0')}',
                        style: AppTypography.chip(
                          textTheme,
                        ).copyWith(color: appColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: <Widget>[
                          _MetricChip(
                            label: '平均睡眠',
                            value:
                                '${report.averageSleepHours.toStringAsFixed(1)}h',
                            color: palette.primary,
                          ),
                          _MetricChip(
                            label: '睡眠质量',
                            value: report.averageSleepQuality.toStringAsFixed(
                              1,
                            ),
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
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  borderRadius: AppRadius.surfacePrimary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('本轮观察亮点', style: AppTypography.cardTitle(textTheme)),
                      const SizedBox(height: AppSpacing.md),
                      if (report.highlights.isEmpty)
                        Text(
                          '继续记录更多夜晚后，这里会总结你的睡眠节律、梦境趋势和晨间恢复状态。',
                          style: AppTypography.bodyMuted(
                            textTheme,
                          ).copyWith(height: 1.5),
                        )
                      else
                        ...report.highlights.map(
                          (String item) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  '•',
                                  style: AppTypography.body(
                                    textTheme,
                                  ).copyWith(color: palette.primary),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: AppTypography.bodyMuted(
                                      textTheme,
                                    ).copyWith(height: 1.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  borderRadius: AppRadius.surfacePrimary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('最近记录', style: AppTypography.cardTitle(textTheme)),
                      const SizedBox(height: AppSpacing.md),
                      if (recent.isEmpty)
                        Text(
                          '还没有新的睡眠记录。',
                          style: AppTypography.bodyMuted(textTheme),
                        )
                      else
                        ...recent
                            .take(7)
                            .map(
                              (SleepSession session) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
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
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label  $value',
        style: AppTypography.chip(
          Theme.of(context).textTheme,
        ).copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _RecentSessionTile extends StatelessWidget {
  const _RecentSessionTile({required this.session});

  final SleepSession session;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final bool pending = !session.hasSubmittedFeedback;
    final bool canOpenFeedback =
        pending &&
        session.status == SleepSessionStatus.awaitingFeedback &&
        !session.sleepModeActive;
    final String subtitle = pending
        ? '已记录 ${session.displaySleepHours().toStringAsFixed(1)}h · ${_pendingStateLabel(session)}'
        : '睡眠 ${session.displaySleepHours().toStringAsFixed(1)}h · '
              '质量 ${session.summary!.sleepQuality}';
    final Color badgeColor = pending
        ? const Color(0xFFF39A3C)
        : const Color(0xFF2D9272);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canOpenFeedback
          ? () {
              context.push(
                AppRoutes.feedbackMorningLocation(sessionId: session.id),
              );
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: appColors.surfaceMuted,
          borderRadius: AppRadius.compactCard,
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.nightlight_round, color: appColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${session.sleepDayDate.month}/${session.sleepDayDate.day}',
                    style: AppTypography.cardTitle(Theme.of(context).textTheme),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.bodyMuted(
                      Theme.of(context).textTheme,
                    ).copyWith(color: appColors.textSecondary),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: badgeColor.withAlpha(18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                pending ? '待补全' : '已完成',
                style: AppTypography.chip(
                  Theme.of(context).textTheme,
                ).copyWith(color: badgeColor, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
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
