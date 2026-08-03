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
import 'package:sleep_dorm_app/core/interaction/app_haptics.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_message_record_card.dart';
import 'package:sleep_dorm_app/core/utils/dorm_quiet_rating.dart';
import 'package:sleep_dorm_app/core/widgets/modals/app_modal.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';
import 'package:sleep_dorm_app/core/widgets/section_title.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/pages/dorm_invite_page.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/support/dorm_event_records.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/support/dorm_member_status_presenter.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/widgets/dorm_member_avatar.dart';

const List<String> _gentleReminderPresets = <String>[
  '如果方便的话，今晚一起把宿舍的环境再放轻一点',
  '被月亮绑架了？该回地球了，宿舍要关门啦～',
];

enum _GentleReminderTab { content, target }

class DormPage extends StatefulWidget {
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
  static const ValueKey<String> currentStatusMoreKey = ValueKey<String>(
    'dorm-current-status-more',
  );
  static const ValueKey<String> heroSettingsKey = ValueKey<String>(
    'dorm-hero-settings',
  );
  static const ValueKey<String> passiveToastKey = ValueKey<String>(
    'dorm-passive-toast',
  );

  @override
  State<DormPage> createState() => _DormPageState();
}

class _DormPageState extends State<DormPage> {
  static const String _liveStatusPageId = 'dorm-page';

  AppServices? _dormNoiseRecordingServices;
  AppServices? _dormLiveStatusServices;
  bool _ledgerAggregateFlushScheduled = false;
  bool _liveStatusSyncScheduled = false;
  bool? _lastLiveStatusActive;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppServices services = context.appServices;
    if (!identical(_dormNoiseRecordingServices, services)) {
      _dormNoiseRecordingServices?.dormRepository.removeListener(
        _scheduleDormAggregateRecordingAfterBuild,
      );
      _dormNoiseRecordingServices = services;
      services.dormRepository.addListener(
        _scheduleDormAggregateRecordingAfterBuild,
      );
      _scheduleDormAggregateRecordingAfterBuild();
    }
    if (!identical(_dormLiveStatusServices, services)) {
      _dormLiveStatusServices?.dormLiveStatusController.setPageActive(
        pageId: _liveStatusPageId,
        active: false,
      );
      _dormLiveStatusServices = services;
    }
    _scheduleDormLiveStatusSync();
  }

  /// [maybeRecordDormAggregate] notifies the ledger; must not run inside [build].
  void _scheduleDormAggregateRecordingAfterBuild() {
    if (!mounted || _ledgerAggregateFlushScheduled) {
      return;
    }
    _ledgerAggregateFlushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ledgerAggregateFlushScheduled = false;
      if (!mounted) {
        return;
      }
      final AppServices services = context.appServices;
      services.dormNoiseSampleLedger.maybeRecordDormAggregate(
        services.dormRepository.currentDorm.noiseDb,
      );
    });
  }

  void _scheduleDormLiveStatusSync() {
    if (!mounted || _liveStatusSyncScheduled) {
      return;
    }
    _liveStatusSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _liveStatusSyncScheduled = false;
      if (!mounted) {
        return;
      }
      final AppServices services = context.appServices;
      final bool shouldPoll = _isDormPageVisible(context);
      if (_lastLiveStatusActive == shouldPoll) {
        return;
      }
      _lastLiveStatusActive = shouldPoll;
      services.dormLiveStatusController.setPageActive(
        pageId: _liveStatusPageId,
        active: shouldPoll,
      );
    });
  }

  bool _isDormPageVisible(BuildContext context) {
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    return TickerMode.valuesOf(context).enabled &&
        (route == null || route.isCurrent);
  }

  @override
  void dispose() {
    _dormNoiseRecordingServices?.dormRepository.removeListener(
      _scheduleDormAggregateRecordingAfterBuild,
    );
    _dormLiveStatusServices?.dormLiveStatusController.setPageActive(
      pageId: _liveStatusPageId,
      active: false,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    _scheduleDormLiveStatusSync();
    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          services.authRepository,
          services.dormRepository,
          services.notificationRepository,
          services.dormLiveStatusController,
          services.dormNoiseSampleLedger,
          services.interferenceProbeController,
        ]),
        builder: (BuildContext context, Widget? child) {
          final Dorm dorm = services.dormRepository.currentDorm;
          if (dorm.id.isEmpty) {
            return const DormInvitePage();
          }
          final bool showDormPresence = dorm.locationAnchor != null;
          final double spatialAvgDb = averageNoiseDbForReturnedMembers(
            members: dorm.members,
            dormAggregateNoiseDb: dorm.noiseDb,
            showPresence: showDormPresence,
          );
          final List<DormNoiseSample> noiseSeries =
              services.dormNoiseSampleLedger.samples;
          final List<DormNoiseSample> forRating = noiseSeries.isEmpty
              ? <DormNoiseSample>[
                  DormNoiseSample(
                    decibel: spatialAvgDb,
                    timestamp: DateTime.now(),
                  ),
                ]
              : noiseSeries;
          final int quietStars = computeDormQuietRating(forRating).stars;
          final UserProfile currentUser = services.authRepository.currentUser;
          final NightMoodPalette palette = context.nightMoodPalette;
          final DateTime liveNow =
              services.dormLiveStatusController.currentTime;
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

          return _DormPencilScaffold(
            dorm: dorm,
            palette: palette,
            currentUser: currentUser,
            currentUserId: currentUserId,
            liveNow: liveNow,
            quietStars: quietStars,
            dormPulseBadge: dormPulseBadge,
            actions: actions,
            events: events,
          );
        },
      ),
    );
  }
}

class _DormPencilScaffold extends StatelessWidget {
  const _DormPencilScaffold({
    required this.dorm,
    required this.palette,
    required this.currentUser,
    required this.currentUserId,
    required this.liveNow,
    required this.quietStars,
    required this.actions,
    required this.events,
    this.dormPulseBadge,
  });

  final Dorm dorm;
  final NightMoodPalette palette;
  final UserProfile currentUser;
  final String currentUserId;
  final DateTime liveNow;
  final int quietStars;
  final DormHonorBadge? dormPulseBadge;
  final List<_DormHubAction> actions;
  final List<DormEventRecord> events;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return SafeArea(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double widthFactor = _dormPageWidthFactor(constraints.maxWidth);
          return DecoratedBox(
            key: DormPage.drawerSheetKey,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  appColors.accentSoft.withAlpha(18),
                  appColors.pageBackground,
                  appColors.pageBackground,
                ],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 112),
              child: Align(
                alignment: Alignment.topCenter,
                child: FractionallySizedBox(
                  widthFactor: widthFactor,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.lg,
                        AppSpacing.xl,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _DormAnimatedSection(
                            order: 0,
                            child: _DormHeader(
                              dorm: dorm,
                              dormPulseBadge: dormPulseBadge,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _DormAnimatedSection(
                            order: 1,
                            child: _DormHeroCard(
                              key: DormPage.heroCardKey,
                              palette: palette,
                              onlineLabel: dormOnlineCountLabel(
                                dorm.members,
                                now: liveNow,
                              ),
                              quietScore: quietStars,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _DormAnimatedSection(
                            order: 2,
                            child: SectionTitle(
                              title: '当前室友状态',
                              actionLabel: '查看全部',
                              actionKey: DormPage.currentStatusMoreKey,
                              variant: SectionTitleVariant.dorm,
                              onAction: () =>
                                  context.push(AppRoutes.dormCurrentStatus),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _DormAnimatedSection(
                            order: 3,
                            child: SizedBox(
                              key: DormPage.roommateListKey,
                              height: _roommateStripHeight(
                                constraints.maxWidth,
                              ),
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: dorm.members.length,
                                separatorBuilder:
                                    (BuildContext context, int index) =>
                                        const SizedBox(width: AppSpacing.md),
                                itemBuilder: (BuildContext context, int index) {
                                  final DormMember member = dorm.members[index];
                                  return _DormMemberCard(
                                    member: member,
                                    showPresence: shouldShowDormPresence(
                                      dorm,
                                      member,
                                    ),
                                    isCurrentUser: member.uid == currentUserId,
                                    currentUserProfile:
                                        member.uid == currentUserId
                                        ? currentUser
                                        : null,
                                    onTap: () => context.push(
                                      AppRoutes.dormMemberLocation(member.uid),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          _DormAnimatedSection(
                            order: 4,
                            child: const SectionTitle(
                              title: '智能寝室协同中心',
                              variant: SectionTitleVariant.dorm,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _DormAnimatedSection(
                            order: 5,
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: actions.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: constraints.maxWidth >= 720
                                        ? 4
                                        : 2,
                                    crossAxisSpacing: AppSpacing.sm,
                                    mainAxisSpacing: AppSpacing.sm,
                                    childAspectRatio:
                                        constraints.maxWidth >= 720
                                        ? 1.2
                                        : 1.38,
                                  ),
                              itemBuilder: (BuildContext context, int index) {
                                return _DormHubCard(
                                  action: actions[index],
                                  palette: palette,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          _DormAnimatedSection(
                            order: 6,
                            child: SectionTitle(
                              title: '寝室状态记录',
                              actionLabel: '查看更多',
                              actionKey: DormPage.eventMoreKey,
                              variant: SectionTitleVariant.dorm,
                              onAction: () =>
                                  context.push(AppRoutes.dormStatus),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _DormAnimatedSection(
                            order: 7,
                            child: Column(
                              children: events
                                  .map((DormEventRecord event) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: AppSpacing.xs,
                                      ),
                                      child: _DormEventTile(
                                        event: event,
                                        onTap: () =>
                                            context.push(AppRoutes.dormStatus),
                                      ),
                                    );
                                  })
                                  .toList(growable: false),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DormAnimatedSection extends StatelessWidget {
  const _DormAnimatedSection({required this.order, required this.child});

  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + order * 35),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * AppSpacing.sm),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _DormHeader extends StatelessWidget {
  const _DormHeader({required this.dorm, this.dormPulseBadge});

  final Dorm dorm;
  final DormHonorBadge? dormPulseBadge;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Text(
            dorm.name,
            style: AppTypography.heroTitle(
              textTheme,
            ).copyWith(color: appColors.textPrimary),
          ),
        ),
        if (dormPulseBadge != null) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          _DormPulseBadgePill(badge: dormPulseBadge!),
        ],
      ],
    );
  }
}

class _DormHeroCard extends StatelessWidget {
  const _DormHeroCard({
    super.key,
    required this.palette,
    required this.onlineLabel,
    required this.quietScore,
  });

  final NightMoodPalette palette;
  final String onlineLabel;
  final int quietScore;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: EdgeInsets.zero,
      boxShadow: AppColors.floatingShadow,
      borderRadius: AppRadius.card,
      child: Container(
        key: DormPage.heroGradientKey,
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 128),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: AppRadius.card,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              appColors.heroEnd,
              appColors.heroMid,
              appColors.heroStart,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '宿舍脉搏',
                    style: AppTypography.chip(textTheme).copyWith(
                      color: AppColors.onDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _HeroActionPill(
                  key: DormPage.heroSettingsKey,
                  label: '寝室设置',
                  onTap: () => context.push(AppRoutes.profileAccountDorm),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '今晚宿舍整体状态平稳',
              style: AppTypography.sectionTitle(
                textTheme,
              ).copyWith(color: AppColors.onDark),
            ),
            const SizedBox(height: AppSpacing.sm),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final Widget onlinePill = _HeroInfoPill(label: onlineLabel);
                final Widget ratingPill = _HeroRatingPill(score: quietScore);
                if (constraints.maxWidth < 280) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Align(alignment: Alignment.centerLeft, child: onlinePill),
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ratingPill,
                      ),
                    ],
                  );
                }
                return Row(
                  children: <Widget>[
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: onlinePill,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Align(alignment: Alignment.centerRight, child: ratingPill),
                  ],
                );
              },
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
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: appColors.surfaceMuted.withAlpha(236),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(badge.icon, size: 16, color: appColors.accent),
          const SizedBox(width: AppSpacing.xs),
          Text(
            badge.label,
            style: AppTypography.meta(textTheme).copyWith(
              color: appColors.textPrimary,
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
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: appColors.surfaceMuted.withAlpha(236),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.meta(
          textTheme,
        ).copyWith(color: appColors.textPrimary, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _HeroActionPill extends StatelessWidget {
  const _HeroActionPill({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Material(
      color: appColors.surfaceMuted.withAlpha(236),
      borderRadius: AppRadius.pill,
      child: InkWell(
        enableFeedback: false,
        borderRadius: AppRadius.pill,
        onTap: AppHaptics.navigationHandler(onTap),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.settings_rounded,
                size: AppSpacing.sm,
                color: appColors.textPrimary,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                label,
                style: AppTypography.chip(textTheme).copyWith(
                  color: appColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
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
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: appColors.surfaceMuted.withAlpha(236),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '安静等级',
            style: AppTypography.meta(textTheme).copyWith(
              color: appColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          ...List<Widget>.generate(
            score,
            (_) => Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Icon(
                Icons.star_rounded,
                size: 16,
                color: appColors.accent,
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
    required this.showPresence,
    required this.isCurrentUser,
    this.currentUserProfile,
    this.onTap,
  });

  final DormMember member;
  final bool showPresence;
  final bool isCurrentUser;
  final UserProfile? currentUserProfile;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color accentColor = _memberColor(member.status, palette, appColors);
    final String? resolvedBadgeId = isCurrentUser
        ? currentUserProfile?.displayBadgeId ?? member.displayBadgeId
        : member.displayBadgeId;
    final HonorBadge? badge = honorBadgeById(resolvedBadgeId);
    final avatarResource = isCurrentUser
        ? currentUserProfile?.avatarResource ?? member.avatarResource
        : member.avatarResource;
    final String fallbackSeed =
        isCurrentUser &&
            currentUserProfile?.avatarFallbackSeed?.trim().isNotEmpty == true
        ? currentUserProfile!.avatarFallbackSeed!
        : member.name;
    return Semantics(
      button: true,
      label: '${member.name}舍友详情',
      child: InkWell(
        enableFeedback: false,
        borderRadius: AppRadius.control,
        onTap: AppHaptics.navigationHandler(onTap),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: SizedBox(
            width: 64,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: accentColor, width: 2),
                      ),
                      child: DormMemberAvatar(
                        key: ValueKey<String>(
                          'dorm-member-avatar-${member.uid}',
                        ),
                        size: 44,
                        accentColor: accentColor,
                        resource: avatarResource,
                        fallbackSeed: fallbackSeed,
                      ),
                    ),
                    if (badge != null)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          key: ValueKey<String>(
                            'dorm-member-badge-${member.uid}',
                          ),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: appColors.accent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: appColors.surface,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.star_rounded,
                            size: 10,
                            color: appColors.surface,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  isCurrentUser ? '${member.name} · 你' : member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.meta(textTheme).copyWith(
                    color: appColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
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
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return AppCard(
      onTap: action.onTap,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      borderRadius: AppRadius.card,
      boxShadow: const <BoxShadow>[],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.iconContainer,
                  color: appColors.accentSoft,
                ),
                alignment: Alignment.center,
                child: Icon(action.icon, color: appColors.accentDeep, size: 18),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.cardTitle(textTheme).copyWith(
              color: appColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            action.detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMuted(
              textTheme,
            ).copyWith(color: appColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _DormEventTile extends StatelessWidget {
  const _DormEventTile({required this.event, required this.onTap});

  final DormEventRecord event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool active = _isDormHomeActiveRecord(event);
    final AppSemanticColors appColors = context.appColors;
    return AppMessageRecordCard(
      onTap: onTap,
      icon: event.icon,
      title: event.title,
      detail: event.detail,
      highlighted: active,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              event.timeLabel,
              style: AppTypography.chip(Theme.of(context).textTheme).copyWith(
                color: active ? appColors.textPrimary : appColors.textSecondary,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.chevron_right_rounded, color: appColors.textSecondary),
        ],
      ),
    );
  }
}

bool _isDormHomeActiveRecord(DormEventRecord event) {
  return event.title.contains('入睡') ||
      event.title.contains('睡眠') ||
      event.title.contains('噪') ||
      event.title.contains('公约');
}

Color _memberColor(
  DormMemberStatus status,
  NightMoodPalette palette,
  AppSemanticColors appColors,
) {
  return switch (status) {
    DormMemberStatus.sleeping => palette.primary,
    DormMemberStatus.quiet => palette.calmBlue,
    DormMemberStatus.away => appColors.textSecondary,
    DormMemberStatus.active => palette.welcomeAccentColor,
  };
}

double _dormPageWidthFactor(double maxWidth) {
  if (maxWidth >= 1200) {
    return 0.42;
  }
  if (maxWidth >= 900) {
    return 0.52;
  }
  if (maxWidth >= 700) {
    return 0.72;
  }
  return 1;
}

double _roommateStripHeight(double maxWidth) {
  return maxWidth >= 700 ? 104 : 96;
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
      await showAppModal<_GentleReminderSelection>(
        context,
        spec: AppRichActionSheetSpec<_GentleReminderSelection>(
          builder: (BuildContext sheetContext) {
            final double maxHeight =
                MediaQuery.sizeOf(sheetContext).height * 0.68;
            return _GentleReminderSheet(
              members: selectableMembers,
              maxHeight: maxHeight,
            );
          },
        ),
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
      message: selection.message,
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
  _GentleReminderTab _activeTab = _GentleReminderTab.content;
  String? _selectedPreset;
  late final TextEditingController _customMessageController;

  @override
  void initState() {
    super.initState();
    _customMessageController = TextEditingController();
  }

  @override
  void dispose() {
    _customMessageController.dispose();
    super.dispose();
  }

  String get _resolvedMessage {
    final String customMessage = _customMessageController.text.trim();
    if (customMessage.isNotEmpty) {
      return customMessage;
    }
    return _selectedPreset?.trim() ?? '';
  }

  bool get _canSubmit => _selectedUid != null && _resolvedMessage.isNotEmpty;

  void _selectPreset(String message) {
    setState(() {
      _selectedPreset = message;
      _customMessageController.clear();
    });
  }

  Widget _buildTabButton(
    BuildContext context, {
    required _GentleReminderTab tab,
    required String label,
  }) {
    final bool selected = _activeTab == tab;
    final AppSemanticColors appColors = context.appColors;
    return Expanded(
      child: GestureDetector(
        onTap: AppHaptics.selectionHandler(
          () => setState(() => _activeTab = tab),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? appColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.meta(Theme.of(context).textTheme).copyWith(
              color: selected
                  ? appColors.textOnAccent
                  : appColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentTab(BuildContext context) {
    final String customMessage = _customMessageController.text.trim();
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '选择提醒内容',
          style: AppTypography.panelTitle(
            textTheme,
          ).copyWith(color: appColors.textPrimary, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '先选一句更合适的表达，也可以自己写一句更贴心的话。',
          style: AppTypography.body(
            textTheme,
          ).copyWith(color: appColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        ..._gentleReminderPresets.map(
          (String message) => InkWell(
            enableFeedback: false,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: AppHaptics.selectionHandler(() => _selectPreset(message)),
            child: Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: _selectedPreset == message && customMessage.isEmpty
                    ? appColors.accentSoft
                    : appColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: _selectedPreset == message && customMessage.isEmpty
                      ? appColors.accentDeep
                      : Colors.transparent,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      _selectedPreset == message && customMessage.isEmpty
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      message,
                      style: AppTypography.body(textTheme).copyWith(
                        color: appColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _customMessageController,
          minLines: 1,
          maxLines: 3,
          onChanged: (String value) {
            if (value.trim().isNotEmpty) {
              setState(() => _selectedPreset = null);
              return;
            }
            setState(() {});
          },
          decoration: InputDecoration(
            hintText: 'Others……',
            filled: true,
            fillColor: appColors.surfaceMuted,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTargetTab(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '选择要提醒的舍友',
          style: AppTypography.panelTitle(
            textTheme,
          ).copyWith(color: appColors.textPrimary, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '我们会用更温和的方式送达提醒，不会直接替你做生硬通知。',
          style: AppTypography.body(
            textTheme,
          ).copyWith(color: appColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          value: !_anonymous,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('是否使用昵称实名发送'),
          subtitle: Text(
            _anonymous ? '默认显示“您的舍友”' : '将显示你的昵称',
            style: AppTypography.bodyMuted(
              textTheme,
            ).copyWith(color: appColors.textSecondary),
          ),
          onChanged: (bool? value) {
            setState(() => _anonymous = !(value ?? false));
          },
        ),
        const SizedBox(height: AppSpacing.md),
        ...widget.members.map(
          (DormMember member) => InkWell(
            enableFeedback: false,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: AppHaptics.selectionHandler(
              () => setState(() => _selectedUid = member.uid),
            ),
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
                          style: AppTypography.cardTitle(textTheme).copyWith(
                            color: appColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          member.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMuted(
                            textTheme,
                          ).copyWith(color: appColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return AppRichActionSheetScaffold(
      title: '委婉提醒',
      description: '先选内容，再选对象；两个栏目可以来回切换。',
      maxHeight: widget.maxHeight,
      header: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: appColors.surfaceMuted,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: <Widget>[
            _buildTabButton(
              context,
              tab: _GentleReminderTab.content,
              label: '内容',
            ),
            _buildTabButton(
              context,
              tab: _GentleReminderTab.target,
              label: '对象',
            ),
          ],
        ),
      ),
      footer: PrimaryButton(
        label: '发送委婉提醒',
        onPressed: !_canSubmit
            ? null
            : () {
                Navigator.of(context).pop(
                  _GentleReminderSelection(
                    targetUid: _selectedUid!,
                    anonymous: _anonymous,
                    message: _resolvedMessage,
                  ),
                );
              },
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: _activeTab == _GentleReminderTab.content
            ? KeyedSubtree(
                key: const ValueKey<String>('gentle-reminder-content'),
                child: _buildContentTab(context),
              )
            : KeyedSubtree(
                key: const ValueKey<String>('gentle-reminder-target'),
                child: _buildTargetTab(context),
              ),
      ),
    );
  }
}

class _GentleReminderSelection {
  const _GentleReminderSelection({
    required this.targetUid,
    required this.anonymous,
    required this.message,
  });

  final String targetUid;
  final bool anonymous;
  final String message;
}
