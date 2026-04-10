import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.actionLabel,
    this.actionKey,
    this.onAction,
    this.titleStyle,
    this.actionStyle,
  });

  final String title;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;
  final TextStyle? titleStyle;
  final TextStyle? actionStyle;

  @override
  Widget build(BuildContext context) {
    final palette = context.nightMoodPalette;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Text(title, style: titleStyle ?? textTheme.headlineSmall),
        ),
        if (actionLabel != null)
          TextButton.icon(
            key: actionKey,
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: palette.primaryDeep,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.chevron_right_rounded, size: 18),
            label: Text(
              actionLabel!,
              style: actionStyle ?? textTheme.labelMedium,
            ),
          ),
      ],
    );
  }
}
