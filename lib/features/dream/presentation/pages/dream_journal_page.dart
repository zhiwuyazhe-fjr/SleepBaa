import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/features/dream/presentation/dream_content.dart';

class DreamJournalPage extends StatelessWidget {
  const DreamJournalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    return DefaultTabController(
      length: 3,
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
                      toolbarHeight: 76,
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
                        preferredSize: const Size.fromHeight(76),
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
                                Tab(text: '新建'),
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
                  _DreamCreateTab(palette: palette),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DreamCreateTab extends StatefulWidget {
  const _DreamCreateTab({required this.palette});

  final NightMoodPalette palette;

  @override
  State<_DreamCreateTab> createState() => _DreamCreateTabState();
}

class _DreamCreateTabState extends State<_DreamCreateTab> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<String> _entries = <String>[];

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _saveDream() async {
    final String draft = _controller.text.trim();
    if (draft.isEmpty) {
      _focusNode.requestFocus();
      return;
    }

    final AppServices services = context.appServices;
    final String sessionId =
        services.sleepSessionRepository.activeSession?.id ??
        'manual-dream-${DateTime.now().millisecondsSinceEpoch}';

    await services.sleepCaptureRepository.addRecord(
      type: SleepCaptureType.dream,
      sessionId: sessionId,
      content: draft,
    );

    if (mounted) {
      setState(() {
        _entries.add(draft);
        _controller.clear();
      });
      _focusNode.unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('这段梦已经收进“梦境记录”。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = widget.palette;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            palette.primaryHighlight.withAlpha(90),
            AppColors.background,
            Colors.white,
          ],
        ),
      ),
      child: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              children: <Widget>[
                Center(
                  child: Container(
                    width: 116,
                    height: 116,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: palette.primarySoft.withAlpha(110),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: palette.primaryHighlight.withAlpha(180),
                          ),
                        ),
                        Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                palette.primaryHighlight,
                                Colors.white,
                              ],
                            ),
                            border: Border.all(
                              color: palette.primarySoft.withAlpha(120),
                            ),
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: palette.primary,
                            size: 34,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  '把梦先轻轻记下来',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '不用一次写完整，先把还记得的画面、人物、颜色或一句话留住就好。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      palette.primaryHighlight.withAlpha(120),
                      Colors.white,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: palette.primarySoft.withAlpha(90),
                    ),
                  ),
                  child: Text(
                    '如果刚醒来还模糊，可以先从“我看到了什么”“我当时什么感觉”“有没有一句特别清楚的话”开始写，我会帮你把梦记轻轻收好。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.primaryDeep,
                      height: 1.55,
                    ),
                  ),
                ),
                if (_entries.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.xl),
                  ..._entries.reversed.map(
                    (String entry) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 520),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                palette.primary,
                                Color.lerp(
                                  palette.primary,
                                  palette.primaryDeep,
                                  0.42,
                                )!,
                              ],
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                              bottomLeft: Radius.circular(24),
                              bottomRight: Radius.circular(8),
                            ),
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: Text(
                            entry,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  height: 1.55,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(245),
              border: Border(
                top: BorderSide(color: palette.primarySoft.withAlpha(70)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: palette.primaryHighlight.withAlpha(70),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: palette.primarySoft.withAlpha(90),
                      ),
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: '例如：我梦见自己站在很高的桥上，风很冷，但并不害怕...',
                        hintStyle: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(
                              color: AppColors.textSecondary.withAlpha(170),
                            ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: 16,
                        ),
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        palette.primary,
                        Color.lerp(palette.primary, palette.primaryDeep, 0.4)!,
                      ],
                    ),
                    boxShadow: AppColors.floatingShadow,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(26),
                      onTap: _saveDream,
                      child: const Center(
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
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

class _DreamListTab extends StatelessWidget {
  const _DreamListTab({required this.palette});

  final NightMoodPalette palette;

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return ListenableBuilder(
      listenable: services.sleepCaptureRepository,
      builder: (BuildContext context, Widget? child) {
        final List<DreamEntryData> capturedEntries = services
            .sleepCaptureRepository
            .recordsByType(SleepCaptureType.dream)
            .map(_dreamEntryFromRecord)
            .toList();
        final List<DreamEntryData> allEntries = <DreamEntryData>[
          ...capturedEntries,
          ...DreamContent.entries,
        ];

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
            ...allEntries.asMap().entries.map(
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  DreamEntryData _dreamEntryFromRecord(SleepCaptureRecord record) {
    final String hh = record.createdAt.hour.toString().padLeft(2, '0');
    final String mm = record.createdAt.minute.toString().padLeft(2, '0');
    return DreamEntryData(
      title: record.title,
      summary: record.content,
      timeLabel: '今天 $hh:$mm',
      moodLabel: '待回看',
      tags: const <String>['AI收录', '睡眠模式'],
      icon: Icons.nights_stay_rounded,
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
                  image: const DecorationImage(
                    image: AssetImage('assets/images/dream_top.png'),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: palette.primarySoft.withAlpha(90),
                      blurRadius: 30,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '学会梦的语言，解锁梦的启示',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '从反复出现的场景、情绪和线索里，慢慢看见梦境在提醒你的东西。',
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
                          insight.summary,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ...insight.points.map(
                          (String point) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Icon(
                                    Icons.circle,
                                    size: 6,
                                    color: palette.primary,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    point,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
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
                  ),
                ],
              ),
            ),
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
