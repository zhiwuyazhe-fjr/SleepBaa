import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/widgets/app_strip_card.dart';
import 'package:sleep_dorm_app/features/profile/data/profile_badges.dart';

class ProfileBadgesPage extends StatelessWidget {
  const ProfileBadgesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('勋章图鉴')),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.xl),
          itemCount: ProfileBadges.all.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (BuildContext context, int index) {
            final ProfileBadgeMeta badge = ProfileBadges.all[index];
            final bool unlocked = badge.unlocked;
            return AppStripCard(
              key: ValueKey<String>('profile-badge-strip-card-$index'),
              onTap: () =>
                  context.push(AppRoutes.profileBadgeDetailPath(badge.id)),
              backgroundColor: unlocked
                  ? palette.primaryHighlight.withAlpha(110)
                  : AppColors.surface,
              borderColor: unlocked
                  ? palette.primarySoft
                  : AppColors.surfaceBorder,
              boxShadow: const <BoxShadow>[],
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: unlocked
                      ? Colors.white.withAlpha(208)
                      : AppColors.surfaceSoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  badge.icon,
                  size: 20,
                  color: unlocked ? palette.primaryDeep : AppColors.textHint,
                ),
              ),
              title: badge.title,
              subtitle: badge.summary,
              titleStyle: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: unlocked
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
              subtitleStyle: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            );
          },
        ),
      ),
    );
  }
}
