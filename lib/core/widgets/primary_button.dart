import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/interaction/app_haptics.dart';

enum PrimaryButtonVariant { filled, soft, ghost }

enum PrimaryButtonSize { regular, compact }

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = PrimaryButtonVariant.filled,
    this.expand = true,
    this.size = PrimaryButtonSize.regular,
    this.foregroundColor,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.isLoading = false,
    this.loadingLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final PrimaryButtonVariant variant;
  final bool expand;
  final PrimaryButtonSize size;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final BorderRadiusGeometry? borderRadius;
  final bool isLoading;
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    final VoidCallback? resolvedOnPressed = onPressed == null || isLoading
        ? null
        : AppHaptics.confirmHandler(onPressed);
    final TextStyle? buttonTextStyle = Theme.of(context).textTheme.labelLarge
        ?.copyWith(
          fontSize: size == PrimaryButtonSize.regular ? 15 : 14,
          fontWeight: FontWeight.w700,
        );
    final ButtonStyle style = FilledButton.styleFrom(
      minimumSize: Size(0, _height),
      padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? AppRadius.button,
      ),
      elevation: 0,
      backgroundColor: _backgroundColor(palette),
      foregroundColor: foregroundColor ?? _foregroundColor(palette),
      side: _borderSide(),
      textStyle: buttonTextStyle,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
    );

    final String resolvedLabel = isLoading ? (loadingLabel ?? label) : label;
    final Widget child;
    if (isLoading) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox.square(
            dimension: size == PrimaryButtonSize.regular ? 18 : 16,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(
                foregroundColor ?? _foregroundColor(palette),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(resolvedLabel),
        ],
      );
    } else {
      child = icon != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: size == PrimaryButtonSize.regular ? 18 : 16),
                const SizedBox(width: AppSpacing.xs),
                Text(resolvedLabel),
              ],
            )
          : Text(resolvedLabel);
    }

    final Widget button = FilledButton(
      onPressed: resolvedOnPressed,
      style: style,
      child: child,
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }

  double get _height {
    return switch (size) {
      PrimaryButtonSize.regular => 56,
      PrimaryButtonSize.compact => 44,
    };
  }

  double get _horizontalPadding {
    return switch (size) {
      PrimaryButtonSize.regular => AppSpacing.xl,
      PrimaryButtonSize.compact => AppSpacing.md,
    };
  }

  Color _backgroundColor(NightMoodPalette palette) {
    if (backgroundColor != null) {
      return backgroundColor!;
    }
    return switch (variant) {
      PrimaryButtonVariant.filled => palette.welcomeAccentColor,
      PrimaryButtonVariant.soft => palette.primarySoft,
      PrimaryButtonVariant.ghost => Colors.transparent,
    };
  }

  Color _foregroundColor(NightMoodPalette palette) {
    return switch (variant) {
      PrimaryButtonVariant.filled => palette.welcomeTextOnAccent,
      PrimaryButtonVariant.soft => palette.primaryDeep,
      PrimaryButtonVariant.ghost => AppColors.textPrimary,
    };
  }

  BorderSide? _borderSide() {
    return switch (variant) {
      PrimaryButtonVariant.ghost => BorderSide(
        color: borderColor ?? AppColors.surfaceBorder,
      ),
      _ => null,
    };
  }
}
