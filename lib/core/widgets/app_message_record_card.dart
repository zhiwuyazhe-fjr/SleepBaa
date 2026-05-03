import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';

class AppMessageRecordCard extends StatelessWidget {
  const AppMessageRecordCard({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    this.timeLabel,
    this.trailing,
    this.onTap,
    this.highlighted = false,
    this.padding,
    this.iconColor,
    this.iconBackgroundColor,
    this.borderRadius,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String? timeLabel;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool highlighted;
  final EdgeInsetsGeometry? padding;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    final Widget? trailingWidget = trailing ?? _buildTimeLabel(context);
    return AppCard(
      onTap: onTap,
      padding:
          padding ??
          const EdgeInsets.symmetric(horizontal: 10, vertical: AppSpacing.sm),
      borderRadius: borderRadius ?? AppRadius.compactCard,
      color: highlighted ? AppColors.legacyCardSurface : AppColors.surface,
      boxShadow: const <BoxShadow>[],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBackgroundColor ?? palette.primaryHighlight,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: iconColor ?? AppColors.textStrong,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: AppColors.textSubtle,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (trailingWidget != null) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            trailingWidget,
          ],
        ],
      ),
    );
  }

  Widget? _buildTimeLabel(BuildContext context) {
    if (timeLabel == null) {
      return null;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        timeLabel!,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: highlighted ? AppColors.textStrong : AppColors.textSecondary,
          fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}
