import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/section_title.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/support/dorm_event_records.dart';

class DormPage extends StatelessWidget {
  const DormPage({super.key});

  static const ValueKey<String> heroCardKey = ValueKey<String>(
    'dorm-hero-card',
  );
  static const ValueKey<String> heroGradientKey = ValueKey<String>(
    'dorm-hero-gradient',
  );
  static const ValueKey<String> drawerSheetKey = ValueKey<String>(
    'dorm-drawer-sheet',
  );
  static const ValueKey<String> roommateListKey = ValueKey<String>(
    'dorm-roommate-list',
  );
  static const ValueKey<String> eventMoreKey = ValueKey<String>(
    'dorm-events-more',
  );

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          services.authRepository,
          services.dormRepository,
          services.notificationRepository,
        ]),
        builder: (BuildContext context, Widget? child) {
          final NightMoodPalette palette = context.nightMoodPalette;
          final Dorm dorm = services.dormRepository.currentDorm;
          final String currentUserId = services.authRepository.currentUser.uid;
          final List<DormEventRecord> events = buildDormEventRecords(
            dorm: dorm,
            notifications: services.notificationRepository.notifications,
            palette: palette,
          );
          final int onlineCount = dorm.members
              .where(
                (DormMember member) => member.status != DormMemberStatus.away,
              )
              .length;
          final int sleepingCount = dorm.members
              .where((DormMember member) => member.sleepModeActive)
              .length;
          final List<_DormHubAction> actions = <_DormHubAction>[
            _DormHubAction(
              title: '宿舍作息约定',
              detail: '查看详情',
              icon: Icons.calendar_today_rounded,
              onTap: () => context.push(AppRoutes.dormRules),
            ),
            _DormHubAction(
              title: '静音模式',
              detail: '今晚执行',
              icon: Icons.volume_off_rounded,
              onTap: () => _showDormSnackBar(context, '今晚 23:00 后的静音提醒已经准备好了。'),
            ),
            _DormHubAction(
              title: '安静挑战',
              detail: '参与挑战',
              icon: Icons.emoji_events_rounded,
              onTap: () => _showDormSnackBar(context, '已记录本周安静挑战，明早可以回看完成情况。'),
            ),
            _DormHubAction(
              title: '委婉提醒',
              detail: '发送提醒',
              icon: Icons.notifications_active_rounded,
              onTap: () =>
                  _showDormSnackBar(context, '已生成一条温和提醒文案，后续可以直接接入消息发送。'),
            ),
          ];

          return SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool wideLayout = constraints.maxWidth >= 720;
                final double horizontalPadding = wideLayout
                    ? AppSpacing.xxxl
                    : AppSpacing.xl;
                final double initialSheetSize = wideLayout ? 0.44 : 0.50;
                final double minSheetSize = wideLayout ? 0.40 : 0.46;
                final double heroMinHeight = wideLayout ? 220 : 236;

                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            palette.primarySoft.withAlpha(24),
                            AppColors.background,
                            AppColors.background,
                          ],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            AppSpacing.lg,
                            horizontalPadding,
                            0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                dorm.name,
                                style: Theme.of(context).textTheme.displayMedium
                                    ?.copyWith(height: 1.05),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _DormHeroCard(
                                key: heroCardKey,
                                palette: palette,
                                onlineCount: onlineCount,
                                sleepingCount: sleepingCount,
                                quietScore: _quietStarsFor(dorm.noiseDb),
                                minHeight: heroMinHeight,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: DraggableScrollableSheet(
                          expand: false,
                          initialChildSize: initialSheetSize,
                          minChildSize: minSheetSize,
                          maxChildSize: 0.94,
                          builder:
                              (
                                BuildContext context,
                                ScrollController scrollController,
                              ) {
                                return Container(
                                  key: drawerSheetKey,
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(44),
                                    ),
                                    boxShadow: AppColors.floatingShadow,
                                  ),
                                  child: ListView(
                                    controller: scrollController,
                                    padding: EdgeInsets.fromLTRB(
                                      horizontalPadding,
                                      AppSpacing.sm,
                                      horizontalPadding,
                                      168,
                                    ),
                                    children: <Widget>[
                                      Center(
                                        child: Container(
                                          width: 48,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: palette.primarySoft
                                                .withAlpha(144),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      SectionTitle(
                                        title: '室友动态',
                                        actionLabel: '宿舍公约',
                                        onAction: () =>
                                            context.push(AppRoutes.dormRules),
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      SizedBox(
                                        key: roommateListKey,
                                        height: 188,
                                        child: ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: dorm.members.length,
                                          separatorBuilder:
                                              (
                                                BuildContext context,
                                                int index,
                                              ) => const SizedBox(
                                                width: AppSpacing.sm,
                                              ),
                                          itemBuilder:
                                              (
                                                BuildContext context,
                                                int index,
                                              ) {
                                                final DormMember member =
                                                    dorm.members[index];
                                                return _DormMemberCard(
                                                  member: member,
                                                  isCurrentUser:
                                                      member.uid ==
                                                      currentUserId,
                                                );
                                              },
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.xl),
                                      const SectionTitle(title: '智能寝室协同中心'),
                                      const SizedBox(height: AppSpacing.md),
                                      GridView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: actions.length,
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 2,
                                              crossAxisSpacing: AppSpacing.md,
                                              mainAxisSpacing: AppSpacing.md,
                                              childAspectRatio: wideLayout
                                                  ? 1.18
                                                  : 1.04,
                                            ),
                                        itemBuilder:
                                            (BuildContext context, int index) {
                                              final _DormHubAction action =
                                                  actions[index];
                                              return _DormHubCard(
                                                action: action,
                                                palette: palette,
                                              );
                                            },
                                      ),
                                      const SizedBox(height: AppSpacing.xl),
                                      SectionTitle(
                                        title: '寝室事件记录',
                                        actionLabel: '查看更多',
                                        actionKey: eventMoreKey,
                                        onAction: () =>
                                            context.push(AppRoutes.dormStatus),
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      ...List<Widget>.generate(
                                        events.length,
                                        (int index) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: AppSpacing.sm,
                                          ),
                                          child: _DormEventTile(
                                            key: ValueKey<String>(
                                              'dorm-event-tile-$index',
                                            ),
                                            event: events[index],
                                            onTap: () => context.push(
                                              AppRoutes.dormStatus,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _DormHeroCard extends StatelessWidget {
  const _DormHeroCard({
    super.key,
    required this.palette,
    required this.onlineCount,
    required this.sleepingCount,
    required this.quietScore,
    required this.minHeight,
  });

  final NightMoodPalette palette;
  final int onlineCount;
  final int sleepingCount;
  final int quietScore;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      boxShadow: AppColors.floatingShadow,
      child: Container(
        key: DormPage.heroGradientKey,
        width: double.infinity,
        constraints: BoxConstraints(minHeight: minHeight),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              palette.heroGradientStart,
              palette.heroGradientMid,
              palette.heroGradientEnd,
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              right: -10,
              top: -20,
              child: Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(18),
                ),
              ),
            ),
            Positioned(
              left: -10,
              bottom: -34,
              child: Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.primarySoft.withAlpha(36),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Dorm Pulse',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.onDark.withAlpha(180),
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '今晚宿舍整体状态平稳',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.onDark,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    _HeroInfoPill(label: '在线 $onlineCount 人'),
                    _HeroInfoPill(label: '睡眠中 $sleepingCount 人'),
                    _HeroRatingPill(score: quietScore),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroInfoPill extends StatelessWidget {
  const _HeroInfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(246),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HeroRatingPill extends StatelessWidget {
  const _HeroRatingPill({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(246),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '安静等级',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          ...List<Widget>.generate(
            score,
            (int index) => const Padding(
              padding: EdgeInsets.only(left: 2),
              child: Icon(
                Icons.star_rounded,
                size: 16,
                color: Color(0xFFF6B400),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DormMemberCard extends StatelessWidget {
  const _DormMemberCard({required this.member, required this.isCurrentUser});

  final DormMember member;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    final Color accentColor = _memberColor(member.status);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      border: Border.all(color: AppColors.divider),
      boxShadow: const <BoxShadow>[],
      child: SizedBox(
        width: 136,
        height: 160,
        child: Column(
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    accentColor.withAlpha(210),
                    palette.primarySoft,
                  ],
                ),
                border: Border.all(color: accentColor, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                member.name.characters.first,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.onDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              isCurrentUser ? '${member.name} · 你' : member.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 38,
              child: Text(
                member.note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: accentColor.withAlpha(24),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _memberLabel(member.status),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DormHubCard extends StatelessWidget {
  const _DormHubCard({required this.action, required this.palette});

  final _DormHubAction action;
  final NightMoodPalette palette;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: action.onTap,
      border: Border.all(color: palette.primarySoft.withAlpha(60)),
      boxShadow: const <BoxShadow>[],
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.primarySoft.withAlpha(20),
              ),
              alignment: Alignment.center,
              child: Icon(action.icon, color: palette.primary, size: 22),
            ),
            Text(
              action.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              action.detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DormEventTile extends StatelessWidget {
  const _DormEventTile({super.key, required this.event, required this.onTap});

  final DormEventRecord event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      color: AppColors.surfaceMuted,
      boxShadow: const <BoxShadow>[],
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: event.color.withAlpha(24),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(event.icon, color: event.color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        event.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      event.timeLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  event.detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _DormHubAction {
  const _DormHubAction({
    required this.title,
    required this.detail,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String detail;
  final IconData icon;
  final VoidCallback onTap;
}

Color _memberColor(DormMemberStatus status) {
  return switch (status) {
    DormMemberStatus.sleeping => const Color(0xFF44B9D7),
    DormMemberStatus.quiet => const Color(0xFF38C89D),
    DormMemberStatus.away => const Color(0xFF3B3F46),
    DormMemberStatus.active => const Color(0xFFF5A53A),
  };
}

String _memberLabel(DormMemberStatus status) {
  return switch (status) {
    DormMemberStatus.sleeping => 'SLEEPING',
    DormMemberStatus.quiet => 'QUIET',
    DormMemberStatus.away => 'AWAY',
    DormMemberStatus.active => 'ACTIVE',
  };
}

int _quietStarsFor(int noiseDb) {
  if (noiseDb <= 35) {
    return 5;
  }
  if (noiseDb <= 45) {
    return 4;
  }
  if (noiseDb <= 55) {
    return 3;
  }
  if (noiseDb <= 65) {
    return 2;
  }
  return 1;
}

void _showDormSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
