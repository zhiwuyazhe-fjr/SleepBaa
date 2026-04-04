import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';

class AssistantFab extends StatelessWidget {
  const AssistantFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'assistant_fab',
      onPressed: () => context.push(AppRoutes.assistant),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onDark,
      elevation: 0,
      icon: const Icon(Icons.auto_awesome_rounded),
      label: const Text('Assistant'),
      tooltip: 'Open assistant',
    );
  }
}
