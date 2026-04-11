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
import 'package:sleep_dorm_app/core/widgets/assistant_fab.dart';
import 'package:sleep_dorm_app/core/widgets/assistant_fab_dock.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';
import 'package:sleep_dorm_app/core/widgets/status_chip.dart';
import 'package:sleep_dorm_app/features/home/presentation/widgets/home_widgets.dart';

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
          services.sleepSessionRepository,
        ]),
        builder: (BuildContext context, Widget? child) {
          final palette = context.nightMoodPalette;
          final SleepSession? session =
              services.sleepSessionRepository.activeSession;
          final Dorm dorm = services.dormRepository.currentDorm;
          return Stack(
            children: <Widget>[
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xxl,
                    AppSpacing.xl,
                    180,
                  ),
                  child: Column(
                    children: <Widget>[
                      Text(
                        'Companion Mode',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: palette.primarySoft.withAlpha(120),
                          letterSpacing: 2.2,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '睡眠模式已开启',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(color: AppColors.onDark),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const SleepModeMoon(),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '安心休息，我会继续帮你守着今晚的节奏。',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.onDark.withAlpha(150),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        alignment: WrapAlignment.center,
                        children: <Widget>[
                          StatusChip(
                            label: session == null
                                ? '刚刚进入睡眠模式'
                                : '已运行 ${(DateTime.now().difference(session.startedAt).inMinutes).clamp(1, 240)} 分钟',
                            backgroundColor: const Color(0x14FFFFFF),
                            foregroundColor: AppColors.onDark,
                            borderColor: AppColors.darkBorder,
                            showDot: true,
                            dotColor: palette.primarySoft,
                          ),
                          StatusChip(
                            label: '宿舍 ${dorm.quietLabel}',
                            backgroundColor: const Color(0x14FFFFFF),
                            foregroundColor: AppColors.onDark,
                            borderColor: AppColors.darkBorder,
                            icon: Icons.volume_off_rounded,
                          ),
                          const StatusChip(
                            label: 'AI 守护中',
                            backgroundColor: Color(0x14FFFFFF),
                            foregroundColor: AppColors.onDark,
                            borderColor: AppColors.darkBorder,
                            icon: Icons.security_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      SessionAudioCard(
                        track: services.audioPlaybackController.currentTrack,
                        playbackState:
                            services.audioPlaybackController.playbackState,
                        position: services.audioPlaybackController.position,
                        onToggle: () async {
                          final AudioTrack? track =
                              services.audioPlaybackController.currentTrack ??
                              services
                                  .recommendationRepository
                                  .tonightRecommendations
                                  .where(
                                    (NightRecommendation item) =>
                                        item.track != null,
                                  )
                                  .first
                                  .track;
                          if (track != null) {
                            await services.audioPlaybackController.toggleTrack(
                              track,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisSpacing: AppSpacing.md,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.08,
                        children: <Widget>[
                          SupportToolCard(
                            title: '难以入睡',
                            subtitle: '快速切到呼吸放松与音频支持',
                            icon: Icons.self_improvement_rounded,
                            onTap: () => context.push(AppRoutes.sleepCantSleep),
                          ),
                          SupportToolCard(
                            title: '记录夜醒',
                            subtitle: '标记醒来的时间与诱因',
                            icon: Icons.bedtime_rounded,
                            onTap: () =>
                                context.push(AppRoutes.logNightAwakening),
                          ),
                          SupportToolCard(
                            title: '灵感记事',
                            subtitle: '进入 AI 助手记录梦境或临时想到的事',
                            icon: Icons.edit_note_rounded,
                            onTap: () => context.push(
                              '${AppRoutes.assistant}?flow=sleep_capture&mode=dream',
                            ),
                          ),
                          SupportToolCard(
                            title: '晨间反馈',
                            subtitle: '醒来后逐条反馈昨晚建议',
                            icon: Icons.wb_sunny_rounded,
                            onTap: () =>
                                context.push(AppRoutes.feedbackMorning),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      PrimaryButton(
                        label: '结束睡眠模式',
                        variant: PrimaryButtonVariant.ghost,
                        foregroundColor: AppColors.onDark,
                        borderColor: AppColors.darkBorder,
                        onPressed: () async {
                          final bool shouldExit = await _showSleepExitDialog(
                            context,
                            palette,
                          );
                          if (!shouldExit) {
                            return;
                          }
                          await services.sleepExperienceController
                              .exitSleepMode();
                          if (context.mounted) {
                            context.go(AppRoutes.homePreSleep);
                          }
                        },
                      ),
                    ],
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

Future<bool> _showSleepExitDialog(
  BuildContext context,
  NightMoodPalette palette,
) async {
  final bool? result = await showGeneralDialog<bool>(
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
                  child: Container(
                    width: 420,
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AppColors.darkCard.withAlpha(248),
                      borderRadius: AppRadius.cardLarge,
                      border: Border.all(color: AppColors.darkBorder),
                      boxShadow: AppColors.floatingShadow,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '完成晨间反馈会更有帮助',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: AppColors.onDark),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '明早完成晨间反馈后，我会根据你今晚的情况继续优化建议，让后面的睡眠干预更贴近你的节奏。',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.onDark.withAlpha(180),
                                height: 1.55,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: PrimaryButton(
                                label: '返回',
                                variant: PrimaryButtonVariant.ghost,
                                foregroundColor: AppColors.onDark,
                                borderColor: AppColors.darkBorder,
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: PrimaryButton(
                                label: '退出',
                                foregroundColor: Colors.white,
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
  return result ?? false;
}
