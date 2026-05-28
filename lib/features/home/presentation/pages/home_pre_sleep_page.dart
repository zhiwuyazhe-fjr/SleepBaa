import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/app_typography.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/interaction/app_haptics.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/core/widgets/home_metric_card.dart';
import 'package:sleep_dorm_app/core/widgets/quick_action_icon_button.dart';
import 'package:sleep_dorm_app/core/widgets/section_title.dart';
import 'package:sleep_dorm_app/features/home/presentation/widgets/home_hero_pair.dart';
import 'package:sleep_dorm_app/features/home/presentation/widgets/home_quick_actions.dart';
import 'package:sleep_dorm_app/features/home/presentation/widgets/home_widgets.dart';

List<NightRecommendation> displayedTonightRecommendations(
  List<NightRecommendation> recommendations,
) {
  final List<NightRecommendation> displayed = <NightRecommendation>[];

  for (final NightRecommendation recommendation in recommendations) {
    if (recommendation.type == RecommendationType.audio) {
      displayed.add(recommendation);
      break;
    }
  }

  for (final NightRecommendation recommendation in recommendations) {
    if (recommendation.type == RecommendationType.audio) {
      continue;
    }
    displayed.add(recommendation);
    if (displayed.length == 3) {
      break;
    }
  }

  if (displayed.length < 3) {
    for (final NightRecommendation recommendation in recommendations) {
      if (displayed.contains(recommendation)) {
        continue;
      }
      displayed.add(recommendation);
      if (displayed.length == 3) {
        break;
      }
    }
  }

  return displayed.toList(growable: false);
}

class HomePreSleepPage extends StatefulWidget {
  const HomePreSleepPage({super.key, this.notice});

  final String? notice;

  @override
  State<HomePreSleepPage> createState() => _HomePreSleepPageState();
}

class _HomePreSleepPageState extends State<HomePreSleepPage> {
  bool _bannerExpanded = false;
  bool _didHandleNotice = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didHandleNotice) {
      return;
    }
    final String normalizedNotice = widget.notice?.trim() ?? '';
    if (normalizedNotice.isEmpty) {
      return;
    }
    _didHandleNotice = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (normalizedNotice == AppRoutes.feedbackSubmittedNotice) {
        notifyPassiveToast(context, message: '小眠已经收到你的晨间反馈❤️');
        return;
      }
      if (normalizedNotice == AppRoutes.feedbackReceivedNotice) {
        notifyPassiveToast(context, message: '您已经填写过晨间反馈，小眠已经收到🫡');
      }
    });
  }

  Future<void> _dismissBanner() async {
    await context.appServices.sleepCaptureRepository.clearPendingBanner();
    if (mounted) {
      setState(() {
        _bannerExpanded = false;
      });
    }
  }

  Future<void> _detectFactor(InterferenceFactorType type) async {
    final AppServices services = context.appServices;
    try {
      await services.interferenceProbeController.detectFactor(type);
      if (!mounted) {
        return;
      }
      final InterferenceFactorSnapshot snapshot = services
          .interferenceProbeController
          .currentState
          .factorOf(type);
      if (snapshot.status == InterferenceFactorStatus.denied) {
        await notifyPassiveToast(context, message: snapshot.detail);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      await notifyPassiveToast(context, message: '这次检测没成功，稍后再试一次吧。');
    }
  }

  String _metricValue(InterferenceFactorSnapshot snapshot) {
    return switch (snapshot.status) {
      InterferenceFactorStatus.measuring => '检测中...',
      InterferenceFactorStatus.denied => '去授权',
      InterferenceFactorStatus.unavailable => snapshot.gradeLabel,
      InterferenceFactorStatus.unsupported => snapshot.gradeLabel,
      InterferenceFactorStatus.error => '重试一下',
      InterferenceFactorStatus.idle => snapshot.value,
      InterferenceFactorStatus.ready => snapshot.value,
    };
  }

  Future<void> _handleRecommendationTap(
    AppServices services,
    NightRecommendation recommendation,
  ) async {
    if (recommendation.type == RecommendationType.audio) {
      context.push(AppRoutes.sleepAudioCatalog);
      return;
    }
    if (recommendation.id == 'thought-clean') {
      context.push('${AppRoutes.assistant}?flow=sleep_capture&mode=memo');
      return;
    }
    await services.sleepExperienceController.handleRecommendationTap(
      recommendation,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          services.authRepository,
          services.dormRepository,
          services.notificationRepository,
          services.recommendationRepository,
          services.settingsRepository,
          services.audioPlaybackController,
          services.sleepCaptureRepository,
          services.interferenceProbeController,
        ]),
        builder: (BuildContext context, Widget? child) {
          final UserProfile profile = services.authRepository.currentUser;
          final Dorm dorm = services.dormRepository.currentDorm;
          final List<NightRecommendation> recommendations =
              services.recommendationRepository.tonightRecommendations;
          final UserSettings settings =
              services.settingsRepository.currentSettings;
          final TonightInterferenceState interference =
              services.interferenceProbeController.currentState;
          final List<HomeQuickActionDefinition> quickActions =
              settings.showHomeQuickActions
              ? homeQuickActionDefinitionsFor(settings.homeQuickActionIds)
              : const <HomeQuickActionDefinition>[];
          final AudioTrack? currentAudioTrack =
              services.audioPlaybackController.currentTrack;
          final bool hasStartedAudio = currentAudioTrack != null;
          final int unread = services.notificationRepository
              .unreadNotifications()
              .length;
          final PendingSleepMemoBanner? pendingBanner =
              services.sleepCaptureRepository.pendingSleepMemoBanner;
          final bool showExpandedBanner =
              pendingBanner != null && _bannerExpanded;
          final List<NightRecommendation> displayedRecommendations =
              displayedTonightRecommendations(recommendations);

          if (pendingBanner == null && _bannerExpanded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _bannerExpanded = false;
                });
              }
            });
          }

          return SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints _) {
                final String greeting = _greetingFor(DateTime.now());
                final TextTheme textTheme = Theme.of(context).textTheme;
                return Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl,
                          AppSpacing.xl,
                          AppSpacing.xl,
                          108,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    '$greeting，${profile.displayName}',
                                    style: AppTypography.heroTitle(textTheme),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                _NotificationBell(
                                  unread: unread,
                                  onTap: () =>
                                      context.push(AppRoutes.notifications),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            HomeHeroPair(
                              left: SleepRiskCard(
                                riskLabel: dorm.noiseDb <= 35
                                    ? '偏低'
                                    : dorm.noiseDb <= 50
                                    ? '中等'
                                    : '偏高',
                                primaryValue: '${dorm.noiseDb} dB',
                              ),
                              right: StartSleepModeCard(
                                isAudioReady:
                                    services
                                        .audioPlaybackController
                                        .currentTrack !=
                                    null,
                                onTap: () async {
                                  await services.sleepExperienceController
                                      .enterSleepMode();
                                  if (context.mounted) {
                                    context.go(AppRoutes.homePostSleep);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            if (settings.showHomeQuickActions) ...<Widget>[
                              SectionTitle(
                                title: '快捷功能',
                                actionLabel: '编辑',
                                variant: SectionTitleVariant.dorm,
                                onAction: () => context.push(
                                  AppRoutes.homeQuickActionsEdit,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                children: <Widget>[
                                  for (
                                    int index = 0;
                                    index < quickActions.length;
                                    index++
                                  ) ...<Widget>[
                                    Expanded(
                                      child: QuickActionIconButton(
                                        icon: quickActions[index].icon,
                                        label: quickActions[index].label,
                                        onTap: () =>
                                            quickActions[index].open(context),
                                      ),
                                    ),
                                    if (index != quickActions.length - 1)
                                      const SizedBox(width: AppSpacing.xs),
                                  ],
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xl),
                            ],
                            SectionTitle(
                              title: '今晚影响因素',
                              actionLabel: '查看详情',
                              variant: SectionTitleVariant.dorm,
                              onAction: () => context.push(
                                AppRoutes.analysisInterferenceFactors,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: HomeMetricCard(
                                    icon: Icons.volume_up_outlined,
                                    label: '宿舍噪声',
                                    value: _metricValue(interference.noise),
                                    onTap: () => _detectFactor(
                                      InterferenceFactorType.noise,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: HomeMetricCard(
                                    icon: Icons.lightbulb_outline_rounded,
                                    label: '灯光环境',
                                    value: _metricValue(interference.light),
                                    onTap: () => _detectFactor(
                                      InterferenceFactorType.light,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: HomeMetricCard(
                                    icon: Icons.smartphone_rounded,
                                    label: '手机使用',
                                    value: _metricValue(
                                      interference.phoneUsage,
                                    ),
                                    onTap: () => _detectFactor(
                                      InterferenceFactorType.phoneUsage,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: HomeMetricCard(
                                    icon: Icons.favorite_border_rounded,
                                    label: '情绪压力',
                                    value: _metricValue(interference.emotion),
                                    onTap: () => _detectFactor(
                                      InterferenceFactorType.emotion,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              '点击卡片更新最新结果',
                              style: AppTypography.bodyMuted(
                                textTheme,
                              ).copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            SectionTitle(
                              title: '今晚行动建议',
                              actionLabel: '查看全部',
                              variant: SectionTitleVariant.dorm,
                              onAction: () =>
                                  context.push(AppRoutes.interventionTask),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            ...displayedRecommendations.map(
                              (NightRecommendation recommendation) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: HomeActionCard(
                                  recommendation: recommendation,
                                  displayTitle:
                                      recommendation.type ==
                                              RecommendationType.audio &&
                                          hasStartedAudio
                                      ? currentAudioTrack.title
                                      : null,
                                  showAudioTransport:
                                      recommendation.type ==
                                          RecommendationType.audio &&
                                      recommendation.executionState ==
                                          RecommendationExecutionState.playing,
                                  onTap: () async {
                                    await _handleRecommendationTap(
                                      services,
                                      recommendation,
                                    );
                                  },
                                  onPlayToggle:
                                      recommendation.type ==
                                          RecommendationType.audio
                                      ? () async {
                                          await services
                                              .sleepExperienceController
                                              .handleRecommendationTap(
                                                recommendation,
                                              );
                                        }
                                      : null,
                                  onPreviousAudio: () async {
                                    await services.sleepExperienceController
                                        .playPreviousAudio();
                                  },
                                  onNextAudio: () async {
                                    await services.sleepExperienceController
                                        .playNextAudio();
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (showExpandedBanner)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: _dismissBanner,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    Positioned(
                      top: 6,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        ignoring: pendingBanner == null,
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 320),
                            reverseDuration: const Duration(milliseconds: 260),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder:
                                (Widget child, Animation<double> animation) {
                                  final Animation<Offset> slide = Tween<Offset>(
                                    begin: const Offset(0, -0.18),
                                    end: Offset.zero,
                                  ).animate(animation);
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: slide,
                                      child: child,
                                    ),
                                  );
                                },
                            child: pendingBanner == null
                                ? const SizedBox.shrink()
                                : _SleepMemoBanner(
                                    key: ValueKey<DateTime>(
                                      pendingBanner.createdAt,
                                    ),
                                    banner: pendingBanner,
                                    expanded: showExpandedBanner,
                                    onTap: () {
                                      if (!_bannerExpanded) {
                                        setState(() {
                                          _bannerExpanded = true;
                                        });
                                      }
                                    },
                                  ),
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

class _SleepMemoBanner extends StatelessWidget {
  const _SleepMemoBanner({
    super.key,
    required this.banner,
    required this.expanded,
    required this.onTap,
  });

  final PendingSleepMemoBanner banner;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: AppHaptics.tapHandler(onTap),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          width: 380,
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: appColors.surfaceRaised.withAlpha(242),
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppColors.floatingShadow,
            border: Border.all(color: appColors.accent.withAlpha(70)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: appColors.accent.withAlpha(38),
                    ),
                    child: Icon(
                      Icons.inventory_2_rounded,
                      color: appColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          banner.title,
                          style: AppTypography.cardTitle(textTheme).copyWith(
                            color: appColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          expanded ? '轻点任意空白处，就能回到首页。' : banner.subtitle,
                          style: AppTypography.bodyMuted(
                            textTheme,
                          ).copyWith(color: appColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: !expanded
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: banner.groups.map((
                            PendingSleepMemoGroup group,
                          ) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              child: _MemoGroupCard(group: group),
                            );
                          }).toList(),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemoGroupCard extends StatelessWidget {
  const _MemoGroupCard({required this.group});

  final PendingSleepMemoGroup group;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: appColors.darkGlass,
        borderRadius: AppRadius.surfacePrimary,
        border: Border.all(color: appColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            group.label,
            style: AppTypography.meta(
              textTheme,
            ).copyWith(color: appColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...group.items.asMap().entries.map((MapEntry<int, String> entry) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == group.items.length - 1 ? 0 : AppSpacing.sm,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: appColors.surface.withAlpha(170),
                  borderRadius: AppRadius.surfaceSecondary,
                ),
                child: Text(
                  '事项 ${entry.key + 1}：${entry.value}',
                  style: AppTypography.bodyMuted(
                    textTheme,
                  ).copyWith(color: appColors.textPrimary.withAlpha(220)),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

String _greetingFor(DateTime now) {
  final int hour = now.hour;
  if (hour >= 5 && hour <= 10) {
    return '早上好';
  }
  if (hour >= 11 && hour <= 17) {
    return '下午好';
  }
  return '晚上好';
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.unread, required this.onTap});

  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: AppHaptics.navigationHandler(onTap),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: appColors.accentDeep,
          shape: BoxShape.circle,
          boxShadow: AppColors.cardShadow,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: <Widget>[
            Icon(Icons.notifications_none_rounded, color: AppColors.onDark),
            if (unread > 0)
              Positioned(
                top: 8,
                right: 4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 24),
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: appColors.accentSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: AppTypography.chip(
                      textTheme,
                    ).copyWith(color: appColors.accentDeep),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
