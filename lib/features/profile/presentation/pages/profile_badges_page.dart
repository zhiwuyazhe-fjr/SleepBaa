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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints viewportConstraints) {
            final Size screenSize = MediaQuery.sizeOf(context);
            final double horizontalPadding =
                viewportConstraints.maxWidth * 0.06;
            final double sectionSpacing = viewportConstraints.maxWidth * 0.06;
            final double gridSpacing = viewportConstraints.maxWidth * 0.03;
            final double screenRatio = screenSize.width / screenSize.height;
            final int crossAxisCount = screenRatio > 0.72
                ? 4
                : screenRatio < 0.42
                ? 2
                : 3;
            final double tileAspectRatio = crossAxisCount == 4 ? 0.68 : 0.62;

            return ListenableBuilder(
              listenable: services.authRepository,
              builder: (BuildContext context, Widget? child) {
                final NightMoodPalette palette = NightMoodPalette.fromMood(
                  NightMood.calm,
                );
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
                    activeBadge?.description ?? '完成睡眠打卡后，最新获得的勋章会自动展示在这里。';
                final String summaryModeLabel = showingLatestEarned
                    ? '自动同步最新'
                    : '手动佩戴中';

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
                                await services.profileFacade.saveEquippedBadge(
                                  null,
                                );
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
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
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
        final double controlSize = constraints.maxWidth * 0.11;
        final double iconSize = controlSize * 0.45;

        return Row(
          children: <Widget>[
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onBack,
                borderRadius: AppRadius.pill,
                child: Ink(
                  width: controlSize,
                  height: controlSize,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(controlSize / 2),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: iconSize,
                    color: palette.primaryDeep,
                  ),
                ),
              ),
            ),
            SizedBox(width: constraints.maxWidth * 0.04),
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
        final double cardPadding = constraints.maxWidth * 0.06;
        final double badgeSize = constraints.maxWidth * 0.24;
        final double gap = constraints.maxWidth * 0.04;

        return Container(
          padding: EdgeInsets.all(cardPadding),
          decoration: BoxDecoration(
            color: palette.primaryHighlight,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: palette.primarySoft.withAlpha(170)),
          ),
          child: Row(
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
              SizedBox(width: gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '当前佩戴：$currentBadgeLabel',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    SizedBox(height: gap * 0.7),
                    Text(
                      currentBadgeDescription,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                    SizedBox(height: gap),
                    Wrap(
                      spacing: gap * 0.75,
                      runSpacing: gap * 0.75,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: constraints.maxWidth * 0.03,
                            vertical: constraints.maxWidth * 0.02,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withAlpha(210),
                            borderRadius: AppRadius.pill,
                          ),
                          child: Text(
                            modeLabel,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        TextButton(
                          onPressed: onRestoreLatest,
                          style: TextButton.styleFrom(
                            backgroundColor: showingLatestEarned
                                ? palette.primarySoft.withAlpha(90)
                                : AppColors.surface.withAlpha(224),
                            foregroundColor: palette.primaryDeep,
                            disabledBackgroundColor: palette.primarySoft
                                .withAlpha(90),
                            disabledForegroundColor: palette.primaryDeep
                                .withAlpha(120),
                            padding: EdgeInsets.symmetric(
                              horizontal: constraints.maxWidth * 0.04,
                              vertical: constraints.maxWidth * 0.025,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.pill,
                            ),
                          ),
                          child: Text(showingLatestEarned ? '已同步最新' : '恢复默认最新'),
                        ),
                      ],
                    ),
                  ],
                ),
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
              final double labelGap = constraints.maxWidth * 0.09;
              return Padding(
                padding: EdgeInsets.symmetric(
                  vertical: constraints.maxWidth * 0.03,
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
                        fontSize: 13,
                        height: 1.25,
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
        final double ringSize = tileSize * 0.61;
        final double ringStroke = tileSize * (isDisplayed ? 0.022 : 0.017);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: tileSize,
          height: tileSize,
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(tileSize * 0.32),
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
              child: Icon(iconData, size: tileSize * 0.27, color: iconColor),
            ),
          ),
        );
      },
    );
  }
}
