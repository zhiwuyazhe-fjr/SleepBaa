import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/features/profile/data/profile_badges.dart';

class ProfileBadgeDetailPage extends StatelessWidget {
  const ProfileBadgeDetailPage({super.key, required this.badgeId});

  final String badgeId;

  @override
  Widget build(BuildContext context) {
    final ProfileBadgeMeta? badge = ProfileBadges.byId(badgeId);

    return Scaffold(
      appBar: AppBar(title: const Text('勋章详情')),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: badge == null
              ? const Center(child: Text('未找到勋章'))
              : _BadgeDetailContent(badge: badge),
        ),
      ),
    );
  }
}

class _BadgeDetailContent extends StatelessWidget {
  const _BadgeDetailContent({required this.badge});

  final ProfileBadgeMeta badge;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppCard(
          borderRadius: AppRadius.cardLarge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: badge.unlocked
                      ? palette.primaryHighlight
                      : AppColors.surfaceSoft,
                  border: Border.all(
                    color: badge.unlocked
                        ? palette.primarySoft
                        : AppColors.surfaceBorder,
                    width: 2,
                  ),
                ),
                child: Icon(
                  badge.icon,
                  size: 36,
                  color: badge.unlocked
                      ? palette.primaryDeep
                      : AppColors.textHint,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                badge.title,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: badge.unlocked
                      ? palette.primaryHighlight
                      : AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Text(
                  badge.unlocked ? '已解锁' : '待解锁',
                  style: textTheme.labelLarge?.copyWith(
                    color: badge.unlocked
                        ? palette.primaryDeep
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                badge.description,
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
