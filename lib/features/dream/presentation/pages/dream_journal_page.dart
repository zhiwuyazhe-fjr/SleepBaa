import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/core/widgets/placeholder_page_scaffold.dart';
import 'package:sleep_dorm_app/mock/mock_data.dart';

class DreamJournalPage extends StatelessWidget {
  const DreamJournalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final PlaceholderPageMeta meta =
        MockData.placeholderPages[AppRoutes.dreamJournal]!;
    return PlaceholderPageScaffold(
      title: meta.title,
      description: meta.description,
      icon: meta.icon,
      primaryActionLabel: meta.primaryActionLabel,
      supportingPoints: meta.supportingPoints,
    );
  }
}
