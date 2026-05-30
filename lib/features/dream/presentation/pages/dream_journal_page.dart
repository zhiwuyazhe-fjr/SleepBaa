import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_page_insets.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/app_typography.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_detail_page_header.dart';
import 'package:sleep_dorm_app/core/widgets/section_title.dart';
import 'package:sleep_dorm_app/features/dream/presentation/dream_content.dart';

class DreamJournalPage extends StatelessWidget {
  const DreamJournalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: appColors.pageBackground,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                appColors.accentSoft.withAlpha(90),
                appColors.pageBackground,
                appColors.pageBackground,
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
                      backgroundColor: appColors.pageBackground.withAlpha(
                        innerBoxIsScrolled ? 248 : 224,
                      ),
                      surfaceTintColor: Colors.transparent,
                      automaticallyImplyLeading: false,
                      titleSpacing: 0,
                      title: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                        ),
                        child: AppDetailPageHeader(
                          title: '梦记',
                          onBack: () => context.pop(),
                        ),
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
                          child: ClipRRect(
                            borderRadius: AppRadius.pill,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: appColors.surface.withAlpha(232),
                                borderRadius: AppRadius.pill,
                                border: Border.all(
                                  color: appColors.borderSubtle,
                                ),
                              ),
                              child: TabBar(
                                dividerColor: Colors.transparent,
                                overlayColor:
                                    const WidgetStatePropertyAll<Color>(
                                      Colors.transparent,
                                    ),
                                splashFactory: NoSplash.splashFactory,
                                indicator: BoxDecoration(
                                  color: appColors.accent,
                                  borderRadius: AppRadius.pill,
                                ),
                                labelColor: appColors.textOnAccent,
                                unselectedLabelColor: appColors.textSecondary,
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
                    ),
                  ],
              body: TabBarView(
                children: <Widget>[
                  const _DreamListTab(),
                  const _DreamMappingTab(),
                  const _DreamCreateTab(),
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
  const _DreamCreateTab();

  @override
  State<_DreamCreateTab> createState() => _DreamCreateTabState();
}

class _DreamCreateTabState extends State<_DreamCreateTab> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<String> _entries = <String>[];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleDraftChanged);
  }

  bool get _canSave => _controller.text.trim().isNotEmpty;

  void _handleDraftChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleDraftChanged);
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
      await notifyPassiveToast(context, message: '这段梦已经收进“梦境记录”。');
    }
  }

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AppSemanticColors appColors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            appColors.accentSoft.withAlpha(64),
            appColors.pageBackground,
            appColors.pageBackground,
          ],
        ),
      ),
      child: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: AppPageInsets.page(
                top: AppSpacing.xl,
                bottom: AppSpacing.lg,
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
                            color: appColors.accentSoft.withAlpha(180),
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
                                appColors.accentSoft,
                                appColors.surface,
                              ],
                            ),
                            border: Border.all(
                              color: appColors.accent.withAlpha(120),
                            ),
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: appColors.accent,
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
                  style: AppTypography.panelTitle(textTheme),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '不用一次写完整，先把还记得的画面、人物、颜色或一句话留住就好。',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMuted(
                    textTheme,
                  ).copyWith(color: appColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppCard(
                  color: Color.alphaBlend(
                    appColors.accentSoft.withAlpha(110),
                    appColors.surface,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  borderRadius: AppRadius.compactCard,
                  border: _dreamCardBorder(palette, alpha: 110),
                  child: Text(
                    '如果刚醒来还模糊，可以先从“我看到了什么”“我当时什么感觉”“有没有一句特别清楚的话”开始写，我会帮你把梦记轻轻收好。',
                    style: AppTypography.body(
                      textTheme,
                    ).copyWith(color: appColors.accentDeep, height: 1.55),
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
                              topLeft: Radius.circular(AppRadius.standard),
                              topRight: Radius.circular(AppRadius.standard),
                              bottomLeft: Radius.circular(AppRadius.standard),
                              bottomRight: Radius.circular(AppRadius.xs),
                            ),
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: Text(
                            entry,
                            style: AppTypography.body(textTheme).copyWith(
                              color: appColors.textOnAccent,
                              height: 1.55,
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
              color: appColors.surface.withAlpha(248),
              border: Border(top: BorderSide(color: appColors.borderSubtle)),
            ),
            child: _DreamComposer(
              controller: _controller,
              focusNode: _focusNode,
              canSubmit: _canSave,
              onSubmit: _saveDream,
            ),
          ),
        ],
      ),
    );
  }
}

class _DreamComposer extends StatelessWidget {
  const _DreamComposer({
    required this.controller,
    required this.focusNode,
    required this.canSubmit,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool canSubmit;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          appColors.accentSoft.withAlpha(78),
          appColors.surface,
        ),
        borderRadius: AppRadius.control,
        border: Border.all(color: appColors.borderSubtle),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: TextField(
                key: const ValueKey<String>('dream-composer-field'),
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                cursorColor: appColors.accentDeep,
                decoration: InputDecoration(
                  isCollapsed: true,
                  hintText: '例如：我梦见自己站在很高的桥上，风很冷，但并不害怕...',
                  hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: appColors.textSecondary.withAlpha(170),
                    height: 1.45,
                  ),
                  border: InputBorder.none,
                ),
                style: AppTypography.body(
                  Theme.of(context).textTheme,
                ).copyWith(color: appColors.textPrimary, height: 1.55),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Semantics(
              button: true,
              label: '收好这段梦',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey<String>('dream-composer-submit'),
                  borderRadius: AppRadius.pill,
                  onTap: canSubmit ? onSubmit : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: canSubmit
                          ? appColors.accent
                          : appColors.accentSoft.withAlpha(180),
                      borderRadius: AppRadius.pill,
                    ),
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      size: 18,
                      color: canSubmit
                          ? appColors.textOnAccent
                          : appColors.accentDeep,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DreamListTab extends StatelessWidget {
  const _DreamListTab();

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    final AppSemanticColors appColors = context.appColors;
    final NightMoodPalette palette = context.nightMoodPalette;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: services.sleepCaptureRepository,
      builder: (BuildContext context, Widget? child) {
        final List<SleepCaptureRecord> capturedRecords =
            List<SleepCaptureRecord>.from(
              services.sleepCaptureRepository.recordsByType(
                SleepCaptureType.dream,
              ),
            )..sort(
              (SleepCaptureRecord a, SleepCaptureRecord b) =>
                  b.createdAt.compareTo(a.createdAt),
            );
        final List<DreamEntryData> capturedEntries = capturedRecords
            .map(_dreamEntryFromRecord)
            .toList();
        final List<DreamEntryData> allEntries = <DreamEntryData>[
          ...capturedEntries,
          ...DreamContent.entries,
        ];
        final DreamEntryData latestEntry = allEntries.first;

        return ListView(
          padding: AppPageInsets.page(
            top: AppSpacing.md,
            bottom: AppSpacing.xxxl,
          ),
          children: <Widget>[
            _HighlightCard(palette: palette),
            const SizedBox(height: AppSpacing.lg),
            SectionTitle(
              title: '最近梦境',
              actionLabel: '查看详细',
              onAction: () {
                context.push(
                  AppRoutes.dreamDetailListLocation(),
                  extra: allEntries,
                );
              },
              titleStyle: AppTypography.sectionTitle(
                textTheme,
              ).copyWith(color: appColors.textPrimary),
              actionStyle: AppTypography.meta(
                textTheme,
              ).copyWith(color: appColors.accentDeep),
            ),
            const SizedBox(height: AppSpacing.sm),
            _DreamEntryCard(entry: latestEntry, palette: palette),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: Column(
                children: <Widget>[
                  Icon(
                    Icons.bedtime_rounded,
                    size: 30,
                    color: appColors.accentSoft.withAlpha(180),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '继续记录，梦里的线索会更清楚',
                    style: AppTypography.bodyMuted(
                      textTheme,
                    ).copyWith(color: appColors.textSecondary),
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
  const _DreamMappingTab();

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    final AppSemanticColors appColors = context.appColors;
    final NightMoodPalette palette = context.nightMoodPalette;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: services.sleepCaptureRepository,
      builder: (BuildContext context, Widget? child) {
        final List<SleepCaptureRecord> records = services.sleepCaptureRepository
            .recordsByType(SleepCaptureType.dream);
        final _DreamAnalysisViewData analysis = _buildDreamAnalysis(records);
        return ListView(
          padding: AppPageInsets.page(
            top: AppSpacing.md,
            bottom: AppSpacing.xxxl,
          ),
          children: <Widget>[
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              borderRadius: AppRadius.compactCard,
              border: _dreamCardBorder(palette),
              child: Column(
                children: <Widget>[
                  Container(
                    key: const ValueKey<String>('dream-mapping-hero-image'),
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: appColors.accentSoft.withAlpha(180),
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
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    analysis.mappingTitle,
                    style: AppTypography.panelTitle(
                      textTheme,
                    ).copyWith(color: appColors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    analysis.mappingDescription,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMuted(
                      textTheme,
                    ).copyWith(color: appColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _PatternBreakdownCard(
              palette: palette,
              patterns: analysis.patterns,
              badgeLabel: analysis.patternBadge,
            ),
            const SizedBox(height: AppSpacing.md),
            ...analysis.insights.map(
              (DreamInsightData insight) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  borderRadius: AppRadius.compactCard,
                  border: _dreamCardBorder(palette),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: appColors.accentSoft.withAlpha(150),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Icon(insight.icon, color: appColors.accent),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              insight.title,
                              style: AppTypography.cardTitle(
                                textTheme,
                              ).copyWith(color: appColors.textPrimary),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              insight.summary,
                              style: AppTypography.bodyMuted(
                                textTheme,
                              ).copyWith(color: appColors.textSecondary),
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
                                        color: appColors.accent,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        point,
                                        style:
                                            AppTypography.bodyMuted(
                                              textTheme,
                                            ).copyWith(
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.palette});

  final NightMoodPalette palette;

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: services.sleepCaptureRepository,
      builder: (BuildContext context, Widget? child) {
        final _DreamAnalysisViewData analysis = _buildDreamAnalysis(
          services.sleepCaptureRepository.recordsByType(SleepCaptureType.dream),
        );
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          borderRadius: AppRadius.compactCard,
          border: _dreamCardBorder(palette),
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
                      color: appColors.accentSoft.withAlpha(170),
                      borderRadius: AppRadius.pill,
                    ),
                    child: Text(
                      analysis.highlight.chipLabel,
                      style: AppTypography.chip(textTheme).copyWith(
                        color: appColors.accentDeep,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(Icons.auto_awesome_rounded, color: appColors.accent),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                analysis.highlight.title,
                style: AppTypography.panelTitle(
                  textTheme,
                ).copyWith(color: appColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                analysis.highlight.description,
                style: AppTypography.bodyMuted(
                  textTheme,
                ).copyWith(color: appColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: analysis.patterns.map((DreamPatternData pattern) {
                  final Color barColor = _barColorForSeed(pattern.colorSeed);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxs,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            height: 16 + (pattern.value * 40),
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(AppRadius.md),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            pattern.label,
                            style: AppTypography.chip(
                              textTheme,
                            ).copyWith(color: appColors.textSecondary),
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
      },
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
  const _PatternBreakdownCard({
    required this.palette,
    required this.patterns,
    required this.badgeLabel,
  });

  final NightMoodPalette palette;
  final List<DreamPatternData> patterns;
  final String badgeLabel;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: AppRadius.compactCard,
      border: _dreamCardBorder(palette),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '梦境类型分布',
                  style: AppTypography.panelTitle(
                    textTheme,
                  ).copyWith(color: appColors.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: appColors.accentSoft.withAlpha(180),
                  borderRadius: AppRadius.pill,
                ),
                child: Text(
                  badgeLabel,
                  style: AppTypography.chip(textTheme).copyWith(
                    color: appColors.accentDeep,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: patterns.asMap().entries.map((
              MapEntry<int, DreamPatternData> item,
            ) {
              final DreamPatternData pattern = item.value;
              final double baseHeight = 30 + (pattern.value * 76);
              final Color barColor = switch (item.key) {
                1 => palette.primarySoft,
                2 => Color.lerp(palette.primarySoft, Colors.white, 0.35)!,
                3 => Color.lerp(palette.primary, Colors.white, 0.62)!,
                _ => palette.primary,
              };
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxs,
                  ),
                  child: Column(
                    children: <Widget>[
                      Container(
                        height: baseHeight,
                        decoration: BoxDecoration(
                          color: barColor.withAlpha(90),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(AppRadius.standard),
                          ),
                        ),
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: math.max(18, baseHeight - 28),
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(AppRadius.standard),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        pattern.label,
                        style: AppTypography.chip(
                          textTheme,
                        ).copyWith(color: appColors.textSecondary),
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

class _DreamAnalysisViewData {
  const _DreamAnalysisViewData({
    required this.highlight,
    required this.patterns,
    required this.insights,
    required this.mappingTitle,
    required this.mappingDescription,
    required this.patternBadge,
  });

  final DreamHighlightData highlight;
  final List<DreamPatternData> patterns;
  final List<DreamInsightData> insights;
  final String mappingTitle;
  final String mappingDescription;
  final String patternBadge;
}

_DreamAnalysisViewData _buildDreamAnalysis(List<SleepCaptureRecord> records) {
  if (records.isEmpty) {
    return const _DreamAnalysisViewData(
      highlight: DreamContent.highlight,
      patterns: DreamContent.patterns,
      insights: DreamContent.insights,
      mappingTitle: '学会梦的语言，解锁梦的启示',
      mappingDescription: '从反复出现的场景、情绪和线索里，慢慢看见梦境在提醒你的东西。',
      patternBadge: '最近 30 天',
    );
  }

  final List<SleepCaptureRecord> sorted = List<SleepCaptureRecord>.from(records)
    ..sort(
      (SleepCaptureRecord a, SleepCaptureRecord b) =>
          b.createdAt.compareTo(a.createdAt),
    );
  final int total = sorted.length;
  final Map<String, int> counts = <String, int>{};
  for (final SleepCaptureRecord record in sorted.take(12)) {
    for (final String label in _dreamPatternLabelsForRecord(record)) {
      counts.update(label, (int value) => value + 1, ifAbsent: () => 1);
    }
  }
  final List<MapEntry<String, int>> topLabels = counts.entries.toList()
    ..sort((MapEntry<String, int> a, MapEntry<String, int> b) {
      final int byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });

  final List<DreamPatternData> patterns = <DreamPatternData>[
    for (int index = 0; index < 4; index++)
      DreamPatternData(
        label: index < topLabels.length ? topLabels[index].key : '留白',
        value: index < topLabels.length
            ? (topLabels[index].value / math.max(1, total)).clamp(0.18, 0.92)
            : 0.18,
        colorSeed: index,
      ),
  ];

  final String topLabel = topLabels.isEmpty ? '梦境' : topLabels.first.key;
  final SleepCaptureRecord latest = sorted.first;
  final String latestSummary = latest.outline.trim().isNotEmpty
      ? latest.outline.trim()
      : latest.content.trim();

  return _DreamAnalysisViewData(
    highlight: DreamHighlightData(
      title: '最近的梦开始围绕“$topLabel”展开',
      description:
          '当前梦记已经接到真实记录，最近 $total 条里，$topLabel 出现得最频繁，主导情绪偏向“${latest.title}”，适合回看时重点关注人物、颜色、地点与提醒感受。',
      chipLabel: '本周已记录 $total 次',
    ),
    patterns: patterns,
    mappingTitle: '从真实梦境里读出重复线索',
    mappingDescription:
        '当前梦记已经接到真实云端数据。最近 $total 条里，高频线索更接近“$topLabel”，情绪倾向可结合醒后标题和摘要继续回看。',
    patternBadge: '最近 $total 条',
    insights: <DreamInsightData>[
      DreamInsightData(
        title: '高频意象',
        summary: '最近梦记里最常见的是“$topLabel”，说明它已经开始成为你这段时间梦境的稳定主题。',
        points: <String>[
          '最近记录共 $total 条，最高频线索是“$topLabel”。',
          if (topLabels.length > 1)
            '第二常见线索是“${topLabels[1].key}”，说明梦境主题不是完全单一的。',
          '这类高频标签来自你真实输入内容和 AI 摘要中的关键词提取，而不是固定示例。',
        ],
        icon: Icons.explore_rounded,
      ),
      DreamInsightData(
        title: '情绪映射',
        summary: '最新一条梦记的标题是“${latest.title}”，可以先把它当作当前醒后主情绪的参考锚点。',
        points: <String>[
          '最新记录时间是 ${_formatRelativeDreamTime(latest.createdAt)}。',
          '如果你发现最近标题经常重复某种情绪词，通常说明醒后的第一感觉比较稳定。',
          '优先回看最近 3 条，比一次看太多更容易发现真实模式。',
        ],
        icon: Icons.favorite_rounded,
      ),
      DreamInsightData(
        title: '调节建议',
        summary: '先从最近一条真实梦记出发，做轻量回看，不要急着给梦下结论。',
        points: <String>[
          '先读一遍最近一条摘要：$latestSummary',
          '如果某个标签连续几天出现，可以在白天简单记下现实里对应的人、事或地点。',
          '映射页更适合做趋势观察，不一定每条梦都要立刻解释清楚。',
        ],
        icon: Icons.self_improvement_rounded,
      ),
    ],
  );
}

Set<String> _dreamPatternLabelsForRecord(SleepCaptureRecord record) {
  final String text = '${record.title} ${record.outline} ${record.content}'
      .toLowerCase();
  final Set<String> labels = <String>{};
  void match(String label, List<String> keywords) {
    if (keywords.any((String keyword) => text.contains(keyword))) {
      labels.add(label);
    }
  }

  match('飞行', <String>['飞', '天空', '高空', '漂浮']);
  match('追逐', <String>['追', '跑', '赶', '逃']);
  match('熟人', <String>['同学', '朋友', '家人', '老师', '室友']);
  match('场景', <String>['房间', '教室', '学校', '电影', '路', '桥']);
  match('情绪', <String>['害怕', '开心', '紧张', '轻松', '平静']);

  if (labels.isEmpty) {
    labels.add('梦境');
  }
  return labels;
}

String _formatRelativeDreamTime(DateTime dateTime) {
  final String hh = dateTime.hour.toString().padLeft(2, '0');
  final String mm = dateTime.minute.toString().padLeft(2, '0');
  return '今天 $hh:$mm';
}

class _DreamEntryCard extends StatelessWidget {
  const _DreamEntryCard({required this.entry, required this.palette});

  final DreamEntryData entry;
  final NightMoodPalette palette;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return AppCard(
      onTap: () => context.push(AppRoutes.dreamDetail, extra: entry),
      borderRadius: AppRadius.compactCard,
      border: _dreamCardBorder(palette, alpha: 100),
      padding: const EdgeInsets.all(AppSpacing.md),
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
                      color: appColors.accentSoft.withAlpha(150),
                      borderRadius: AppRadius.pill,
                    ),
                    child: Text(
                      tag,
                      style: AppTypography.chip(textTheme).copyWith(
                        color: appColors.accentDeep,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Spacer(),
              Text(
                entry.timeLabel,
                style: AppTypography.chip(
                  textTheme,
                ).copyWith(color: appColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            entry.title,
            style: AppTypography.cardTitle(
              textTheme,
            ).copyWith(color: appColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            entry.summary,
            style: AppTypography.bodyMuted(
              textTheme,
            ).copyWith(color: appColors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: appColors.accentSoft.withAlpha(170),
                  borderRadius: AppRadius.iconContainer,
                ),
                child: Icon(entry.icon, color: appColors.accent),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '醒来情绪：${entry.moodLabel}',
                style: AppTypography.meta(
                  textTheme,
                ).copyWith(color: appColors.accentDeep),
              ),
              const Spacer(),
              Icon(Icons.east_rounded, color: appColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }
}

Border _dreamCardBorder(NightMoodPalette palette, {int alpha = 90}) {
  return Border.all(color: palette.primaryHighlight.withAlpha(alpha));
}
