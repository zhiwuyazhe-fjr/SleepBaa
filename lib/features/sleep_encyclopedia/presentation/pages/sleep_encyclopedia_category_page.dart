import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/features/sleep_encyclopedia/data/sleep_encyclopedia_content.dart';
import 'package:sleep_dorm_app/features/sleep_encyclopedia/presentation/sleep_encyclopedia_text.dart';

class SleepEncyclopediaCategoryPage extends StatelessWidget {
  const SleepEncyclopediaCategoryPage({super.key, required this.categorySlug});

  final String categorySlug;

  @override
  Widget build(BuildContext context) {
    final SleepEncyclopediaCategory? category =
        SleepEncyclopediaContent.categoryBySlug(categorySlug);
    if (category == null) {
      return const _SleepEncyclopediaNotFoundPage(title: '未找到该分类');
    }

    final List<SleepEncyclopediaTopic> topics =
        SleepEncyclopediaContent.topicsForCategory(categorySlug);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(category.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          AppCard(
            padding: EdgeInsets.zero,
            borderRadius: AppRadius.cardLarge,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    category.accentColor.withAlpha(40),
                    Colors.white,
                  ],
                ),
                borderRadius: AppRadius.cardLarge,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: category.accentColor.withAlpha(28),
                      borderRadius: AppRadius.iconContainer,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      category.icon,
                      color: category.accentColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    category.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    sleepEncyclopediaCardSubtitle(category.description),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '共 ${topics.length} 个话题 · ${category.subtitle}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: category.accentColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...topics.map(
            (SleepEncyclopediaTopic topic) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                onTap: () => context.push(
                  AppRoutes.sleepEncyclopediaTopicLocation(topic.slug),
                ),
                color: Colors.white,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        _MetaPill(
                          text: topic.heroLabel,
                          color: category.accentColor,
                        ),
                        const Spacer(),
                        Text(
                          topic.readTime,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.textHint,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      topic.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      sleepEncyclopediaCardSubtitle(topic.summary),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: AppRadius.pill,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SleepEncyclopediaNotFoundPage extends StatelessWidget {
  const _SleepEncyclopediaNotFoundPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            '内容正在整理中，稍后可以从百科首页重新进入。',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
