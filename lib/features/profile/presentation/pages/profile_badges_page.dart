import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/features/profile/presentation/widgets/profile_badge_support.dart';

class ProfileBadgesPage extends StatelessWidget {
  const ProfileBadgesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;

    return ListenableBuilder(
      listenable: services.authRepository,
      builder: (BuildContext context, Widget? child) {
        final NightMoodPalette palette = context.nightMoodPalette;
        final Color pageBackground = Color.alphaBlend(
          palette.primaryHighlight.withAlpha(24),
          AppColors.background,
        );
        final UserProfile profile = services.authRepository.currentUser;
        final List<ProfileBadgeStatusData> badges = buildProfileBadgeCatalog(
          profile,
        );
        final HonorBadge? activeBadge = honorBadgeById(profile.displayBadgeId);
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
            activeBadge?.description ?? '完成睡眠打卡后，最新获得的勋章会自动展示在这里。';
        final String summaryModeLabel = showingLatestEarned
            ? '自动同步最新'
            : '手动佩戴中';

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
                          _ProfileBadgesHeader(
                            countLabel:
                                '$unlockedCount / ${kHonorBadgeCatalog.length}',
                            onBack: () => Navigator.of(context).maybePop(),
                            palette: palette,
                          ),
                          SizedBox(height: sectionSpacing),
                          _ProfileBadgeSummaryCard(
                            key: const ValueKey<String>(
                              'profile-badge-summary-card',
                            ),
                            badge: activeBadge,
                            currentBadgeLabel: currentBadgeLabel,
                            currentBadgeDescription: currentBadgeDescription,
                            modeLabel: summaryModeLabel,
                            showingLatestEarned: showingLatestEarned,
                            palette: palette,
                            onRestoreLatest: showingLatestEarned
                                ? null
                                : () async {
                                    await services.profileFacade
                                        .saveEquippedBadge(null);
                                  },
                          ),
                          SizedBox(height: sectionSpacing),
                          Row(
                            children: <Widget>[
                              Text(
                                '全部勋章',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const Spacer(),
                              Text(
                                '${kHonorBadgeCatalog.length} 枚全部可查看',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                          SizedBox(height: viewportConstraints.maxWidth * 0.04),
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
                              final ProfileBadgeStatusData badge =
                                  badges[index];
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

class _ProfileBadgesHeader extends StatelessWidget {
  const _ProfileBadgesHeader({
    required this.countLabel,
    required this.onBack,
    required this.palette,
  });

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
                '勋章图鉴',
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

class _ProfileBadgeSummaryCard extends StatelessWidget {
  const _ProfileBadgeSummaryCard({
    super.key,
    required this.badge,
    required this.currentBadgeLabel,
    required this.currentBadgeDescription,
    required this.modeLabel,
    required this.showingLatestEarned,
    required this.palette,
    required this.onRestoreLatest,
  });

  final HonorBadge? badge;
  final String currentBadgeLabel;
  final String currentBadgeDescription;
  final String modeLabel;
  final bool showingLatestEarned;
  final NightMoodPalette palette;
  final VoidCallback? onRestoreLatest;

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
                      badge: badge,
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
                          '当前佩戴：$currentBadgeLabel',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontSize: titleFontSize,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        SizedBox(height: rowGap * 0.72),
                        Text(
                          currentBadgeDescription,
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
                          label: showingLatestEarned ? '已同步最新' : '恢复默认最新',
                          onPressed: onRestoreLatest,
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
    required this.badge,
    required this.palette,
    required this.size,
  });

  final HonorBadge? badge;
  final NightMoodPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool hasBadge = badge != null;
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
        hasBadge ? badge!.icon : Icons.emoji_events_outlined,
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
