import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sleep_dorm_app/core/data/model_serializers.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class UserSettingsCacheStore {
  UserSettingsCacheStore({SharedPreferences? sharedPreferences})
    : _sharedPreferences = sharedPreferences;

  static const String _key = 'user_settings_cache';

  SharedPreferences? _sharedPreferences;

  Future<UserSettings?> read() async {
    try {
      final String? raw = (await _prefs()).getString(_key);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return ModelSerializers.userSettingsFromMap(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> write(UserSettings settings) async {
    try {
      await (await _prefs()).setString(
        _key,
        jsonEncode(ModelSerializers.userSettingsToMap(settings)),
      );
    } catch (_) {
      // Best-effort cache; cloud settings remain the source of truth.
    }
  }

  Future<void> clear() async {
    try {
      await (await _prefs()).remove(_key);
    } catch (_) {
      // Best-effort cleanup.
    }
  }

  Future<SharedPreferences> _prefs() async {
    return _sharedPreferences ??= await SharedPreferences.getInstance();
  }
}
