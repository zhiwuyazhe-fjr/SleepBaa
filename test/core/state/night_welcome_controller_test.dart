import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/state/night_welcome_controller.dart';
import 'package:sleep_dorm_app/core/utils/evening_period.dart';

void main() {
  test(
    'shouldShowWelcome is false when persisted evening period matches clock period',
    () {
      final DateTime t = DateTime(2026, 4, 18, 21, 30);
      final String key = eveningPeriodKey(t);
      final NightWelcomeController controller = NightWelcomeController(
        clock: () => t,
        showInDebugOutsideNight: true,
        initialLocalHandledEveningPeriodKey: key,
      );
      expect(
        controller.shouldShowWelcome(
          homeMode: HomeMode.preSleep,
          persistedEveningWelcomePeriodKey: null,
        ),
        isFalse,
      );
    },
  );

  test(
    'shouldShowWelcome still uses in-memory dismissed key when persisted null',
    () {
      final DateTime t = DateTime(2026, 4, 18, 21, 30);
      final NightWelcomeController controller = NightWelcomeController(
        clock: () => t,
        showInDebugOutsideNight: true,
      );
      controller.dismissForCurrentVisit();
      expect(
        controller.shouldShowWelcome(
          homeMode: HomeMode.preSleep,
          persistedEveningWelcomePeriodKey: null,
        ),
        isFalse,
      );
    },
  );
}
