import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';

class DormInvitePage extends StatelessWidget {
  const DormInvitePage({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final NightMoodPalette palette = context.nightMoodPalette;
    return Scaffold(
      appBar: AppBar(title: const Text('Invite Dormmate')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('宿舍邀请码', style: textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'DORM-SLEEP-204',
                      style: textTheme.displayMedium?.copyWith(
                        color: palette.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '后续可以支持二维码、链接分享和短信邀请。当前先保留一个清晰的占位流程。',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
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
                    Text('接下来会完善', style: textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.md),
                    const Text('1. 一键复制邀请码'),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('2. 生成二维码与短链接'),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('3. 邀请成功后的宿舍初始化流程'),
                  ],
                ),
              ),
              const Spacer(),
              const PrimaryButton(
                label: '复制邀请码',
                icon: Icons.copy_rounded,
                onPressed: null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
