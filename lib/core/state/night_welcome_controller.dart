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
  String? _completedNightKey;
  String? _dismissedNightKey;
  String? _themeOverrideNightKey;
  NightMood? _activeNightMood;
  bool _isHomeVisible = false;

  String get currentNightKey => nightWindowKey(_clock());

  DateTime get now => _clock();

  NightMood? effectiveMood(NightMood? persistedMood) {
    if (_themeOverrideNightKey == currentNightKey) {
      return _activeNightMood;
    }
    return persistedMood;
  }

  bool shouldShowWelcome({required HomeMode homeMode}) {
    return homeMode == HomeMode.preSleep &&
        _completedNightKey != currentNightKey &&
        _dismissedNightKey != currentNightKey &&
        (_showInDebugOutsideNight || isNightTime(_clock()));
  }

  void dismissForCurrentVisit() {
    if (_dismissedNightKey == currentNightKey) {
      return;
    }
    _dismissedNightKey = currentNightKey;
    notifyListeners();
  }

  void clearSessionMoodOverride() {
    _themeOverrideNightKey = currentNightKey;
    _activeNightMood = null;
    notifyListeners();
  }

  void syncHomeVisibility(bool isVisible) {
    if (_isHomeVisible == isVisible) {
      return;
    }
    _isHomeVisible = isVisible;

    if (!isVisible &&
        _dismissedNightKey == currentNightKey &&
        _completedNightKey != currentNightKey) {
      _dismissedNightKey = null;
    }
    notifyListeners();
  }

  void markCompleted() {
    if (!(_showInDebugOutsideNight || isNightTime(_clock()))) {
      return;
    }
    if (_completedNightKey == currentNightKey) {
      return;
    }
    _completedNightKey = currentNightKey;
    _dismissedNightKey = null;
    notifyListeners();
  }

  void setCompletedMood(NightMood mood) {
    _themeOverrideNightKey = currentNightKey;
    _activeNightMood = mood;
    markCompleted();
  }
}

bool isNightTime(DateTime value) {
  return value.hour >= 18 || value.hour < 5;
}

String nightWindowKey(DateTime value) {
  final DateTime anchor = value.hour < 5
      ? value.subtract(const Duration(days: 1))
      : value;
  return '${anchor.year.toString().padLeft(4, '0')}-'
      '${anchor.month.toString().padLeft(2, '0')}-'
      '${anchor.day.toString().padLeft(2, '0')}';
}
