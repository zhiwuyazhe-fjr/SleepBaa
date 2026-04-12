import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/section_title.dart';

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

  Future<void> _showPendingToast(BuildContext context) {
    return notifyPassiveToast(context, message: '$title 正在整理中');
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final NightMoodPalette palette = context.nightMoodPalette;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            96,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SectionTitle(
                title: '内容预告',
                titleStyle: textTheme.headlineSmall?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                onTap: () => _showPendingToast(context),
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(icon, size: 24, color: palette.primary),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      title,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      description,
                      style: textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF888888),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                color: AppColors.legacyCardSurface,
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '本页将逐步补全',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final String point in supportingPoints) ...<Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Icon(
                              Icons.brightness_1_rounded,
                              size: 8,
                              color: palette.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              point,
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => _showPendingToast(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.welcomeAccentColor,
                    foregroundColor: palette.welcomeTextOnAccent,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: const StadiumBorder(),
                    textStyle: textTheme.labelLarge?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  icon: const Icon(Icons.insights_rounded, size: 18),
                  label: Text(primaryActionLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
