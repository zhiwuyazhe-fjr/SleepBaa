import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
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
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xxl,
                AppSpacing.xl,
                AppSpacing.xxl,
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
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.onDark,
                    ),
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
                        onTap: () => context.push(AppRoutes.logNightAwakening),
                      ),
                      SupportToolCard(
                        title: '灵感记事',
                        subtitle: '捕捉梦境片段与想到的事',
                        icon: Icons.edit_note_rounded,
                        onTap: () => context.push(AppRoutes.dreamJournal),
                      ),
                      SupportToolCard(
                        title: '晨间反馈',
                        subtitle: '醒来后逐条反馈昨晚建议',
                        icon: Icons.wb_sunny_rounded,
                        onTap: () => context.push(AppRoutes.feedbackMorning),
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
                      await services.sleepExperienceController.exitSleepMode();
                      if (context.mounted) {
                        context.go(AppRoutes.homePreSleep);
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
