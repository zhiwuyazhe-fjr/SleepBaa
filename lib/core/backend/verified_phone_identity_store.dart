import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persisted after a successful phone login. Drives the auth gate so the
/// login screen is not shown again until [VerifiedPhoneIdentityStore.clear]
/// (settings sign-out).
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
  VerifiedPhoneIdentityStore({FlutterSecureStorage? secureStorage})
    : _secureStorage =
          secureStorage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const String _key = 'cloudbase.verified_phone_identity';

  final FlutterSecureStorage _secureStorage;

  Future<VerifiedPhoneIdentity?> read() async {
    try {
      final String? raw = await _secureStorage.read(key: _key);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return VerifiedPhoneIdentity.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> write(VerifiedPhoneIdentity identity) async {
    try {
      await _secureStorage.write(
        key: _key,
        value: jsonEncode(identity.toJson()),
      );
    } catch (_) {
      // Best-effort; auth gate still uses in-memory profile when possible.
    }
  }

  Future<void> clear() async {
    try {
      await _secureStorage.delete(key: _key);
    } catch (_) {}
  }
}
