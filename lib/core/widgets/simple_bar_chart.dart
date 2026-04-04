import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';

class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.values,
    this.highlightedIndices = const <int>{},
  });

  final List<double> values;
  final Set<int> highlightedIndices;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.card,
      ),
      child: SizedBox(
        height: 120,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List<Widget>.generate(values.length, (int index) {
            final bool highlighted = highlightedIndices.contains(index);
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == values.length - 1 ? 0 : AppSpacing.xs,
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: values[index].clamp(0.15, 1),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: highlighted
                            ? palette.primarySoft
                            : AppColors.surfaceBorder,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppRadius.xl),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
