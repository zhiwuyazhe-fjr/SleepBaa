import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/app_typography.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_detail_page_header.dart';

class ThoughtVaultPage extends StatelessWidget {
  const ThoughtVaultPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    final NightMoodPalette palette = context.nightMoodPalette;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppDetailPageAppBar(
        title: '事记仓库',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: ListenableBuilder(
        listenable: services.sleepCaptureRepository,
        builder: (BuildContext context, Widget? child) {
          final List<SleepCaptureRecord> records = services
              .sleepCaptureRepository
              .recordsByType(SleepCaptureType.memo);
          if (records.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  '睡眠模式里记下的事，会在这里慢慢收成卡片。',
                  style: AppTypography.body(
                    textTheme,
                  ).copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              120,
            ),
            itemBuilder: (BuildContext context, int index) {
              final SleepCaptureRecord record = records[index];
              return AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                borderRadius: AppRadius.compactCard,
                onTap: () =>
                    context.push(AppRoutes.profileThoughtDetail, extra: record),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: palette.primaryHighlight,
                            borderRadius: AppRadius.pill,
                          ),
                          child: Text(
                            _formatRecordTime(record.createdAt),
                            style: AppTypography.chip(
                              textTheme,
                            ).copyWith(color: palette.primaryDeep),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.east_rounded,
                          color: palette.primaryDeep.withAlpha(150),
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      record.title,
                      style: AppTypography.cardTitle(textTheme),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      record.outline,
                      style: AppTypography.bodyMuted(
                        textTheme,
                      ).copyWith(color: AppColors.textSecondary, height: 1.5),
                    ),
                  ],
                ),
              );
            },
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(height: AppSpacing.md),
            itemCount: records.length,
          );
        },
      ),
    );
  }

  String _formatRecordTime(DateTime dateTime) {
    final String month = dateTime.month.toString().padLeft(2, '0');
    final String day = dateTime.day.toString().padLeft(2, '0');
    final String hour = dateTime.hour.toString().padLeft(2, '0');
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }
}
