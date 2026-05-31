import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/interaction/app_haptics.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';

class AppSettingsGroup extends StatelessWidget {
  const AppSettingsGroup({
    super.key,
    required this.children,
    this.title,
    this.borderRadius,
    this.titleStyle,
    this.padding = const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
    this.headerPadding = const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.xxs,
    ),
  });

  final String? title;
  final List<Widget> children;
  final BorderRadius? borderRadius;
  final TextStyle? titleStyle;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry headerPadding;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: padding,
      borderRadius: borderRadius ?? AppRadius.compactCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null)
            Padding(
              padding: headerPadding,
              child: Text(
                title!,
                style:
                    titleStyle ??
                    Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ...children,
        ],
      ),
    );
  }
}

class AppSettingsItem extends StatelessWidget {
  const AppSettingsItem({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.iconBackgroundColor,
    this.iconContainerKey,
    this.iconContainerSize = 36,
    this.iconSize = 20,
    this.titleStyle,
    this.trailing,
    this.onTap,
    this.iconContainerBorderRadius,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    this.leadingWidth = 28,
    this.minHeight,
    this.borderRadius,
    this.hapticRole = AppHapticRole.navigation,
  });

  final String title;
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final Key? iconContainerKey;
  final double iconContainerSize;
  final double iconSize;
  final TextStyle? titleStyle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final BorderRadius? iconContainerBorderRadius;
  final EdgeInsetsGeometry padding;
  final double leadingWidth;
  final double? minHeight;
  final BorderRadius? borderRadius;
  final AppHapticRole? hapticRole;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    Widget row = Padding(
      padding: padding,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight ?? 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              _SettingsItemIcon(
                icon: icon!,
                iconColor: iconColor ?? appColors.textPrimary,
                iconSize: iconSize,
                backgroundColor: iconBackgroundColor,
                containerKey: iconContainerKey,
                containerSize: iconContainerSize,
                borderRadius: iconContainerBorderRadius,
                leadingWidth: leadingWidth,
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Text(
                title,
                style:
                    titleStyle ??
                    Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ] else if (onTap != null) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: appColors.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) {
      return row;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: borderRadius ?? AppRadius.control,
        onTap: hapticRole == null
            ? onTap
            : AppHaptics.handler(onTap, role: hapticRole!),
        child: row,
      ),
    );
  }
}

class AppSettingsValueTrailing extends StatelessWidget {
  const AppSettingsValueTrailing({
    super.key,
    required this.value,
    this.showChevron = true,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.maxWidth,
  });

  final String value;
  final bool showChevron;
  final int? maxLines;
  final TextOverflow overflow;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final Widget row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Flexible(
          child: Text(
            value,
            maxLines: maxLines,
            overflow: overflow,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: appColors.textSecondary,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
        if (showChevron) ...<Widget>[
          const SizedBox(width: AppSpacing.xxs),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: appColors.textSecondary,
          ),
        ],
      ],
    );
    if (maxWidth == null) {
      return row;
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth!),
      child: row,
    );
  }
}

class AppSettingsToggle extends StatelessWidget {
  const AppSettingsToggle({super.key, required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    final AppSemanticColors appColors = context.appColors;
    return Semantics(
      toggled: value,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 52,
        height: 26,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? palette.primarySoft : appColors.surfaceMuted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: value
                ? palette.primary.withValues(alpha: 0.28)
                : appColors.borderSubtle,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? palette.primary : appColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsItemIcon extends StatelessWidget {
  const _SettingsItemIcon({
    required this.icon,
    required this.iconColor,
    required this.iconSize,
    required this.backgroundColor,
    required this.containerKey,
    required this.containerSize,
    required this.borderRadius,
    required this.leadingWidth,
  });

  final IconData icon;
  final Color iconColor;
  final double iconSize;
  final Color? backgroundColor;
  final Key? containerKey;
  final double containerSize;
  final BorderRadius? borderRadius;
  final double leadingWidth;

  @override
  Widget build(BuildContext context) {
    if (backgroundColor == null && containerKey == null) {
      return SizedBox(
        width: leadingWidth,
        child: Center(
          child: Icon(icon, size: iconSize, color: iconColor),
        ),
      );
    }

    return Container(
      key: containerKey,
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: borderRadius ?? AppRadius.iconContainer,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: iconColor),
    );
  }
}

class AppSettingsDetailItem extends StatelessWidget {
  const AppSettingsDetailItem({
    super.key,
    required this.label,
    required this.value,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
  });

  final String label;
  final String value;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.appColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.appColors.textPrimary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
