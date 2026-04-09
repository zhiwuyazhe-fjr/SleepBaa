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
        final bool shouldShowWelcome = services.nightWelcomeController
            .shouldShowWelcome(homeMode: HomeMode.preSleep);

        if (!shouldShowWelcome) {
          return const HomePreSleepPage();
        }

        return NightMoodWelcomeFlow(
          initialMood: settings.selectedNightMood,
          onSkip: _dismissLocally,
          onComplete: (NightMood mood) =>
              _completeWelcome(services: services, mood: mood),
        );
      },
    );
  }

  Future<void> _dismissLocally() async {
    final controller = context.appServices.nightWelcomeController;
    controller.clearSessionMoodOverride();
    controller.dismissForCurrentVisit();
  }

  Future<void> _completeWelcome({
    required AppServices services,
    required NightMood mood,
  }) async {
    services.nightWelcomeController.setCompletedMood(mood);
    await services.profileFacade.saveNightMood(mood);
  }
}
