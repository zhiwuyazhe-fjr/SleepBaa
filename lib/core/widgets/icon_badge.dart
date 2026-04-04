import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';

class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    this.size = 52,
    this.borderRadius,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final double size;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius ?? AppRadius.card,
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: iconColor, size: size * 0.48),
    );
  }
}
