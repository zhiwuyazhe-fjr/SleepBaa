import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';

class AppMenuGroupCardItem {
  const AppMenuGroupCardItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
    this.titleStyle,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;
  final TextStyle? titleStyle;
  final Color? iconColor;
}

class AppMenuGroupCard extends StatelessWidget {
  const AppMenuGroupCard({
    super.key,
    required this.items,
    this.cardKey,
    this.borderRadius,
    this.padding = const EdgeInsets.symmetric(vertical: AppSpacing.xs),
  });

  final List<AppMenuGroupCardItem> items;
  final Key? cardKey;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: cardKey,
      padding: padding,
      borderRadius: borderRadius ?? AppRadius.stripCard,
      child: Column(
        children: <Widget>[
          for (final AppMenuGroupCardItem item in items)
            _AppMenuGroupRow(item: item),
        ],
      ),
    );
  }
}

class _AppMenuGroupRow extends StatelessWidget {
  const _AppMenuGroupRow({required this.item});

  final AppMenuGroupCardItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              Icon(item.icon, color: item.iconColor ?? AppColors.textPrimary),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(item.title, style: item.titleStyle)),
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
