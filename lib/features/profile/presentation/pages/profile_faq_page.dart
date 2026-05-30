import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/app_typography.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_detail_page_header.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';

class ProfileFaqPage extends StatelessWidget {
  const ProfileFaqPage({super.key});

  Future<void> _showComingSoon(BuildContext context) {
    return notifyPassiveToast(context, message: 'FAQ 正在整理中');
  }

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: appColors.pageBackground,
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
            Text(
              '帮助主题',
              style: AppTypography.sectionTitle(
                textTheme,
              ).copyWith(color: appColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Row(
              children: <Widget>[
                Expanded(
                  child: _FaqTopicCard(
                    icon: Icons.person_outline_rounded,
                    label: '账号资料',
                    value: '头像与昵称',
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _FaqTopicCard(
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
                  child: _FaqTopicCard(
                    icon: Icons.menu_book_rounded,
                    label: '夜间记录',
                    value: '梦记与仓库',
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _FaqTopicCard(
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
              color: appColors.surface,
              border: Border.all(color: appColors.borderSubtle),
              borderRadius: AppRadius.surfacePrimary,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '常见问题速览',
                    style: AppTypography.panelTitle(
                      textTheme,
                    ).copyWith(color: appColors.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '这里会整理头像设置、睡眠报告查看、打卡热力说明，以及梦记与事记仓库的使用方式。',
                    style: AppTypography.body(
                      textTheme,
                    ).copyWith(color: appColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              color: appColors.surfaceMuted,
              border: Border.all(color: appColors.borderSubtle),
              borderRadius: AppRadius.surfacePrimary,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '本页将逐步补全',
                    style: AppTypography.cardTitle(
                      textTheme,
                    ).copyWith(color: appColors.textPrimary),
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
                            color: appColors.accentDeep,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            point,
                            style: AppTypography.bodyMuted(
                              textTheme,
                            ).copyWith(color: appColors.textSecondary),
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
            PrimaryButton(
              label: '常见问题内容将继续补充',
              icon: Icons.help_outline_rounded,
              onPressed: () => _showComingSoon(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqTopicCard extends StatelessWidget {
  const _FaqTopicCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return AppCard(
      color: appColors.surface,
      border: Border.all(color: appColors.borderSubtle),
      borderRadius: AppRadius.compactCard,
      padding: const EdgeInsets.all(AppSpacing.sm),
      boxShadow: const <BoxShadow>[],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: appColors.accentSoft,
              borderRadius: AppRadius.control,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: appColors.accentDeep, size: 18),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.cardTitle(
              textTheme,
            ).copyWith(color: appColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.chip(
              textTheme,
            ).copyWith(color: appColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
