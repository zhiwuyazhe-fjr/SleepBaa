import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/app_typography.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_detail_page_header.dart';
import 'package:sleep_dorm_app/features/home/presentation/widgets/home_widgets.dart';

class MicroInterventionTaskPage extends StatelessWidget {
  const MicroInterventionTaskPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          services.recommendationRepository,
          services.audioPlaybackController,
        ]),
        builder: (BuildContext context, Widget? child) {
          final List<NightRecommendation> recommendations =
              services.recommendationRepository.tonightRecommendations;
          final AudioTrack? currentAudioTrack =
              services.audioPlaybackController.currentTrack;
          final int selectedCount = recommendations
              .where(
                (NightRecommendation item) =>
                    item.executionState != RecommendationExecutionState.idle,
              )
              .length;

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xxl,
              ),
              children: <Widget>[
                AppDetailPageHeader(
                  title: '全部今晚建议',
                  onBack: () => context.pop(),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  borderRadius: AppRadius.surfacePrimary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '这些建议来自昨晚环境、宿舍状态和你最近的反馈。',
                        style: AppTypography.panelTitle(textTheme),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '已采纳 $selectedCount / ${recommendations.length} 条，点击卡片右侧按钮即可立即执行或切换状态。',
                        style: AppTypography.bodyMuted(textTheme),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                ...recommendations.map(
                  (NightRecommendation recommendation) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: HomeActionCard(
                      recommendation: recommendation,
                      displayTitle:
                          recommendation.type == RecommendationType.audio &&
                              currentAudioTrack != null
                          ? currentAudioTrack.title
                          : null,
                      showAudioTransport:
                          recommendation.type == RecommendationType.audio &&
                          recommendation.executionState ==
                              RecommendationExecutionState.playing,
                      onTap: () async {
                        await services.sleepExperienceController
                            .handleRecommendationTap(recommendation);
                      },
                      onPlayToggle:
                          recommendation.type == RecommendationType.audio
                          ? () async {
                              await services.sleepExperienceController
                                  .handleRecommendationTap(recommendation);
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
          );
        },
      ),
    );
  }
}
