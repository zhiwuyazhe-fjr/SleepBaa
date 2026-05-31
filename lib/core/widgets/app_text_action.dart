import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/app_typography.dart';
import 'package:sleep_dorm_app/core/interaction/app_haptics.dart';

class AppTextAction extends StatelessWidget {
  const AppTextAction({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.foregroundColor,
    this.hapticRole = AppHapticRole.tap,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? foregroundColor;
  final AppHapticRole hapticRole;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final Color resolvedForeground = foregroundColor ?? appColors.accentDeep;
    final ButtonStyle style = TextButton.styleFrom(
      foregroundColor: resolvedForeground,
      disabledForegroundColor: appColors.textSecondary.withAlpha(150),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
      textStyle: AppTypography.meta(
        Theme.of(context).textTheme,
      ).copyWith(fontWeight: FontWeight.w700),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
    final VoidCallback? resolvedOnPressed = AppHaptics.handler(
      onPressed,
      role: hapticRole,
    );

    if (icon == null) {
      return TextButton(
        onPressed: resolvedOnPressed,
        style: style,
        child: Text(label),
      );
    }

    return TextButton.icon(
      onPressed: resolvedOnPressed,
      style: style,
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}
