import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
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
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    this.leadingWidth = 28,
    this.minHeight,
    this.borderRadius,
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
  final EdgeInsetsGeometry padding;
  final double leadingWidth;
  final double? minHeight;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final Widget? leading = icon == null
        ? null
        : _buildLeadingIcon(icon!, color: iconColor ?? AppColors.textPrimary);
    Widget row = Padding(
      padding: padding,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight ?? 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            if (leading != null) ...<Widget>[
              SizedBox(
                width: leadingWidth,
                child: Center(child: leading),
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
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textHint,
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
        onTap: () {
          HapticFeedback.lightImpact();
          onTap!();
        },
        child: row,
      ),
    );
  }

  Widget _buildLeadingIcon(IconData icon, {required Color color}) {
    if (iconBackgroundColor == null && iconContainerKey == null) {
      return Icon(icon, size: iconSize, color: color);
    }
    return Container(
      key: iconContainerKey,
      constraints: BoxConstraints.tightFor(
        width: iconContainerSize,
        height: iconContainerSize,
      ),
      decoration: BoxDecoration(
        color: iconBackgroundColor ?? Colors.transparent,
        borderRadius: AppRadius.iconContainer,
      ),
      child: Center(
        child: Icon(icon, size: iconSize, color: color),
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
  });

  final String value;
  final bool showChevron;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (showChevron) ...<Widget>[
          const SizedBox(width: AppSpacing.xxs),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.textHint,
          ),
        ],
      ],
    );
  }
}

class AppSettingsToggle extends StatelessWidget {
  const AppSettingsToggle({super.key, required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    return Semantics(
      toggled: value,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 52,
        height: 26,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? palette.primarySoft : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: value
                ? palette.primary.withValues(alpha: 0.28)
                : AppColors.surfaceBorder,
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
              color: value ? palette.primary : AppColors.textHint,
            ),
          ),
        ),
      ),
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
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
