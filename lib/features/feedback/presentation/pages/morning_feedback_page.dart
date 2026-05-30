import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_detail_page_header.dart';
import 'package:sleep_dorm_app/core/widgets/modals/app_modal.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';

@visibleForTesting
bool shouldShowMorningFeedbackLoading({
  required String explicitSessionId,
  required bool isReadyForSessionLookup,
  required List<SleepSession> sessions,
}) {
  final String normalizedSessionId = explicitSessionId.trim();
  if (normalizedSessionId.isEmpty || isReadyForSessionLookup) {
    return false;
  }
  return !sessions.any(
    (SleepSession session) => session.id == normalizedSessionId,
  );
}

@visibleForTesting
bool canOpenMorningFeedbackExplicitSession(SleepSession session) {
  return isLiveMorningFeedbackSession(session) ||
      canSubmitMorningFeedbackForSession(session);
}

@visibleForTesting
bool isLiveMorningFeedbackSession(SleepSession session) {
  return session.status == SleepSessionStatus.active &&
      session.sleepModeActive &&
      session.openSegment != null &&
      !session.hasSubmittedFeedback;
}

class MorningFeedbackPage extends StatefulWidget {
  const MorningFeedbackPage({
    super.key,
    this.sessionId,
    this.allowReturnToSleep = false,
  });

  final String? sessionId;
  final bool allowReturnToSleep;

  @override
  State<MorningFeedbackPage> createState() => _MorningFeedbackPageState();
}

class _MorningFeedbackPageState extends State<MorningFeedbackPage> {
  final Map<String, RecommendationFeedbackStatus> _statuses =
      <String, RecommendationFeedbackStatus>{};
  final Map<String, TextEditingController> _feedbackNotes =
      <String, TextEditingController>{};
  int _estimatedSleepLatency = 20;
  int _sleepQuality = 4;
  int _restedLevel = 4;
  String? _boundSessionId;
  bool _isReturningToSleep = false;
  bool _isSubmittingFeedback = false;
  Timer? _liveRefreshTimer;

  @override
  void initState() {
    super.initState();
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 30), (
      Timer timer,
    ) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    for (final TextEditingController controller in _feedbackNotes.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    final AppSemanticColors appColors = context.appColors;
    final NightMoodPalette palette = context.nightMoodPalette;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        services.sleepSessionRepository,
        services.notificationRepository,
      ]),
      builder: (BuildContext context, Widget? child) {
        final SleepSessionRepository repository =
            services.sleepSessionRepository;
        final GoRouterState routerState = GoRouterState.of(context);
        final String explicitSessionId =
            widget.sessionId ??
            routerState.uri.queryParameters['sessionId'] ??
            '';
        final DateTime feedbackMoment =
            services.sleepExperienceController.currentTime;
        final _MorningFeedbackTarget target = _resolveTargetSession(
          repository,
          feedbackMoment: feedbackMoment,
          explicitSessionId: explicitSessionId,
        );
        final SleepSession? session = target.session;
        final bool isLiveMode =
            session != null && target.mode == _MorningFeedbackMode.live;
        final bool usesReturnFlow = widget.allowReturnToSleep || isLiveMode;
        return PopScope<void>(
          canPop: !usesReturnFlow,
          onPopInvokedWithResult: (bool didPop, void result) {
            if (didPop) {
              return;
            }
            if (isLiveMode) {
              _triggerDiscardLiveFeedback();
              return;
            }
            if (!widget.allowReturnToSleep) {
              return;
            }
            _triggerReturnToSleep();
          },
          child: Scaffold(
            backgroundColor: appColors.pageBackground,
            appBar: AppDetailPageAppBar(
              title: '晨间反馈',
              onBack: _isReturningToSleep
                  ? () {}
                  : usesReturnFlow
                  ? isLiveMode
                        ? _triggerDiscardLiveFeedback
                        : _triggerReturnToSleep
                  : () => Navigator.of(context).maybePop(),
            ),
            body: _buildBody(
              context,
              services: services,
              palette: palette,
              repository: repository,
              explicitSessionId: explicitSessionId,
              target: target,
              feedbackMoment: feedbackMoment,
              usesReturnFlow: usesReturnFlow,
              isLiveMode: isLiveMode,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required AppServices services,
    required NightMoodPalette palette,
    required SleepSessionRepository repository,
    required String explicitSessionId,
    required _MorningFeedbackTarget target,
    required DateTime feedbackMoment,
    required bool usesReturnFlow,
    required bool isLiveMode,
  }) {
    if (_isReturningToSleep) {
      return _ReturningToSleepLoading(palette: palette);
    }
    if (_isSubmittingFeedback) {
      return _SubmittingMorningFeedbackLoading(palette: palette);
    }
    if (shouldShowMorningFeedbackLoading(
      explicitSessionId: explicitSessionId,
      isReadyForSessionLookup: repository.isReadyForSessionLookup,
      sessions: repository.sessions,
    )) {
      return const Center(child: CircularProgressIndicator());
    }
    final SleepSession? session = target.session;
    if (session == null) {
      return Center(child: Text(target.message));
    }
    _bindSession(session);
    final DateTime endAt = _resolveFeedbackDisplayEndAt(
      session,
      feedbackMoment,
    );
    final DateTime startAt = _resolveFeedbackDisplayStartAt(session, endAt);
    final int totalRecordMinutes = session.liveTrackedDurationMinutes(
      now: endAt,
    );
    final int actualSleepMinutes = (totalRecordMinutes - _estimatedSleepLatency)
        .clamp(0, 24 * 60);
    final AppSemanticColors appColors = context.appColors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: <Widget>[
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          borderRadius: AppRadius.compactCard,
          color: appColors.surface,
          border: Border.all(color: appColors.borderSubtle),
          boxShadow: const <BoxShadow>[],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xxs,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: <Widget>[
                  Text(
                    '睡眠摘要',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${_formatDateLabel(startAt)} ${_formatClock(startAt)} - '
                    '${_formatDateLabel(endAt)} ${_formatClock(endAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: appColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _MetricSummaryTile(
                      label: '睡眠质量',
                      value: '$_sleepQuality / 5',
                      palette: palette,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _MetricSummaryTile(
                      label: '恢复感',
                      value: '$_restedLevel / 5',
                      palette: palette,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              _MetricSummaryTile(
                label: '实际睡眠时长',
                value: _formatDurationMinutes(actualSleepMinutes),
                palette: palette,
                detail:
                    '记录 ${_formatDurationMinutes(totalRecordMinutes)}，扣除预计入睡时长后自动计算',
              ),
              const SizedBox(height: AppSpacing.sm),
              _MetricSlider(
                label: '预计入睡时长',
                value: _estimatedSleepLatency.toDouble(),
                min: 0,
                max: 120,
                divisions: 24,
                suffix: 'min',
                palette: palette,
                onChanged: (double value) {
                  setState(() => _estimatedSleepLatency = value.round());
                },
              ),
              _MetricSlider(
                label: '睡眠质量',
                value: _sleepQuality.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                suffix: '/5',
                palette: palette,
                onChanged: (double value) {
                  setState(() => _sleepQuality = value.round());
                },
              ),
              _MetricSlider(
                label: '起床恢复感',
                value: _restedLevel.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                suffix: '/5',
                palette: palette,
                onChanged: (double value) {
                  setState(() => _restedLevel = value.round());
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '逐条反馈建议',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${session.recommendations.length} 条',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: appColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ...session.recommendations.map((NightRecommendation recommendation) {
          final TextEditingController noteController = _feedbackNotes
              .putIfAbsent(recommendation.id, TextEditingController.new);
          final RecommendationFeedbackStatus current =
              _statuses[recommendation.id] ??
              _defaultFeedbackStatusFor(session, recommendation);
          final bool wasExecuted = _wasRecommendationExecuted(
            session,
            recommendation,
          );
          final bool hasNote = noteController.text.trim().isNotEmpty;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              borderRadius: AppRadius.compactCard,
              color: appColors.surface,
              border: Border.all(color: appColors.borderSubtle),
              boxShadow: const <BoxShadow>[],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    recommendation.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    recommendation.subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: appColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      _CompactStatusPill(
                        icon: wasExecuted
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        label: wasExecuted ? '昨晚已执行' : '昨晚未执行',
                        highlight: wasExecuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      _CompactActionPill(
                        icon: hasNote
                            ? Icons.edit_note_rounded
                            : Icons.add_rounded,
                        label: hasNote ? '已填写说明' : '补充说明',
                        onTap: () => _showRecommendationNoteSheet(
                          context,
                          controller: noteController,
                        ),
                      ),
                      _CompactActionPill(
                        label: '反馈状态：${_feedbackLabel(current)} ▾',
                        highlight:
                            current == RecommendationFeedbackStatus.effective,
                        onTap: () async {
                          final RecommendationFeedbackStatus? selected =
                              await _showRecommendationStatusSheet(
                                context,
                                current: current,
                              );
                          if (selected == null || !mounted) {
                            return;
                          }
                          setState(
                            () => _statuses[recommendation.id] = selected,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        PrimaryButton(
          label: isLiveMode ? '提交反馈并结束本次睡眠' : '提交反馈',
          size: PrimaryButtonSize.compact,
          onPressed: () async {
            if (_isSubmittingFeedback) {
              return;
            }
            setState(() => _isSubmittingFeedback = true);
            final GoRouter router = GoRouter.of(context);
            final DateTime submittedAt =
                services.sleepExperienceController.currentTime;
            final int submittedRecordMinutes = session
                .liveTrackedDurationMinutes(now: submittedAt);
            final int submittedActualSleepMinutes =
                (submittedRecordMinutes - _estimatedSleepLatency).clamp(
                  0,
                  24 * 60,
                );
            final List<RecommendationFeedback> feedback = session
                .recommendations
                .map((NightRecommendation item) {
                  return RecommendationFeedback(
                    recommendationId: item.id,
                    status:
                        _statuses[item.id] ??
                        _defaultFeedbackStatusFor(session, item),
                    note: _feedbackNotes[item.id]?.text.trim() ?? '',
                    submittedAt: DateTime.now(),
                  );
                })
                .toList(growable: false);
            try {
              await services.sleepExperienceController.submitMorningFeedback(
                session: session,
                summary: MorningSummary(
                  sleepQuality: _sleepQuality,
                  restedLevel: _restedLevel,
                  totalSleepHours: submittedActualSleepMinutes / 60,
                  awakeningsCount: session.awakenings.length,
                  note: '',
                ),
                feedback: feedback,
              );
              if (!context.mounted) {
                return;
              }
              router.go(
                AppRoutes.homePreSleepLocation(
                  notice: AppRoutes.feedbackSubmittedNotice,
                ),
              );
            } catch (_) {
              if (!context.mounted) {
                return;
              }
              setState(() => _isSubmittingFeedback = false);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('提交晨间反馈失败，请重试')));
            }
          },
        ),
        if (usesReturnFlow) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: '返回',
            size: PrimaryButtonSize.compact,
            variant: PrimaryButtonVariant.ghost,
            onPressed: _isReturningToSleep
                ? null
                : isLiveMode
                ? _triggerDiscardLiveFeedback
                : _triggerReturnToSleep,
          ),
        ],
      ],
    );
  }

  void _triggerDiscardLiveFeedback() {
    if (!context.mounted) {
      return;
    }
    unawaited(_handleDiscardLiveFeedback(context));
  }

  void _triggerReturnToSleep() {
    if (!context.mounted) {
      return;
    }
    unawaited(_handleReturnToSleep(context));
  }

  _MorningFeedbackTarget _resolveTargetSession(
    SleepSessionRepository repository, {
    required DateTime feedbackMoment,
    String? explicitSessionId,
  }) {
    final String normalizedSessionId = explicitSessionId?.trim() ?? '';
    if (normalizedSessionId.isNotEmpty) {
      for (final SleepSession session in repository.sessions) {
        if (session.id != normalizedSessionId) {
          continue;
        }
        if (session.hasSubmittedFeedback) {
          return const _MorningFeedbackTarget(
            message: '这条睡眠记录已完成晨间反馈，可在我的页查看同步结果。',
          );
        }
        if (isLiveMorningFeedbackSession(session)) {
          return _MorningFeedbackTarget(
            session: session,
            mode: _MorningFeedbackMode.live,
          );
        }
        if (_canSubmitFeedbackFor(session)) {
          return _MorningFeedbackTarget(
            session: session,
            mode: _MorningFeedbackMode.historical,
          );
        }
        return const _MorningFeedbackTarget(message: '这条睡眠记录当前不可继续补反馈。');
      }
      return const _MorningFeedbackTarget(message: '没有找到对应的睡眠记录。');
    }

    final String currentSleepDayKey = sleepDayKeyFromDate(feedbackMoment);
    final SleepSession? currentSleepDaySession = repository
        .sessionForSleepDayKey(currentSleepDayKey);
    if (currentSleepDaySession != null &&
        _canSubmitFeedbackFor(currentSleepDaySession)) {
      return _MorningFeedbackTarget(
        session: currentSleepDaySession,
        mode: _MorningFeedbackMode.historical,
      );
    }
    return const _MorningFeedbackTarget(message: '当前没有待补反馈的睡眠记录。');
  }

  void _bindSession(SleepSession session) {
    if (_boundSessionId == session.id) {
      return;
    }
    _boundSessionId = session.id;
    _statuses.clear();
    for (final TextEditingController controller in _feedbackNotes.values) {
      controller.dispose();
    }
    _feedbackNotes.clear();
    _estimatedSleepLatency = 20;
    _sleepQuality = 4;
    _restedLevel = 4;
    final Map<String, RecommendationFeedback> feedbackByRecommendation =
        <String, RecommendationFeedback>{
          for (final RecommendationFeedback feedback in session.feedback)
            feedback.recommendationId: feedback,
        };
    for (final NightRecommendation recommendation in session.recommendations) {
      final RecommendationFeedback? existing =
          feedbackByRecommendation[recommendation.id];
      _statuses[recommendation.id] =
          existing?.status ??
          _defaultFeedbackStatusFor(session, recommendation);
      final String existingNote = existing?.note.trim() ?? '';
      if (existingNote.isNotEmpty) {
        _feedbackNotes[recommendation.id] = TextEditingController(
          text: existingNote,
        );
      }
    }
  }

  Future<void> _handleReturnToSleep(BuildContext context) async {
    if (!widget.allowReturnToSleep || _isReturningToSleep) {
      return;
    }
    final bool shouldReturn = await _confirmReturnToSleep(context);
    if (!shouldReturn || !context.mounted) {
      return;
    }
    setState(() => _isReturningToSleep = true);
    try {
      await context.appServices.sleepExperienceController
          .resumeSleepModeFromFeedbackReturn();
      if (!context.mounted) {
        return;
      }
      GoRouter.of(context).go(AppRoutes.homePostSleep);
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      setState(() => _isReturningToSleep = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('返回睡眠模式失败，请重试')));
    }
  }

  Future<bool> _confirmReturnToSleep(BuildContext context) async {
    final bool? confirmed = await showAppModal<bool>(
      context,
      spec: const AppConfirmationDialogSpec(
        title: '返回睡眠模式？',
        body: '返回后将恢复睡眠模式继续计时，并丢弃当前未提交的晨间反馈。',
        icon: AppDialogIconSpec(icon: Icons.bedtime_rounded),
        cancelLabel: '继续填写',
        confirmLabel: '确认返回',
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _handleDiscardLiveFeedback(BuildContext context) async {
    final bool shouldDiscard = await _confirmDiscardLiveFeedback(context);
    if (!shouldDiscard || !context.mounted) {
      return;
    }
    GoRouter.of(context).go(AppRoutes.homePostSleep);
  }

  Future<bool> _confirmDiscardLiveFeedback(BuildContext context) async {
    final bool? confirmed = await showAppModal<bool>(
      context,
      spec: const AppDestructiveDialogSpec(
        title: '放弃本次填写？',
        body: '返回后将丢弃当前未提交的晨间反馈，并回到睡眠模式页面继续计时。',
        icon: AppDialogIconSpec(icon: Icons.delete_outline_rounded),
        cancelLabel: '继续填写',
        confirmLabel: '放弃并返回',
      ),
    );
    return confirmed ?? false;
  }

  Future<RecommendationFeedbackStatus?> _showRecommendationStatusSheet(
    BuildContext context, {
    required RecommendationFeedbackStatus current,
  }) {
    FocusScope.of(context).unfocus();
    return showAppModal<RecommendationFeedbackStatus>(
      context,
      spec: AppSelectionSheetSpec<RecommendationFeedbackStatus>(
        title: '选择反馈状态',
        description: '选择一个更贴近昨晚实际体验的状态。',
        selectedValue: current,
        useSafeArea: true,
        showDragHandle: true,
        options: RecommendationFeedbackStatus.values
            .map(
              (RecommendationFeedbackStatus status) =>
                  AppSelectionOption<RecommendationFeedbackStatus>(
                    value: status,
                    label: _feedbackLabel(status),
                  ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _showRecommendationNoteSheet(
    BuildContext context, {
    required TextEditingController controller,
  }) async {
    FocusScope.of(context).unfocus();
    await showAppModal<void>(
      context,
      spec: AppEditorSheetSpec<void>(
        useSafeArea: true,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (BuildContext sheetContext) {
          return AppBottomSheetScaffold(
            key: const ValueKey<String>('app-bottom-sheet-editor'),
            title: '补充说明',
            description: '用于备注这一条建议的实际体验。关闭抽屉时释放焦点。',
            includeBottomViewInsets: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: controller,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: '比如：昨晚实际执行时遇到的情况...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: '保存说明',
                  size: PrimaryButtonSize.compact,
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (!context.mounted) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  String _feedbackLabel(RecommendationFeedbackStatus status) {
    return switch (status) {
      RecommendationFeedbackStatus.effective => '有效',
      RecommendationFeedbackStatus.neutral => '一般',
      RecommendationFeedbackStatus.ineffective => '无效',
      RecommendationFeedbackStatus.skipped => '未执行',
    };
  }

  bool _wasRecommendationExecuted(
    SleepSession session,
    NightRecommendation recommendation,
  ) {
    return session.selectedRecommendationIds.contains(recommendation.id) ||
        recommendation.executionState != RecommendationExecutionState.idle;
  }

  RecommendationFeedbackStatus _defaultFeedbackStatusFor(
    SleepSession session,
    NightRecommendation recommendation,
  ) {
    return _wasRecommendationExecuted(session, recommendation)
        ? RecommendationFeedbackStatus.neutral
        : RecommendationFeedbackStatus.skipped;
  }

  String _formatDurationMinutes(int minutes) {
    final int hours = minutes ~/ 60;
    final int remainder = minutes % 60;
    if (hours <= 0) {
      return '${remainder}min';
    }
    return '${hours}h ${remainder.toString().padLeft(2, '0')}min';
  }

  DateTime _resolveFeedbackDisplayEndAt(
    SleepSession session,
    DateTime feedbackMoment,
  ) {
    final DateTime? recordedEndAt = resolveMorningFeedbackSessionEndAt(session);
    if (recordedEndAt == null || feedbackMoment.isAfter(recordedEndAt)) {
      return feedbackMoment;
    }
    return recordedEndAt;
  }

  DateTime _resolveFeedbackDisplayStartAt(
    SleepSession session,
    DateTime endAt,
  ) {
    final DateTime sleepDayDate = session.sleepDayDate;
    final DateTime cutoffStart = DateTime(
      sleepDayDate.year,
      sleepDayDate.month,
      sleepDayDate.day - 1,
      20,
    );
    for (final SleepSegment segment in session.segments) {
      final DateTime effectiveEnd = segment.endedAt ?? endAt;
      if (effectiveEnd.isBefore(cutoffStart)) {
        continue;
      }
      if (segment.startedAt.isBefore(cutoffStart)) {
        return cutoffStart;
      }
      return segment.startedAt;
    }
    final DateTime fallback = session.displayStartAt;
    return fallback.isBefore(cutoffStart) ? cutoffStart : fallback;
  }

  String _formatDateLabel(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day}';
  }

  String _formatClock(DateTime dateTime) {
    final String hour = dateTime.hour.toString().padLeft(2, '0');
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool _canSubmitFeedbackFor(SleepSession session) {
    return canSubmitMorningFeedbackForSession(session);
  }
}

class _MorningFeedbackTarget {
  const _MorningFeedbackTarget({
    this.session,
    this.mode = _MorningFeedbackMode.historical,
    this.message = '当前没有待补反馈的睡眠记录。',
  });

  final SleepSession? session;
  final _MorningFeedbackMode mode;
  final String message;
}

enum _MorningFeedbackMode { live, historical }

class _SubmittingMorningFeedbackLoading extends StatelessWidget {
  const _SubmittingMorningFeedbackLoading({required this.palette});

  final NightMoodPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(color: palette.primary),
            const SizedBox(height: AppSpacing.lg),
            Text('正在提交晨间反馈...', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _ReturningToSleepLoading extends StatelessWidget {
  const _ReturningToSleepLoading({required this.palette});

  final NightMoodPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(color: palette.primary),
            const SizedBox(height: AppSpacing.lg),
            Text('正在返回睡眠模式...', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _MetricSlider extends StatelessWidget {
  const _MetricSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.palette,
    required this.onChanged,
    this.divisions,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String suffix;
  final NightMoodPalette palette;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                '${value.toStringAsFixed(divisions == null ? 1 : 0)}$suffix',
                textAlign: TextAlign.end,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: palette.primary),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: palette.primarySoft,
            inactiveTrackColor: appColors.surfaceMuted,
            overlayShape: SliderComponentShape.noOverlay,
            thumbColor: palette.primary,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            trackHeight: 4,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _MetricSummaryTile extends StatelessWidget {
  const _MetricSummaryTile({
    required this.label,
    required this.value,
    required this.palette,
    this.detail,
  });

  final String label;
  final String value;
  final NightMoodPalette palette;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: appColors.surfaceMuted,
        borderRadius: AppRadius.surfaceSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: appColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: palette.primaryDeep,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (detail != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              detail!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: appColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactActionPill extends StatelessWidget {
  const _CompactActionPill({
    required this.label,
    required this.onTap,
    this.icon,
    this.highlight = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    final AppSemanticColors appColors = context.appColors;
    final Color background = highlight
        ? palette.primaryHighlight
        : appColors.surfaceMuted;
    final Color foreground = highlight
        ? palette.primaryDeep
        : appColors.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.surfaceSecondary,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
              color: background,
              borderRadius: AppRadius.surfaceSecondary,
              border: Border.all(
              color: highlight ? palette.primarySoft : appColors.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 14, color: appColors.textSecondary),
                const SizedBox(width: AppSpacing.xxs),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactStatusPill extends StatelessWidget {
  const _CompactStatusPill({
    required this.label,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    final AppSemanticColors appColors = context.appColors;
    final Color background = highlight
        ? palette.primaryHighlight
        : appColors.surfaceMuted;
    final Color foreground = highlight
        ? palette.primaryDeep
        : appColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.surfaceSecondary,
        border: Border.all(
          color: highlight ? palette.primarySoft : appColors.borderSubtle,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
