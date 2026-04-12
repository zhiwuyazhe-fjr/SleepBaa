import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';

class AppStripCard extends StatelessWidget {
  const AppStripCard({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.trailingIcon,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor = AppColors.surface,
    this.borderColor = AppColors.surfaceBorder,
    this.borderRadius,
    this.boxShadow = const <BoxShadow>[],
    this.titleStyle,
    this.subtitleStyle,
    this.trailingBackgroundColor = AppColors.background,
    this.trailingBorderColor = AppColors.surfaceBorder,
    this.trailingForegroundColor = AppColors.textPrimary,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final IconData? trailingIcon;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color borderColor;
  final BorderRadius? borderRadius;
  final List<BoxShadow> boxShadow;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final Color trailingBackgroundColor;
  final Color trailingBorderColor;
  final Color trailingForegroundColor;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: onTap,
      padding: padding,
      color: backgroundColor,
      borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: borderColor),
      boxShadow: boxShadow,
      child: Row(
        children: <Widget>[
          leading,
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      titleStyle ??
                      textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        subtitleStyle ??
                        textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            trailing!,
          ] else if (trailingIcon != null) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: trailingBackgroundColor,
                shape: BoxShape.circle,
                border: Border.all(color: trailingBorderColor),
              ),
              alignment: Alignment.center,
              child: Icon(
                trailingIcon,
                size: 22,
                color: trailingForegroundColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
