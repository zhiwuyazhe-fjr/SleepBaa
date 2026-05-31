import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/interaction/app_haptics.dart';

enum PrimaryButtonVariant { filled, soft, ghost }

enum PrimaryButtonSize { regular, compact, mini }

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = PrimaryButtonVariant.filled,
    this.expand = true,
    this.size = PrimaryButtonSize.regular,
    this.hapticRole,
    this.foregroundColor,
    this.disabledForegroundColor,
    this.backgroundColor,
    this.pressedBackgroundColor,
    this.disabledBackgroundColor,
    this.borderColor,
    this.borderRadius,
    this.elevation,
    this.shadowColor,
    this.textStyle,
    this.isLoading = false,
    this.loadingLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final PrimaryButtonVariant variant;
  final bool expand;
  final PrimaryButtonSize size;
  final AppHapticRole? hapticRole;
  final Color? foregroundColor;
  final Color? disabledForegroundColor;
  final Color? backgroundColor;
  final Color? pressedBackgroundColor;
  final Color? disabledBackgroundColor;
  final Color? borderColor;
  final BorderRadiusGeometry? borderRadius;
  final double? elevation;
  final Color? shadowColor;
  final TextStyle? textStyle;
  final bool isLoading;
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    final AppSemanticColors appColors = context.appColors;
    final AppHapticRole resolvedHapticRole =
        hapticRole ??
        switch (variant) {
          PrimaryButtonVariant.filled => AppHapticRole.confirm,
          PrimaryButtonVariant.soft ||
          PrimaryButtonVariant.ghost => AppHapticRole.tap,
        };
    final VoidCallback? resolvedOnPressed = onPressed == null || isLoading
        ? null
        : AppHaptics.handler(onPressed, role: resolvedHapticRole);
    final Color resolvedBackground = _backgroundColor(palette, appColors);
    final Color resolvedForeground =
        foregroundColor ?? _foregroundColor(palette, appColors);
    final Color resolvedDisabledBackground =
        disabledBackgroundColor ?? _disabledBackgroundColor(appColors);
    final Color resolvedDisabledForeground =
        disabledForegroundColor ?? appColors.textSecondary.withAlpha(170);
    final TextStyle? buttonTextStyle =
        textStyle ??
        Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: switch (size) {
            PrimaryButtonSize.regular => 15,
            PrimaryButtonSize.compact => 14,
            PrimaryButtonSize.mini => 12,
          },
          fontWeight: FontWeight.w700,
        );
    final ButtonStyle style =
        FilledButton.styleFrom(
          minimumSize: Size(0, _height),
          padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? AppRadius.button,
          ),
          elevation:
              elevation ?? (variant == PrimaryButtonVariant.filled ? 3 : 0),
          shadowColor:
              shadowColor ??
              (variant == PrimaryButtonVariant.filled
                  ? appColors.accent.withAlpha(82)
                  : Colors.transparent),
          backgroundColor: resolvedBackground,
          foregroundColor: resolvedForeground,
          disabledBackgroundColor: resolvedDisabledBackground,
          disabledForegroundColor: resolvedDisabledForeground,
          side: _borderSide(appColors),
          textStyle: buttonTextStyle,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.standard,
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.disabled)) {
              return resolvedDisabledBackground;
            }
            if (pressedBackgroundColor != null &&
                states.contains(WidgetState.pressed)) {
              return pressedBackgroundColor!;
            }
            return resolvedBackground;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.disabled)) {
              return resolvedDisabledForeground;
            }
            return resolvedForeground;
          }),
          overlayColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.pressed)) {
              return resolvedForeground.withValues(alpha: 0.08);
            }
            return null;
          }),
        );

    final String resolvedLabel = isLoading ? (loadingLabel ?? label) : label;
    final Widget child;
    if (isLoading) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox.square(
            dimension: _iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(resolvedForeground),
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
                Icon(icon, size: _iconSize),
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
      PrimaryButtonSize.regular => 48,
      PrimaryButtonSize.compact => 44,
      PrimaryButtonSize.mini => 36,
    };
  }

  double get _horizontalPadding {
    return switch (size) {
      PrimaryButtonSize.regular => AppSpacing.xl,
      PrimaryButtonSize.compact => AppSpacing.md,
      PrimaryButtonSize.mini => AppSpacing.sm,
    };
  }

  double get _iconSize {
    return switch (size) {
      PrimaryButtonSize.regular => 18,
      PrimaryButtonSize.compact => 16,
      PrimaryButtonSize.mini => 14,
    };
  }

  Color _backgroundColor(NightMoodPalette palette, AppSemanticColors colors) {
    if (backgroundColor != null) {
      return backgroundColor!;
    }
    return switch (variant) {
      PrimaryButtonVariant.filled => colors.accent,
      PrimaryButtonVariant.soft => colors.accentSoft,
      PrimaryButtonVariant.ghost => Colors.transparent,
    };
  }

  Color _foregroundColor(NightMoodPalette palette, AppSemanticColors colors) {
    return switch (variant) {
      PrimaryButtonVariant.filled => colors.textOnAccent,
      PrimaryButtonVariant.soft => colors.accentDeep,
      PrimaryButtonVariant.ghost => colors.textPrimary,
    };
  }

  Color _disabledBackgroundColor(AppSemanticColors colors) {
    if (backgroundColor != null) {
      return Color.alphaBlend(
        colors.surfaceMuted.withAlpha(180),
        backgroundColor!,
      );
    }
    return switch (variant) {
      PrimaryButtonVariant.filled => Color.alphaBlend(
        colors.accent.withAlpha(60),
        colors.surfaceMuted,
      ),
      PrimaryButtonVariant.soft => colors.surfaceMuted,
      PrimaryButtonVariant.ghost => Colors.transparent,
    };
  }

  BorderSide? _borderSide(AppSemanticColors colors) {
    return switch (variant) {
      PrimaryButtonVariant.ghost => BorderSide(
        color: borderColor ?? colors.borderSubtle,
      ),
      PrimaryButtonVariant.soft => BorderSide(
        color: borderColor ?? colors.accentSoft.withAlpha(190),
      ),
      _ => null,
    };
  }
}
