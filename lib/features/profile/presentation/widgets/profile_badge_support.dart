import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
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
  final List<ProfileBadgeStatusData> catalog = buildProfileBadgeCatalog(
    profile,
  );
  final Map<String, ProfileBadgeStatusData> byId =
      <String, ProfileBadgeStatusData>{
        for (final ProfileBadgeStatusData item in catalog) item.badge.id: item,
      };
  final Set<String> addedIds = <String>{};
  final List<ProfileBadgeStatusData> preview = <ProfileBadgeStatusData>[];

  void addById(String? badgeId) {
    if (badgeId == null ||
        preview.length >= maxItems ||
        !addedIds.add(badgeId)) {
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
      final NightMoodPalette palette = NightMoodPalette.fromMood(
        NightMood.calm,
      );
      final String statusLabel = !unlocked
          ? '未获得'
          : explicitlyEquipped
          ? '当前佩戴'
          : selected
          ? '当前展示'
          : '已获得';
      final String infoTitle = unlocked ? '佩戴方式' : '解锁提示';
      final String infoChipLabel = !unlocked
          ? '未解锁也可查看'
          : explicitlyEquipped
          ? '已手动佩戴'
          : selected
          ? '当前展示中'
          : '已解锁';
      final String infoBody = !unlocked
          ? '现在还没有获得这枚勋章，但可以先查看说明。继续保持睡眠记录，它解锁后就能佩戴展示。'
          : explicitlyEquipped
          ? '你已经手动佩戴了这枚勋章；如果恢复默认，页面会自动展示最新获得的勋章。'
          : selected
          ? '这枚勋章正在展示中。你可以保持默认展示，也可以继续切换到别的已获得勋章。'
          : '这枚勋章已经解锁，点击下方按钮就能把它设为当前展示勋章。';

      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double sheetPadding = constraints.maxWidth * 0.06;
              final double blockGap = constraints.maxWidth * 0.045;
              final double handleWidth = constraints.maxWidth * 0.12;
              final double badgeSize = constraints.maxWidth * 0.22;
              final double chipHorizontal = constraints.maxWidth * 0.03;
              final double chipVertical = constraints.maxWidth * 0.02;
              final double ctaHeight = constraints.maxWidth * 0.14;
              final double topRadius = constraints.maxWidth * 0.1;

              return Container(
                key: ValueKey<String>('profile-badge-sheet-${badge.id}'),
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  sheetPadding,
                  blockGap * 0.4,
                  sheetPadding,
                  sheetPadding,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(topRadius),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: handleWidth,
                        height: handleWidth * 0.1,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBorder,
                          borderRadius: BorderRadius.circular(
                            handleWidth * 0.1,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: blockGap),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        _SheetBadgeVisual(
                          badge: badge,
                          unlocked: unlocked,
                          palette: palette,
                          size: badgeSize,
                        ),
                        SizedBox(width: blockGap * 0.8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                badge.label,
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              SizedBox(height: blockGap * 0.35),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: chipHorizontal,
                                  vertical: chipVertical,
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
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: blockGap),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(constraints.maxWidth * 0.04),
                      decoration: BoxDecoration(
                        color: palette.primaryHighlight,
                        borderRadius: AppRadius.card,
                      ),
                      child: Text(
                        badge.description,
                        style: Theme.of(sheetContext).textTheme.bodyLarge
                            ?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.65,
                            ),
                      ),
                    ),
                    SizedBox(height: blockGap * 0.8),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(constraints.maxWidth * 0.04),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: AppRadius.card,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            infoTitle,
                            style: Theme.of(sheetContext).textTheme.titleMedium
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          SizedBox(height: blockGap * 0.5),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: chipHorizontal,
                              vertical: chipVertical,
                            ),
                            decoration: BoxDecoration(
                              color: unlocked
                                  ? palette.primary.withAlpha(36)
                                  : AppColors.surface,
                              borderRadius: AppRadius.pill,
                            ),
                            child: Text(
                              infoChipLabel,
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: unlocked
                                        ? palette.primaryDeep
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          SizedBox(height: blockGap * 0.5),
                          Text(
                            infoBody,
                            style: Theme.of(sheetContext).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.55,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (unlocked) ...<Widget>[
                      SizedBox(height: blockGap),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: selected
                              ? null
                              : () async {
                                  await services.profileFacade
                                      .saveEquippedBadge(badge.id);
                                  if (sheetContext.mounted) {
                                    Navigator.of(sheetContext).pop();
                                  }
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.primarySoft,
                            foregroundColor: palette.primaryDeep,
                            disabledBackgroundColor: palette.primaryHighlight,
                            disabledForegroundColor: palette.primaryDeep
                                .withAlpha(120),
                            minimumSize: Size.fromHeight(ctaHeight),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.pill,
                            ),
                            textStyle: Theme.of(sheetContext)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          child: Text(selected ? statusLabel : '佩戴此勋章'),
                        ),
                      ),
                      if (profile.equippedBadgeId != null) ...<Widget>[
                        SizedBox(height: blockGap * 0.5),
                        Center(
                          child: TextButton(
                            onPressed: () async {
                              await services.profileFacade.saveEquippedBadge(
                                null,
                              );
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: palette.primaryDeep,
                            ),
                            child: const Text('恢复最新获得'),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );
}

class _SheetBadgeVisual extends StatelessWidget {
  const _SheetBadgeVisual({
    required this.badge,
    required this.unlocked,
    required this.palette,
    required this.size,
  });

  final HonorBadge badge;
  final bool unlocked;
  final NightMoodPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    final double borderWidth = size * 0.025;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: unlocked ? palette.primaryHighlight : AppColors.surfaceSoft,
        border: Border.all(
          color: unlocked ? palette.primarySoft : AppColors.surfaceBorder,
          width: borderWidth,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        unlocked ? badge.icon : Icons.lock_rounded,
        size: size * 0.4,
        color: unlocked ? palette.primaryDeep : AppColors.textHint,
      ),
    );
  }
}
