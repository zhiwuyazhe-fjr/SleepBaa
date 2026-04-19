import 'package:shared_preferences/shared_preferences.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/utils/evening_period.dart';

/// Boot-time snapshot: handled welcome period + optional fixed encouragement line.
class LocalEveningWelcomeBootState {
  const LocalEveningWelcomeBootState({
    required this.periodKey,
    this.encouragementLine,
    this.moodSnapshot,
  });

  final String periodKey;

  /// Same string as [UserSettings.eveningEncouragementLine]; may be null for legacy prefs.
  final String? encouragementLine;
  final NightMood? moodSnapshot;
}

/// Device-local persistence for welcome handling + fixed encouragement for the period.
/// Cloud snapshots may omit encouragement; this keeps one stable line until the next period.
abstract final class EveningWelcomeLocalStore {
  static const String _periodKey = 'evening_welcome_handled_period_key';
  static const String _lineKey = 'evening_encouragement_line_local';
  static const String _moodKey = 'evening_encouragement_mood_local';

  /// Removes stored state if it belongs to a past [eveningPeriodKey] (new 20:00 cycle).
  static Future<void> pruneStaleAgainstNow() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? storedPeriod = prefs.getString(_periodKey);
    if (storedPeriod == null || storedPeriod.isEmpty) {
      return;
    }
    final String nowKey = eveningPeriodKey(DateTime.now());
    if (storedPeriod != nowKey) {
      await prefs.remove(_periodKey);
      await prefs.remove(_lineKey);
      await prefs.remove(_moodKey);
    }
  }

  /// Persists period + encouragement together so the quote survives restarts independently of cloud.
  static Future<void> persistWelcomeOutcome({
    required String periodKey,
    required String encouragementLine,
    required NightMood? moodSnapshot,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_periodKey, periodKey);
    await prefs.setString(_lineKey, encouragementLine);
    await prefs.setString(
      _moodKey,
      moodSnapshot == null ? 'unknown' : moodSnapshot.name,
    );
  }

  /// After [pruneStaleAgainstNow], describes current-period local state (if any).
  static Future<LocalEveningWelcomeBootState?> readBootState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? periodKey = prefs.getString(_periodKey);
    if (periodKey == null || periodKey.isEmpty) {
      return null;
    }
    final String? line = prefs.getString(_lineKey);
    final String? moodRaw = prefs.getString(_moodKey);
    return LocalEveningWelcomeBootState(
      periodKey: periodKey,
      encouragementLine: (line != null && line.isNotEmpty) ? line : null,
      moodSnapshot: _parseMood(moodRaw),
    );
  }

  static NightMood? _parseMood(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'unknown') {
      return null;
    }
    for (final NightMood mood in NightMood.values) {
      if (mood.name == raw) {
        return mood;
      }
    }
    return null;
  }
}
