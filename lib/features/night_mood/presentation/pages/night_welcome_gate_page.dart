import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/features/home/presentation/pages/home_pre_sleep_page.dart';
import 'package:sleep_dorm_app/features/night_mood/presentation/widgets/night_mood_welcome_flow.dart';

class NightWelcomeGatePage extends StatefulWidget {
  const NightWelcomeGatePage({super.key});

  @override
  State<NightWelcomeGatePage> createState() => _NightWelcomeGatePageState();
}

class _NightWelcomeGatePageState extends State<NightWelcomeGatePage> {
  bool _welcomeDismissedLocally = false;

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        services.settingsRepository,
        services.nightWelcomeController,
      ]),
      builder: (BuildContext context, Widget? child) {
        final UserSettings settings =
            services.settingsRepository.currentSettings;
        final bool shouldShowWelcome =
            !_welcomeDismissedLocally &&
            services.nightWelcomeController.shouldShowWelcome(
              homeMode: HomeMode.preSleep,
            );

        if (!shouldShowWelcome) {
          return const HomePreSleepPage();
        }

        return NightMoodWelcomeFlow(
          initialMood: settings.selectedNightMood,
          onSkip: () => _dismissAndPersist(
            services: services,
            settings: settings,
            mood: null,
          ),
          onComplete: (NightMood mood) => _dismissAndPersist(
            services: services,
            settings: settings,
            mood: mood,
          ),
        );
      },
    );
  }

  Future<void> _dismissAndPersist({
    required AppServices services,
    required UserSettings settings,
    required NightMood? mood,
  }) async {
    if (mounted) {
      setState(() => _welcomeDismissedLocally = true);
    }
    services.nightWelcomeController.markHandled();
    await services.settingsRepository.saveSettings(
      mood == null
          ? settings.copyWith(clearSelectedNightMood: true)
          : settings.copyWith(selectedNightMood: mood),
    );
  }
}
