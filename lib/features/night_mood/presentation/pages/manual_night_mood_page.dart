import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/features/night_mood/presentation/widgets/night_mood_welcome_flow.dart';

class ManualNightMoodPage extends StatelessWidget {
  const ManualNightMoodPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    final UserSettings settings = services.settingsRepository.currentSettings;

    return NightMoodWelcomeFlow(
      initialMood: settings.selectedNightMood,
      completeButtonLabel: '保存心情主题',
      onSkip: () async => _leaveFlow(context),
      onComplete: (NightMood mood) async {
        final UserSettings nextSettings = services.profileFacade.currentSettings
            .copyWith(selectedNightMood: mood);
        services.settingsRepository.replaceLocalSettings(nextSettings);
        services.nightWelcomeController.releaseNightMoodThemeOverride();
        await services.profileFacade.saveNightMood(mood);
        if (context.mounted) {
          _leaveFlow(context);
        }
      },
    );
  }

  void _leaveFlow(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.profileSettings);
  }
}
