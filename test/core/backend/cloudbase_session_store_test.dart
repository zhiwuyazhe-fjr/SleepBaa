import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final Map<String, String> secureStorage = <String, String>{};
  bool throwOnRead = false;
  bool throwOnWrite = false;
  bool throwOnDelete = false;

  Future<dynamic> handleSecureStorageCall(MethodCall call) async {
    final Map<dynamic, dynamic> arguments =
        call.arguments as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{};
    final String key = arguments['key'] as String? ?? '';
    switch (call.method) {
      case 'read':
        if (throwOnRead) {
          throw PlatformException(code: 'read-failed');
        }
        return secureStorage[key];
      case 'write':
        if (throwOnWrite) {
          throw PlatformException(code: 'write-failed');
        }
        secureStorage[key] = arguments['value'] as String? ?? '';
        return null;
      case 'delete':
        if (throwOnDelete) {
          throw PlatformException(code: 'delete-failed');
        }
        secureStorage.remove(key);
        return null;
      case 'containsKey':
        return secureStorage.containsKey(key);
      case 'readAll':
        return Map<String, String>.from(secureStorage);
      case 'deleteAll':
        secureStorage.clear();
        return null;
      default:
        return null;
    }
  }

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          secureStorageChannel,
          handleSecureStorageCall,
        );
  });

  setUp(() {
    secureStorage.clear();
    throwOnRead = false;
    throwOnWrite = false;
    throwOnDelete = false;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  test(
    'ensureDeviceId restores the mirrored fallback when secure storage later misses the key',
    () async {
      final SharedPreferences sharedPreferences =
          await SharedPreferences.getInstance();
      final CloudBaseSessionStore firstStore = CloudBaseSessionStore(
        sharedPreferences: sharedPreferences,
      );

      final String firstDeviceId = await firstStore.ensureDeviceId();
      expect(firstDeviceId, isNotEmpty);
      expect(secureStorage['cloudbase.device_id'], firstDeviceId);
      expect(sharedPreferences.getString('cloudbase.device_id'), firstDeviceId);

      secureStorage.clear();

      final CloudBaseSessionStore secondStore = CloudBaseSessionStore(
        sharedPreferences: sharedPreferences,
      );
      final String restoredDeviceId = await secondStore.ensureDeviceId();

      expect(restoredDeviceId, firstDeviceId);
    },
  );

  test(
    'ensureDeviceId keeps the same id when secure storage read and write throw',
    () async {
      final SharedPreferences sharedPreferences =
          await SharedPreferences.getInstance();
      throwOnRead = true;
      throwOnWrite = true;

      final CloudBaseSessionStore firstStore = CloudBaseSessionStore(
        sharedPreferences: sharedPreferences,
      );
      final String firstDeviceId = await firstStore.ensureDeviceId();

      expect(firstDeviceId, isNotEmpty);
      expect(sharedPreferences.getString('cloudbase.device_id'), firstDeviceId);

      final CloudBaseSessionStore secondStore = CloudBaseSessionStore(
        sharedPreferences: sharedPreferences,
      );
      final String restoredDeviceId = await secondStore.ensureDeviceId();

      expect(restoredDeviceId, firstDeviceId);
    },
  );

  test('readPersistedSession bypasses an older in-memory session', () async {
    final SharedPreferences sharedPreferences =
        await SharedPreferences.getInstance();
    final CloudBaseSessionStore store = CloudBaseSessionStore(
      sharedPreferences: sharedPreferences,
    );
    final DateTime now = DateTime.now().toUtc();
    final CloudBaseSession oldSession = CloudBaseSession(
      accessToken: 'old-access',
      refreshToken: 'old-refresh',
      subject: 'user-1',
      expiresAt: now.add(const Duration(hours: 1)),
      deviceId: 'device-1',
    );
    final CloudBaseSession newSession = oldSession.copyWith(
      accessToken: 'new-access',
      refreshToken: 'new-refresh',
      expiresAt: now.add(const Duration(hours: 2)),
      persistedAt: now.add(const Duration(minutes: 1)),
    );

    await store.writeSession(oldSession);
    secureStorage['cloudbase.session'] = jsonEncode(newSession.toJson());

    expect((await store.readSession())?.accessToken, 'old-access');
    expect((await store.readPersistedSession())?.accessToken, 'new-access');
    expect((await store.readSession())?.accessToken, 'new-access');
  });

  test('newer mirror wins over stale secure refresh token', () async {
    final SharedPreferences sharedPreferences =
        await SharedPreferences.getInstance();
    final DateTime now = DateTime.now().toUtc();
    final CloudBaseSession staleSecure = CloudBaseSession(
      accessToken: 'stale-access',
      refreshToken: 'stale-refresh',
      subject: 'user-1',
      expiresAt: now.add(const Duration(minutes: 20)),
      deviceId: 'device-1',
      persistedAt: now,
    );
    final CloudBaseSession freshMirror = staleSecure.copyWith(
      accessToken: 'fresh-access',
      refreshToken: 'fresh-refresh',
      expiresAt: now.add(const Duration(hours: 2)),
      persistedAt: now.add(const Duration(minutes: 1)),
    );
    secureStorage['cloudbase.session'] = jsonEncode(staleSecure.toJson());
    await sharedPreferences.setString(
      'cloudbase.session.mirror',
      jsonEncode(freshMirror.toJson()),
    );

    final CloudBaseSessionStore store = CloudBaseSessionStore(
      sharedPreferences: sharedPreferences,
    );
    final CloudBaseSession? restored = await store.readPersistedSession();

    expect(restored?.accessToken, 'fresh-access');
    expect(restored?.refreshToken, 'fresh-refresh');
    final CloudBaseSession? repairedSecure = CloudBaseSession.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(secureStorage['cloudbase.session']!) as Map,
      ),
    );
    expect(repairedSecure?.accessToken, 'fresh-access');
  });

  test('newer secure session wins over stale mirror', () async {
    final SharedPreferences sharedPreferences =
        await SharedPreferences.getInstance();
    final DateTime now = DateTime.now().toUtc();
    final CloudBaseSession staleMirror = CloudBaseSession(
      accessToken: 'stale-access',
      refreshToken: 'stale-refresh',
      subject: 'user-1',
      expiresAt: now.add(const Duration(minutes: 20)),
      deviceId: 'device-1',
      persistedAt: now,
    );
    final CloudBaseSession freshSecure = staleMirror.copyWith(
      accessToken: 'fresh-access',
      refreshToken: 'fresh-refresh',
      expiresAt: now.add(const Duration(hours: 2)),
      persistedAt: now.add(const Duration(minutes: 1)),
    );
    secureStorage['cloudbase.session'] = jsonEncode(freshSecure.toJson());
    await sharedPreferences.setString(
      'cloudbase.session.mirror',
      jsonEncode(staleMirror.toJson()),
    );

    final CloudBaseSessionStore store = CloudBaseSessionStore(
      sharedPreferences: sharedPreferences,
    );
    final CloudBaseSession? restored = await store.readPersistedSession();

    expect(restored?.accessToken, 'fresh-access');
    final CloudBaseSession? repairedMirror = CloudBaseSession.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(sharedPreferences.getString('cloudbase.session.mirror')!)
            as Map,
      ),
    );
    expect(repairedMirror?.accessToken, 'fresh-access');
  });

  test('legacy sessions without persistedAt use the later expiry', () async {
    final SharedPreferences sharedPreferences =
        await SharedPreferences.getInstance();
    final DateTime now = DateTime.now().toUtc();
    final CloudBaseSession staleSecure = CloudBaseSession(
      accessToken: 'stale-access',
      refreshToken: 'stale-refresh',
      subject: 'user-1',
      expiresAt: now.add(const Duration(minutes: 20)),
      deviceId: 'device-1',
    );
    final CloudBaseSession freshMirror = staleSecure.copyWith(
      accessToken: 'fresh-access',
      refreshToken: 'fresh-refresh',
      expiresAt: now.add(const Duration(hours: 2)),
    );
    secureStorage['cloudbase.session'] = jsonEncode(staleSecure.toJson());
    await sharedPreferences.setString(
      'cloudbase.session.mirror',
      jsonEncode(freshMirror.toJson()),
    );

    final CloudBaseSessionStore store = CloudBaseSessionStore(
      sharedPreferences: sharedPreferences,
    );

    expect((await store.readPersistedSession())?.accessToken, 'fresh-access');
  });

  test(
    'writeSession keeps a recovery copy when secure storage write fails',
    () async {
      final SharedPreferences sharedPreferences =
          await SharedPreferences.getInstance();
      final CloudBaseSessionStore store = CloudBaseSessionStore(
        sharedPreferences: sharedPreferences,
      );
      final CloudBaseSession session = CloudBaseSession(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        subject: 'user-1',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        deviceId: 'device-1',
      );
      throwOnWrite = true;

      await store.writeSession(session);

      throwOnWrite = false;
      final CloudBaseSessionStore restoredStore = CloudBaseSessionStore(
        sharedPreferences: sharedPreferences,
      );
      expect(
        (await restoredStore.readPersistedSession())?.accessToken,
        'access-token',
      );
    },
  );
}
