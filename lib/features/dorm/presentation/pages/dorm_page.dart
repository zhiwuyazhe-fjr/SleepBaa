import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/section_title.dart';

class DormPage extends StatelessWidget {
  const DormPage({super.key});

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
          final Dorm dorm = services.dormRepository.currentDorm;
          final String currentUserId = services.authRepository.currentUser.uid;
          final List<_DormEvent> events = _buildDormEvents(
            context,
            dorm,
            services.notificationRepository.notifications,
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
              onTap: () => _showDormSnackBar(context, '今晚 23:00 后的静音提醒已为你准备好。'),
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

                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        AppSpacing.xl,
                        horizontalPadding,
                        160,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            dorm.name,
                            style: Theme.of(
                              context,
                            ).textTheme.displayMedium?.copyWith(height: 1.05),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          _DormHeroCard(
                            onlineCount: onlineCount,
                            sleepingCount: sleepingCount,
                            quietScore: _quietStarsFor(dorm.noiseDb),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          SectionTitle(
                            title: '室友动态',
                            actionLabel: '宿舍公约',
                            onAction: () => context.push(AppRoutes.dormRules),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SizedBox(
                            height: 136,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: dorm.members.length,
                              separatorBuilder:
                                  (BuildContext context, int index) =>
                                      const SizedBox(width: AppSpacing.sm),
                              itemBuilder: (BuildContext context, int index) {
                                final DormMember member = dorm.members[index];
                                return _DormMemberCard(
                                  member: member,
                                  isCurrentUser: member.uid == currentUserId,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          const SectionTitle(title: '智能宿舍协同中心'),
                          const SizedBox(height: AppSpacing.md),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: actions.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: AppSpacing.md,
                                  mainAxisSpacing: AppSpacing.md,
                                  childAspectRatio: wideLayout ? 1.18 : 1.08,
                                ),
                            itemBuilder: (BuildContext context, int index) {
                              final _DormHubAction action = actions[index];
                              return _DormHubCard(action: action);
                            },
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          SectionTitle(
                            title: '寝室事件记录',
                            actionLabel: '查看更多',
                            onAction: () =>
                                context.push(AppRoutes.notifications),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          ...events.map(
                            (_DormEvent event) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: _DormEventTile(event: event),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
    required this.onlineCount,
    required this.sleepingCount,
    required this.quietScore,
  });

  final int onlineCount;
  final int sleepingCount;
  final int quietScore;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      border: Border.all(color: AppColors.primarySoft.withAlpha(60)),
      boxShadow: AppColors.floatingShadow,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AppColors.primarySoft.withAlpha(72),
              AppColors.surface,
              Colors.white,
            ],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Stack(
          children: <Widget>[
            Positioned(
              right: -24,
              top: -20,
              child: Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primarySoft.withAlpha(32),
                ),
              ),
            ),
            Positioned(
              left: 24,
              bottom: -42,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withAlpha(12),
                ),
              ),
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                _HeroInfoPill(label: '在线: $onlineCount 人'),
                _HeroInfoPill(label: '睡眠中: $sleepingCount 人'),
                _HeroRatingPill(score: quietScore),
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
        color: Colors.white.withAlpha(244),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primarySoft.withAlpha(70)),
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
        color: Colors.white.withAlpha(244),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primarySoft.withAlpha(70)),
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
        width: 108,
        child: Column(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    accentColor.withAlpha(210),
                    AppColors.primarySoft,
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
  const _DormHubCard({required this.action});

  final _DormHubAction action;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: action.onTap,
      border: Border.all(color: AppColors.divider),
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
            Icon(action.icon, color: AppColors.primary, size: 22),
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
  const _DormEventTile({required this.event});

  final _DormEvent event;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      color: AppColors.surfaceMuted,
      boxShadow: const <BoxShadow>[],
      onTap: event.onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: event.color,
              shape: BoxShape.circle,
            ),
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

class _DormEvent {
  const _DormEvent({
    required this.title,
    required this.detail,
    required this.color,
    required this.timeLabel,
    required this.onTap,
  });

  final String title;
  final String detail;
  final Color color;
  final String timeLabel;
  final VoidCallback onTap;
}

List<_DormEvent> _buildDormEvents(
  BuildContext context,
  Dorm dorm,
  List<NotificationItem> notifications,
) {
  NotificationItem? dormNotification;
  for (final NotificationItem item in notifications) {
    if (item.category == NotificationCategory.dorm) {
      dormNotification = item;
      break;
    }
  }

  DormMember? latestMember;
  for (final DormMember member in dorm.members) {
    if (latestMember == null ||
        member.lastActiveAt.isAfter(latestMember.lastActiveAt)) {
      latestMember = member;
    }
  }

  final List<_DormEvent> items = <_DormEvent>[
    if (dormNotification != null)
      _DormEvent(
        title: dormNotification.title,
        detail: dormNotification.body,
        color: AppColors.primary,
        timeLabel: _relativeTimeLabel(dormNotification.createdAt),
        onTap: () => context.push(AppRoutes.notifications),
      ),
    if (latestMember != null)
      _DormEvent(
        title: '${latestMember.name} 刚刚更新了状态',
        detail: latestMember.note,
        color: const Color(0xFFF1A936),
        timeLabel: _relativeTimeLabel(latestMember.lastActiveAt),
        onTap: () => _showDormSnackBar(context, '今晚的最新室友动态已经同步到宿舍面板。'),
      ),
    if (dorm.rules.isNotEmpty)
      _DormEvent(
        title: '今晚默认执行安静公约',
        detail: dorm.rules.first.title,
        color: const Color(0xFF63D4ED),
        timeLabel: '规则',
        onTap: () => context.push(AppRoutes.dormRules),
      ),
  ];

  return items;
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

String _relativeTimeLabel(DateTime dateTime) {
  final Duration difference = DateTime.now().difference(dateTime);
  if (difference.inMinutes < 1) {
    return '刚刚';
  }
  if (difference.inHours < 1) {
    return '${difference.inMinutes} 分钟前';
  }
  if (difference.inDays < 1) {
    return '${difference.inHours} 小时前';
  }
  return '${difference.inDays} 天前';
}

void _showDormSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
