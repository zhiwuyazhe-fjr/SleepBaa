import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';

class AppSettingsGroup extends StatelessWidget {
  const AppSettingsGroup({
    super.key,
    required this.children,
    this.title,
    this.borderRadius,
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
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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
    this.iconSize = 20,
    this.titleStyle,
    this.trailing,
    this.onTap,
    this.iconBackgroundColor,
    this.iconContainerSize = 36,
    this.iconContainerBorderRadius,
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
  final double iconSize;
  final TextStyle? titleStyle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconBackgroundColor;
  final double iconContainerSize;
  final BorderRadius? iconContainerBorderRadius;
  final EdgeInsetsGeometry padding;
  final double leadingWidth;
  final double? minHeight;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
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
                iconColor: iconColor ?? AppColors.textPrimary,
                iconSize: iconSize,
                backgroundColor: iconBackgroundColor,
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
}

class _SettingsItemIcon extends StatelessWidget {
  const _SettingsItemIcon({
    required this.icon,
    required this.iconColor,
    required this.iconSize,
    required this.backgroundColor,
    required this.containerSize,
    required this.borderRadius,
    required this.leadingWidth,
  });

  final IconData icon;
  final Color iconColor;
  final double iconSize;
  final Color? backgroundColor;
  final double containerSize;
  final BorderRadius? borderRadius;
  final double leadingWidth;

  @override
  Widget build(BuildContext context) {
    if (backgroundColor == null) {
      return SizedBox(
        width: leadingWidth,
        child: Center(
          child: Icon(icon, size: iconSize, color: iconColor),
        ),
      );
    }

    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: backgroundColor,
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
