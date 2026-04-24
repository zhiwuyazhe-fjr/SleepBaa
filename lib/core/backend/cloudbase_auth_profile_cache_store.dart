import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sleep_dorm_app/core/data/model_serializers.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class CloudBaseAuthProfileCacheStore {
  CloudBaseAuthProfileCacheStore({SharedPreferences? sharedPreferences})
    : _sharedPreferences = sharedPreferences;

  static const String _key = 'cloudbase.auth_profile_cache';

  SharedPreferences? _sharedPreferences;

  Future<UserProfile?> read() async {
    try {
      final String? raw = (await _prefs()).getString(_key);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final UserProfile profile = ModelSerializers.userProfileFromMap(
        Map<String, dynamic>.from(decoded),
      );
      return profile.uid.trim().isEmpty ? null : profile;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(UserProfile profile) async {
    if (profile.uid.trim().isEmpty) {
      return;
    }
    try {
      await (await _prefs()).setString(
        _key,
        jsonEncode(ModelSerializers.userProfileToMap(profile)),
      );
    } catch (_) {
      // Best-effort cache; auth recovery falls back to live session state.
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
