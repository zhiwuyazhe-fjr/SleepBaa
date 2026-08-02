import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sleep_dorm_app/core/backend/app_environment.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_auth_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_session_coordinator.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_session_store.dart';

void main() {
  test('refresh rejection never deletes the durable session', () async {
    final _MemorySessionStore store = _MemorySessionStore(
      _expiredSession('access-1', 'refresh-1'),
    );
    final CloudBaseSessionCoordinator coordinator = CloudBaseSessionCoordinator(
      sessionStore: store,
      authClient: CloudBaseAuthClient(
        environment: _environment,
        httpClient: MockClient((http.Request request) async {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'error': 'invalid_grant',
              'error_description': 'refresh token expired',
            }),
            401,
          );
        }),
      ),
      concurrentRefreshBackoff: const <Duration>[],
    );

    await expectLater(
      coordinator.requireFreshSession(),
      throwsA(isA<CloudBaseAuthException>()),
    );

    expect(store.session?.accessToken, 'access-1');
    expect(store.session?.refreshToken, 'refresh-1');
    expect(store.clearCalls, 0);
  });

  test('concurrent refresh requests rotate the token only once', () async {
    int refreshCalls = 0;
    final _MemorySessionStore store = _MemorySessionStore(
      _expiredSession('access-1', 'refresh-1'),
    );
    final CloudBaseSessionCoordinator coordinator = CloudBaseSessionCoordinator(
      sessionStore: store,
      authClient: CloudBaseAuthClient(
        environment: _environment,
        httpClient: MockClient((http.Request request) async {
          refreshCalls += 1;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return http.Response(
            jsonEncode(<String, dynamic>{
              'access_token': 'access-2',
              'refresh_token': 'refresh-2',
              'sub': 'user-1',
              'expires_in': 3600,
            }),
            200,
          );
        }),
      ),
    );

    final List<CloudBaseSession> sessions = await Future.wait(
      List<Future<CloudBaseSession>>.generate(
        8,
        (_) => coordinator.requireFreshSession(),
      ),
    );

    expect(refreshCalls, 1);
    expect(
      sessions.every((CloudBaseSession s) => s.accessToken == 'access-2'),
      isTrue,
    );
    expect(store.session?.refreshToken, 'refresh-2');
  });

  test(
    'successive access-token expirations keep rotating one durable account',
    () async {
      DateTime now = DateTime(2026, 8, 2, 10);
      int refreshCalls = 0;
      final _MemorySessionStore store = _MemorySessionStore(
        CloudBaseSession(
          accessToken: 'access-0',
          refreshToken: 'refresh-0',
          subject: 'user-1',
          expiresAt: now.add(const Duration(minutes: 1)),
          deviceId: 'device-1',
        ),
      );
      final CloudBaseSessionCoordinator coordinator =
          CloudBaseSessionCoordinator(
            sessionStore: store,
            authClient: CloudBaseAuthClient(
              environment: _environment,
              httpClient: MockClient((http.Request request) async {
                refreshCalls += 1;
                return http.Response(
                  jsonEncode(<String, dynamic>{
                    'access_token': 'access-$refreshCalls',
                    'refresh_token': 'refresh-$refreshCalls',
                    'sub': 'user-1',
                    'expires_in': 3600,
                  }),
                  200,
                );
              }),
            ),
            clock: () => now,
          );

      expect((await coordinator.requireFreshSession()).accessToken, 'access-1');
      now = now.add(const Duration(minutes: 56));
      expect((await coordinator.requireFreshSession()).accessToken, 'access-2');

      expect(refreshCalls, 2);
      expect(store.session?.subject, 'user-1');
      expect(store.clearCalls, 0);
    },
  );
}

const AppEnvironment _environment = AppEnvironment(
  target: AppBackendTarget.production,
  appIdPrefix: 'com.dormsleep.app',
  cloudbaseEnvId: 'demo-env',
  cloudbaseAuthBaseUrl: 'https://example.com',
  cloudbaseAppApiBaseUrl: 'https://example.com',
  cloudbasePublishableKey: 'publishable-key',
  cloudbaseClientId: 'demo-env',
);

CloudBaseSession _expiredSession(String accessToken, String refreshToken) {
  return CloudBaseSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
    subject: 'user-1',
    expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
    deviceId: 'device-1',
  );
}

class _MemorySessionStore extends CloudBaseSessionStore {
  _MemorySessionStore(this.session);

  CloudBaseSession? session;
  int clearCalls = 0;

  @override
  Future<String> ensureDeviceId() async => session?.deviceId ?? 'device-1';

  @override
  Future<CloudBaseSession?> readSession() async => session;

  @override
  Future<CloudBaseSession?> readPersistedSession() async => session;

  @override
  Future<void> writeSession(CloudBaseSession next) async {
    session = next;
  }

  @override
  Future<void> clearSession() async {
    clearCalls += 1;
    session = null;
  }
}
