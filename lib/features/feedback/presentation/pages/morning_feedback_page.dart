import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';

class MorningFeedbackPage extends StatefulWidget {
  const MorningFeedbackPage({super.key});

  @override
  State<MorningFeedbackPage> createState() => _MorningFeedbackPageState();
}

class _MorningFeedbackPageState extends State<MorningFeedbackPage> {
  final TextEditingController _noteController = TextEditingController();
  final Map<String, RecommendationFeedbackStatus> _statuses =
      <String, RecommendationFeedbackStatus>{};
  final Map<String, TextEditingController> _feedbackNotes =
      <String, TextEditingController>{};
  double _sleepHours = 7.1;
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
      appBar: AppBar(title: const Text('晨间反馈')),
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          services.sleepSessionRepository,
          services.notificationRepository,
        ]),
        builder: (BuildContext context, Widget? child) {
          final SleepSession? session =
              services.sleepSessionRepository.latestAwaitingFeedbackSession;
          if (session == null) {
            return const Center(child: Text('当前没有待反馈的睡眠记录。'));
          }

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
                    _MetricSlider(
                      label: '总睡眠时长',
                      value: _sleepHours,
                      min: 4,
                      max: 10,
                      suffix: 'h',
                      palette: palette,
                      onChanged: (double value) {
                        setState(() => _sleepHours = value);
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
                  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(
                    context,
                  );
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
                      .toList();
                  await services.sleepExperienceController
                      .submitMorningFeedback(
                        session: session,
                        summary: MorningSummary(
                          sleepQuality: _sleepQuality,
                          restedLevel: _restedLevel,
                          totalSleepHours: _sleepHours,
                          awakeningsCount: session.awakenings.length,
                          note: _noteController.text.trim(),
                        ),
                        feedback: feedback,
                      );
                  if (!mounted) {
                    return;
                  }
                  messenger.showSnackBar(
                    const SnackBar(content: Text('已记录晨间反馈')),
                  );
                  router.go(AppRoutes.homePreSleep);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  String _feedbackLabel(RecommendationFeedbackStatus status) {
    return switch (status) {
      RecommendationFeedbackStatus.effective => '有效',
      RecommendationFeedbackStatus.neutral => '一般',
      RecommendationFeedbackStatus.ineffective => '无效',
      RecommendationFeedbackStatus.skipped => '未执行',
    };
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
  final ValueChanged<double> onChanged;

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
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}
