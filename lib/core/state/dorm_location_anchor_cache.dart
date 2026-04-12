import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sleep_dorm_app/core/data/model_serializers.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class DormLocationAnchorCache {
  DormLocationAnchorCache({
    FlutterSecureStorage? storage,
    FlutterSecureStorage? legacyStorage,
  })
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          ),
      _legacyStorage = legacyStorage ?? const FlutterSecureStorage();

  static const String _prefix = 'dorm_location_anchor_v1';
  static const String _latestSuffix = 'latest';

  final FlutterSecureStorage _storage;
  final FlutterSecureStorage _legacyStorage;

  Future<void> save({
    required String uid,
    required String dormId,
    required DormLocationAnchor anchor,
  }) async {
    final String normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      return;
    }
    await _storage.write(
      key: _latestCacheKey(uid: normalizedUid),
      value: jsonEncode(ModelSerializers.dormLocationAnchorToMap(anchor)),
    );
    if (dormId.trim().isEmpty) {
      return;
    }
    await _storage.write(
      key: _cacheKey(uid: normalizedUid, dormId: dormId),
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
    final String key = _cacheKey(uid: uid, dormId: dormId);
    return _readWithLegacyFallback(key);
  }

  Future<DormLocationAnchor?> readLatest({
    required String uid,
  }) async {
    if (uid.trim().isEmpty) {
      return null;
    }
    return _readWithLegacyFallback(_latestCacheKey(uid: uid));
  }

  Future<void> clear({
    required String uid,
    required String dormId,
  }) async {
    if (uid.trim().isEmpty || dormId.trim().isEmpty) {
      return;
    }
    final String key = _cacheKey(uid: uid, dormId: dormId);
    await _storage.delete(key: key);
    await _legacyStorage.delete(key: key);
  }

  Future<DormLocationAnchor?> _readWithLegacyFallback(String key) async {
    final DormLocationAnchor? primaryValue = _decode(await _storage.read(key: key));
    if (primaryValue != null) {
      return primaryValue;
    }
    final String? legacyRawValue = await _legacyStorage.read(key: key);
    final DormLocationAnchor? legacyValue = _decode(legacyRawValue);
    if (legacyValue == null) {
      return null;
    }
    await _storage.write(
      key: key,
      value: jsonEncode(ModelSerializers.dormLocationAnchorToMap(legacyValue)),
    );
    return legacyValue;
  }

  DormLocationAnchor? _decode(String? rawValue) {
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

  String _cacheKey({
    required String uid,
    required String dormId,
  }) {
    return '$_prefix::$uid::$dormId';
  }

  String _latestCacheKey({
    required String uid,
  }) {
    return '$_prefix::$uid::$_latestSuffix';
  }
}
