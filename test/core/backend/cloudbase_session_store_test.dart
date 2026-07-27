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
    final CloudBaseSession oldSession = CloudBaseSession(
      accessToken: 'old-access',
      refreshToken: 'old-refresh',
      subject: 'user-1',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      deviceId: 'device-1',
    );
    final CloudBaseSession newSession = oldSession.copyWith(
      accessToken: 'new-access',
      refreshToken: 'new-refresh',
    );

    await store.writeSession(oldSession);
    secureStorage['cloudbase.session'] = jsonEncode(newSession.toJson());

    expect((await store.readSession())?.accessToken, 'old-access');
    expect((await store.readPersistedSession())?.accessToken, 'new-access');
    expect((await store.readSession())?.accessToken, 'new-access');
  });

  test('writeSession does not hide secure storage write failures', () async {
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

    await expectLater(
      store.writeSession(session),
      throwsA(isA<PlatformException>()),
    );

    throwOnWrite = false;
    expect(await store.readSession(), isNull);
  });
}
