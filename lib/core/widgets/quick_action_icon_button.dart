import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/app_typography.dart';
import 'package:sleep_dorm_app/core/interaction/app_haptics.dart';

class QuickActionIconButton extends StatelessWidget {
  const QuickActionIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: AppHaptics.tapHandler(onTap),
      enableFeedback: false,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: appColors.accentSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 24, color: appColors.accentDeep),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.meta(
              textTheme,
            ).copyWith(color: appColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
