import 'package:flutter/foundation.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

typedef AppClock = DateTime Function();

class NightWelcomeController extends ChangeNotifier {
  NightWelcomeController({
    required AppClock clock,
    bool showInDebugOutsideNight = kDebugMode,
  }) : _clock = clock,
       _showInDebugOutsideNight = showInDebugOutsideNight;

  final AppClock _clock;
  final bool _showInDebugOutsideNight;
  bool _hasHandledThisLaunch = false;

  bool get hasHandledThisLaunch => _hasHandledThisLaunch;

  DateTime get now => _clock();

  bool shouldShowWelcome({required HomeMode homeMode}) {
    return homeMode == HomeMode.preSleep &&
        !_hasHandledThisLaunch &&
        (_showInDebugOutsideNight || isNightTime(_clock()));
  }

  void markHandled() {
    if (_hasHandledThisLaunch) {
      return;
    }
    _hasHandledThisLaunch = true;
    notifyListeners();
  }
}

bool isNightTime(DateTime value) {
  return value.hour >= 18 || value.hour < 5;
}
