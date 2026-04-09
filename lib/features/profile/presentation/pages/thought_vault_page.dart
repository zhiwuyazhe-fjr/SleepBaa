import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';

class ThoughtVaultPage extends StatelessWidget {
  const ThoughtVaultPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('事记仓库')),
      body: ListenableBuilder(
        listenable: services.sleepCaptureRepository,
        builder: (BuildContext context, Widget? child) {
          final List<SleepCaptureRecord> records = services.sleepCaptureRepository
              .recordsByType(SleepCaptureType.memo);
          if (records.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  '睡眠模式里记下的事，会在这里慢慢收成卡片。',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
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
                borderRadius: AppRadius.cardLarge,
                onTap: () => context.push(
                  AppRoutes.profileThoughtDetail,
                  extra: record,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryHighlight,
                            borderRadius: AppRadius.pill,
                          ),
                          child: Text(
                            _formatRecordTime(record.createdAt),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: AppColors.primaryDeep),
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.east_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      record.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      record.outline,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
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
