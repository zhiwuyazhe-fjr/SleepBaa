import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
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
  const ProfileBadgesPage({
    super.key,
    this.mode = BadgeCatalogMode.profile,
  });

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
        final Color pageBackground = Color.alphaBlend(
          palette.primaryHighlight.withAlpha(24),
          AppColors.background,
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
                        viewportConstraints.maxWidth * 0.06;
                    final double sectionSpacing =
                        viewportConstraints.maxWidth * 0.06;
                    final double gridSpacing =
                        viewportConstraints.maxWidth * 0.03;
                    final double screenRatio =
                        screenSize.width / screenSize.height;
                    final int crossAxisCount = screenRatio > 0.72
                        ? 4
                        : screenRatio < 0.42
                        ? 2
                        : 3;
                    final double tileAspectRatio = crossAxisCount == 4
                        ? 0.74
                        : 0.66;

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
                      final String currentBadgeDescription =
                          activeBadge?.description ??
                          '完成睡眠打卡后，最新获得的勋章会自动展示在这里。';
                      final String summaryModeLabel = showingLatestEarned
                          ? '自动同步最新'
                          : '手动佩戴中';

                      countLabel = '$unlockedCount / ${kHonorBadgeCatalog.length}';
                      catalogChildren = <Widget>[
                        _CatalogSummaryCard(
                          key: const ValueKey<String>('profile-badge-summary-card'),
                          iconData: activeBadge?.icon,
                          title: '当前佩戴：$currentBadgeLabel',
                          description: currentBadgeDescription,
                          modeLabel: summaryModeLabel,
                          actionLabel: showingLatestEarned
                              ? '已同步最新'
                              : '恢复默认最新',
                          palette: palette,
                          onActionPressed: showingLatestEarned
                              ? null
                              : () async {
                                  await services.profileFacade.saveEquippedBadge(
                                    null,
                                  );
                                },
                        ),
                        SizedBox(height: sectionSpacing),
                        _BadgeSectionHeader(
                          title: '全部勋章',
                          detail: '${kHonorBadgeCatalog.length} 枚全部可查看',
                        ),
                        SizedBox(
                          height: viewportConstraints.maxWidth * 0.04,
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
                      final DormHonorBadge? activeBadge = resolvedDormBadgeId ==
                              null
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
                      final String currentBadgeDescription =
                          activeBadge?.meaning ??
                          '寝室获得勋章后，最新一枚会自动展示在这里。';
                      final String summaryModeLabel = showingLatestEarned
                          ? '自动同步最新'
                          : '手动切换中';

                      countLabel =
                          '$unlockedCount / ${kDormHonorBadgeCatalog.length}';
                      catalogChildren = <Widget>[
                        _CatalogSummaryCard(
                          key: const ValueKey<String>('dorm-badge-summary-card'),
                          iconData: activeBadge?.icon,
                          title: '当前展示：$currentBadgeLabel',
                          description: currentBadgeDescription,
                          modeLabel: summaryModeLabel,
                          actionLabel: showingLatestEarned
                              ? '已同步最新'
                              : '恢复默认最新',
                          palette: palette,
                          onActionPressed: showingLatestEarned
                              ? null
                              : () => _saveDormBadgeSelection(services, null),
                        ),
                        SizedBox(height: sectionSpacing),
                        _DormPulseBadgeVisibilityCard(
                          value: effectiveShowDormPulseBadge,
                          palette: palette,
                          onChanged: (bool value) =>
                              _setDormPulseBadgeVisibility(services, value),
                        ),
                        SizedBox(height: sectionSpacing),
                        _BadgeSectionHeader(
                          title: '全部勋章',
                          detail: '${kDormHonorBadgeCatalog.length} 枚全部可查看',
                        ),
                        SizedBox(
                          height: viewportConstraints.maxWidth * 0.04,
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
                            palette: palette,
                          ),
                          SizedBox(height: sectionSpacing * 0.8),
                          _BadgeCatalogModeSwitch(
                            activeMode: widget.mode,
                            palette: palette,
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
    required this.palette,
  });

  final String title;
  final String titleKeySuffix;
  final String countLabel;
  final VoidCallback onBack;
  final NightMoodPalette palette;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double iconTapSize = constraints.maxWidth * 0.09;
        final double iconSize = iconTapSize * 0.7;

        return Row(
          children: <Widget>[
            SizedBox(
              width: iconTapSize,
              height: iconTapSize,
              child: Material(
                color: Colors.transparent,
                child: InkResponse(
                  onTap: onBack,
                  radius: iconTapSize * 0.5,
                  containedInkWell: false,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      Icons.arrow_back_rounded,
                      size: iconSize,
                      color: palette.primaryDeep,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: constraints.maxWidth * 0.02),
            Expanded(
              child: Text(
                title,
                key: ValueKey<String>('badge-catalog-title-$titleKeySuffix'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: palette.primaryDeep,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth * 0.03,
                vertical: constraints.maxWidth * 0.02,
              ),
              decoration: BoxDecoration(
                color: palette.primaryHighlight,
                borderRadius: AppRadius.pill,
              ),
              child: Text(
                countLabel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: palette.primaryDeep,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BadgeCatalogModeSwitch extends StatelessWidget {
  const _BadgeCatalogModeSwitch({
    required this.activeMode,
    required this.palette,
    required this.onModeSelected,
  });

  final BadgeCatalogMode activeMode;
  final NightMoodPalette palette;
  final ValueChanged<BadgeCatalogMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.pill,
        border: Border.all(color: palette.primarySoft.withAlpha(150)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: BadgeCatalogMode.values
            .map(
              (BadgeCatalogMode mode) => Expanded(
                child: _BadgeCatalogModeButton(
                  mode: mode,
                  selected: mode == activeMode,
                  palette: palette,
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
    required this.palette,
    required this.onTap,
  });

  final BadgeCatalogMode mode;
  final bool selected;
  final NightMoodPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            color: selected
                ? palette.welcomeAccentColor
                : Colors.transparent,
            borderRadius: AppRadius.pill,
          ),
          alignment: Alignment.center,
          child: Text(
            mode.title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected
                  ? palette.welcomeTextOnAccent
                  : AppColors.textSecondary,
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
    required this.description,
    required this.modeLabel,
    required this.actionLabel,
    required this.palette,
    required this.onActionPressed,
  });

  final IconData? iconData;
  final String title;
  final String description;
  final String modeLabel;
  final String actionLabel;
  final NightMoodPalette palette;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double horizontalPadding = constraints.maxWidth * 0.06;
        final double verticalPadding = constraints.maxWidth * 0.075;
        final double badgeSize = constraints.maxWidth * 0.22;
        final double rowGap = constraints.maxWidth * 0.04;
        final double contentActionGap = constraints.maxWidth * 0.075;
        final double scale = (constraints.maxWidth / 360).clamp(0.92, 1.08);
        final double actionHeight = constraints.maxWidth * 0.108;
        final double chipHorizontalPadding = constraints.maxWidth * 0.026;
        final double buttonHorizontalPadding = constraints.maxWidth * 0.038;
        final double titleFontSize =
            ((Theme.of(context).textTheme.headlineSmall?.fontSize ?? 24) *
                    scale)
                .toDouble();
        final double bodyFontSize =
            ((Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16) * scale)
                .toDouble();

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: palette.primarySoft.withAlpha(150)),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontSize: titleFontSize,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        SizedBox(height: rowGap * 0.72),
                        Text(
                          description,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontSize: bodyFontSize,
                                color: AppColors.textSecondary,
                                height: 1.55,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: contentActionGap),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _SummaryModeChip(
                        modeLabel: modeLabel,
                        horizontalPadding: chipHorizontalPadding,
                        height: actionHeight,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _SummaryActionButton(
                          label: actionLabel,
                          onPressed: onActionPressed,
                          backgroundColor: palette.welcomeAccentColor,
                          foregroundColor: palette.welcomeTextOnAccent,
                          horizontalPadding: buttonHorizontalPadding,
                          height: actionHeight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
    final bool hasBadge = iconData != null;
    final double borderWidth = size * 0.025;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasBadge ? palette.primaryHighlight : AppColors.surface,
        border: Border.all(
          color: hasBadge ? palette.primarySoft : AppColors.surfaceBorder,
          width: borderWidth,
        ),
        boxShadow: hasBadge
            ? <BoxShadow>[
                BoxShadow(
                  color: palette.primary.withAlpha(28),
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
        color: hasBadge ? palette.primaryDeep : AppColors.textHint,
      ),
    );
  }
}

class _SummaryModeChip extends StatelessWidget {
  const _SummaryModeChip({
    required this.modeLabel,
    required this.horizontalPadding,
    required this.height,
  });

  final String modeLabel;
  final double horizontalPadding;
  final double height;

  @override
  Widget build(BuildContext context) {
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
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
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
    required this.horizontalPadding,
    required this.height,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final double horizontalPadding;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        disabledBackgroundColor: backgroundColor.withAlpha(110),
        disabledForegroundColor: foregroundColor.withAlpha(140),
        elevation: 0,
        shadowColor: Colors.transparent,
        minimumSize: Size(0, height),
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.pill),
        textStyle: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
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
    return Row(
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Text(
          detail,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.textSecondary,
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
    required this.palette,
    required this.onChanged,
  });

  final bool value;
  final NightMoodPalette palette;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppSettingsGroup(
      key: const ValueKey<String>('dorm-badge-visibility-group'),
      title: '寝室脉搏',
      children: <Widget>[
        AppSettingsItem(
          key: const ValueKey<String>('dorm-badge-visibility-item'),
          icon: Icons.graphic_eq_rounded,
          iconColor: palette.primaryDeep,
          title: '显示当前勋章',
          trailing: _DormBadgeVisibilityToggle(value: value, palette: palette),
          onTap: () => onChanged(!value),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        ),
      ],
    );
  }
}

class _DormBadgeVisibilityToggle extends StatelessWidget {
  const _DormBadgeVisibilityToggle({
    required this.value,
    required this.palette,
  });

  final bool value;
  final NightMoodPalette palette;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 52,
        height: 26,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? palette.primarySoft : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: value
                ? palette.primary.withValues(alpha: 0.28)
                : AppColors.surfaceBorder,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? palette.primary : AppColors.surface,
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
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
                    SizedBox(height: labelGap),
                    Text(
                      badge.badge.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 12,
                        height: 1.18,
                        fontWeight: FontWeight.w800,
                        color: badge.unlocked
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: labelGap * 0.35),
                    Text(
                      badge.statusLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: badge.selected
                            ? palette.primaryDeep
                            : badge.unlocked
                            ? AppColors.textSecondary
                            : AppColors.textSubtle,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
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
    final bool isDisplayed = badge.selected;
    final Color surfaceColor = badge.unlocked
        ? isDisplayed
              ? palette.primary
              : palette.primaryHighlight
        : AppColors.surface;
    final Border? outerBorder = !badge.unlocked
        ? Border.all(color: AppColors.divider)
        : null;
    final Color ringColor = isDisplayed
        ? palette.primarySoft.withAlpha(210)
        : badge.unlocked
        ? palette.primarySoft
        : AppColors.surfaceBorder;
    final IconData iconData = badge.unlocked
        ? badge.badge.icon
        : Icons.lock_rounded;
    final Color iconColor = isDisplayed
        ? AppColors.onDark
        : badge.unlocked
        ? palette.primary
        : AppColors.textHint;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double tileSize = constraints.maxWidth;
        final double visualSize = tileSize * 0.84;
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
                    SizedBox(height: labelGap),
                    Text(
                      badge.badge.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 12,
                        height: 1.18,
                        fontWeight: FontWeight.w800,
                        color: badge.unlocked
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: labelGap * 0.35),
                    Text(
                      badge.statusLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: badge.selected
                            ? palette.primaryDeep
                            : badge.unlocked
                            ? AppColors.textSecondary
                            : AppColors.textSubtle,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
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
    final bool isDisplayed = badge.selected;
    final Color surfaceColor = badge.unlocked
        ? isDisplayed
              ? palette.primary
              : palette.primaryHighlight
        : AppColors.surface;
    final Border? outerBorder = !badge.unlocked
        ? Border.all(color: AppColors.divider)
        : null;
    final Color ringColor = isDisplayed
        ? palette.primarySoft.withAlpha(210)
        : badge.unlocked
        ? palette.primarySoft
        : AppColors.surfaceBorder;
    final IconData iconData = badge.unlocked
        ? badge.badge.icon
        : Icons.lock_rounded;
    final Color iconColor = isDisplayed
        ? AppColors.onDark
        : badge.unlocked
        ? palette.primary
        : AppColors.textHint;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double tileSize = constraints.maxWidth;
        final double visualSize = tileSize * 0.84;
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
