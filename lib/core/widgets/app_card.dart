import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/interaction/app_haptics.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.color,
    this.borderRadius,
    this.border,
    this.boxShadow,
    this.onTap,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final BorderRadius? borderRadius;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final BorderRadius effectiveRadius = borderRadius ?? AppRadius.cardLarge;
    final BoxDecoration decoration = BoxDecoration(
      color: color ?? appColors.surface,
      borderRadius: effectiveRadius,
      border: border,
      boxShadow: boxShadow ?? AppColors.cardShadow,
    );

    final Widget content = Container(
      decoration: decoration,
      padding: padding,
      child: child,
    );

    if (onTap == null) {
      return ClipRRect(
        borderRadius: effectiveRadius,
        clipBehavior: clipBehavior,
        child: content,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: effectiveRadius,
        onTap: AppHaptics.tapHandler(onTap),
        enableFeedback: false,
        child: ClipRRect(
          borderRadius: effectiveRadius,
          clipBehavior: clipBehavior,
          child: content,
        ),
      ),
    );
  }
}
