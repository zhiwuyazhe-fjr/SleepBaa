import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';

class MorningFeedbackPage extends StatefulWidget {
  const MorningFeedbackPage({
    super.key,
    this.preferredSession,
    this.preferredSessionId,
  });

  final SleepSession? preferredSession;
  final String? preferredSessionId;

  @override
  State<MorningFeedbackPage> createState() => _MorningFeedbackPageState();
}

class _MorningFeedbackPageState extends State<MorningFeedbackPage> {
  static const Duration _maxActiveFeedbackSessionAge = Duration(hours: 18);
  final TextEditingController _noteController = TextEditingController();
  final Map<String, RecommendationFeedbackStatus> _statuses =
      <String, RecommendationFeedbackStatus>{};
  final Map<String, TextEditingController> _feedbackNotes =
      <String, TextEditingController>{};
  int _estimatedSleepLatency = 20;
  int _sleepQuality = 4;
  int _restedLevel = 4;

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
      appBar: AppBar(
        title: const Text('晨间反馈'),
        leading: IconButton(
          onPressed: () => GoRouter.of(context).go(_fallbackRoute(services)),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          services.sleepSessionRepository,
          services.notificationRepository,
        ]),
        builder: (BuildContext context, Widget? child) {
          final List<SleepSession> sessions =
              services.sleepSessionRepository.sessions;
          final bool waitingForPreferredSession =
              sessions.isEmpty &&
              ((widget.preferredSessionId?.trim().isNotEmpty == true) ||
                  widget.preferredSession != null);
          final SleepSession? completedSession = _resolveCompletedSession(
            sessions,
          );
          final SleepSession? session = _resolveSession(
            sessions,
            services.sleepSessionRepository.latestAwaitingFeedbackSession,
          );
          if (waitingForPreferredSession) {
            return const Center(child: CircularProgressIndicator());
          }
          if (session == null) {
            if (completedSession != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.check_circle_rounded,
                        size: 48,
                        color: palette.primary,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        '这次晨间反馈已经填写完成',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '不用重复提交啦，我们已经把这次反馈记下来了。',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      PrimaryButton(
                        label: '返回主页',
                        onPressed: () => GoRouter.of(context).go(
                          completedSession.sleepModeActive
                              ? AppRoutes.homePostSleep
                              : AppRoutes.homePreSleep,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.bedtime_off_rounded,
                      size: 44,
                      color: palette.primarySoft,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '当前没有待反馈的睡眠记录',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '请先结束一次睡眠模式，或者回到主页继续查看当前状态。',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      label: '返回主页',
                      onPressed: () => GoRouter.of(
                        context,
                      ).go(_fallbackRoute(services)),
                    ),
                  ],
                ),
              ),
            );
          }
          final DateTime endAt =
              session.endedAt ??
              (_isStaleActiveSession(session)
                  ? (session.updatedAt ?? session.startedAt)
                  : DateTime.now());
          final Duration totalRecordDuration = endAt.difference(
            session.startedAt,
          );
          final int totalRecordMinutes = totalRecordDuration.inMinutes.clamp(
            0,
            24 * 60,
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
                      '昨晚的整体感觉',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _MetricSummary(
                      label: '总记录时长',
                      primaryValue: _formatDurationMinutes(totalRecordMinutes),
                      detail: _formatDateTimeRangeLabel(
                        session.startedAt,
                        endAt,
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
                      label: '起床疲倦感',
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
                  final bool keepSleepModeActive =
                      session.sleepModeActive &&
                      session.status == SleepSessionStatus.active &&
                      session.endedAt == null;
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
                      .toList();
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
                  notifyPassiveToast(context, message: '已记录晨间反馈');
                  router.go(
                    keepSleepModeActive
                        ? AppRoutes.homePostSleep
                        : AppRoutes.homePreSleep,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  SleepSession? _resolveSession(
    List<SleepSession> sessions,
    SleepSession? latestAwaitingFeedbackSession,
  ) {
    final SleepSession? preferredSession = widget.preferredSession;
    final String? explicitPreferredId =
        widget.preferredSessionId?.trim().isNotEmpty == true
        ? widget.preferredSessionId!.trim()
        : null;
    final String? preferredId = explicitPreferredId ?? preferredSession?.id;

    if (preferredId != null && preferredId.isNotEmpty) {
      for (final SleepSession session in sessions) {
        if (session.id != preferredId) {
          continue;
        }
        if (context.appServices.sleepSessionRepository.isFeedbackCompleted(
          preferredId,
        )) {
          return null;
        }
        if (_isStaleActiveSession(session)) {
          return null;
        }
        if (session.status == SleepSessionStatus.awaitingFeedback ||
            session.status == SleepSessionStatus.active ||
            session.endedAt != null) {
          return session;
        }
        return null;
      }
    }

    if (latestAwaitingFeedbackSession != null &&
        !_isStaleActiveSession(latestAwaitingFeedbackSession)) {
      return latestAwaitingFeedbackSession;
    }

    final List<SleepSession> fallbackCandidates =
        sessions
            .where(
              (SleepSession session) =>
                  session.summary == null &&
                  !_isStaleActiveSession(session) &&
                  (session.endedAt != null ||
                      session.status == SleepSessionStatus.active) &&
                  session.status != SleepSessionStatus.completed,
            )
            .toList()
          ..sort(
            (SleepSession a, SleepSession b) =>
                b.startedAt.compareTo(a.startedAt),
          );
    return fallbackCandidates.isEmpty ? null : fallbackCandidates.first;
  }

  bool _isStaleActiveSession(SleepSession session) {
    return session.status == SleepSessionStatus.active &&
        session.endedAt == null &&
        DateTime.now().difference(session.startedAt) >=
            _maxActiveFeedbackSessionAge;
  }

  String _fallbackRoute(AppServices services) {
    return services.sleepSessionRepository.activeSession != null
        ? AppRoutes.homePostSleep
        : AppRoutes.homePreSleep;
  }

  SleepSession? _resolveCompletedSession(List<SleepSession> sessions) {
    final String? explicitPreferredId =
        widget.preferredSessionId?.trim().isNotEmpty == true
        ? widget.preferredSessionId!.trim()
        : null;
    final String? preferredId = explicitPreferredId ?? widget.preferredSession?.id;
    if (preferredId == null || preferredId.isEmpty) {
      return null;
    }
    if (context.appServices.sleepSessionRepository.isFeedbackCompleted(
      preferredId,
    )) {
      for (final SleepSession session in sessions) {
        if (session.id == preferredId) {
          return session;
        }
      }
    }
    for (final SleepSession session in sessions) {
      if (session.id == preferredId && session.summary != null) {
        return session;
      }
    }
    return null;
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

  String _formatDateTimeRangeLabel(DateTime start, DateTime end) {
    final String startDay = '昨日';
    final String endDay = start.day == end.day ? '今日' : '今日';
    return '$startDay ${_formatClock(start)} 到 $endDay ${_formatClock(end)}';
  }

  String _formatClock(DateTime dateTime) {
    final String hour = dateTime.hour.toString().padLeft(2, '0');
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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
