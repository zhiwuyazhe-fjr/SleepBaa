import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_typography.dart';

class HomeMetricCard extends StatelessWidget {
  const HomeMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.backgroundColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Widget content = Container(
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 84),
      decoration: BoxDecoration(
        color: backgroundColor ?? appColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 24, color: appColors.accentDeep),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.panelTitle(
                    textTheme,
                  ).copyWith(color: appColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMuted(
              textTheme,
            ).copyWith(color: appColors.textSecondary),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: content,
    );
  }
}
