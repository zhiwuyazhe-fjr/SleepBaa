import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/home_metric_card.dart';
import 'package:sleep_dorm_app/core/widgets/section_title.dart';
import 'package:sleep_dorm_app/mock/mock_data.dart';

class InterferenceFactorPage extends StatelessWidget {
  const InterferenceFactorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    final PlaceholderPageMeta meta =
        MockData.placeholderPages[AppRoutes.analysisInterferenceFactors]!;
    final NightMoodPalette palette = context.nightMoodPalette;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(meta.title)),
      body: ListenableBuilder(
        listenable: services.dormRepository,
        builder: (BuildContext context, Widget? child) {
          final Dorm dorm = services.dormRepository.currentDorm;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              96,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionTitle(
                  title: '今晚影响因素',
                  titleStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: HomeMetricCard(
                        icon: Icons.volume_up_outlined,
                        label: '宿舍噪声',
                        value: '${dorm.noiseDb} dB',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: HomeMetricCard(
                        icon: Icons.lightbulb_outline_rounded,
                        label: '灯光环境',
                        value: dorm.lightLabel,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const Row(
                  children: <Widget>[
                    Expanded(
                      child: HomeMetricCard(
                        icon: Icons.smartphone_rounded,
                        label: '手机使用',
                        value: '45 分钟',
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: HomeMetricCard(
                        icon: Icons.favorite_border_rounded,
                        label: '情绪压力',
                        value: '低强度',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '今晚分析摘要',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        meta.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF888888),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  color: const Color(0xFFF2F2F2),
                  borderRadius: BorderRadius.circular(20),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '本页将逐步补全',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final String point in meta.supportingPoints) ...<Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Icon(
                                Icons.brightness_1_rounded,
                                size: 8,
                                color: palette.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                point,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w400,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2C8E78),
                      foregroundColor: AppColors.onDark,
                      shape: const StadiumBorder(),
                      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    icon: const Icon(Icons.insights_rounded, size: 18),
                    label: Text(meta.primaryActionLabel),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
