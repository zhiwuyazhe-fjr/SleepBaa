import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/metric_tile.dart';
import 'package:sleep_dorm_app/core/widgets/section_title.dart';
import 'package:sleep_dorm_app/features/home/presentation/widgets/home_widgets.dart';

class HomePreSleepPage extends StatelessWidget {
  const HomePreSleepPage({super.key});

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
          services.audioPlaybackController,
        ]),
        builder: (BuildContext context, Widget? child) {
          final UserProfile profile = services.authRepository.currentUser;
          final Dorm dorm = services.dormRepository.currentDorm;
          final List<NightRecommendation> recommendations =
              services.recommendationRepository.tonightRecommendations;
          final int unread = services.notificationRepository
              .unreadNotifications()
              .length;

          return SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return Stack(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.xl,
                        AppSpacing.xl,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      '晚上好，${profile.displayName}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.displayMedium,
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Row(
                                      children: <Widget>[
                                        const Icon(
                                          Icons.circle,
                                          size: 8,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        Expanded(
                                          child: Text(
                                            dorm.overview,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
                          const SizedBox(height: AppSpacing.xl),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: SleepRiskCard(
                                  riskLabel: dorm.noiseDb <= 35 ? '偏低' : '中等',
                                  primaryValue: '${dorm.noiseDb} dB',
                                  secondaryValue: dorm.lightLabel,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: StartSleepModeCard(
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
                            ],
                          ),
                        ],
                      ),
                    ),
                    DraggableScrollableSheet(
                      initialChildSize: 0.56,
                      minChildSize: 0.52,
                      maxChildSize: 0.9,
                      builder:
                          (
                            BuildContext context,
                            ScrollController scrollController,
                          ) {
                            return Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(48),
                                ),
                                boxShadow: AppColors.floatingShadow,
                              ),
                              child: ListView(
                                controller: scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.xl,
                                  AppSpacing.lg,
                                  AppSpacing.xl,
                                  132,
                                ),
                                children: <Widget>[
                                  Center(
                                    child: Container(
                                      width: 46,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: AppColors.divider,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  SectionTitle(
                                    title: '今晚行动建议',
                                    actionLabel: '查看全部',
                                    onAction: () =>
                                        context.push(AppRoutes.interventionTask),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  ...recommendations.map(
                                    (NightRecommendation recommendation) =>
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: AppSpacing.md,
                                          ),
                                          child: HomeActionCard(
                                            recommendation: recommendation,
                                            onTap: () async {
                                              await services
                                                  .sleepExperienceController
                                                  .handleRecommendationTap(
                                                    recommendation,
                                                  );
                                            },
                                          ),
                                        ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  SectionTitle(
                                    title: '今晚影响因素',
                                    actionLabel: '查看详情',
                                    onAction: () => context.push(
                                      AppRoutes.analysisInterferenceFactors,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  GridView.count(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: AppSpacing.md,
                                    mainAxisSpacing: AppSpacing.md,
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    childAspectRatio: 0.98,
                                    children: <Widget>[
                                      MetricTile(
                                        icon: Icons.volume_down_rounded,
                                        label: '宿舍噪声',
                                        value: '${dorm.noiseDb} dB',
                                        detail: '当前状态 ${dorm.quietLabel}',
                                      ),
                                      MetricTile(
                                        icon: Icons.lightbulb_rounded,
                                        label: '灯光环境',
                                        value: dorm.lightLabel,
                                        detail: '更适合慢慢进入放松状态',
                                      ),
                                      const MetricTile(
                                        icon: Icons.phone_iphone_rounded,
                                        label: '手机使用',
                                        value: '45 分钟',
                                        detail: '建议睡前先放下手机 15 分钟',
                                      ),
                                      const MetricTile(
                                        icon: Icons.favorite_rounded,
                                        label: '情绪压力',
                                        value: '低强度',
                                        detail: '整体可放松，适合轻干预后入睡',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
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

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.unread, required this.onTap});

  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          shape: BoxShape.circle,
          boxShadow: AppColors.cardShadow,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: <Widget>[
            const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.onDark,
            ),
            if (unread > 0)
              Positioned(
                top: 8,
                right: 4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 24),
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.darkSurface, width: 2),
                    boxShadow: AppColors.cardShadow,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primaryDeep,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
