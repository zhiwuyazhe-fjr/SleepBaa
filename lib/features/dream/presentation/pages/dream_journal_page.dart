import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/features/dream/presentation/dream_content.dart';

class DreamJournalPage extends StatelessWidget {
  const DreamJournalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                palette.primaryHighlight.withAlpha(120),
                AppColors.background,
                AppColors.background,
              ],
            ),
          ),
          child: SafeArea(
            child: NestedScrollView(
              headerSliverBuilder:
                  (BuildContext context, bool innerBoxIsScrolled) => <Widget>[
                    SliverAppBar(
                      pinned: true,
                      floating: true,
                      elevation: 0,
                      backgroundColor: AppColors.background.withAlpha(
                        innerBoxIsScrolled ? 248 : 224,
                      ),
                      surfaceTintColor: Colors.transparent,
                      leading: IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '梦记',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '记录梦境，再看见它和情绪的连接',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      bottom: PreferredSize(
                        preferredSize: const Size.fromHeight(68),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xl,
                            AppSpacing.sm,
                            AppSpacing.xl,
                            AppSpacing.md,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(210),
                              borderRadius: AppRadius.pill,
                              border: Border.all(
                                color: palette.primarySoft.withAlpha(120),
                              ),
                            ),
                            child: TabBar(
                              dividerColor: Colors.transparent,
                              indicator: BoxDecoration(
                                color: palette.primary,
                                borderRadius: AppRadius.pill,
                              ),
                              labelColor: Colors.white,
                              unselectedLabelColor: AppColors.textSecondary,
                              indicatorSize: TabBarIndicatorSize.tab,
                              tabs: const <Widget>[
                                Tab(text: '梦境'),
                                Tab(text: '映射'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
              body: TabBarView(
                children: <Widget>[
                  _DreamListTab(palette: palette),
                  _DreamMappingTab(palette: palette),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DreamListTab extends StatelessWidget {
  const _DreamListTab({required this.palette});

  final NightMoodPalette palette;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        120,
      ),
      children: <Widget>[
        _HighlightCard(palette: palette),
        const SizedBox(height: AppSpacing.xl),
        Text(
          '最近梦境',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...DreamContent.entries.asMap().entries.map(
          (MapEntry<int, DreamEntryData> item) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _DreamEntryCard(
              entry: item.value,
              palette: palette,
              index: item.key,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Column(
            children: <Widget>[
              Icon(
                Icons.bedtime_rounded,
                size: 34,
                color: palette.primarySoft.withAlpha(180),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '继续记录，梦里的线索会更清楚',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DreamMappingTab extends StatelessWidget {
  const _DreamMappingTab({required this.palette});

  final NightMoodPalette palette;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        120,
      ),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.cardLarge,
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            children: <Widget>[
              Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.primaryHighlight.withAlpha(180),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: palette.primarySoft.withAlpha(90),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.cloud_rounded,
                  size: 64,
                  color: palette.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '梦境映射更柔和了',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '先用“场景 + 情绪 + 睡前状态”来看，不急着下结论。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _PatternBreakdownCard(palette: palette),
        const SizedBox(height: AppSpacing.md),
        ...DreamContent.insights.map(
          (DreamInsightData insight) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.card,
                boxShadow: AppColors.cardShadow,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: palette.primaryHighlight.withAlpha(150),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(insight.icon, color: palette.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          insight.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          insight.description,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                palette.primary,
                Color.lerp(palette.primary, palette.primaryDeep, 0.45)!,
              ],
            ),
            borderRadius: AppRadius.cardLarge,
            boxShadow: AppColors.floatingShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '记录建议',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ...DreamContent.suggestions.map(
                (String item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          item,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white.withAlpha(220)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.palette});

  final NightMoodPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.cardLarge,
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: palette.primaryHighlight.withAlpha(170),
                  borderRadius: AppRadius.pill,
                ),
                child: Text(
                  DreamContent.highlight.chipLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: palette.primaryDeep,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.auto_awesome_rounded, color: palette.primary),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            DreamContent.highlight.title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            DreamContent.highlight.description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: DreamContent.patterns.map((DreamPatternData pattern) {
              final Color barColor = _barColorForSeed(pattern.colorSeed);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        height: 28 + (pattern.value * 80),
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        pattern.label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _barColorForSeed(int seed) {
    switch (seed) {
      case 1:
        return palette.primarySoft;
      case 2:
        return Color.lerp(palette.primarySoft, Colors.white, 0.35)!;
      case 3:
        return Color.lerp(palette.primary, Colors.white, 0.62)!;
      default:
        return palette.primary;
    }
  }
}

class _PatternBreakdownCard extends StatelessWidget {
  const _PatternBreakdownCard({required this.palette});

  final NightMoodPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.cardLarge,
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '梦境类型分布',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: palette.primaryHighlight.withAlpha(180),
                  borderRadius: AppRadius.pill,
                ),
                child: Text(
                  '最近 30 天',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: palette.primaryDeep,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: DreamContent.patterns.asMap().entries.map((
              MapEntry<int, DreamPatternData> item,
            ) {
              final DreamPatternData pattern = item.value;
              final double baseHeight = 38 + (pattern.value * 96);
              final Color barColor = switch (item.key) {
                1 => palette.primarySoft,
                2 => Color.lerp(palette.primarySoft, Colors.white, 0.35)!,
                3 => Color.lerp(palette.primary, Colors.white, 0.62)!,
                _ => palette.primary,
              };
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: <Widget>[
                      Container(
                        height: baseHeight,
                        decoration: BoxDecoration(
                          color: barColor.withAlpha(90),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(22),
                          ),
                        ),
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: math.max(18, baseHeight - 28),
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(22),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        pattern.label,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DreamEntryCard extends StatelessWidget {
  const _DreamEntryCard({
    required this.entry,
    required this.palette,
    required this.index,
  });

  final DreamEntryData entry;
  final NightMoodPalette palette;
  final int index;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = switch (index % 3) {
      0 => const BorderRadius.only(
        topLeft: Radius.circular(AppRadius.md),
        topRight: Radius.circular(AppRadius.xl),
        bottomLeft: Radius.circular(AppRadius.md),
        bottomRight: Radius.circular(AppRadius.md),
      ),
      1 => const BorderRadius.only(
        topLeft: Radius.circular(AppRadius.xl),
        topRight: Radius.circular(AppRadius.md),
        bottomLeft: Radius.circular(AppRadius.md),
        bottomRight: Radius.circular(AppRadius.xl),
      ),
      _ => const BorderRadius.only(
        topLeft: Radius.circular(AppRadius.md),
        topRight: Radius.circular(AppRadius.md),
        bottomLeft: Radius.circular(AppRadius.xl),
        bottomRight: Radius.circular(AppRadius.md),
      ),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: () => context.push(AppRoutes.dreamDetail),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: radius,
            boxShadow: AppColors.cardShadow,
            border: Border.all(color: palette.primaryHighlight.withAlpha(80)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: entry.tags.take(2).map((String tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: palette.primaryHighlight.withAlpha(150),
                            borderRadius: AppRadius.pill,
                          ),
                          child: Text(
                            tag,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: palette.primaryDeep,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        );
                      }).toList(),
                    ),
                    const Spacer(),
                    Text(
                      entry.timeLabel,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  entry.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  entry.summary,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: palette.primaryHighlight.withAlpha(170),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(entry.icon, color: palette.primary),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '醒来情绪：${entry.moodLabel}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: palette.primaryDeep,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.east_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
