import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/utils/formatters.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';

class CantSleepPage extends StatefulWidget {
  const CantSleepPage({super.key});

  @override
  State<CantSleepPage> createState() => _CantSleepPageState();
}

class _CantSleepPageState extends State<CantSleepPage> {
  String _selectedCause = '脑子停不下来';

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return Scaffold(
      appBar: AppBar(title: const Text('难以入眠')),
      body: ListenableBuilder(
        listenable: services.audioPlaybackController,
        builder: (BuildContext context, Widget? child) {
          final AudioTrack track =
              services.audioPlaybackController.currentTrack ??
              services.recommendationRepository.tonightRecommendations
                  .firstWhere((NightRecommendation item) => item.track != null)
                  .track!;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: <Widget>[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '现在最卡住你的是什么？',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <String>['脑子停不下来', '宿舍还有动静', '身体还紧绷', '担心明天起不来']
                          .map((String cause) {
                            return ChoiceChip(
                              label: Text(cause),
                              selected: _selectedCause == cause,
                              onSelected: (_) =>
                                  setState(() => _selectedCause = cause),
                            );
                          })
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                color: AppColors.surfaceMuted,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '即时建议',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text('1. 暂时不要看手机时间。'),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('2. 把注意力收回到呼吸和身体接触床面的感觉。'),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('3. 如果 20 分钟后仍无法入睡，再决定是否短暂离床放松。'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '继续助眠音频',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      track.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${track.subtitle} · ${Formatters.formatDuration(track.duration)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: PrimaryButton(
                            label: services.audioPlaybackController.isPlaying
                                ? '暂停音频'
                                : '继续播放',
                            onPressed: () async {
                              await services.audioPlaybackController
                                  .toggleTrack(track);
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: PrimaryButton(
                            label: '停止',
                            variant: PrimaryButtonVariant.ghost,
                            onPressed: () async {
                              await services.audioPlaybackController.stop();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
