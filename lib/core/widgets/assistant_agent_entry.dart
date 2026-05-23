import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';

class AssistantAgentEntryButton extends StatelessWidget {
  const AssistantAgentEntryButton({
    super.key,
    required this.label,
    required this.prompt,
    this.source,
    this.icon = Icons.auto_awesome_rounded,
    this.autoSubmit = true,
    this.expanded = true,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final String prompt;
  final String? source;
  final IconData icon;
  final bool autoSubmit;
  final bool expanded;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final ButtonStyle? style =
        backgroundColor == null && foregroundColor == null
        ? null
        : FilledButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
          );
    final Widget button = FilledButton.icon(
      style: style,
      onPressed: () {
        context.push(
          AppRoutes.assistantAgentLocation(
            prompt: prompt,
            source: source,
            autoSubmit: autoSubmit,
          ),
        );
      },
      icon: Icon(icon),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
    if (!expanded) {
      return button;
    }
    return SizedBox(width: double.infinity, child: button);
  }
}
