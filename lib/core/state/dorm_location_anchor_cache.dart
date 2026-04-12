import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sleep_dorm_app/core/data/model_serializers.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class DormLocationAnchorCache {
  DormLocationAnchorCache({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _prefix = 'dorm_location_anchor_v1';

  final FlutterSecureStorage _storage;

  Future<void> save({
    required String uid,
    required String dormId,
    required DormLocationAnchor anchor,
  }) async {
    if (uid.trim().isEmpty || dormId.trim().isEmpty) {
      return;
    }
    await _storage.write(
      key: _cacheKey(uid: uid, dormId: dormId),
      value: jsonEncode(ModelSerializers.dormLocationAnchorToMap(anchor)),
    );
  }

  Future<DormLocationAnchor?> read({
    required String uid,
    required String dormId,
  }) async {
    if (uid.trim().isEmpty || dormId.trim().isEmpty) {
      return null;
    }
    final String? rawValue = await _storage.read(
      key: _cacheKey(uid: uid, dormId: dormId),
    );
    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(rawValue);
      if (decoded is Map) {
        return ModelSerializers.dormLocationAnchorFromMap(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> clear({
    required String uid,
    required String dormId,
  }) async {
    if (uid.trim().isEmpty || dormId.trim().isEmpty) {
      return;
    }
    await _storage.delete(key: _cacheKey(uid: uid, dormId: dormId));
  }

  String _cacheKey({
    required String uid,
    required String dormId,
  }) {
    return '$_prefix::$uid::$dormId';
  }
}
