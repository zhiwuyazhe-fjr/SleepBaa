import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/home_metric_card.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';
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
      appBar: AppBar(title: Text(meta.title)),
      body: ListenableBuilder(
        listenable: services.dormRepository,
        builder: (BuildContext context, Widget? child) {
          final Dorm dorm = services.dormRepository.currentDorm;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              120,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionTitle(
                  title: '今晚影响因素',
                  titleStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
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
                const SizedBox(height: AppSpacing.md),
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
                const SizedBox(height: AppSpacing.xl),
                AppCard(
                  color: AppColors.surface,
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
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  color: const Color(0xFFF7F8FA),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '本页将逐步补全',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
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
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: meta.primaryActionLabel,
                  icon: Icons.insights_rounded,
                  onPressed: () {},
                  variant: PrimaryButtonVariant.soft,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
