import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/widgets/app_detail_page_header.dart';
import 'package:sleep_dorm_app/features/dream/presentation/dream_content.dart';

class DreamDetailPage extends StatelessWidget {
  const DreamDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    final AppSemanticColors appColors = context.appColors;
    final DreamEntryData entry = DreamContent.entries.first;

    return Scaffold(
      backgroundColor: appColors.pageBackground,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              appColors.accentSoft.withAlpha(100),
              appColors.pageBackground,
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            children: <Widget>[
              AppDetailPageHeader(title: '梦境详情', onBack: () => context.pop()),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: appColors.surface,
                  borderRadius: AppRadius.cardLarge,
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: entry.tags.map((String tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: appColors.accentSoft.withAlpha(170),
                            borderRadius: AppRadius.pill,
                          ),
                          child: Text(
                            tag,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: appColors.accentDeep,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      entry.title,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: appColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      entry.summary,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: appColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        _MetaChip(
                          label: entry.timeLabel,
                          icon: Icons.schedule_rounded,
                          palette: palette,
                        ),
                        _MetaChip(
                          label: '情绪 ${entry.moodLabel}',
                          icon: Icons.favorite_rounded,
                          palette: palette,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _DetailSection(
                title: '梦境映射',
                palette: palette,
                children: const <String>[
                  '高频场景是“漂浮、光亮、熟悉地点”，通常和你放松的夜晚有关。',
                  '醒来后的第一情绪偏轻松，说明这个梦更像在整理白天的信息，而不是在放大压力。',
                  '如果今晚继续记录，可以重点补充人物、方向和颜色。',
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _DetailSection(
                title: '睡前关联',
                palette: palette,
                children: const <String>[
                  '睡前 30 分钟内屏幕使用较少时，更容易记住完整梦境。',
                  '轻音乐和较暗的灯光，会让梦境描述更连贯。',
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.children,
    required this.palette,
  });

  final String title;
  final List<String> children;
  final NightMoodPalette palette;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(
              color: appColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...children.map(
            (String item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: palette.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: appColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.icon,
    required this.palette,
  });

  final String label;
  final IconData icon;
  final NightMoodPalette palette;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: appColors.accentSoft.withAlpha(160),
        borderRadius: AppRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: appColors.accentDeep),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: appColors.accentDeep,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
