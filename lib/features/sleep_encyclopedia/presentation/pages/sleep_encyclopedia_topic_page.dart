import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_detail_page_header.dart';
import 'package:sleep_dorm_app/features/sleep_encyclopedia/data/sleep_encyclopedia_content.dart';
import 'package:sleep_dorm_app/features/sleep_encyclopedia/presentation/sleep_encyclopedia_text.dart';

class SleepEncyclopediaTopicPage extends StatelessWidget {
  const SleepEncyclopediaTopicPage({super.key, required this.topicSlug});

  final String topicSlug;

  @override
  Widget build(BuildContext context) {
    final SleepEncyclopediaTopic? topic = SleepEncyclopediaContent.topicBySlug(
      topicSlug,
    );
    if (topic == null) {
      return const _TopicNotFoundPage();
    }
    final SleepEncyclopediaCategory category =
        SleepEncyclopediaContent.categoryBySlug(topic.categorySlug)!;
    final List<SleepEncyclopediaTopic> relatedTopics =
        SleepEncyclopediaContent.relatedTopics(topic);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              category.accentColor.withAlpha(30),
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            children: <Widget>[
              AppDetailPageHeader(title: '睡眠百科', onBack: () => context.pop()),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                padding: EdgeInsets.zero,
                borderRadius: AppRadius.cardLarge,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.cardLarge,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        category.accentColor.withAlpha(36),
                        Colors.white,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: <Widget>[
                          _Pill(
                            text: category.title,
                            color: category.accentColor,
                          ),
                          _Pill(
                            text: topic.heroLabel,
                            color: category.accentColor,
                          ),
                          _Pill(
                            text: topic.readTime,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        topic.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        sleepEncyclopediaCardSubtitle(topic.subtitle),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        topic.summary,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.62,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _TopicImageSlot(
                        title: '图片预留区',
                        description: topic.imageAsset == null
                            ? '后续可以在这里放插画、信息图、睡前步骤图或封面视觉。'
                            : '当前已绑定图片资源，后续可以替换成正式素材。',
                        accentColor: category.accentColor,
                        imageAsset: topic.imageAsset,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _DetailSection(
                title: '核心结论',
                accentColor: category.accentColor,
                useBullet: false,
                items: <String>[topic.keyTakeaway],
              ),
              const SizedBox(height: AppSpacing.md),
              _DetailSection(
                title: '为什么会这样',
                accentColor: category.accentColor,
                items: topic.whyItHappens,
              ),
              const SizedBox(height: AppSpacing.md),
              _DetailSection(
                title: '今晚可以怎么做',
                accentColor: category.accentColor,
                items: topic.tonightActions,
              ),
              const SizedBox(height: AppSpacing.md),
              _DetailSection(
                title: '需要留意的信号',
                accentColor: category.accentColor,
                items: topic.watchouts,
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                color: Colors.white,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '继续阅读',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...relatedTopics.map(
                      (SleepEncyclopediaTopic related) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: InkWell(
                          borderRadius: AppRadius.card,
                          onTap: () => context.pushReplacement(
                            AppRoutes.sleepEncyclopediaTopicLocation(
                              related.slug,
                            ),
                          ),
                          child: Ink(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: AppRadius.card,
                            ),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        related.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        sleepEncyclopediaCardSubtitle(
                                          related.subtitle,
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: AppColors.textSecondary,
                                              height: 1.45,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                const Icon(Icons.arrow_forward_rounded),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextButton.icon(
                      onPressed: () => context.push(
                        AppRoutes.sleepEncyclopediaCategoryLocation(
                          category.slug,
                        ),
                      ),
                      icon: const Icon(Icons.grid_view_rounded),
                      label: Text('回到 ${category.title} 分类'),
                    ),
                  ],
                ),
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
    required this.accentColor,
    required this.items,
    this.useBullet = true,
  });

  final String title;
  final Color accentColor;
  final List<String> items;
  final bool useBullet;

  @override
  Widget build(BuildContext context) {
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
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.md),
          ...items.map(
            (String item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (useBullet) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.55,
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

class _TopicImageSlot extends StatelessWidget {
  const _TopicImageSlot({
    required this.title,
    required this.description,
    required this.accentColor,
    this.imageAsset,
  });

  final String title;
  final String description;
  final Color accentColor;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 196,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.card,
        border: Border.all(color: accentColor.withAlpha(50)),
      ),
      child: imageAsset == null
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.image_outlined, color: accentColor, size: 30),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            )
          : ClipRRect(
              borderRadius: AppRadius.card,
              child: SizedBox.expand(
                child: Image.asset(
                  imageAsset!,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder:
                      (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) => Center(
                        child: Text(
                          '图片加载中',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                ),
              ),
            ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

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
        color: color.withAlpha(color == AppColors.textSecondary ? 20 : 26),
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

class _TopicNotFoundPage extends StatelessWidget {
  const _TopicNotFoundPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppDetailPageAppBar(
        title: '未找到该话题',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            '这个百科话题暂时还没准备好，可以先回到睡眠百科首页浏览其他内容。',
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
