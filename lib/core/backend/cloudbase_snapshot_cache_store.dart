import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract interface class CloudBaseSnapshotCache {
  Future<Map<String, dynamic>?> read();

  Future<void> write(Map<String, dynamic> payload);

  Future<void> clear();
}

class CloudBaseSnapshotCacheStore implements CloudBaseSnapshotCache {
  CloudBaseSnapshotCacheStore({SharedPreferences? sharedPreferences})
    : _sharedPreferences = sharedPreferences;

  static const String _key = 'cloudbase.bootstrap_snapshot.v1';

  SharedPreferences? _sharedPreferences;

  @override
  Future<Map<String, dynamic>?> read() async {
    try {
      final String? raw = (await _prefs()).getString(_key);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(Map<String, dynamic> payload) async {
    if (payload.isEmpty) {
      return;
    }
    try {
      await (await _prefs()).setString(_key, jsonEncode(payload));
    } catch (_) {
      // The in-memory committed snapshot remains authoritative for this run.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await (await _prefs()).remove(_key);
    } catch (_) {
      // Best-effort cleanup; account guards still reject a mismatched cache.
    }
  }

  Future<SharedPreferences> _prefs() async {
    return _sharedPreferences ??= await SharedPreferences.getInstance();
  }
}
