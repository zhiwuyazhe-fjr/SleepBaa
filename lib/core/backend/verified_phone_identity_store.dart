import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Durable account principal created after a successful phone login.
///
/// This record, not the short-lived access token, drives the login gate. It is
/// removed only by an explicit user sign-out.
class VerifiedPhoneIdentity {
  const VerifiedPhoneIdentity({
    required this.subject,
    required this.phoneNumber,
    this.phoneLinkedAt,
  });

  final String subject;
  final String phoneNumber;
  final DateTime? phoneLinkedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'subject': subject,
    'phoneNumber': phoneNumber,
    'phoneLinkedAt': phoneLinkedAt?.toIso8601String(),
  };

  static VerifiedPhoneIdentity? fromJson(Map<String, dynamic> map) {
    final String subject = map['subject'] as String? ?? '';
    final String phoneNumber = map['phoneNumber'] as String? ?? '';
    if (subject.isEmpty || phoneNumber.trim().isEmpty) {
      return null;
    }
    final String? linkedRaw = map['phoneLinkedAt'] as String?;
    return VerifiedPhoneIdentity(
      subject: subject,
      phoneNumber: phoneNumber,
      phoneLinkedAt: linkedRaw == null ? null : DateTime.tryParse(linkedRaw),
    );
  }
}

class VerifiedPhoneIdentityStore {
  VerifiedPhoneIdentityStore({
    FlutterSecureStorage? secureStorage,
    SharedPreferences? sharedPreferences,
  }) : _secureStorage =
           secureStorage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(
               encryptedSharedPreferences: true,
               resetOnError: true,
             ),
           ),
       _sharedPreferences = sharedPreferences;

  static const String _key = 'cloudbase.verified_phone_identity';
  static const String _mirrorKey = 'cloudbase.verified_phone_identity.mirror';

  final FlutterSecureStorage _secureStorage;
  SharedPreferences? _sharedPreferences;

  Future<VerifiedPhoneIdentity?> read() async {
    final VerifiedPhoneIdentity? secure = _decode(await _readSecure());
    final VerifiedPhoneIdentity? mirror = _decode(await _readMirror());
    final VerifiedPhoneIdentity? selected = _newest(secure, mirror);
    if (selected == null) {
      return null;
    }
    final String encoded = jsonEncode(selected.toJson());
    await _writeMirror(encoded);
    await _writeSecure(encoded);
    return selected;
  }

  Future<void> write(VerifiedPhoneIdentity identity) async {
    final String encoded = jsonEncode(identity.toJson());
    // The non-secret principal mirror prevents a transient Android Keystore
    // failure from sending an already signed-in user back to the login page.
    await _writeMirror(encoded);
    await _writeSecure(encoded);
  }

  Future<void> clear() async {
    try {
      await _secureStorage.delete(key: _key);
    } catch (_) {}
    try {
      await (await _prefs()).remove(_mirrorKey);
    } catch (_) {}
  }

  VerifiedPhoneIdentity? _newest(
    VerifiedPhoneIdentity? secure,
    VerifiedPhoneIdentity? mirror,
  ) {
    if (secure == null) {
      return mirror;
    }
    if (mirror == null) {
      return secure;
    }
    final DateTime secureAt = secure.phoneLinkedAt ?? DateTime(1970);
    final DateTime mirrorAt = mirror.phoneLinkedAt ?? DateTime(1970);
    return mirrorAt.isAfter(secureAt) ? mirror : secure;
  }

  VerifiedPhoneIdentity? _decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return VerifiedPhoneIdentity.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<String?> _readSecure() async {
    try {
      return await _secureStorage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeSecure(String value) async {
    try {
      await _secureStorage.write(key: _key, value: value);
    } catch (_) {}
  }

  Future<String?> _readMirror() async {
    try {
      return (await _prefs()).getString(_mirrorKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeMirror(String value) async {
    try {
      await (await _prefs()).setString(_mirrorKey, value);
    } catch (_) {}
  }

  Future<SharedPreferences> _prefs() async {
    return _sharedPreferences ??= await SharedPreferences.getInstance();
  }
}
