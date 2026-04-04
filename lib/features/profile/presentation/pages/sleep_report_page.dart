import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/core/widgets/placeholder_page_scaffold.dart';
import 'package:sleep_dorm_app/mock/mock_data.dart';
import 'package:sleep_dorm_app/app/routes.dart';

class SleepReportPage extends StatelessWidget {
  const SleepReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final PlaceholderPageMeta meta =
        MockData.placeholderPages[AppRoutes.profileReport]!;
    return PlaceholderPageScaffold(
      title: meta.title,
      description: meta.description,
      icon: meta.icon,
      primaryActionLabel: meta.primaryActionLabel,
      supportingPoints: meta.supportingPoints,
    );
  }
}
