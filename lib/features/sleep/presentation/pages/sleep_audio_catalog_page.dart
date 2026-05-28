import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/utils/formatters.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_detail_page_header.dart';

class SleepAudioCatalogPage extends StatefulWidget {
  const SleepAudioCatalogPage({super.key});

  @override
  State<SleepAudioCatalogPage> createState() => _SleepAudioCatalogPageState();
}

class _SleepAudioCatalogPageState extends State<SleepAudioCatalogPage> {
  bool _requestedInitialRefresh = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedInitialRefresh) {
      return;
    }
    _requestedInitialRefresh = true;
    unawaited(
      context.appServices.recommendationRepository.refreshAudioCatalog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    final NightMoodPalette palette = context.nightMoodPalette;
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[
            services.recommendationRepository,
            services.audioPlaybackController,
          ]),
          builder: (BuildContext context, Widget? child) {
            final List<AudioTrack> tracks =
                services.recommendationRepository.audioCatalog;
            final AudioTrack? currentTrack =
                services.audioPlaybackController.currentTrack;
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xxl,
              ),
              children: <Widget>[
                AppDetailPageHeader(
                  title: '睡前放松音频',
                  foregroundColor: AppColors.onDark,
                  onBack: () => context.pop(),
                  trailing: IconButton(
                    tooltip: '刷新',
                    onPressed: () async {
                      await services.recommendationRepository
                          .refreshAudioCatalog();
                    },
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: palette.primarySoft,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '选择今晚想听的声音。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onDark.withAlpha(170),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (tracks.isEmpty)
                  _EmptyAudioCatalog(
                    onRefresh: () async {
                      await services.recommendationRepository
                          .refreshAudioCatalog();
                    },
                  )
                else
                  ...tracks.map(
                    (AudioTrack track) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _AudioCatalogTile(
                        track: track,
                        isCurrent: currentTrack?.id == track.id,
                        playbackState:
                            services.audioPlaybackController.playbackState,
                        onTap: () async {
                          await services.sleepExperienceController
                              .playAudioTrack(track);
                        },
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AudioCatalogTile extends StatelessWidget {
  const _AudioCatalogTile({
    required this.track,
    required this.isCurrent,
    required this.playbackState,
    required this.onTap,
  });

  final AudioTrack track;
  final bool isCurrent;
  final PlaybackState playbackState;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    final bool isPlaying = isCurrent && playbackState == PlaybackState.playing;
    final String? duration = track.duration > Duration.zero
        ? Formatters.formatDuration(track.duration)
        : null;
    return AppCard(
      padding: EdgeInsets.zero,
      color: isCurrent ? palette.primary.withAlpha(54) : AppColors.darkGlass,
      borderRadius: AppRadius.surfacePrimary,
      border: Border.all(
        color: isCurrent
            ? palette.primarySoft.withAlpha(100)
            : AppColors.darkBorder,
      ),
      boxShadow: const <BoxShadow>[],
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: palette.primary.withAlpha(50),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                isPlaying ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
                color: palette.primarySoft,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.onDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (duration != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      duration,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onDark.withAlpha(150),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
              color: palette.primarySoft,
              size: 32,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAudioCatalog extends StatelessWidget {
  const _EmptyAudioCatalog({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.darkGlass,
      borderRadius: AppRadius.surfacePrimary,
      border: Border.all(color: AppColors.darkBorder),
      boxShadow: const <BoxShadow>[],
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.library_music_outlined,
            color: AppColors.onDark,
            size: 32,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '暂无可播放音频',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.onDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => unawaited(onRefresh()),
            child: const Text('重新同步'),
          ),
        ],
      ),
    );
  }
}
