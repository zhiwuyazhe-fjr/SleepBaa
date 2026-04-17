import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/features/profile/presentation/widgets/profile_badge_support.dart';

class ProfileBadgesPage extends StatelessWidget {
  const ProfileBadgesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;

    return Scaffold(
      appBar: AppBar(title: const Text('勋章图鉴')),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: services.authRepository,
          builder: (BuildContext context, Widget? child) {
            final NightMoodPalette palette = context.nightMoodPalette;
            final UserProfile profile = services.authRepository.currentUser;
            final List<ProfileBadgeStatusData> badges =
                buildProfileBadgeCatalog(profile);
            final HonorBadge? activeBadge = honorBadgeById(
              profile.displayBadgeId,
            );
            final HonorBadge? latestEarnedBadge = honorBadgeById(
              profile.latestEarnedBadgeId,
            );
            final bool showingLatestEarned =
                activeBadge?.id == latestEarnedBadge?.id;
            final int unlockedCount = badges
                .where((ProfileBadgeStatusData badge) => badge.unlocked)
                .length;
            final String currentBadgeLabel = activeBadge?.label ?? '暂无勋章';
            final String currentBadgeDescription =
                activeBadge?.description ?? '完成睡眠打卡后，最新获得的勋章会自动成为当前展示。';

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                96,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AppCard(
                    key: const ValueKey<String>('profile-badge-summary-card'),
                    borderRadius: AppRadius.surfacePrimary,
                    color: palette.primaryHighlight,
                    border: Border.all(
                      color: palette.primarySoft.withAlpha(70),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        _BadgeVisual(badge: activeBadge, palette: palette),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '当前佩戴：$currentBadgeLabel',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                currentBadgeDescription,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: showingLatestEarned
                                      ? null
                                      : () async {
                                          await services.profileFacade
                                              .saveEquippedBadge(null);
                                        },
                                  style: TextButton.styleFrom(
                                    backgroundColor: showingLatestEarned
                                        ? palette.primary.withAlpha(40)
                                        : palette.primaryHighlight,
                                    foregroundColor: showingLatestEarned
                                        ? palette.primaryDeep.withAlpha(180)
                                        : palette.primaryDeep,
                                    disabledBackgroundColor: palette.primary
                                        .withAlpha(40),
                                    disabledForegroundColor: palette.primaryDeep
                                        .withAlpha(120),
                                    side: BorderSide(
                                      color: showingLatestEarned
                                          ? Colors.transparent
                                          : palette.primarySoft,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                      vertical: AppSpacing.sm,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: AppRadius.pill,
                                    ),
                                  ),
                                  child: Text(
                                    showingLatestEarned ? '已佩戴' : '佩戴最新获得',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: <Widget>[
                      Text(
                        '全部勋章',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$unlockedCount / ${kHonorBadgeCatalog.length}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  GridView.count(
                    crossAxisCount: 3,
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 0.88,
                    shrinkWrap: true,
                    primary: false,
                    physics: const NeverScrollableScrollPhysics(),
                    children: badges
                        .map(
                          (ProfileBadgeStatusData badge) =>
                              _ProfileBadgeGridTile(
                                badge: badge,
                                onTap: () => showProfileBadgeDetailsSheet(
                                  context,
                                  badge: badge.badge,
                                ),
                              ),
                        )
                        .toList(growable: false),
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

class _ProfileBadgeGridTile extends StatelessWidget {
  const _ProfileBadgeGridTile({required this.badge, required this.onTap});

  final ProfileBadgeStatusData badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;

    return Tooltip(
      message: badge.badge.description,
      child: AppCard(
        key: ValueKey<String>('profile-badge-grid-${badge.badge.id}'),
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
        ),
        borderRadius: AppRadius.card,
        border: Border.all(
          color: badge.selected
              ? palette.primary
              : badge.unlocked
              ? palette.primarySoft
              : AppColors.divider,
          width: badge.selected ? 2 : 1,
        ),
        color: badge.unlocked
            ? badge.selected
                  ? palette.primary.withAlpha(24)
                  : palette.primaryHighlight
            : AppColors.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: badge.unlocked
                    ? badge.selected
                          ? palette.primary.withAlpha(28)
                          : palette.primary.withAlpha(18)
                    : AppColors.surface,
                border: Border.all(
                  color: badge.selected
                      ? palette.primary
                      : badge.unlocked
                      ? palette.primarySoft
                      : AppColors.divider,
                  width: badge.selected ? 2 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                badge.unlocked ? badge.badge.icon : Icons.lock_rounded,
                size: 26,
                color: badge.unlocked
                    ? palette.primary
                    : AppColors.textSecondary.withAlpha(110),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              badge.badge.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textPrimary.withAlpha(
                  badge.unlocked ? 255 : 120,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              badge.statusLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: badge.selected
                    ? palette.primary
                    : AppColors.textSecondary,
                fontWeight: badge.selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeVisual extends StatelessWidget {
  const _BadgeVisual({required this.badge, required this.palette});

  final HonorBadge? badge;
  final NightMoodPalette palette;

  @override
  Widget build(BuildContext context) {
    final bool hasBadge = badge != null;

    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasBadge ? palette.primaryHighlight : AppColors.surfaceSoft,
        border: Border.all(
          color: hasBadge ? palette.primarySoft : AppColors.surfaceBorder,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        hasBadge ? badge!.icon : Icons.emoji_events_outlined,
        size: 38,
        color: hasBadge ? palette.primaryDeep : AppColors.textHint,
      ),
    );
  }
}
