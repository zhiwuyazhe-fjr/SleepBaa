import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/app_typography.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_detail_page_header.dart';
import 'package:sleep_dorm_app/core/widgets/app_settings_group.dart';
import 'package:sleep_dorm_app/features/profile/presentation/widgets/profile_badge_support.dart';

enum BadgeCatalogMode { profile, dorm }

extension _BadgeCatalogModeCopy on BadgeCatalogMode {
  String get title {
    switch (this) {
      case BadgeCatalogMode.profile:
        return '个人勋章';
      case BadgeCatalogMode.dorm:
        return '寝室勋章';
    }
  }

  String get route {
    switch (this) {
      case BadgeCatalogMode.profile:
        return AppRoutes.profileBadges;
      case BadgeCatalogMode.dorm:
        return AppRoutes.dormBadges;
    }
  }

  String get keySuffix {
    switch (this) {
      case BadgeCatalogMode.profile:
        return 'profile';
      case BadgeCatalogMode.dorm:
        return 'dorm';
    }
  }
}

class ProfileBadgesPage extends StatefulWidget {
  const ProfileBadgesPage({super.key, this.mode = BadgeCatalogMode.profile});

  final BadgeCatalogMode mode;

  @override
  State<ProfileBadgesPage> createState() => _ProfileBadgesPageState();
}

class _ProfileBadgesPageState extends State<ProfileBadgesPage> {
  bool? _pendingShowDormPulseBadge;
  bool _hasPendingDormBadgeSelection = false;
  String? _pendingSelectedDormBadgeId;

  void _switchMode(BadgeCatalogMode nextMode) {
    if (nextMode == widget.mode) {
      return;
    }
    context.pushReplacement(nextMode.route);
  }

  String? _normalizeBadgeId(String? badgeId) {
    final String? normalizedBadgeId = badgeId?.trim();
    if (normalizedBadgeId == null || normalizedBadgeId.isEmpty) {
      return null;
    }
    return normalizedBadgeId;
  }

  String? _resolveDormPreviewBadgeId({
    required Dorm dorm,
    required String? preferredDormBadgeId,
  }) {
    final String? normalizedDormBadgeId = _normalizeBadgeId(
      preferredDormBadgeId,
    );
    if (normalizedDormBadgeId != null &&
        dorm.hasEarnedDormBadge(normalizedDormBadgeId)) {
      return normalizedDormBadgeId;
    }
    return dorm.latestEarnedDormBadgeId;
  }

  Future<void> _saveDormBadgeSelection(
    AppServices services,
    String? badgeId,
  ) async {
    setState(() {
      _hasPendingDormBadgeSelection = true;
      _pendingSelectedDormBadgeId = badgeId;
    });
    try {
      await services.profileFacade.saveDormBadgeSelection(badgeId);
    } finally {
      if (mounted) {
        setState(() {
          _hasPendingDormBadgeSelection = false;
        });
      }
    }
  }

  Future<void> _setDormPulseBadgeVisibility(
    AppServices services,
    bool visible,
  ) async {
    setState(() {
      _pendingShowDormPulseBadge = visible;
    });
    try {
      await services.profileFacade.setDormPulseBadgeVisibility(visible);
    } finally {
      if (mounted) {
        setState(() {
          _pendingShowDormPulseBadge = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;

    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        services.authRepository,
        services.dormRepository,
      ]),
      builder: (BuildContext context, Widget? child) {
        final NightMoodPalette palette = context.nightMoodPalette;
        final AppSemanticColors appColors = context.appColors;
        final Color pageBackground = Color.alphaBlend(
          appColors.accentSoft.withAlpha(24),
          appColors.pageBackground,
        );
        final UserProfile profile = services.authRepository.currentUser;
        final Dorm dorm = services.dormRepository.currentDorm;

        return Scaffold(
          backgroundColor: pageBackground,
          body: SafeArea(
            child: LayoutBuilder(
              builder:
                  (BuildContext context, BoxConstraints viewportConstraints) {
                    final Size screenSize = MediaQuery.sizeOf(context);
                    final double horizontalPadding =
                        (viewportConstraints.maxWidth * 0.055).clamp(
                          AppSpacing.lg,
                          AppSpacing.xxl,
                        );
                    final double sectionSpacing =
                        (viewportConstraints.maxWidth * 0.046).clamp(
                          AppSpacing.md,
                          AppSpacing.xl,
                        );
                    final double gridSpacing =
                        (viewportConstraints.maxWidth * 0.026).clamp(
                          AppSpacing.xs,
                          AppSpacing.md,
                        );
                    final double screenRatio =
                        screenSize.width / screenSize.height;
                    final int crossAxisCount = screenRatio > 0.72
                        ? 4
                        : screenRatio < 0.42
                        ? 2
                        : 3;
                    final double tileAspectRatio =
                        widget.mode == BadgeCatalogMode.dorm
                        ? (crossAxisCount == 4 ? 0.88 : 0.78)
                        : (crossAxisCount == 4 ? 0.8 : 0.7);

                    late final String countLabel;
                    late final List<Widget> catalogChildren;

                    if (widget.mode == BadgeCatalogMode.profile) {
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
                          .where(
                            (ProfileBadgeStatusData badge) => badge.unlocked,
                          )
                          .length;
                      final String currentBadgeLabel =
                          activeBadge?.label ?? '暂无勋章';
                      final String summaryModeLabel = showingLatestEarned
                          ? '自动同步最新'
                          : '手动佩戴中';

                      countLabel =
                          '$unlockedCount / ${kHonorBadgeCatalog.length}';
                      catalogChildren = <Widget>[
                        _CatalogSummaryCard(
                          key: const ValueKey<String>(
                            'profile-badge-summary-card',
                          ),
                          iconData: activeBadge?.icon,
                          title: currentBadgeLabel,
                          modeLabel: summaryModeLabel,
                          actionLabel: showingLatestEarned ? '已同步最新' : '恢复默认最新',
                          palette: palette,
                          onTap: activeBadge == null
                              ? null
                              : () => showProfileBadgeDetailsSheet(
                                  context,
                                  badge: activeBadge,
                                ),
                          onActionPressed: showingLatestEarned
                              ? null
                              : () async {
                                  await services.profileFacade
                                      .saveEquippedBadge(null);
                                },
                        ),
                        SizedBox(height: sectionSpacing),
                        _BadgeSectionHeader(
                          title: '全部勋章',
                          detail: '${kHonorBadgeCatalog.length} 枚全部可查看',
                        ),
                        SizedBox(
                          height: (viewportConstraints.maxWidth * 0.035).clamp(
                            AppSpacing.sm,
                            AppSpacing.lg,
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          primary: false,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: badges.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: gridSpacing,
                                mainAxisSpacing: sectionSpacing * 0.8,
                                childAspectRatio: tileAspectRatio,
                              ),
                          itemBuilder: (BuildContext context, int index) {
                            final ProfileBadgeStatusData badge = badges[index];
                            return _ProfileBadgeGridTile(
                              badge: badge,
                              palette: palette,
                              onTap: () => showProfileBadgeDetailsSheet(
                                context,
                                badge: badge.badge,
                              ),
                            );
                          },
                        ),
                      ];
                    } else {
                      final bool effectiveShowDormPulseBadge =
                          _pendingShowDormPulseBadge ??
                          profile.showDormPulseBadge;
                      final String? preferredDormBadgeId =
                          _hasPendingDormBadgeSelection
                          ? _pendingSelectedDormBadgeId
                          : profile.selectedDormBadgeId;
                      final String? resolvedDormBadgeId =
                          _resolveDormPreviewBadgeId(
                            dorm: dorm,
                            preferredDormBadgeId: preferredDormBadgeId,
                          );
                      final String? normalizedSelectedDormBadgeId =
                          _normalizeBadgeId(preferredDormBadgeId);
                      final DormHonorBadge? activeBadge =
                          resolvedDormBadgeId == null
                          ? null
                          : dormHonorBadgeById(resolvedDormBadgeId);
                      final List<DormBadgeStatusData> badges =
                          buildDormBadgeCatalog(
                            profile: profile,
                            dorm: dorm,
                            displayedBadgeId: resolvedDormBadgeId,
                            selectedDormBadgeId: normalizedSelectedDormBadgeId,
                          );
                      final int unlockedCount = badges
                          .where((DormBadgeStatusData badge) => badge.unlocked)
                          .length;
                      final bool showingLatestEarned =
                          normalizedSelectedDormBadgeId == null;
                      final String currentBadgeLabel =
                          activeBadge?.label ?? '暂无勋章';
                      final String summaryModeLabel = showingLatestEarned
                          ? '自动同步最新'
                          : '手动切换中';

                      countLabel =
                          '$unlockedCount / ${kDormHonorBadgeCatalog.length}';
                      catalogChildren = <Widget>[
                        _CatalogSummaryCard(
                          key: const ValueKey<String>(
                            'dorm-badge-summary-card',
                          ),
                          iconData: activeBadge?.icon,
                          title: currentBadgeLabel,
                          modeLabel: summaryModeLabel,
                          actionLabel: showingLatestEarned ? '已同步最新' : '恢复默认最新',
                          palette: palette,
                          onTap: activeBadge == null
                              ? null
                              : () => showDormBadgeDetailsSheet(
                                  context,
                                  badge: activeBadge,
                                ),
                          onActionPressed: showingLatestEarned
                              ? null
                              : () => _saveDormBadgeSelection(services, null),
                        ),
                        SizedBox(height: sectionSpacing),
                        _DormPulseBadgeVisibilityCard(
                          value: effectiveShowDormPulseBadge,
                          onChanged: (bool value) =>
                              _setDormPulseBadgeVisibility(services, value),
                        ),
                        SizedBox(height: sectionSpacing),
                        _BadgeSectionHeader(
                          title: '全部勋章',
                          detail: '${kDormHonorBadgeCatalog.length} 枚全部可查看',
                        ),
                        SizedBox(
                          height: (viewportConstraints.maxWidth * 0.035).clamp(
                            AppSpacing.sm,
                            AppSpacing.lg,
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          primary: false,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: badges.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: gridSpacing,
                                mainAxisSpacing: sectionSpacing * 0.8,
                                childAspectRatio: tileAspectRatio,
                              ),
                          itemBuilder: (BuildContext context, int index) {
                            final DormBadgeStatusData badge = badges[index];
                            return _DormBadgeGridTile(
                              badge: badge,
                              palette: palette,
                              onTap: () => showDormBadgeDetailsSheet(
                                context,
                                badge: badge.badge,
                              ),
                            );
                          },
                        ),
                      ];
                    }

                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        viewportConstraints.maxHeight * 0.02,
                        horizontalPadding,
                        screenSize.height * 0.05,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _BadgeCatalogHeader(
                            title: widget.mode.title,
                            titleKeySuffix: widget.mode.keySuffix,
                            countLabel: countLabel,
                            onBack: () => Navigator.of(context).maybePop(),
                          ),
                          SizedBox(height: sectionSpacing * 0.8),
                          _BadgeCatalogModeSwitch(
                            activeMode: widget.mode,
                            onModeSelected: _switchMode,
                          ),
                          SizedBox(height: sectionSpacing),
                          ...catalogChildren,
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
}

class _BadgeCatalogHeader extends StatelessWidget {
  const _BadgeCatalogHeader({
    required this.title,
    required this.titleKeySuffix,
    required this.countLabel,
    required this.onBack,
  });

  final String title;
  final String titleKeySuffix;
  final String countLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return AppDetailPageHeader(
          title: title,
          titleKey: ValueKey<String>('badge-catalog-title-$titleKeySuffix'),
          onBack: onBack,
          trailing: Container(
            padding: EdgeInsets.symmetric(
              horizontal: constraints.maxWidth * 0.03,
              vertical: constraints.maxWidth * 0.02,
            ),
            decoration: BoxDecoration(
              color: appColors.accentSoft,
              borderRadius: AppRadius.pill,
            ),
            child: Text(
              countLabel,
              style: AppTypography.meta(textTheme).copyWith(
                color: appColors.accentDeep,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BadgeCatalogModeSwitch extends StatelessWidget {
  const _BadgeCatalogModeSwitch({
    required this.activeMode,
    required this.onModeSelected,
  });

  final BadgeCatalogMode activeMode;
  final ValueChanged<BadgeCatalogMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.pill,
        border: Border.all(color: appColors.accentSoft.withAlpha(150)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: BadgeCatalogMode.values
            .map(
              (BadgeCatalogMode mode) => Expanded(
                child: _BadgeCatalogModeButton(
                  mode: mode,
                  selected: mode == activeMode,
                  onTap: () => onModeSelected(mode),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _BadgeCatalogModeButton extends StatelessWidget {
  const _BadgeCatalogModeButton({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final BadgeCatalogMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('badge-catalog-mode-${mode.keySuffix}'),
        borderRadius: AppRadius.pill,
        onTap: selected ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? appColors.accent : Colors.transparent,
            borderRadius: AppRadius.pill,
          ),
          alignment: Alignment.center,
          child: Text(
            mode.title,
            style: AppTypography.meta(textTheme).copyWith(
              color: selected
                  ? appColors.textOnAccent
                  : appColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogSummaryCard extends StatelessWidget {
  const _CatalogSummaryCard({
    super.key,
    required this.iconData,
    required this.title,
    required this.modeLabel,
    required this.actionLabel,
    required this.palette,
    required this.onActionPressed,
    this.onTap,
  });

  final IconData? iconData;
  final String title;
  final String modeLabel;
  final String actionLabel;
  final NightMoodPalette palette;
  final VoidCallback? onActionPressed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final AppSemanticColors appColors = context.appColors;
        final TextTheme textTheme = Theme.of(context).textTheme;
        final double horizontalPadding = (constraints.maxWidth * 0.045).clamp(
          AppSpacing.md,
          AppSpacing.xl,
        );
        final double verticalPadding = (constraints.maxWidth * 0.028).clamp(
          AppSpacing.sm,
          AppSpacing.lg,
        );
        final double badgeSize = (constraints.maxWidth * 0.13).clamp(64, 82);
        final double rowGap = (constraints.maxWidth * 0.03).clamp(
          AppSpacing.sm,
          AppSpacing.lg,
        );
        final double actionGap = (constraints.maxWidth * 0.02).clamp(
          AppSpacing.xs,
          AppSpacing.sm,
        );
        final double actionHeight = (constraints.maxWidth * 0.052).clamp(
          32,
          38,
        );
        final double chipHorizontalPadding = (constraints.maxWidth * 0.024)
            .clamp(AppSpacing.xs, AppSpacing.sm);
        final double buttonHorizontalPadding = (constraints.maxWidth * 0.03)
            .clamp(AppSpacing.sm, AppSpacing.md);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: onTap,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: appColors.accentSoft.withAlpha(150)),
                boxShadow: AppColors.cardShadow,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  SizedBox.square(
                    dimension: badgeSize,
                    child: _SummaryBadgeVisual(
                      iconData: iconData,
                      palette: palette,
                      size: badgeSize,
                    ),
                  ),
                  SizedBox(width: rowGap),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: AppTypography.sectionTitle(textTheme)
                                .copyWith(
                                  color: appColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: rowGap),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 112,
                      maxWidth: 112,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _SummaryModeChip(
                          key: const ValueKey<String>(
                            'badge-summary-mode-chip',
                          ),
                          modeLabel: modeLabel,
                          horizontalPadding: chipHorizontalPadding,
                          height: actionHeight,
                        ),
                        SizedBox(height: actionGap),
                        SizedBox(
                          key: const ValueKey<String>(
                            'badge-summary-action-button',
                          ),
                          height: actionHeight,
                          width: double.infinity,
                          child: _SummaryActionButton(
                            label: actionLabel,
                            onPressed: onActionPressed,
                            backgroundColor: AppColors.surfaceMuted,
                            foregroundColor: palette.primaryDeep,
                            disabledForegroundColor: AppColors.textSecondary,
                            horizontalPadding: buttonHorizontalPadding,
                            height: actionHeight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SummaryBadgeVisual extends StatelessWidget {
  const _SummaryBadgeVisual({
    required this.iconData,
    required this.palette,
    required this.size,
  });

  final IconData? iconData;
  final NightMoodPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final bool hasBadge = iconData != null;
    final double borderWidth = size * 0.025;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasBadge ? appColors.accentSoft : appColors.surface,
        border: Border.all(
          color: hasBadge ? appColors.accent : appColors.borderSubtle,
          width: borderWidth,
        ),
        boxShadow: hasBadge
            ? <BoxShadow>[
                BoxShadow(
                  color: appColors.accent.withAlpha(28),
                  blurRadius: size * 0.18,
                  offset: Offset(0, size * 0.05),
                ),
              ]
            : const <BoxShadow>[],
      ),
      alignment: Alignment.center,
      child: Icon(
        hasBadge ? iconData! : Icons.emoji_events_outlined,
        size: size * 0.44,
        color: hasBadge ? appColors.accentDeep : AppColors.textHint,
      ),
    );
  }
}

class _SummaryModeChip extends StatelessWidget {
  const _SummaryModeChip({
    super.key,
    required this.modeLabel,
    required this.horizontalPadding,
    required this.height,
  });

  final String modeLabel;
  final double horizontalPadding;
  final double height;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.pill,
      ),
      alignment: Alignment.center,
      child: Text(
        modeLabel,
        textAlign: TextAlign.center,
        style: AppTypography.meta(
          Theme.of(context).textTheme,
        ).copyWith(color: appColors.textSecondary, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SummaryActionButton extends StatelessWidget {
  const _SummaryActionButton({
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.disabledForegroundColor,
    required this.horizontalPadding,
    required this.height,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color disabledForegroundColor;
  final double horizontalPadding;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        disabledBackgroundColor: backgroundColor,
        disabledForegroundColor: disabledForegroundColor,
        elevation: 0,
        shadowColor: Colors.transparent,
        minimumSize: Size.fromHeight(height),
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.pill),
        textStyle: AppTypography.meta(
          Theme.of(context).textTheme,
        ).copyWith(fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }
}

class _BadgeSectionHeader extends StatelessWidget {
  const _BadgeSectionHeader({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        Text(
          title,
          style: AppTypography.sectionTitle(
            textTheme,
          ).copyWith(color: appColors.textPrimary, fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        Text(
          detail,
          style: AppTypography.meta(textTheme).copyWith(
            color: appColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _DormPulseBadgeVisibilityCard extends StatelessWidget {
  const _DormPulseBadgeVisibilityCard({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return AppSettingsGroup(
      key: const ValueKey<String>('dorm-badge-visibility-group'),
      children: <Widget>[
        AppSettingsItem(
          key: const ValueKey<String>('dorm-badge-visibility-item'),
          icon: Icons.graphic_eq_rounded,
          iconColor: appColors.accentDeep,
          iconBackgroundColor: appColors.surfaceMuted,
          title: '寝室脉搏显示当前勋章',
          titleStyle: AppTypography.body(
            textTheme,
          ).copyWith(color: appColors.textPrimary, fontWeight: FontWeight.w600),
          trailing: AppSettingsToggle(value: value),
          onTap: () => onChanged(!value),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        ),
      ],
    );
  }
}

class _ProfileBadgeGridTile extends StatelessWidget {
  const _ProfileBadgeGridTile({
    required this.badge,
    required this.palette,
    required this.onTap,
  });

  final ProfileBadgeStatusData badge;
  final NightMoodPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Tooltip(
      message: badge.badge.description,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey<String>('profile-badge-grid-${badge.badge.id}'),
          onTap: onTap,
          borderRadius: AppRadius.card,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double labelGap = constraints.maxWidth * 0.05;
              return Padding(
                padding: EdgeInsets.symmetric(
                  vertical: constraints.maxWidth * 0.02,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _ProfileBadgeTileVisual(badge: badge, palette: palette),
                    SizedBox(height: labelGap * 0.75),
                    Text(
                      badge.badge.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTypography.meta(textTheme).copyWith(
                        height: 1.18,
                        fontWeight: FontWeight.w800,
                        color: badge.unlocked
                            ? appColors.textPrimary
                            : appColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: labelGap * 0.24),
                    Text(
                      badge.statusLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTypography.chip(textTheme).copyWith(
                        color: badge.selected
                            ? appColors.accentDeep
                            : badge.unlocked
                            ? appColors.textSecondary
                            : AppColors.textSubtle,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileBadgeTileVisual extends StatelessWidget {
  const _ProfileBadgeTileVisual({required this.badge, required this.palette});

  final ProfileBadgeStatusData badge;
  final NightMoodPalette palette;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final bool isDisplayed = badge.selected;
    final Color surfaceColor = badge.unlocked
        ? isDisplayed
              ? appColors.accent
              : appColors.accentSoft
        : appColors.surface;
    final Border? outerBorder = !badge.unlocked
        ? Border.all(color: appColors.borderSubtle)
        : null;
    final Color ringColor = isDisplayed
        ? appColors.accentSoft.withAlpha(210)
        : badge.unlocked
        ? appColors.accentSoft
        : appColors.borderSubtle;
    final IconData iconData = badge.unlocked
        ? badge.badge.icon
        : Icons.lock_rounded;
    final Color iconColor = isDisplayed
        ? appColors.accentDeep
        : badge.unlocked
        ? appColors.accentDeep
        : AppColors.textHint;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double tileSize = constraints.maxWidth;
        final double visualSize = tileSize * 0.76;
        final double ringSize = visualSize * 0.61;
        final double ringStroke = visualSize * (isDisplayed ? 0.022 : 0.017);

        return SizedBox(
          width: tileSize,
          height: visualSize,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: visualSize,
              height: visualSize,
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(visualSize * 0.32),
                border: outerBorder,
              ),
              child: Center(
                child: Container(
                  width: ringSize,
                  height: ringSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ringColor, width: ringStroke),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    iconData,
                    size: visualSize * 0.27,
                    color: iconColor,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DormBadgeGridTile extends StatelessWidget {
  const _DormBadgeGridTile({
    required this.badge,
    required this.palette,
    required this.onTap,
  });

  final DormBadgeStatusData badge;
  final NightMoodPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Tooltip(
      message: badge.badge.meaning,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey<String>('dorm-badge-grid-${badge.badge.id}'),
          onTap: onTap,
          borderRadius: AppRadius.card,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double labelGap = constraints.maxWidth * 0.05;
              return Padding(
                padding: EdgeInsets.symmetric(
                  vertical: constraints.maxWidth * 0.02,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _DormBadgeTileVisual(badge: badge, palette: palette),
                    SizedBox(height: labelGap * 0.75),
                    Text(
                      badge.badge.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTypography.meta(textTheme).copyWith(
                        height: 1.18,
                        fontWeight: FontWeight.w800,
                        color: badge.unlocked
                            ? appColors.textPrimary
                            : appColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: labelGap * 0.24),
                    Text(
                      badge.statusLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTypography.chip(textTheme).copyWith(
                        color: badge.selected
                            ? appColors.accentDeep
                            : badge.unlocked
                            ? appColors.textSecondary
                            : AppColors.textSubtle,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DormBadgeTileVisual extends StatelessWidget {
  const _DormBadgeTileVisual({required this.badge, required this.palette});

  final DormBadgeStatusData badge;
  final NightMoodPalette palette;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final bool isDisplayed = badge.selected;
    final Color surfaceColor = badge.unlocked
        ? isDisplayed
              ? appColors.accent
              : appColors.accentSoft
        : appColors.surface;
    final Border? outerBorder = !badge.unlocked
        ? Border.all(color: appColors.borderSubtle)
        : null;
    final Color ringColor = isDisplayed
        ? appColors.accentSoft.withAlpha(210)
        : badge.unlocked
        ? appColors.accentSoft
        : appColors.borderSubtle;
    final IconData iconData = badge.unlocked
        ? badge.badge.icon
        : Icons.lock_rounded;
    final Color iconColor = isDisplayed
        ? appColors.accentDeep
        : badge.unlocked
        ? appColors.accentDeep
        : AppColors.textHint;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double tileSize = constraints.maxWidth;
        final double visualSize = tileSize * 0.72;
        final double ringSize = visualSize * 0.61;
        final double ringStroke = visualSize * (isDisplayed ? 0.022 : 0.017);

        return SizedBox(
          width: tileSize,
          height: visualSize,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: visualSize,
              height: visualSize,
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(visualSize * 0.32),
                border: outerBorder,
              ),
              child: Center(
                child: Container(
                  width: ringSize,
                  height: ringSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ringColor, width: ringStroke),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    iconData,
                    size: visualSize * 0.27,
                    color: iconColor,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
