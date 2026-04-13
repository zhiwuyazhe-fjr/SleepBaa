import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class ProfileBadgeStatusData {
  const ProfileBadgeStatusData({
    required this.badge,
    required this.unlocked,
    required this.selected,
    required this.explicitlyEquipped,
  });

  final HonorBadge badge;
  final bool unlocked;
  final bool selected;
  final bool explicitlyEquipped;

  String get statusLabel {
    if (!unlocked) {
      return '未获得';
    }
    if (explicitlyEquipped) {
      return '当前佩戴';
    }
    if (selected) {
      return '当前展示';
    }
    return '点击佩戴';
  }
}

List<ProfileBadgeStatusData> buildProfileBadgeCatalog(UserProfile profile) {
  final String? displayBadgeId = profile.displayBadgeId;
  final String? equippedBadgeId = profile.equippedBadgeId?.trim();

  return kHonorBadgeCatalog
      .map(
        (HonorBadge badge) => ProfileBadgeStatusData(
          badge: badge,
          unlocked: profile.hasEarnedBadge(badge.id),
          selected: displayBadgeId == badge.id,
          explicitlyEquipped: equippedBadgeId == badge.id,
        ),
      )
      .toList(growable: false);
}

List<ProfileBadgeStatusData> buildProfileBadgePreview(
  UserProfile profile, {
  int maxItems = 4,
}) {
  final List<ProfileBadgeStatusData> catalog = buildProfileBadgeCatalog(profile);
  final Map<String, ProfileBadgeStatusData> byId =
      <String, ProfileBadgeStatusData>{
        for (final ProfileBadgeStatusData item in catalog) item.badge.id: item,
      };
  final Set<String> addedIds = <String>{};
  final List<ProfileBadgeStatusData> preview = <ProfileBadgeStatusData>[];

  void addById(String? badgeId) {
    if (badgeId == null || preview.length >= maxItems || !addedIds.add(badgeId)) {
      return;
    }
    final ProfileBadgeStatusData? item = byId[badgeId];
    if (item != null) {
      preview.add(item);
    }
  }

  addById(profile.displayBadgeId);
  for (final String badgeId in profile.earnedBadgeIds) {
    addById(badgeId);
  }
  for (final ProfileBadgeStatusData item in catalog.where(
    (ProfileBadgeStatusData item) => !item.unlocked,
  )) {
    addById(item.badge.id);
  }
  for (final ProfileBadgeStatusData item in catalog) {
    addById(item.badge.id);
  }

  return preview.take(maxItems).toList(growable: false);
}

Future<void> showProfileBadgeDetailsSheet(
  BuildContext context, {
  required HonorBadge badge,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) {
      final AppServices services = sheetContext.appServices;
      final UserProfile profile = services.authRepository.currentUser;
      final bool unlocked = profile.hasEarnedBadge(badge.id);
      final bool selected = profile.displayBadgeId == badge.id;
      final bool explicitlyEquipped = profile.equippedBadgeId == badge.id;
      final NightMoodPalette palette = sheetContext.nightMoodPalette;
      final String statusLabel = !unlocked
          ? '未获得'
          : explicitlyEquipped
          ? '当前佩戴'
          : selected
          ? '当前展示'
          : '已获得';

      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.md,
          ),
          child: Container(
            key: ValueKey<String>('profile-badge-sheet-${badge.id}'),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.sheetTop,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBorder,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: unlocked
                            ? palette.primaryHighlight
                            : AppColors.surfaceSoft,
                        border: Border.all(
                          color: unlocked
                              ? palette.primarySoft
                              : AppColors.surfaceBorder,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        unlocked ? badge.icon : Icons.lock_rounded,
                        size: 30,
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
                            badge.label,
                            style: Theme.of(sheetContext).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: unlocked
                                  ? palette.primaryHighlight
                                  : AppColors.surfaceSoft,
                              borderRadius: AppRadius.pill,
                            ),
                            child: Text(
                              statusLabel,
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: unlocked
                                        ? palette.primaryDeep
                                        : AppColors.textSecondary,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  badge.description,
                  style: Theme.of(sheetContext).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  unlocked
                      ? '已获得后可以在图鉴里切换当前展示的个人勋章。'
                      : '继续完成睡眠记录与宿舍协作后，就能解锁并展示这枚勋章。',
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textHint,
                    height: 1.5,
                  ),
                ),
                if (unlocked) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: selected
                          ? null
                          : () async {
                              await services.profileFacade.saveEquippedBadge(
                                badge.id,
                              );
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                              }
                            },
                      child: Text(selected ? statusLabel : '佩戴此勋章'),
                    ),
                  ),
                  if (profile.equippedBadgeId != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () async {
                          await services.profileFacade.saveEquippedBadge(null);
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                        child: const Text('恢复最新获得'),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
