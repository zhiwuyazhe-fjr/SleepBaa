import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';
import 'package:sleep_dorm_app/core/widgets/section_title.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/pages/dorm_invite_page.dart';
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
  static const ValueKey<String> passiveToastKey = ValueKey<String>(
    'dorm-passive-toast',
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
          final Dorm dorm = services.dormRepository.currentDorm;
          if (dorm.id.isEmpty) {
            return const DormInvitePage();
          }
          final UserProfile currentUser = services.authRepository.currentUser;
          final NightMoodPalette palette = context.nightMoodPalette;
          final String currentUserId = currentUser.uid;
          final List<DormEventRecord> events = buildDormEventRecords(
            dorm: dorm,
            notifications: services.notificationRepository.notifications,
            palette: palette,
          );
          final DormPendingRuleProposal? pendingProposal =
              dorm.pendingRuleProposal;
          final bool hasPendingRuleDot =
              pendingProposal != null &&
              pendingProposal.proposerUid != currentUserId &&
              pendingProposal.needsReviewFrom(currentUserId);
          final int onlineCount = dorm.members
              .where(
                (DormMember member) => member.status != DormMemberStatus.away,
              )
              .length;
          final int sleepingCount = dorm.members
              .where((DormMember member) => member.sleepModeActive)
              .length;
          final String? selectedDormBadgeId = currentUser.resolveDormBadgeId(
            dorm.earnedDormBadgeIds,
          );
          final DormHonorBadge? dormPulseBadge = currentUser.showDormPulseBadge
              ? dormHonorBadgeById(selectedDormBadgeId)
              : null;
          final List<_DormHubAction> actions = <_DormHubAction>[
            _DormHubAction(
              title: '宿舍公约',
              detail: hasPendingRuleDot ? '有新规则待确认' : '查看详情',
              icon: Icons.calendar_today_rounded,
              showDot: hasPendingRuleDot,
              onTap: () => context.push(
                hasPendingRuleDot
                    ? '${AppRoutes.dormRules}?review=1'
                    : AppRoutes.dormRules,
              ),
            ),
            _DormHubAction(
              title: '静音模式',
              detail: '今晚执行',
              icon: Icons.volume_off_rounded,
              onTap: () => _showDormToast(context, '今晚 23:00 后的静音提醒已经准备好了。'),
            ),
            _DormHubAction(
              title: '宿舍勋章',
              detail: '查看勋章',
              icon: Icons.emoji_events_rounded,
              onTap: () => context.push(AppRoutes.dormBadges),
            ),
            _DormHubAction(
              title: '委婉提醒',
              detail: '发送提醒',
              icon: Icons.notifications_active_rounded,
              onTap: () => _showGentleReminderPicker(
                context: context,
                services: services,
                dorm: dorm,
                currentUserId: currentUserId,
              ),
            ),
          ];

          return SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool wideLayout = constraints.maxWidth >= 720;
                final double horizontalPadding = wideLayout
                    ? AppSpacing.xxxl
                    : AppSpacing.xl;
                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            palette.primarySoft.withAlpha(28),
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
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      dorm.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .displayMedium
                                          ?.copyWith(height: 1.05),
                                    ),
                                  ),
                                  if (dormPulseBadge != null) ...<Widget>[
                                    const SizedBox(width: AppSpacing.sm),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: _DormPulseBadgePill(
                                        badge: dormPulseBadge,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _DormHeroCard(
                                key: heroCardKey,
                                palette: palette,
                                onlineCount: onlineCount,
                                sleepingCount: sleepingCount,
                                quietScore: _quietStarsFor(dorm.noiseDb),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      top: 112,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: DraggableScrollableSheet(
                            initialChildSize: wideLayout ? 0.72 : 0.74,
                            minChildSize: wideLayout ? 0.7 : 0.72,
                            maxChildSize: 1,
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
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.md),
                                        SectionTitle(
                                          title: '舍友动态',
                                          actionLabel: '邀请舍友',
                                          onAction: () => context.push(
                                            AppRoutes.dormInvite,
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.md),
                                        SizedBox(
                                          key: roommateListKey,
                                          height: 188,
                                          child: ListView.separated(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: dorm.members.length,
                                            separatorBuilder: (_, index) =>
                                                const SizedBox(
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
                                                    currentUserProfile:
                                                        member.uid ==
                                                            currentUserId
                                                        ? services
                                                              .authRepository
                                                              .currentUser
                                                        : null,
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
                                              (
                                                BuildContext context,
                                                int index,
                                              ) {
                                                return _DormHubCard(
                                                  action: actions[index],
                                                  palette: palette,
                                                );
                                              },
                                        ),
                                        const SizedBox(height: AppSpacing.xl),
                                        SectionTitle(
                                          title: '寝室状态记录',
                                          actionLabel: '查看更多',
                                          actionKey: eventMoreKey,
                                          onAction: () => context.push(
                                            AppRoutes.dormStatus,
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.md),
                                        ...events.map(
                                          (DormEventRecord event) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: AppSpacing.sm,
                                            ),
                                            child: _DormEventTile(
                                              event: event,
                                              onActionTap:
                                                  event.actionRoute == null
                                                  ? null
                                                  : () => context.push(
                                                      event.actionRoute!,
                                                    ),
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
  });

  final NightMoodPalette palette;
  final int onlineCount;
  final int sleepingCount;
  final int quietScore;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      boxShadow: AppColors.floatingShadow,
      child: Container(
        key: DormPage.heroGradientKey,
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 196),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '宿舍脉搏',
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
      ),
    );
  }
}

class _DormPulseBadgePill extends StatelessWidget {
  const _DormPulseBadgePill({required this.badge});

  final DormHonorBadge badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(236),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(badge.icon, size: 16, color: const Color(0xFF076B5E)),
          const SizedBox(width: AppSpacing.xs),
          Text(
            badge.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
            (_) => const Padding(
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
  const _DormMemberCard({
    required this.member,
    required this.isCurrentUser,
    this.currentUserProfile,
  });

  final DormMember member;
  final bool isCurrentUser;
  final UserProfile? currentUserProfile;

  @override
  Widget build(BuildContext context) {
    final Color accentColor = _memberColor(member.status);
    final String? resolvedBadgeId =
        currentUserProfile?.displayBadgeId ?? member.displayBadgeId;
    final HonorBadge? badge = honorBadgeById(resolvedBadgeId);
    final Uint8List? avatarBytes = isCurrentUser
        ? currentUserProfile?.avatarBytes
        : null;
    final String? avatarUrl = isCurrentUser
        ? currentUserProfile?.avatarUrl ?? member.avatarUrl
        : member.avatarUrl;
    final String fallbackSeed =
        currentUserProfile?.avatarFallbackSeed?.trim().isNotEmpty == true
        ? currentUserProfile!.avatarFallbackSeed!
        : member.name;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      border: Border.all(color: AppColors.divider),
      boxShadow: const <BoxShadow>[],
      child: SizedBox(
        width: 136,
        height: 154,
        child: Column(
          children: <Widget>[
            _DormMemberAvatar(
              radius: 26,
              accentColor: accentColor,
              avatarBytes: avatarBytes,
              avatarUrl: avatarUrl,
              fallbackSeed: fallbackSeed,
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
              height: 34,
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
            if (badge != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6B400).withAlpha(28),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: Color(0xFFF6B400),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        badge.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF9B6A00),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _DormMemberAvatar extends StatelessWidget {
  const _DormMemberAvatar({
    required this.radius,
    required this.accentColor,
    required this.fallbackSeed,
    this.avatarBytes,
    this.avatarUrl,
  });

  final double radius;
  final Color accentColor;
  final Uint8List? avatarBytes;
  final String? avatarUrl;
  final String fallbackSeed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accentColor.withAlpha(42),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (avatarBytes != null && avatarBytes!.isNotEmpty) {
      return Image.memory(
        avatarBytes!,
        fit: BoxFit.cover,
        width: radius * 2,
        height: radius * 2,
      );
    }
    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      return Image.network(
        avatarUrl!,
        fit: BoxFit.cover,
        width: radius * 2,
        height: radius * 2,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) {
              return _buildFallback(context);
            },
      );
    }
    return _buildFallback(context);
  }

  Widget _buildFallback(BuildContext context) {
    final String fallbackText = fallbackSeed.trim().isEmpty
        ? '?'
        : fallbackSeed.characters.first.toUpperCase();
    return Container(
      color: accentColor.withAlpha(24),
      alignment: Alignment.center,
      child: Text(
        fallbackText,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: accentColor,
          fontWeight: FontWeight.w800,
        ),
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
    this.showDot = false,
  });

  final String title;
  final String detail;
  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;
}

class _DormHubCard extends StatelessWidget {
  const _DormHubCard({required this.action, required this.palette});

  final _DormHubAction action;
  final NightMoodPalette palette;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: action.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: palette.primaryHighlight,
                ),
                alignment: Alignment.center,
                child: Icon(action.icon, color: palette.primaryDeep),
              ),
              const Spacer(),
              if (action.showDot)
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            action.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            action.detail,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _DormEventTile extends StatelessWidget {
  const _DormEventTile({
    required this.event,
    required this.onTap,
    this.onActionTap,
  });

  final DormEventRecord event;
  final VoidCallback onTap;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: event.color.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(event.icon, color: event.color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  event.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  event.detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (onActionTap != null)
            TextButton(
              onPressed: onActionTap,
              style: TextButton.styleFrom(
                foregroundColor: event.color,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
              ),
              child: Text(
                event.timeLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: event.color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            Text(
              event.timeLabel,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
            ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

Color _memberColor(DormMemberStatus status) {
  return switch (status) {
    DormMemberStatus.sleeping => const Color(0xFF4458D8),
    DormMemberStatus.quiet => const Color(0xFF2D9272),
    DormMemberStatus.away => const Color(0xFF8A8F9F),
    DormMemberStatus.active => const Color(0xFFF39A3C),
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

Future<void> _showGentleReminderPicker({
  required BuildContext context,
  required AppServices services,
  required Dorm dorm,
  required String currentUserId,
}) async {
  final List<DormMember> selectableMembers = dorm.members
      .where((DormMember member) => member.uid != currentUserId)
      .toList(growable: false);
  if (selectableMembers.isEmpty) {
    _showDormToast(context, '当前还没有可提醒的舍友。');
    return;
  }

  final _GentleReminderSelection? selection =
      await showModalBottomSheet<_GentleReminderSelection>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext sheetContext) {
          final double bottomGap =
              MediaQuery.viewPaddingOf(sheetContext).bottom + 88;
          final double maxHeight =
              MediaQuery.sizeOf(sheetContext).height * 0.68;
          return Padding(
            padding: EdgeInsets.only(bottom: bottomGap),
            child: _GentleReminderSheet(
              members: selectableMembers,
              maxHeight: maxHeight,
            ),
          );
        },
      );

  if (selection == null ||
      selection.targetUid.trim().isEmpty ||
      !context.mounted) {
    return;
  }

  try {
    await services.dormFacade.sendGentleReminder(
      targetUid: selection.targetUid,
      anonymous: selection.anonymous,
    );
    if (context.mounted) {
      _showDormToast(
        context,
        selection.anonymous ? '已匿名生成委婉提醒。' : '已按昵称实名生成委婉提醒。',
      );
    }
  } catch (error) {
    if (context.mounted) {
      _showDormToast(context, '发送失败：$error');
    }
  }
}

void _showDormToast(BuildContext context, String message) {
  notifyPassiveToast(
    context,
    message: message,
    toastKey: DormPage.passiveToastKey,
  );
}

class _GentleReminderSheet extends StatefulWidget {
  const _GentleReminderSheet({required this.members, required this.maxHeight});

  final List<DormMember> members;
  final double maxHeight;

  @override
  State<_GentleReminderSheet> createState() => _GentleReminderSheetState();
}

class _GentleReminderSheetState extends State<_GentleReminderSheet> {
  String? _selectedUid;
  bool _anonymous = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.maxHeight),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '选择要提醒的舍友',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '我们会用更温和的方式生成提醒文案，不会直接替你做生硬通知。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: const VisualDensity(
                    horizontal: -2,
                    vertical: -2,
                  ),
                  value: !_anonymous,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('是否使用昵称实名发送'),
                  subtitle: Text(
                    _anonymous ? '默认显示“您的舍友”' : '将显示你的昵称',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  onChanged: (bool? value) {
                    setState(() => _anonymous = !(value ?? false));
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                ...widget.members.map(
                  (DormMember member) => InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    onTap: () => setState(() => _selectedUid = member.uid),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              _selectedUid == member.uid
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  member.name,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  member.note,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: '生成提醒文案',
                  onPressed: _selectedUid == null
                      ? null
                      : () {
                          Navigator.of(context).pop(
                            _GentleReminderSelection(
                              targetUid: _selectedUid!,
                              anonymous: _anonymous,
                            ),
                          );
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GentleReminderSelection {
  const _GentleReminderSelection({
    required this.targetUid,
    required this.anonymous,
  });

  final String targetUid;
  final bool anonymous;
}
