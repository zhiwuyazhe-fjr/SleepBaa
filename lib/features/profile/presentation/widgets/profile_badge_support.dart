import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_typography.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/modals/app_modal.dart';

String? _normalizeBadgeId(String? badgeId) {
  final String? normalizedBadgeId = badgeId?.trim();
  if (normalizedBadgeId == null || normalizedBadgeId.isEmpty) {
    return null;
  }
  return normalizedBadgeId;
}

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

class DormBadgeStatusData {
  const DormBadgeStatusData({
    required this.badge,
    required this.unlocked,
    required this.selected,
    required this.explicitlySelected,
  });

  final DormHonorBadge badge;
  final bool unlocked;
  final bool selected;
  final bool explicitlySelected;

  String get statusLabel {
    if (!unlocked) {
      return '未获得';
    }
    if (explicitlySelected) {
      return '当前展示';
    }
    if (selected) {
      return '自动展示';
    }
    return '点击查看';
  }
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

List<DormBadgeStatusData> buildDormBadgeCatalog({
  required UserProfile profile,
  required Dorm dorm,
  String? displayedBadgeId,
  String? selectedDormBadgeId,
}) {
  final String? resolvedDisplayedBadgeId =
      _normalizeBadgeId(displayedBadgeId) ??
      profile.resolveDormBadgeId(dorm.earnedDormBadgeIds);
  final String? resolvedSelectedBadgeId =
      _normalizeBadgeId(selectedDormBadgeId) ??
      _normalizeBadgeId(profile.selectedDormBadgeId);

  return kDormHonorBadgeCatalog
      .map(
        (DormHonorBadge badge) => DormBadgeStatusData(
          badge: badge,
          unlocked: dorm.hasEarnedDormBadge(badge.id),
          selected: resolvedDisplayedBadgeId == badge.id,
          explicitlySelected: resolvedSelectedBadgeId == badge.id,
        ),
      )
      .toList(growable: false);
}

Future<void> showProfileBadgeDetailsSheet(
  BuildContext context, {
  required HonorBadge badge,
}) {
  final AppServices services = context.appServices;
  return showAppModal<void>(
    context,
    spec: AppRichDetailSheetSpec<void>(
      builder: (BuildContext sheetContext) {
        final UserProfile profile = services.authRepository.currentUser;
        final bool unlocked = profile.hasEarnedBadge(badge.id);
        final bool selected = profile.displayBadgeId == badge.id;
        final bool explicitlyEquipped = profile.equippedBadgeId == badge.id;
        final NightMoodPalette palette = sheetContext.nightMoodPalette;
        final AppSemanticColors appColors = sheetContext.appColors;
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

        return AppRichDetailSheetScaffold(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double sheetPadding = constraints.maxWidth * 0.06;
              final double blockGap = constraints.maxWidth * 0.045;
              final double badgeSize = constraints.maxWidth * 0.22;
              final double chipHorizontal = constraints.maxWidth * 0.03;
              final double chipVertical = constraints.maxWidth * 0.02;
              final double ctaHeight = constraints.maxWidth * 0.14;

              return Container(
                key: ValueKey<String>('profile-badge-sheet-${badge.id}'),
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  sheetPadding,
                  blockGap,
                  sheetPadding,
                  constraints.maxWidth * 0.03,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
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
                                      color: appColors.textPrimary,
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
                                      ? appColors.accentSoft
                                      : appColors.surfaceMuted,
                                  borderRadius: AppRadius.pill,
                                ),
                                child: Text(
                                  statusLabel,
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                        color: unlocked
                                            ? appColors.accentDeep
                                            : appColors.textSecondary,
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
                        color: appColors.accentSoft,
                        borderRadius: AppRadius.card,
                      ),
                      child: Text(
                        badge.description,
                        style: Theme.of(sheetContext).textTheme.bodyLarge
                            ?.copyWith(
                              color: appColors.textSecondary,
                              height: 1.65,
                            ),
                      ),
                    ),
                    SizedBox(height: blockGap * 0.8),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(constraints.maxWidth * 0.04),
                      decoration: BoxDecoration(
                        color: appColors.surfaceMuted,
                        borderRadius: AppRadius.card,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            infoTitle,
                            style: Theme.of(sheetContext).textTheme.titleMedium
                                ?.copyWith(
                                  color: appColors.textPrimary,
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
                                  : appColors.surface,
                              borderRadius: AppRadius.pill,
                            ),
                            child: Text(
                              infoChipLabel,
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: unlocked
                                        ? appColors.accentDeep
                                        : appColors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          SizedBox(height: blockGap * 0.5),
                          Text(
                            infoBody,
                            style: Theme.of(sheetContext).textTheme.bodyMedium
                                ?.copyWith(
                                  color: appColors.textSecondary,
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
                            backgroundColor: appColors.accent,
                            foregroundColor: appColors.textOnAccent,
                            disabledBackgroundColor: appColors.accent
                                .withAlpha(110),
                            disabledForegroundColor: appColors.textOnAccent
                                .withAlpha(140),
                            elevation: 0,
                            shadowColor: Colors.transparent,
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
                        SizedBox(height: blockGap * 0.45),
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
                              foregroundColor: appColors.accentDeep,
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
        );
      },
    ),
  );
}

Future<void> showDormBadgeDetailsSheet(
  BuildContext context, {
  required DormHonorBadge badge,
}) {
  final AppServices services = context.appServices;
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) {
      final UserProfile profile = services.authRepository.currentUser;
      final Dorm dorm = services.dormRepository.currentDorm;
      final bool unlocked = dorm.hasEarnedDormBadge(badge.id);
      final String? displayedBadgeId = profile.resolveDormBadgeId(
        dorm.earnedDormBadgeIds,
      );
      final String? selectedDormBadgeId = _normalizeBadgeId(
        profile.selectedDormBadgeId,
      );
      final bool selected = displayedBadgeId == badge.id;
      final bool explicitlySelected = selectedDormBadgeId == badge.id;
      final NightMoodPalette palette = sheetContext.nightMoodPalette;
      final AppSemanticColors appColors = sheetContext.appColors;
      final TextTheme textTheme = Theme.of(sheetContext).textTheme;
      final String statusLabel = !unlocked
          ? '未获得'
          : explicitlySelected
          ? '当前展示'
          : selected
          ? '自动展示'
          : '已解锁';
      final String infoTitle = unlocked ? '展示方式' : '解锁提示';
      final String infoChipLabel = !unlocked
          ? '未解锁也可查看'
          : explicitlySelected
          ? '已手动展示'
          : selected
          ? '自动同步最新'
          : '已解锁';
      final String infoBody = !unlocked
          ? '现在还没有获得这枚寝室勋章，但可以先查看说明。继续保持寝室协作和作息表现，解锁后就能展示。'
          : explicitlySelected
          ? '你已经手动展示了这枚寝室勋章；如果恢复默认，页面会自动展示最新获得的寝室勋章。'
          : selected
          ? '这枚寝室勋章正在自动展示中。获得新的寝室勋章后，这里的展示会随之自动更新。'
          : '这枚寝室勋章已经解锁，点击下方按钮就能把它设为当前展示。';

      return Padding(
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
            final double bottomSafeInset = MediaQuery.viewPaddingOf(
              sheetContext,
            ).bottom;
            final double bottomGestureInset = MediaQuery.systemGestureInsetsOf(
              sheetContext,
            ).bottom;
            final double bottomInset = bottomSafeInset > bottomGestureInset
                ? bottomSafeInset
                : bottomGestureInset;
            final double bottomPadding = bottomInset > 0
                ? bottomInset + (constraints.maxWidth * 0.02)
                : constraints.maxWidth * 0.03;

            return Container(
              key: ValueKey<String>('dorm-badge-sheet-${badge.id}'),
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                sheetPadding,
                blockGap * 0.4,
                sheetPadding,
                bottomPadding,
              ),
              decoration: BoxDecoration(
                color: appColors.surface,
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
                        color: appColors.borderSubtle,
                        borderRadius: BorderRadius.circular(handleWidth * 0.1),
                      ),
                    ),
                  ),
                  SizedBox(height: blockGap),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      _DormSheetBadgeVisual(
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
                              style: AppTypography.sectionTitle(textTheme)
                                  .copyWith(
                                    color: appColors.textPrimary,
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
                                    ? appColors.accentSoft
                                    : appColors.surfaceMuted,
                                borderRadius: AppRadius.pill,
                              ),
                              child: Text(
                                statusLabel,
                                style: AppTypography.meta(textTheme).copyWith(
                                  color: unlocked
                                      ? appColors.accentDeep
                                      : appColors.textSecondary,
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
                      color: appColors.accentSoft,
                      borderRadius: AppRadius.card,
                    ),
                    child: Text(
                      badge.meaning,
                      style: AppTypography.body(
                        textTheme,
                      ).copyWith(color: appColors.textSecondary),
                    ),
                  ),
                  SizedBox(height: blockGap * 0.8),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(constraints.maxWidth * 0.04),
                    decoration: BoxDecoration(
                      color: appColors.surfaceMuted,
                      borderRadius: AppRadius.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          infoTitle,
                          style: AppTypography.panelTitle(textTheme).copyWith(
                            color: appColors.textPrimary,
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
                                ? appColors.accent.withAlpha(36)
                                : appColors.surface,
                            borderRadius: AppRadius.pill,
                          ),
                          child: Text(
                            infoChipLabel,
                            style: AppTypography.meta(textTheme).copyWith(
                              color: unlocked
                                  ? appColors.accentDeep
                                  : appColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(height: blockGap * 0.5),
                        Text(
                          infoBody,
                          style: AppTypography.body(
                            textTheme,
                          ).copyWith(color: appColors.textSecondary),
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
                                    .saveDormBadgeSelection(badge.id);
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: appColors.accent,
                          foregroundColor: appColors.textOnAccent,
                          disabledBackgroundColor: appColors.accent.withAlpha(
                            110,
                          ),
                          disabledForegroundColor: appColors.textOnAccent
                              .withAlpha(140),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          minimumSize: Size.fromHeight(ctaHeight),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.pill,
                          ),
                          textStyle: AppTypography.panelTitle(
                            textTheme,
                          ).copyWith(fontWeight: FontWeight.w800),
                        ),
                        child: Text(selected ? statusLabel : '展示这枚勋章'),
                      ),
                    ),
                    if (profile.selectedDormBadgeId != null) ...<Widget>[
                      SizedBox(height: blockGap * 0.45),
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            await services.profileFacade.saveDormBadgeSelection(
                              null,
                            );
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: appColors.accentDeep,
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
    final AppSemanticColors appColors = context.appColors;
    final double borderWidth = size * 0.025;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: unlocked ? appColors.accentSoft : appColors.surfaceMuted,
        border: Border.all(
          color: unlocked ? appColors.accent : appColors.borderSubtle,
          width: borderWidth,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        unlocked ? badge.icon : Icons.lock_rounded,
        size: size * 0.4,
        color: unlocked ? appColors.accentDeep : appColors.textSecondary,
      ),
    );
  }
}

class _DormSheetBadgeVisual extends StatelessWidget {
  const _DormSheetBadgeVisual({
    required this.badge,
    required this.unlocked,
    required this.palette,
    required this.size,
  });

  final DormHonorBadge badge;
  final bool unlocked;
  final NightMoodPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final double borderWidth = size * 0.025;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: unlocked ? appColors.accentSoft : appColors.surfaceMuted,
        border: Border.all(
          color: unlocked ? appColors.accent : appColors.borderSubtle,
          width: borderWidth,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        unlocked ? badge.icon : Icons.lock_rounded,
        size: size * 0.4,
        color: unlocked ? appColors.accentDeep : appColors.textSecondary,
      ),
    );
  }
}
