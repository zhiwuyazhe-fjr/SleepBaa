import 'package:shared_preferences/shared_preferences.dart';

/// Device-local persistence for which [eveningPeriodKey] the user already
/// completed or skipped the night welcome for. Cloud snapshots may omit this
/// field on cold start; local storage makes "no second welcome" reliable.
abstract final class EveningWelcomeLocalStore {
  static const String _key = 'evening_welcome_handled_period_key';

  static Future<String?> readHandledPeriodKey() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> writeHandledPeriodKey(String periodKey) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, periodKey);
  }
}
