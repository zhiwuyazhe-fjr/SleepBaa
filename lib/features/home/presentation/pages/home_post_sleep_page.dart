import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/state/sleep_experience_controller.dart';
import 'package:sleep_dorm_app/core/widgets/assistant_fab.dart';
import 'package:sleep_dorm_app/core/widgets/assistant_fab_dock.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';
import 'package:sleep_dorm_app/core/widgets/status_chip.dart';
import 'package:sleep_dorm_app/features/home/presentation/widgets/home_widgets.dart';

enum _SleepExitAction { back, pause, finish }

class HomePostSleepPage extends StatelessWidget {
  const HomePostSleepPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          services.audioPlaybackController,
          services.dormRepository,
          services.recommendationRepository,
          services.sleepSessionRepository,
        ]),
        builder: (BuildContext context, Widget? child) {
          final NightMoodPalette palette = context.nightMoodPalette;
          final SleepSession? session =
              services.sleepSessionRepository.activeSession;
          final Dorm dorm = services.dormRepository.currentDorm;
          final NightRecommendation? audioRecommendation = services
              .recommendationRepository
              .tonightRecommendations
              .cast<NightRecommendation?>()
              .firstWhere(
                (NightRecommendation? item) =>
                    item?.type == RecommendationType.audio,
                orElse: () => null,
              );
          final List<_SleepSupportTool> tools = <_SleepSupportTool>[
            _SleepSupportTool(
              title: '难以入睡',
              subtitle: '快速切到呼吸放松与音频支持',
              icon: Icons.self_improvement_rounded,
              onTap: () => context.push(AppRoutes.sleepCantSleep),
            ),
            _SleepSupportTool(
              title: '记录夜醒',
              subtitle: '标记醒来的时间与诱因',
              icon: Icons.bedtime_rounded,
              onTap: () => context.push(AppRoutes.logNightAwakening),
            ),
            _SleepSupportTool(
              title: '灵感记事',
              subtitle: '进入 AI 助手记录梦境或临时想到的事',
              icon: Icons.edit_note_rounded,
              onTap: () => context.push(
                '${AppRoutes.assistant}?flow=sleep_capture&mode=dream',
              ),
            ),
            _SleepSupportTool(
              title: '晨间反馈',
              subtitle: '醒来后逐条反馈昨晚建议',
              icon: Icons.wb_sunny_rounded,
              onTap: () async {
                await _finishSleepModeAndOpenFeedback(context, services);
              },
            ),
          ];
          return Stack(
            children: <Widget>[
              SafeArea(
                child: PopScope<void>(
                  canPop: false,
                  onPopInvokedWithResult: (bool didPop, void result) {
                    if (didPop) {
                      return;
                    }
                    unawaited(_handleSleepPageExit(context, services));
                  },
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      final double contentWidth =
                          constraints.maxWidth - (AppSpacing.md * 2);
                      final double moonSize = contentWidth.clamp(160.0, 220.0);
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.md,
                          160,
                        ),
                        child: Column(
                          children: <Widget>[
                            Text(
                              'Companion Mode',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: palette.primarySoft.withAlpha(120),
                                    letterSpacing: 1.6,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '睡眠模式已开启',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: AppColors.onDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            SleepModeMoon(size: moonSize),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '安心休息，我会继续帮你守着今晚的节奏。',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.onDark.withAlpha(160),
                                    height: 1.4,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            StreamBuilder<int>(
                              stream: Stream<int>.periodic(
                                const Duration(seconds: 30),
                                (int count) => count,
                              ),
                              initialData: 0,
                              builder:
                                  (BuildContext context, AsyncSnapshot<int> _) {
                                    final String runtimeLabel;
                                    if (session == null) {
                                      runtimeLabel = '刚刚进入睡眠模式';
                                    } else if (session.hasSubmittedFeedback) {
                                      runtimeLabel = '晨间反馈已完成，本次不再累计';
                                    } else {
                                      runtimeLabel =
                                          '已运行 ${session.liveTrackedDurationMinutes().clamp(1, 24 * 60)} 分钟';
                                    }
                                    return Wrap(
                                      spacing: AppSpacing.xs,
                                      runSpacing: AppSpacing.xs,
                                      alignment: WrapAlignment.center,
                                      children: <Widget>[
                                        StatusChip(
                                          label: runtimeLabel,
                                          backgroundColor: AppColors.darkBorder,
                                          foregroundColor: AppColors.onDark,
                                          borderColor: AppColors.darkBorder,
                                          showDot: true,
                                          dotColor: palette.primarySoft,
                                        ),
                                        StatusChip(
                                          label: '宿舍 ${dorm.quietLabel}',
                                          backgroundColor: AppColors.darkBorder,
                                          foregroundColor: AppColors.onDark,
                                          borderColor: AppColors.darkBorder,
                                          icon: Icons.volume_off_rounded,
                                        ),
                                        const StatusChip(
                                          label: 'AI 守护中',
                                          backgroundColor: AppColors.darkBorder,
                                          foregroundColor: AppColors.onDark,
                                          borderColor: AppColors.darkBorder,
                                          icon: Icons.security_rounded,
                                        ),
                                      ],
                                    );
                                  },
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            SessionAudioCard(
                              track:
                                  services
                                      .audioPlaybackController
                                      .currentTrack ??
                                  audioRecommendation?.track,
                              playbackState: services
                                  .audioPlaybackController
                                  .playbackState,
                              position:
                                  services.audioPlaybackController.position,
                              onToggle: () async {
                                await services.sleepExperienceController
                                    .toggleSleepAudio();
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _SleepSupportToolsSection(tools: tools),
                            const SizedBox(height: AppSpacing.md),
                            PrimaryButton(
                              label: '结束睡眠模式',
                              size: PrimaryButtonSize.compact,
                              variant: PrimaryButtonVariant.ghost,
                              foregroundColor: AppColors.onDark,
                              borderColor: AppColors.darkBorder,
                              onPressed: () =>
                                  _handleSleepPageExit(context, services),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned.fill(
                child: SafeArea(
                  top: false,
                  child: AssistantFabDock(child: const AssistantFab()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SleepSupportTool {
  const _SleepSupportTool({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

class _SleepSupportToolsSection extends StatelessWidget {
  const _SleepSupportToolsSection({required this.tools});

  final List<_SleepSupportTool> tools;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (int index = 0; index < tools.length; index += 2) ...<Widget>[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: _buildCard(tools[index])),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: index + 1 < tools.length
                      ? _buildCard(tools[index + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          if (index + 2 < tools.length) const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }

  Widget _buildCard(_SleepSupportTool tool) {
    return SupportToolCard(
      title: tool.title,
      subtitle: tool.subtitle,
      icon: tool.icon,
      onTap: tool.onTap,
    );
  }
}

Future<void> _handleSleepPageExit(
  BuildContext context,
  AppServices services,
) async {
  final _SleepExitAction? action = await _showSleepExitDialog(context);
  if (!context.mounted || action == null) {
    return;
  }
  switch (action) {
    case _SleepExitAction.back:
      return;
    case _SleepExitAction.pause:
      await services.sleepExperienceController.pauseSleepMode();
      if (context.mounted) {
        context.go(AppRoutes.homePreSleep);
      }
      return;
    case _SleepExitAction.finish:
      await _finishSleepModeAndOpenFeedback(context, services);
      return;
  }
}

Future<void> _finishSleepModeAndOpenFeedback(
  BuildContext context,
  AppServices services,
) async {
  final FinishSleepModeResult result = await services.sleepExperienceController
      .finishSleepMode();
  if (!context.mounted) {
    return;
  }
  _routeAfterSleepModeFinish(
    context,
    services: services,
    result: result,
    resumeToSleep: true,
  );
}

void _routeAfterSleepModeFinish(
  BuildContext context, {
  required AppServices services,
  required FinishSleepModeResult result,
  required bool resumeToSleep,
}) {
  final SleepSession? currentSleepDaySession = services.sleepSessionRepository
      .sessionForSleepDayKey(
        sleepDayKeyFromDate(services.sleepExperienceController.currentTime),
      );
  switch (result) {
    case FinishSleepModeResult.noActiveSession:
      context.go(AppRoutes.homePreSleep);
      return;
    case FinishSleepModeResult.goToFeedback:
      context.push(
        AppRoutes.feedbackMorningLocation(
          sessionId: currentSleepDaySession?.id,
          resumeToSleep: resumeToSleep,
        ),
      );
      return;
    case FinishSleepModeResult.goHomeFeedbackAlreadySubmitted:
      context.go(
        AppRoutes.homePreSleepLocation(
          notice: AppRoutes.feedbackReceivedNotice,
        ),
      );
      return;
  }
}

Future<_SleepExitAction?> _showSleepExitDialog(BuildContext context) {
  return showGeneralDialog<_SleepExitAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'sleep-exit-confirm',
    barrierColor: Colors.black.withAlpha(70),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) {
          return Material(
            color: Colors.transparent,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: const SizedBox.expand(),
                  ),
                ),
                Center(
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final bool useStackedActions =
                              constraints.maxWidth < 420;
                          return Container(
                            constraints: const BoxConstraints(maxWidth: 440),
                            margin: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xl,
                            ),
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: AppColors.darkCard.withAlpha(248),
                              borderRadius: AppRadius.surfacePrimary,
                              border: Border.all(color: AppColors.darkBorder),
                              boxShadow: AppColors.floatingShadow,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  '结束后怎么处理这段睡眠？',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(color: AppColors.onDark),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  '如果只是暂时离开睡眠模式，可以先退出；真正准备结束这一晚时，再进入晨间反馈补全记录。',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppColors.onDark.withAlpha(180),
                                        height: 1.55,
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                if (useStackedActions) ...<Widget>[
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: PrimaryButton(
                                          label: '返回',
                                          size: PrimaryButtonSize.compact,
                                          variant: PrimaryButtonVariant.ghost,
                                          foregroundColor: AppColors.onDark,
                                          borderColor: AppColors.darkBorder,
                                          onPressed: () => Navigator.of(
                                            context,
                                          ).pop(_SleepExitAction.back),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: PrimaryButton(
                                          label: '退出',
                                          size: PrimaryButtonSize.compact,
                                          variant: PrimaryButtonVariant.ghost,
                                          foregroundColor: AppColors.onDark,
                                          borderColor: AppColors.darkBorder,
                                          onPressed: () => Navigator.of(
                                            context,
                                          ).pop(_SleepExitAction.pause),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  PrimaryButton(
                                    label: '结束并去晨间反馈',
                                    size: PrimaryButtonSize.compact,
                                    foregroundColor: Colors.white,
                                    onPressed: () => Navigator.of(
                                      context,
                                    ).pop(_SleepExitAction.finish),
                                  ),
                                ] else
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: PrimaryButton(
                                          label: '返回',
                                          size: PrimaryButtonSize.compact,
                                          variant: PrimaryButtonVariant.ghost,
                                          foregroundColor: AppColors.onDark,
                                          borderColor: AppColors.darkBorder,
                                          onPressed: () => Navigator.of(
                                            context,
                                          ).pop(_SleepExitAction.back),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: PrimaryButton(
                                          label: '退出',
                                          size: PrimaryButtonSize.compact,
                                          variant: PrimaryButtonVariant.ghost,
                                          foregroundColor: AppColors.onDark,
                                          borderColor: AppColors.darkBorder,
                                          onPressed: () => Navigator.of(
                                            context,
                                          ).pop(_SleepExitAction.pause),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: PrimaryButton(
                                          label: '结束并去晨间反馈',
                                          size: PrimaryButtonSize.compact,
                                          foregroundColor: Colors.white,
                                          onPressed: () => Navigator.of(
                                            context,
                                          ).pop(_SleepExitAction.finish),
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  '退出后再次进入，睡眠时长可累计，完成晨间反馈后该日时长就不再累计。',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.onDark.withAlpha(140),
                                        height: 1.5,
                                      ),
                                ),
                              ],
                            ),
                          );
                        },
                  ),
                ),
              ],
            ),
          );
        },
    transitionBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
              child: child,
            ),
          );
        },
  );
}
