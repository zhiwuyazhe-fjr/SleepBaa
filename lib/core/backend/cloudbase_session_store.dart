import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  });

  final String accessToken;
  final String refreshToken;
  final String subject;
  final DateTime expiresAt;
  final String deviceId;
  final String? scope;
  final String tokenType;

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
  }) {
    return CloudBaseSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      subject: subject ?? this.subject,
      expiresAt: expiresAt ?? this.expiresAt,
      deviceId: deviceId ?? this.deviceId,
      scope: scope ?? this.scope,
      tokenType: tokenType ?? this.tokenType,
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
    };
  }

  static CloudBaseSession? fromJson(Map<String, dynamic> map) {
    final String accessToken = map['accessToken'] as String? ?? '';
    final String refreshToken = map['refreshToken'] as String? ?? '';
    final String subject = map['subject'] as String? ?? '';
    final String deviceId = map['deviceId'] as String? ?? '';
    final String? expiresAtRaw = map['expiresAt'] as String?;
    final DateTime? expiresAt =
        expiresAtRaw == null ? null : DateTime.tryParse(expiresAtRaw);
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
    );
  }
}

class CloudBaseSessionStore {
  CloudBaseSessionStore({FlutterSecureStorage? secureStorage})
    : _secureStorage =
          secureStorage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const String _sessionKey = 'cloudbase.session';
  static const String _deviceIdKey = 'cloudbase.device_id';

  final FlutterSecureStorage _secureStorage;
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
    final String? raw = await _readValue(_sessionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      _memorySession = CloudBaseSession.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return _memorySession;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeSession(CloudBaseSession session) async {
    _memorySession = session;
    _memoryDeviceId = session.deviceId;
    await _writeValue(_sessionKey, jsonEncode(session.toJson()));
    await _writeValue(_deviceIdKey, session.deviceId);
  }

  Future<void> clearSession() async {
    _memorySession = null;
    await _deleteValue(_sessionKey);
  }

  Future<void> clearAll() async {
    _memorySession = null;
    _memoryDeviceId = null;
    await _deleteValue(_sessionKey);
    await _deleteValue(_deviceIdKey);
  }

  Future<String?> _readValue(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (_) {
      return key == _deviceIdKey ? _memoryDeviceId : null;
    }
  }

  Future<void> _writeValue(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (_) {
      if (key == _deviceIdKey) {
        _memoryDeviceId = value;
      }
    }
  }

  Future<void> _deleteValue(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (_) {
      if (key == _deviceIdKey) {
        _memoryDeviceId = null;
      }
    }
  }
}
