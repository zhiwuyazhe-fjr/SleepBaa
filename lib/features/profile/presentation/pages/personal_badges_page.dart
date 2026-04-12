import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';

class PersonalBadgesPage extends StatelessWidget {
  const PersonalBadgesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return Scaffold(
      appBar: AppBar(title: const Text('专属荣誉勋章')),
      body: ListenableBuilder(
        listenable: services.authRepository,
        builder: (BuildContext context, Widget? child) {
          final UserProfile profile = services.authRepository.currentUser;
          final HonorBadge? activeBadge = honorBadgeById(
            profile.displayBadgeId,
          );
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: <Widget>[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '当前展示',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      activeBadge == null
                          ? '当前默认展示最新获得的勋章'
                          : '当前展示：${activeBadge.label}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
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
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.md,
                children: kHonorBadgeCatalog
                    .map((HonorBadge badge) {
                      final bool unlocked = profile.hasEarnedBadge(badge.id);
                      final bool selected = profile.displayBadgeId == badge.id;
                      return SizedBox(
                        width: 108,
                        child: _PersonalBadgeTile(
                          badge: badge,
                          unlocked: unlocked,
                          selected: selected,
                          onTap: !unlocked
                              ? null
                              : () async {
                                  await services.profileFacade
                                      .saveEquippedBadge(
                                        selected ? null : badge.id,
                                      );
                                },
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PersonalBadgeTile extends StatelessWidget {
  const _PersonalBadgeTile({
    required this.badge,
    required this.unlocked,
    required this.selected,
    this.onTap,
  });

  final HonorBadge badge;
  final bool unlocked;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    return Tooltip(
      message: badge.description,
      child: InkWell(
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
                  color: unlocked
                      ? palette.primary.withAlpha(selected ? 28 : 18)
                      : AppColors.surfaceSoft,
                  border: Border.all(
                    color: selected
                        ? palette.primary
                        : unlocked
                        ? palette.primarySoft
                        : AppColors.divider,
                    width: selected ? 2.5 : 1.5,
                  ),
                ),
                child: Icon(
                  unlocked ? badge.icon : Icons.lock_rounded,
                  color: unlocked
                      ? palette.primary
                      : AppColors.textSecondary.withAlpha(110),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                badge.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textPrimary.withAlpha(unlocked ? 255 : 120),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                selected
                    ? '当前佩戴'
                    : unlocked
                    ? '点击佩戴'
                    : '未获得',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? palette.primary : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
