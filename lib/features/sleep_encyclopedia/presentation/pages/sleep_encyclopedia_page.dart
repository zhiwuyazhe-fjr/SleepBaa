import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/widgets/app_detail_page_header.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/features/sleep_encyclopedia/data/sleep_encyclopedia_content.dart';
import 'package:sleep_dorm_app/features/sleep_encyclopedia/presentation/sleep_encyclopedia_text.dart';

class SleepEncyclopediaPage extends StatelessWidget {
  const SleepEncyclopediaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<SleepEncyclopediaTopic> featuredTopics =
        SleepEncyclopediaContent.featuredTopics();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppDetailPageAppBar(
        title: '睡眠百科',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          const _HeroCard(),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(title: '先看这几篇', subtitle: '适合第一次进入百科时快速浏览。'),
          const SizedBox(height: AppSpacing.sm),
          ...featuredTopics.map(
            (SleepEncyclopediaTopic topic) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _TopicPreviewCard(
                topic: topic,
                onTap: () => context.push(
                  AppRoutes.sleepEncyclopediaTopicLocation(topic.slug),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionHeader(title: '按主题查看', subtitle: '围绕真实睡眠场景拆分，阅读压力不会太大。'),
          const SizedBox(height: AppSpacing.sm),
          ...SleepEncyclopediaContent.categories.map(
            (SleepEncyclopediaCategory category) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _CategoryCard(
                category: category,
                topicCount: category.topicSlugs.length,
                onTap: () => context.push(
                  AppRoutes.sleepEncyclopediaCategoryLocation(category.slug),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionHeader(title: '阅读建议', subtitle: '如果你不知道先看哪里，可以按现在的状态进入。'),
          const SizedBox(height: AppSpacing.sm),
          _ReadingPathCard(
            title: '我今晚就睡不着',
            description: '先看入睡、脑子停不下来、手机停不下来的几个话题。',
            slugs: const <String>[
              'cant-fall-asleep',
              'racing-thoughts',
              'phone-before-sleep',
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _ReadingPathCard(
            title: '我最近作息有点乱',
            description: '适合熬夜后恢复、午睡拿捏、睡很久仍然累这条线。',
            slugs: const <String>[
              'stay-up-late-recovery',
              'nap-length',
              'sleep-enough-still-tired',
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _ReadingPathCard(
            title: '我更像是被环境和压力拖住',
            description: '适合宿舍干扰、压力影响和夜里容易醒的情况。',
            slugs: const <String>[
              'roommate-noise',
              'stress-and-sleep',
              'wake-up-at-night',
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      borderRadius: AppRadius.cardLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 208,
              child: Image.asset(
                'assets/images/sleep_encyclopedia/hero_cat_sleep_real.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder:
                    (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) => const SizedBox.shrink(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F6F1),
                    borderRadius: AppRadius.pill,
                  ),
                  child: Text(
                    '睡眠百科',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.primaryDeep,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '今晚想先了解哪类睡眠问题？',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: AppColors.textStrong,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '从入睡、作息、宿舍环境和压力梦境里挑一个开始就好。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _TopicPreviewCard extends StatelessWidget {
  const _TopicPreviewCard({required this.topic, required this.onTap});

  final SleepEncyclopediaTopic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final SleepEncyclopediaCategory category =
        SleepEncyclopediaContent.categoryBySlug(topic.categorySlug)!;
    return AppCard(
      onTap: onTap,
      color: Colors.white,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _Tag(text: category.title, color: category.accentColor),
              const Spacer(),
              Text(
                topic.readTime,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            topic.title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            sleepEncyclopediaCardSubtitle(topic.subtitle),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.topicCount,
    required this.onTap,
  });

  final SleepEncyclopediaCategory category;
  final int topicCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      borderRadius: AppRadius.card,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: AppRadius.card,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[category.accentColor.withAlpha(36), Colors.white],
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: category.accentColor.withAlpha(30),
                borderRadius: AppRadius.iconContainer,
              ),
              alignment: Alignment.center,
              child: Icon(category.icon, color: category.accentColor, size: 26),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    category.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    sleepEncyclopediaCardSubtitle(category.description),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '$topicCount 个话题 · ${category.subtitle}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: category.accentColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingPathCard extends StatelessWidget {
  const _ReadingPathCard({
    required this.title,
    required this.description,
    required this.slugs,
  });

  final String title;
  final String description;
  final List<String> slugs;

  @override
  Widget build(BuildContext context) {
    final List<SleepEncyclopediaTopic> topics = slugs
        .map(SleepEncyclopediaContent.topicBySlug)
        .whereType<SleepEncyclopediaTopic>()
        .toList(growable: false);

    return AppCard(
      color: Colors.white,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            sleepEncyclopediaCardSubtitle(description),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: topics
                .map(
                  (SleepEncyclopediaTopic topic) => ActionChip(
                    label: Text(topic.title),
                    backgroundColor: AppColors.surfaceMuted,
                    side: BorderSide.none,
                    onPressed: () => context.push(
                      AppRoutes.sleepEncyclopediaTopicLocation(topic.slug),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color effectiveColor = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: effectiveColor.withAlpha(26),
        borderRadius: AppRadius.pill,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: effectiveColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
