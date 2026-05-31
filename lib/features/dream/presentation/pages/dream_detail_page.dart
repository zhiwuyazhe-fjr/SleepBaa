import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/app_typography.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_detail_page_header.dart';
import 'package:sleep_dorm_app/features/dream/presentation/dream_content.dart';

class DreamDetailPage extends StatefulWidget {
  const DreamDetailPage({
    super.key,
    this.entry,
    this.entries = DreamContent.entries,
    this.showList = false,
  });

  final DreamEntryData? entry;
  final List<DreamEntryData> entries;
  final bool showList;

  @override
  State<DreamDetailPage> createState() => _DreamDetailPageState();
}

class _DreamDetailPageState extends State<DreamDetailPage> {
  DreamEntryData? _cachedEntry;

  @override
  void initState() {
    super.initState();
    _cachedEntry = widget.entry;
  }

  @override
  void didUpdateWidget(covariant DreamDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entry != null && widget.entry != _cachedEntry) {
      _cachedEntry = widget.entry;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final List<DreamEntryData> resolvedEntries = widget.entries.isEmpty
        ? DreamContent.entries
        : widget.entries;
    final DreamEntryData resolvedEntry =
        _cachedEntry ?? widget.entry ?? resolvedEntries.first;

    return Scaffold(
      backgroundColor: appColors.pageBackground,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              appColors.accentSoft.withAlpha(86),
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
              AppDetailPageHeader(
                title: widget.showList ? '全部梦境' : '梦境详情',
                onBack: () => context.pop(),
              ),
              const SizedBox(height: AppSpacing.md),
              if (widget.showList)
                _DreamEntryList(entries: resolvedEntries)
              else
                _SingleDreamDetail(entry: resolvedEntry),
            ],
          ),
        ),
      ),
    );
  }
}

class _SingleDreamDetail extends StatelessWidget {
  const _SingleDreamDetail({required this.entry});

  final DreamEntryData entry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _DreamOverviewCard(entry: entry),
        const SizedBox(height: AppSpacing.md),
        _DetailSection(
          title: '梦境映射',
          points: <String>[
            '高频线索是“${entry.tags.take(2).join('、')}”，适合和醒来后的第一情绪一起回看。',
            '醒来情绪偏“${entry.moodLabel}”，说明这条梦更适合作为近期状态的轻量观察。',
            '如果同类标签连续出现，可以在白天简单记下对应的人、事或地点。',
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const _DetailSection(
          title: '睡前关联',
          points: <String>[
            '睡前信息量变少时，梦境描述通常更连贯，也更容易记住画面细节。',
            '轻音乐和较暗的灯光更适合作为回看这类梦境的背景线索。',
          ],
        ),
      ],
    );
  }
}

class _DreamEntryList extends StatelessWidget {
  const _DreamEntryList({required this.entries});

  final List<DreamEntryData> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: entries
          .map(
            (DreamEntryData entry) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _DreamListCard(entry: entry),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _DreamOverviewCard extends StatelessWidget {
  const _DreamOverviewCard({required this.entry});

  final DreamEntryData entry;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return AppCard(
      color: appColors.surface,
      border: Border.all(color: appColors.borderSubtle),
      borderRadius: AppRadius.compactCard,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _TagRow(tags: entry.tags),
          const SizedBox(height: AppSpacing.md),
          Text(
            entry.title,
            style: AppTypography.sectionTitle(
              textTheme,
            ).copyWith(color: appColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            entry.summary,
            style: AppTypography.body(
              textTheme,
            ).copyWith(color: appColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              _MetaChip(label: entry.timeLabel, icon: Icons.schedule_rounded),
              _MetaChip(
                label: '情绪 ${entry.moodLabel}',
                icon: Icons.favorite_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DreamListCard extends StatelessWidget {
  const _DreamListCard({required this.entry});

  final DreamEntryData entry;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return AppCard(
      onTap: () => context.push(AppRoutes.dreamDetail, extra: entry),
      color: appColors.surface,
      border: Border.all(color: appColors.borderSubtle),
      borderRadius: AppRadius.compactCard,
      padding: const EdgeInsets.all(AppSpacing.md),
      boxShadow: const <BoxShadow>[],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: appColors.accentSoft,
              borderRadius: AppRadius.iconContainer,
            ),
            alignment: Alignment.center,
            child: Icon(entry.icon, color: appColors.accentDeep, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cardTitle(
                          textTheme,
                        ).copyWith(color: appColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      entry.timeLabel,
                      style: AppTypography.chip(
                        textTheme,
                      ).copyWith(color: appColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  entry.summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMuted(
                    textTheme,
                  ).copyWith(color: appColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                _TagRow(tags: entry.tags.take(2).toList(growable: false)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.points});

  final String title;
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return AppCard(
      color: appColors.surface,
      border: Border.all(color: appColors.borderSubtle),
      borderRadius: AppRadius.compactCard,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: AppTypography.cardTitle(
              textTheme,
            ).copyWith(color: appColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...points.map(
            (String item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: appColors.accentDeep,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      item,
                      style: AppTypography.bodyMuted(
                        textTheme,
                      ).copyWith(color: appColors.textSecondary),
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

class _TagRow extends StatelessWidget {
  const _TagRow({required this.tags});

  final Iterable<String> tags;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: tags.map((String tag) => _TagChip(label: tag)).toList(),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
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
        label,
        style: AppTypography.chip(
          Theme.of(context).textTheme,
        ).copyWith(color: appColors.accentDeep, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: appColors.accentSoft.withAlpha(160),
        borderRadius: AppRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: appColors.accentDeep),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.meta(Theme.of(context).textTheme).copyWith(
              color: appColors.accentDeep,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
