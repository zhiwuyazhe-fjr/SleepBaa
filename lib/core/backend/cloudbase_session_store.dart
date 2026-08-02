import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sleep_dorm_app/core/utils/id_generator.dart';

class CloudBaseSession {
  const CloudBaseSession({
    required this.accessToken,
    required this.refreshToken,
    required this.subject,
    required this.expiresAt,
    required this.deviceId,
    this.scope,
    this.tokenType = 'Bearer',
    this.persistedAt,
  });

  final String accessToken;
  final String refreshToken;
  final String subject;
  final DateTime expiresAt;
  final String deviceId;
  final String? scope;
  final String tokenType;

  /// Time at which this token pair was durably written. Older installations
  /// do not have this field, so selection falls back to [expiresAt].
  final DateTime? persistedAt;

  bool get isExpired =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 30)));

  CloudBaseSession copyWith({
    String? accessToken,
    String? refreshToken,
    String? subject,
    DateTime? expiresAt,
    String? deviceId,
    String? scope,
    String? tokenType,
    DateTime? persistedAt,
  }) {
    return CloudBaseSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      subject: subject ?? this.subject,
      expiresAt: expiresAt ?? this.expiresAt,
      deviceId: deviceId ?? this.deviceId,
      scope: scope ?? this.scope,
      tokenType: tokenType ?? this.tokenType,
      persistedAt: persistedAt ?? this.persistedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'subject': subject,
      'expiresAt': expiresAt.toIso8601String(),
      'deviceId': deviceId,
      'scope': scope,
      'tokenType': tokenType,
      'persistedAt': persistedAt?.toIso8601String(),
    };
  }

  static CloudBaseSession? fromJson(Map<String, dynamic> map) {
    final String accessToken = map['accessToken'] as String? ?? '';
    final String refreshToken = map['refreshToken'] as String? ?? '';
    final String subject = map['subject'] as String? ?? '';
    final String deviceId = map['deviceId'] as String? ?? '';
    final String? expiresAtRaw = map['expiresAt'] as String?;
    final DateTime? expiresAt = expiresAtRaw == null
        ? null
        : DateTime.tryParse(expiresAtRaw);
    final String? persistedAtRaw = map['persistedAt'] as String?;
    final DateTime? persistedAt = persistedAtRaw == null
        ? null
        : DateTime.tryParse(persistedAtRaw);
    if (accessToken.isEmpty ||
        refreshToken.isEmpty ||
        subject.isEmpty ||
        deviceId.isEmpty ||
        expiresAt == null) {
      return null;
    }
    return CloudBaseSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      subject: subject,
      expiresAt: expiresAt,
      deviceId: deviceId,
      scope: map['scope'] as String?,
      tokenType: map['tokenType'] as String? ?? 'Bearer',
      persistedAt: persistedAt,
    );
  }
}

class CloudBaseSessionStore {
  CloudBaseSessionStore({
    FlutterSecureStorage? secureStorage,
    SharedPreferences? sharedPreferences,
  }) : _sharedPreferences = sharedPreferences,
       _secureStorage =
           secureStorage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(
               encryptedSharedPreferences: true,
               resetOnError: true,
             ),
           );

  static const String _sessionKey = 'cloudbase.session';
  // SharedPreferences is a recovery mirror for devices whose Android Keystore
  // becomes temporarily unreadable or unwritable. Both copies are compared;
  // neither storage backend is allowed to overwrite a newer rotated token.
  static const String _sessionMirrorKey = 'cloudbase.session.mirror';
  static const String _deviceIdKey = 'cloudbase.device_id';

  final FlutterSecureStorage _secureStorage;
  SharedPreferences? _sharedPreferences;
  CloudBaseSession? _memorySession;
  String? _memoryDeviceId;

  Future<String> ensureDeviceId() async {
    final String? existing = await _readValue(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      _memoryDeviceId = existing;
      return existing;
    }
    final String created = IdGenerator.next('cb-device');
    _memoryDeviceId = created;
    await _writeValue(_deviceIdKey, created);
    return created;
  }

  Future<CloudBaseSession?> readSession() async {
    if (_memorySession != null) {
      return _memorySession;
    }
    return readPersistedSession();
  }

  /// Reads both durable copies and chooses the newest token rotation.
  ///
  /// A secure-storage write can fail while the SharedPreferences mirror still
  /// succeeds. Always preferring secure storage would then resurrect the old
  /// refresh token on the next cold start and cause an `invalid_grant` logout.
  Future<CloudBaseSession?> readPersistedSession() async {
    final CloudBaseSession? secureSession = _decodeSession(
      await _readSecureValue(_sessionKey),
    );
    final CloudBaseSession? mirrorSession = _decodeSession(
      await _readSessionMirror(),
    );
    final CloudBaseSession? selected = _selectNewestSession(
      secureSession,
      mirrorSession,
    );
    if (selected == null) {
      return null;
    }

    final CloudBaseSession normalized = selected.persistedAt == null
        ? selected.copyWith(persistedAt: DateTime.now().toUtc())
        : selected;
    final String encoded = jsonEncode(normalized.toJson());
    _memorySession = normalized;
    _memoryDeviceId = normalized.deviceId;

    // Converge stale/corrupt copies without allowing either repair failure to
    // hide an otherwise valid session.
    await _writeSessionMirror(encoded);
    await _writeSecureSessionBestEffort(encoded);
    return normalized;
  }

  CloudBaseSession? _selectNewestSession(
    CloudBaseSession? secureSession,
    CloudBaseSession? mirrorSession,
  ) {
    if (secureSession == null) {
      return mirrorSession;
    }
    if (mirrorSession == null) {
      return secureSession;
    }

    final DateTime? securePersistedAt = secureSession.persistedAt;
    final DateTime? mirrorPersistedAt = mirrorSession.persistedAt;
    if (securePersistedAt != null || mirrorPersistedAt != null) {
      if (securePersistedAt == null) {
        return mirrorSession;
      }
      if (mirrorPersistedAt == null) {
        return secureSession;
      }
      final int persistedComparison = securePersistedAt.compareTo(
        mirrorPersistedAt,
      );
      if (persistedComparison != 0) {
        return persistedComparison > 0 ? secureSession : mirrorSession;
      }
    }

    final int expiryComparison = secureSession.expiresAt.compareTo(
      mirrorSession.expiresAt,
    );
    if (expiryComparison != 0) {
      return expiryComparison > 0 ? secureSession : mirrorSession;
    }

    // Equal versions normally contain the same token. Prefer secure storage
    // only as a deterministic tie-breaker, never simply because it exists.
    return secureSession;
  }

  CloudBaseSession? _decodeSession(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return CloudBaseSession.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> writeSession(CloudBaseSession session) async {
    final CloudBaseSession stamped = session.copyWith(
      persistedAt: DateTime.now().toUtc(),
    );
    final String encoded = jsonEncode(stamped.toJson());
    // Write the recovery mirror first. If Android Keystore becomes briefly
    // unavailable, a successfully refreshed token must still survive restart.
    await _writeSessionMirror(encoded);
    await _writeSecureSessionBestEffort(encoded);
    _memorySession = stamped;
    _memoryDeviceId = stamped.deviceId;
    await _writeValue(_deviceIdKey, stamped.deviceId);
  }

  Future<void> clearSession() async {
    _memorySession = null;
    await _deleteValue(_sessionKey);
    await _deleteSessionMirror();
  }

  Future<void> clearAll() async {
    _memorySession = null;
    _memoryDeviceId = null;
    await _deleteValue(_sessionKey);
    await _deleteSessionMirror();
    await _deleteValue(_deviceIdKey);
  }

  Future<String?> _readSecureValue(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _readValue(String key) async {
    if (key == _deviceIdKey) {
      final String? persisted = await _readSecureValue(key);
      if (persisted != null && persisted.isNotEmpty) {
        return persisted;
      }
      final String? fallback = await _readFallbackDeviceId();
      return fallback?.isNotEmpty == true ? fallback : _memoryDeviceId;
    }
    return _readSecureValue(key);
  }

  Future<void> _writeValue(String key, String value) async {
    if (key == _deviceIdKey) {
      _memoryDeviceId = value;
      try {
        await _secureStorage.write(key: key, value: value);
      } catch (_) {
        // Best-effort secure write; keep the SharedPreferences mirror.
      }
      await _writeFallbackDeviceId(value);
      return;
    }

    bool persistedSecurely = false;
    try {
      await _secureStorage.write(key: key, value: value);
      persistedSecurely = await _secureStorage.read(key: key) == value;
    } catch (_) {
      // Keystore failures must not turn a successful login into a logout.
    }
    if (!persistedSecurely) {
      throw StateError('Secure storage did not persist the value.');
    }
  }

  Future<void> _writeSecureSessionBestEffort(String value) async {
    try {
      await _secureStorage.write(key: _sessionKey, value: value);
    } catch (_) {
      // The mirror remains authoritative until a later read repairs this copy.
    }
  }

  Future<void> _deleteValue(String key) async {
    if (key == _deviceIdKey) {
      _memoryDeviceId = null;
      try {
        await _secureStorage.delete(key: key);
      } catch (_) {
        // Best-effort secure delete; keep cleaning the fallback mirror.
      }
      await _deleteFallbackDeviceId();
      return;
    }
    try {
      await _secureStorage.delete(key: key);
    } catch (_) {
      // Ignore non-device deletes when secure storage is unavailable.
    }
  }

  Future<String?> _readSessionMirror() async {
    try {
      return (await _prefs()).getString(_sessionMirrorKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeSessionMirror(String value) async {
    try {
      await (await _prefs()).setString(_sessionMirrorKey, value);
    } catch (_) {
      // The secure copy is still available when the mirror cannot be written.
    }
  }

  Future<void> _deleteSessionMirror() async {
    try {
      await (await _prefs()).remove(_sessionMirrorKey);
    } catch (_) {}
  }

  Future<String?> _readFallbackDeviceId() async {
    try {
      return (await _prefs()).getString(_deviceIdKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeFallbackDeviceId(String value) async {
    try {
      await (await _prefs()).setString(_deviceIdKey, value);
    } catch (_) {
      // Best-effort fallback only.
    }
  }

  Future<void> _deleteFallbackDeviceId() async {
    try {
      await (await _prefs()).remove(_deviceIdKey);
    } catch (_) {
      // Best-effort fallback only.
    }
  }

  Future<SharedPreferences> _prefs() async {
    return _sharedPreferences ??= await SharedPreferences.getInstance();
  }
}
