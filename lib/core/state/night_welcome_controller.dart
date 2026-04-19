import 'package:flutter/foundation.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/utils/evening_period.dart';

typedef AppClock = DateTime Function();

class NightWelcomeController extends ChangeNotifier {
  NightWelcomeController({
    required AppClock clock,
    bool showInDebugOutsideNight = kDebugMode,
    String? initialLocalHandledEveningPeriodKey,
  }) : _clock = clock,
       _showInDebugOutsideNight = showInDebugOutsideNight,
       _handledEveningPeriodKey = initialLocalHandledEveningPeriodKey;

  final AppClock _clock;
  final bool _showInDebugOutsideNight;

  /// Last [eveningPeriodKey] for which welcome was completed/skipped (device
  /// prefs at startup + updates here). Survives process death.
  String? _handledEveningPeriodKey;
  String? _completedNightKey;
  String? _dismissedNightKey;
  String? _themeOverrideNightKey;
  NightMood? _activeNightMood;
  bool _isHomeVisible = false;

  String get currentNightKey => eveningPeriodKey(_clock());

  DateTime get now => _clock();

  NightMood? effectiveMood(NightMood? persistedMood) {
    if (_themeOverrideNightKey == currentNightKey) {
      return _activeNightMood;
    }
    return persistedMood;
  }

  /// [persistedEveningWelcomePeriodKey] is [UserSettings.eveningEncouragementPeriodKey]
  /// when the cloud snapshot includes it (may be null on cold start before sync).
  bool shouldShowWelcome({
    required HomeMode homeMode,
    String? persistedEveningWelcomePeriodKey,
  }) {
    if (homeMode != HomeMode.preSleep) {
      return false;
    }
    if (_handledEveningPeriodKey != null &&
        _handledEveningPeriodKey == currentNightKey) {
      return false;
    }
    if (persistedEveningWelcomePeriodKey != null &&
        persistedEveningWelcomePeriodKey == currentNightKey) {
      return false;
    }
    if (_completedNightKey == currentNightKey ||
        _dismissedNightKey == currentNightKey) {
      return false;
    }
    return _showInDebugOutsideNight || isNightTime(_clock());
  }

  /// Call after persisting the handled period to device storage so UI updates.
  void recordWelcomeHandledForPeriod(String eveningPeriodKey) {
    _handledEveningPeriodKey = eveningPeriodKey;
    notifyListeners();
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

  /// Drops welcome-flow theme lock so [effectiveMood] follows persisted settings.
  ///
  /// Call after the user explicitly picks a night mood in settings. Unlike
  /// [clearSessionMoodOverride] (used when skipping welcome), this clears the
  /// override key entirely so saved [UserSettings.selectedNightMood] drives the theme.
  void releaseNightMoodThemeOverride() {
    _themeOverrideNightKey = null;
    _activeNightMood = null;
    notifyListeners();
  }

  void syncHomeVisibility(bool isVisible) {
    if (_isHomeVisible == isVisible) {
      return;
    }
    _isHomeVisible = isVisible;
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
  return value.hour >= 20 || value.hour < 5;
}
