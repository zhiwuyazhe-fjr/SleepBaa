import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/interaction/app_haptics.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';

class AppMenuGroupCardItem {
  const AppMenuGroupCardItem({
    required this.title,
    required this.onTap,
    this.icon,
    this.subtitle,
    this.trailing,
    this.titleStyle,
    this.subtitleStyle,
    this.iconColor,
    this.iconSize = 20,
    this.iconBackgroundColor,
    this.iconContainerSize = 36,
    this.iconContainerBorderRadius,
  });

  final IconData? icon;
  final String title;
  final VoidCallback onTap;
  final String? subtitle;
  final Widget? trailing;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final Color? iconColor;
  final double iconSize;
  final Color? iconBackgroundColor;
  final double iconContainerSize;
  final BorderRadius? iconContainerBorderRadius;
}

class AppMenuGroupCard extends StatelessWidget {
  const AppMenuGroupCard({
    super.key,
    required this.items,
    this.cardKey,
    this.borderRadius,
    this.padding = const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    this.itemPadding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
  });

  final List<AppMenuGroupCardItem> items;
  final Key? cardKey;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry itemPadding;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: cardKey,
      padding: padding,
      borderRadius: borderRadius ?? AppRadius.stripCard,
      child: Column(
        children: <Widget>[
          for (final AppMenuGroupCardItem item in items)
            _AppMenuGroupRow(item: item, padding: itemPadding),
        ],
      ),
    );
  }
}

class _AppMenuGroupRow extends StatelessWidget {
  const _AppMenuGroupRow({required this.item, required this.padding});

  final AppMenuGroupCardItem item;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: AppHaptics.navigationHandler(item.onTap),
        borderRadius: AppRadius.control,
        child: Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (item.icon != null) ...<Widget>[
                _AppMenuGroupIcon(item: item),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(item.title, style: item.titleStyle),
                    if (item.subtitle != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        item.subtitle!,
                        style:
                            item.subtitleStyle ??
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              item.trailing ??
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textHint,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppMenuGroupIcon extends StatelessWidget {
  const _AppMenuGroupIcon({required this.item});

  final AppMenuGroupCardItem item;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = item.iconColor ?? AppColors.textPrimary;
    if (item.iconBackgroundColor == null) {
      return SizedBox(
        width: item.iconSize + AppSpacing.xs,
        child: Center(
          child: Icon(item.icon!, size: item.iconSize, color: iconColor),
        ),
      );
    }

    return Container(
      width: item.iconContainerSize,
      height: item.iconContainerSize,
      decoration: BoxDecoration(
        color: item.iconBackgroundColor,
        borderRadius: item.iconContainerBorderRadius ?? AppRadius.iconContainer,
      ),
      alignment: Alignment.center,
      child: Icon(item.icon!, size: item.iconSize, color: iconColor),
    );
  }
}
