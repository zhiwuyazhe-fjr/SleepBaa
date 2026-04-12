import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
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
            return AppCard(
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              color: unlocked
                  ? palette.primaryHighlight.withAlpha(110)
                  : AppColors.surface,
              border: Border.all(
                color: unlocked ? palette.primarySoft : AppColors.surfaceBorder,
              ),
              boxShadow: const <BoxShadow>[],
              onTap: () =>
                  context.push(AppRoutes.profileBadgeDetailPath(badge.id)),
              child: Row(
                children: <Widget>[
                  Container(
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
                      color: unlocked
                          ? palette.primaryDeep
                          : AppColors.textHint,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          badge.title,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: unlocked
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          badge.summary,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textHint,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
