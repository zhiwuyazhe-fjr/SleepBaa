import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';

enum PrimaryButtonVariant { filled, soft, ghost }

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = PrimaryButtonVariant.filled,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final PrimaryButtonVariant variant;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final palette = context.nightMoodPalette;
    final ButtonStyle style = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.pill),
      elevation: 0,
      backgroundColor: _backgroundColor(palette),
      foregroundColor: _foregroundColor(palette),
      side: _borderSide(),
      textStyle: Theme.of(context).textTheme.labelLarge,
    );

    final Widget button = icon != null
        ? FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 20),
            label: Text(label),
          )
        : FilledButton(onPressed: onPressed, style: style, child: Text(label));

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }

  Color _backgroundColor(NightMoodPalette palette) {
    return switch (variant) {
      PrimaryButtonVariant.filled => palette.primary,
      PrimaryButtonVariant.soft => palette.primarySoft,
      PrimaryButtonVariant.ghost => Colors.transparent,
    };
  }

  Color _foregroundColor(NightMoodPalette palette) {
    return switch (variant) {
      PrimaryButtonVariant.filled => AppColors.onDark,
      PrimaryButtonVariant.soft => palette.primaryDeep,
      PrimaryButtonVariant.ghost => AppColors.textPrimary,
    };
  }

  BorderSide? _borderSide() {
    return switch (variant) {
      PrimaryButtonVariant.ghost => const BorderSide(
        color: AppColors.surfaceBorder,
      ),
      _ => null,
    };
  }
}
