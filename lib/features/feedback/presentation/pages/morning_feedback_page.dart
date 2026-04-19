import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
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
  final TextEditingController _noteController = TextEditingController();
  final Map<String, RecommendationFeedbackStatus> _statuses =
      <String, RecommendationFeedbackStatus>{};
  final Map<String, TextEditingController> _feedbackNotes =
      <String, TextEditingController>{};
  int _estimatedSleepLatency = 20;
  int _sleepQuality = 4;
  int _restedLevel = 4;
  String? _boundSessionId;
  bool _isReturningToSleep = false;

  @override
  void dispose() {
    _noteController.dispose();
    for (final TextEditingController controller in _feedbackNotes.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    final NightMoodPalette palette = context.nightMoodPalette;
    return Scaffold(
      appBar: AppBar(title: const Text('晨间反馈')),
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          services.sleepSessionRepository,
          services.notificationRepository,
        ]),
        builder: (BuildContext context, Widget? child) {
          if (_isReturningToSleep) {
            return _ReturningToSleepLoading(palette: palette);
          }
          final SleepSessionRepository repository =
              services.sleepSessionRepository;
          final GoRouterState routerState = GoRouterState.of(context);
          final String explicitSessionId =
              widget.sessionId ??
              routerState.uri.queryParameters['sessionId'] ??
              '';
          if (shouldShowMorningFeedbackLoading(
            explicitSessionId: explicitSessionId,
            isReadyForSessionLookup: repository.isReadyForSessionLookup,
            sessions: repository.sessions,
          )) {
            return const Center(child: CircularProgressIndicator());
          }
          final DateTime feedbackMoment =
              services.sleepExperienceController.currentTime;
          final _MorningFeedbackTarget target = _resolveTargetSession(
            repository,
            feedbackMoment: feedbackMoment,
            explicitSessionId: explicitSessionId,
          );
          final SleepSession? session = target.session;
          if (session == null) {
            return Center(child: Text(target.message));
          }
          _bindSession(session);
          final DateTime endAt = _resolveFeedbackDisplayEndAt(
            session,
            feedbackMoment,
          );
          final DateTime startAt = _resolveFeedbackDisplayStartAt(
            session,
            endAt,
          );
          final int totalRecordMinutes = session.liveTrackedDurationMinutes(
            now: endAt,
          );
          final int actualSleepMinutes =
              (totalRecordMinutes - _estimatedSleepLatency).clamp(0, 24 * 60);
          final double actualSleepHours = actualSleepMinutes / 60;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: <Widget>[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '昨晚的整体感受',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _MetricSummary(
                      label: '总记录时长',
                      primaryValue: _formatDurationMinutes(totalRecordMinutes),
                      detail: _formatFeedbackWindowLabel(
                        startAt,
                        endAt,
                        totalRecordMinutes,
                      ),
                      palette: palette,
                    ),
                    const SizedBox(height: AppSpacing.md),
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
                    _MetricSummary(
                      label: '实际睡眠时长',
                      primaryValue: _formatDurationMinutes(actualSleepMinutes),
                      detail: '按总记录时长减去预计入睡时长自动推算得到',
                      palette: palette,
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
                    TextField(
                      controller: _noteController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: '补充说明',
                        hintText: '比如：几点入睡、是否中途被吵醒、整体精神状态如何',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                '逐条反馈昨晚建议',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.md),
              ...session.recommendations.map((
                NightRecommendation recommendation,
              ) {
                final TextEditingController noteController = _feedbackNotes
                    .putIfAbsent(recommendation.id, TextEditingController.new);
                final RecommendationFeedbackStatus current =
                    _statuses[recommendation.id] ??
                    RecommendationFeedbackStatus.neutral;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          recommendation.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          recommendation.subtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: RecommendationFeedbackStatus.values.map((
                            RecommendationFeedbackStatus status,
                          ) {
                            return ChoiceChip(
                              label: Text(_feedbackLabel(status)),
                              selected: current == status,
                              onSelected: (_) {
                                setState(
                                  () => _statuses[recommendation.id] = status,
                                );
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: noteController,
                          decoration: const InputDecoration(
                            labelText: '这条建议的补充感受',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              PrimaryButton(
                label: '提交反馈',
                onPressed: () async {
                  final GoRouter router = GoRouter.of(context);
                  final List<RecommendationFeedback> feedback = session
                      .recommendations
                      .map((NightRecommendation item) {
                        return RecommendationFeedback(
                          recommendationId: item.id,
                          status:
                              _statuses[item.id] ??
                              RecommendationFeedbackStatus.neutral,
                          note: _feedbackNotes[item.id]?.text.trim() ?? '',
                          submittedAt: DateTime.now(),
                        );
                      })
                      .toList(growable: false);
                  await services.sleepExperienceController
                      .submitMorningFeedback(
                        session: session,
                        summary: MorningSummary(
                          sleepQuality: _sleepQuality,
                          restedLevel: _restedLevel,
                          totalSleepHours: actualSleepHours,
                          awakeningsCount: session.awakenings.length,
                          note: _noteController.text.trim(),
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
                },
              ),
              if (widget.allowReturnToSleep) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: '返回',
                  variant: PrimaryButtonVariant.ghost,
                  onPressed: () async {
                    await _handleReturnToSleep(context);
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
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
        if (_canSubmitFeedbackFor(session)) {
          return _MorningFeedbackTarget(session: session);
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
      return _MorningFeedbackTarget(session: currentSleepDaySession);
    }
    return const _MorningFeedbackTarget(message: '当前没有待补反馈的睡眠记录。');
  }

  void _bindSession(SleepSession session) {
    if (_boundSessionId == session.id) {
      return;
    }
    _boundSessionId = session.id;
    _noteController.clear();
    _statuses.clear();
    for (final TextEditingController controller in _feedbackNotes.values) {
      controller.dispose();
    }
    _feedbackNotes.clear();
    _estimatedSleepLatency = 20;
    _sleepQuality = 4;
    _restedLevel = 4;
  }

  bool _hasUnsavedChanges() {
    if (_estimatedSleepLatency != 20 ||
        _sleepQuality != 4 ||
        _restedLevel != 4) {
      return true;
    }
    if (_noteController.text.trim().isNotEmpty || _statuses.isNotEmpty) {
      return true;
    }
    return _feedbackNotes.values.any(
      (TextEditingController controller) => controller.text.trim().isNotEmpty,
    );
  }

  Future<void> _handleReturnToSleep(BuildContext context) async {
    if (!widget.allowReturnToSleep || _isReturningToSleep) {
      return;
    }
    if (_hasUnsavedChanges()) {
      final bool shouldReturn = await _confirmReturnToSleep(context);
      if (!shouldReturn || !context.mounted) {
        return;
      }
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
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('返回继续计时？'),
          content: const Text('返回后会丢失这次未提交的晨间反馈内容，并恢复睡眠模式继续计时。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('继续填写'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认返回'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  String _feedbackLabel(RecommendationFeedbackStatus status) {
    return switch (status) {
      RecommendationFeedbackStatus.effective => '有效',
      RecommendationFeedbackStatus.neutral => '一般',
      RecommendationFeedbackStatus.ineffective => '无效',
      RecommendationFeedbackStatus.skipped => '未执行',
    };
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

  String _formatFeedbackWindowLabel(
    DateTime start,
    DateTime end,
    int totalRecordMinutes,
  ) {
    return '${_formatDateLabel(start)} ${_formatClock(start)} - '
        '${_formatDateLabel(end)} ${_formatClock(end)} '
        '累计${_formatDurationMinutes(totalRecordMinutes)}';
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
  const _MorningFeedbackTarget({this.session, this.message = '当前没有待补反馈的睡眠记录。'});

  final SleepSession? session;
  final String message;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text(
              '${value.toStringAsFixed(divisions == null ? 1 : 0)}$suffix',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: palette.primary),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            disabledActiveTrackColor: palette.primary,
            disabledInactiveTrackColor: AppColors.surfaceBorder,
            disabledThumbColor: palette.primary,
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

class _MetricSummary extends StatelessWidget {
  const _MetricSummary({
    required this.label,
    required this.primaryValue,
    required this.detail,
    required this.palette,
  });

  final String label;
  final String primaryValue;
  final String detail;
  final NightMoodPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text(
                primaryValue,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: palette.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            detail,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
