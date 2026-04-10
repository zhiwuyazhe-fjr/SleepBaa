import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';

class HomeHeroPair extends StatelessWidget {
  const HomeHeroPair({
    super.key,
    required this.left,
    required this.right,
    this.spacing = AppSpacing.md,
  });

  final Widget left;
  final Widget right;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: left),
        SizedBox(width: spacing),
        Expanded(child: right),
      ],
    );
  }
}
