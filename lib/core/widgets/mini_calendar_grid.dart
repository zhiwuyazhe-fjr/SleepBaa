import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';

class MiniCalendarGrid extends StatelessWidget {
  const MiniCalendarGrid({
    super.key,
    required this.weekdays,
    required this.intensity,
    this.showWeekdays = true,
    this.childAspectRatio = 1,
  });

  final List<String> weekdays;
  final List<int> intensity;
  final bool showWeekdays;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    final AppSemanticColors appColors = context.appColors;
    return Column(
      children: <Widget>[
        if (showWeekdays) ...<Widget>[
          Row(
            children: weekdays
                .map(
                  (String label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: appColors.textSecondary.withAlpha(120),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        GridView.builder(
          itemCount: intensity.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: AppSpacing.xs,
            crossAxisSpacing: AppSpacing.xs,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (BuildContext context, int index) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: _resolveColor(intensity[index], palette, appColors),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
            );
          },
        ),
      ],
    );
  }

  Color _resolveColor(
    int step,
    NightMoodPalette palette,
    AppSemanticColors appColors,
  ) {
    return switch (step) {
      5 => palette.primary,
      4 => palette.primarySoft,
      3 => palette.primarySoft.withAlpha(190),
      2 => palette.primarySoft.withAlpha(120),
      1 => palette.primarySoft.withAlpha(72),
      _ => appColors.surfaceMuted,
    };
  }
}
