import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_detail_page_header.dart';
import 'package:sleep_dorm_app/core/widgets/home_metric_card.dart';
import 'package:sleep_dorm_app/core/widgets/section_title.dart';

class ProfileFaqPage extends StatelessWidget {
  const ProfileFaqPage({super.key});

  Future<void> _showComingSoon(BuildContext context) {
    return notifyPassiveToast(context, message: 'FAQ 正在整理中');
  }

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppDetailPageAppBar(
        title: '常见问题',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SingleChildScrollView(
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
              title: '帮助主题',
              titleStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Row(
              children: <Widget>[
                Expanded(
                  child: HomeMetricCard(
                    icon: Icons.person_outline_rounded,
                    label: '账号资料',
                    value: '头像与昵称',
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: HomeMetricCard(
                    icon: Icons.bedtime_outlined,
                    label: '睡眠记录',
                    value: '报告与打卡',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Row(
              children: <Widget>[
                Expanded(
                  child: HomeMetricCard(
                    icon: Icons.menu_book_rounded,
                    label: '夜间记录',
                    value: '梦记与仓库',
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: HomeMetricCard(
                    icon: Icons.help_center_outlined,
                    label: '使用支持',
                    value: '常见处理',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              onTap: () => _showComingSoon(context),
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '常见问题速览',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '这里会整理头像设置、睡眠报告查看、打卡热力说明，以及梦记与事记仓库的使用方式。',
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
              color: AppColors.legacyCardSurface,
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
                  for (final String point in const <String>[
                    '如何修改头像、昵称与个人标签',
                    '睡眠质量、睡眠时长和热力图分别代表什么',
                    '梦记、事记仓库与勋章页的常见使用问题',
                  ]) ...<Widget>[
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
                onPressed: () => _showComingSoon(context),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.welcomeAccentColor,
                  foregroundColor: palette.welcomeTextOnAccent,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: const StadiumBorder(),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                icon: const Icon(Icons.help_outline_rounded, size: 18),
                label: const Text('常见问题内容将继续补充'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
