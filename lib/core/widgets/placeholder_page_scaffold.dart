import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';

class PlaceholderPageScaffold extends StatelessWidget {
  const PlaceholderPageScaffold({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.primaryActionLabel,
    this.supportingPoints = const <String>[],
  });

  final String title;
  final String description;
  final IconData icon;
  final String primaryActionLabel;
  final List<String> supportingPoints;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final NightMoodPalette palette = context.nightMoodPalette;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(icon, size: 34, color: palette.primary),
                    const SizedBox(height: AppSpacing.lg),
                    Text(title, style: textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      description,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                color: AppColors.surfaceMuted,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Planned modules', style: textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.md),
                    for (final String point in supportingPoints) ...<Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Icon(
                              Icons.brightness_1_rounded,
                              size: 8,
                              color: palette.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(point, style: textTheme.bodyMedium),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: primaryActionLabel,
                icon: Icons.construction_rounded,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}
