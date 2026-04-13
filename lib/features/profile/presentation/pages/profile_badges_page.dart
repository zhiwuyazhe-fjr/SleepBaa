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
            final HonorBadge? activeBadge = honorBadgeById(profile.displayBadgeId);
            final int unlockedCount = badges
                .where((ProfileBadgeStatusData badge) => badge.unlocked)
                .length;
            final String currentBadgeLabel = activeBadge == null
                ? '当前默认展示最新获得的勋章'
                : profile.equippedBadgeId == null
                ? '当前展示：${activeBadge.label}'
                : '当前佩戴：${activeBadge.label}';

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
                    border: Border.all(color: palette.primarySoft.withAlpha(70)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              '当前展示',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            Text(
                              '$unlockedCount / ${kHonorBadgeCatalog.length}',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          currentBadgeLabel,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '点击任意勋章可查看说明，并把已获得勋章切换为当前展示。',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textHint,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextButton(
                          onPressed: profile.equippedBadgeId == null
                              ? null
                              : () async {
                                  await services.profileFacade.saveEquippedBadge(
                                    null,
                                  );
                                },
                          child: const Text('恢复最新获得'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    '全部勋章',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '已获得的勋章会高亮显示，未解锁的勋章也可以先查看说明。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.md,
                    children: badges
                        .map(
                          (ProfileBadgeStatusData badge) => SizedBox(
                            width: 104,
                            child: _ProfileBadgeGridTile(
                              badge: badge,
                              onTap: () => showProfileBadgeDetailsSheet(
                                context,
                                badge: badge.badge,
                              ),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey<String>('profile-badge-grid-${badge.badge.id}'),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Column(
              children: <Widget>[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: badge.unlocked
                        ? badge.selected
                            ? palette.primary.withAlpha(28)
                            : palette.primary.withAlpha(18)
                        : AppColors.surfaceSoft,
                    border: Border.all(
                      color: badge.selected
                          ? palette.primary
                          : badge.unlocked
                          ? palette.primarySoft
                          : AppColors.divider,
                      width: badge.selected ? 2.5 : 1.5,
                    ),
                  ),
                  child: Icon(
                    badge.unlocked ? badge.badge.icon : Icons.lock_rounded,
                    color: badge.unlocked
                        ? palette.primary
                        : AppColors.textSecondary.withAlpha(110),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  badge.badge.label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textPrimary.withAlpha(
                      badge.unlocked ? 255 : 120,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  badge.statusLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: badge.selected
                        ? palette.primary
                        : AppColors.textSecondary,
                    fontWeight: badge.selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
