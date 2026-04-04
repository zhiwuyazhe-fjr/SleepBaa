import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';

class MiniCalendarGrid extends StatelessWidget {
  const MiniCalendarGrid({
    super.key,
    required this.weekdays,
    required this.intensity,
  });

  final List<String> weekdays;
  final List<int> intensity;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: weekdays
              .map(
                (String label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary.withAlpha(120),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          itemCount: intensity.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: AppSpacing.xs,
            crossAxisSpacing: AppSpacing.xs,
          ),
          itemBuilder: (BuildContext context, int index) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: _resolveColor(intensity[index]),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
            );
          },
        ),
      ],
    );
  }

  Color _resolveColor(int step) {
    return switch (step) {
      4 => AppColors.primary,
      3 => AppColors.primarySoft,
      2 => AppColors.primarySoft.withAlpha(190),
      1 => AppColors.primarySoft.withAlpha(100),
      _ => AppColors.surfaceSoft,
    };
  }
}
