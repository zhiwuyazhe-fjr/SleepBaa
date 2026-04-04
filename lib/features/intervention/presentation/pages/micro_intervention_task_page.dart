import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/features/home/presentation/widgets/home_widgets.dart';

class MicroInterventionTaskPage extends StatelessWidget {
  const MicroInterventionTaskPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return Scaffold(
      appBar: AppBar(title: const Text('今晚全部建议')),
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          services.recommendationRepository,
          services.audioPlaybackController,
        ]),
        builder: (BuildContext context, Widget? child) {
          final List<NightRecommendation> recommendations =
              services.recommendationRepository.tonightRecommendations;
          final int selectedCount = recommendations
              .where(
                (NightRecommendation item) =>
                    item.executionState != RecommendationExecutionState.idle,
              )
              .length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            children: <Widget>[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '这些建议来自昨晚环境、宿舍状态和你最近的反馈。',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '已采纳 $selectedCount / ${recommendations.length} 条，点击卡片右侧按钮即可立即执行或切换状态。',
                      style: Theme.of(context).textTheme.bodyMedium,
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
                    onTap: () async {
                      await services.sleepExperienceController
                          .handleRecommendationTap(recommendation);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
