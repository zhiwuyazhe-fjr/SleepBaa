import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/content/evening_encouragement_quotes.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/state/evening_welcome_local_store.dart';
import 'package:sleep_dorm_app/core/state/night_welcome_controller.dart';
import 'package:sleep_dorm_app/core/utils/evening_period.dart';
import 'package:sleep_dorm_app/features/home/presentation/pages/home_pre_sleep_page.dart';
import 'package:sleep_dorm_app/features/night_mood/presentation/widgets/night_mood_welcome_flow.dart';

class NightWelcomeGatePage extends StatefulWidget {
  const NightWelcomeGatePage({super.key, this.notice});

  final String? notice;

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
            .shouldShowWelcome(
              homeMode: HomeMode.preSleep,
              persistedEveningWelcomePeriodKey:
                  settings.eveningEncouragementPeriodKey,
            );

        if (!shouldShowWelcome) {
          return HomePreSleepPage(notice: widget.notice);
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

  /// Skips welcome; encouragement uses the impatient pool only here (not from settings).
  Future<void> _dismissLocally() async {
    final AppServices services = context.appServices;
    final NightWelcomeController controller = services.nightWelcomeController;
    final String periodKey = eveningPeriodKey(DateTime.now());
    final String line = pickRandomEncouragementLine(mood: null);
    await EveningWelcomeLocalStore.persistWelcomeOutcome(
      periodKey: periodKey,
      encouragementLine: line,
      moodSnapshot: null,
    );
    controller.recordWelcomeHandledForPeriod(periodKey);
    controller.clearSessionMoodOverride();
    controller.dismissForCurrentVisit();
    await services.profileFacade.saveEveningEncouragement(
      periodKey: periodKey,
      line: line,
      moodSnapshot: null,
    );
  }

  /// Persists mood + encouragement in one save so the profile quote survives CloudBase snapshot refresh.
  Future<void> _completeWelcome({
    required AppServices services,
    required NightMood mood,
  }) async {
    final String periodKey = eveningPeriodKey(DateTime.now());
    final String line = pickRandomEncouragementLine(mood: mood);
    await EveningWelcomeLocalStore.persistWelcomeOutcome(
      periodKey: periodKey,
      encouragementLine: line,
      moodSnapshot: mood,
    );
    services.nightWelcomeController.recordWelcomeHandledForPeriod(periodKey);
    services.nightWelcomeController.setCompletedMood(mood);
    await services.profileFacade.saveNightWelcomeSelection(
      mood: mood,
      periodKey: periodKey,
      encouragementLine: line,
    );
  }
}
