import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';

enum SectionTitleVariant { standard, dorm }

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.actionLabel,
    this.actionKey,
    this.onAction,
    this.variant = SectionTitleVariant.standard,
    this.titleStyle,
    this.actionStyle,
  });

  final String title;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;
  final SectionTitleVariant variant;
  final TextStyle? titleStyle;
  final TextStyle? actionStyle;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool useDormStyle = variant == SectionTitleVariant.dorm;
    final TextStyle? resolvedTitleStyle =
        titleStyle ??
        (useDormStyle
            ? textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              )
            : textTheme.headlineSmall);
    final TextStyle? resolvedActionStyle =
        actionStyle ??
        (useDormStyle
            ? textTheme.labelMedium?.copyWith(
                color: palette.welcomeAccentColor,
                fontWeight: FontWeight.w700,
              )
            : textTheme.labelMedium);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(child: Text(title, style: resolvedTitleStyle)),
        if (actionLabel != null)
          TextButton.icon(
            key: actionKey,
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: useDormStyle
                  ? palette.welcomeAccentColor
                  : palette.primaryDeep,
              padding: useDormStyle
                  ? const EdgeInsets.symmetric(horizontal: AppSpacing.xs)
                  : EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: useDormStyle ? VisualDensity.compact : null,
            ),
            iconAlignment: IconAlignment.end,
            icon: Icon(
              Icons.chevron_right_rounded,
              size: useDormStyle ? 16 : 18,
            ),
            label: Text(actionLabel!, style: resolvedActionStyle),
          ),
      ],
    );
  }
}
