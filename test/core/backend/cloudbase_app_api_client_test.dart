import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sleep_dorm_app/core/backend/app_environment.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_app_api_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_auth_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_session_store.dart';

void main() {
  test('post normalizes nested DateTime values before encoding JSON', () async {
    late Map<String, dynamic> body;
    final CloudBaseAppApiClient client = CloudBaseAppApiClient(
      environment: _environment,
      sessionStore: _SeededSessionStore(),
      authClient: CloudBaseAuthClient(environment: _environment),
      httpClient: MockClient((http.Request request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      }),
    );

    final DateTime startedAt = DateTime.utc(2026, 4, 17, 21, 0);
    final DateTime endedAt = DateTime.utc(2026, 4, 18, 7, 0);
    final DateTime submittedAt = DateTime.utc(2026, 4, 18, 7, 5);

    await client.post(
      '/api/feedback/morning',
      body: <String, dynamic>{
        'sessionId': 'session-1',
        'session': <String, dynamic>{
          'id': 'session-1',
          'startedAt': startedAt,
          'endedAt': endedAt,
          'segments': <Map<String, dynamic>>[
            <String, dynamic>{'startedAt': startedAt, 'endedAt': endedAt},
          ],
          'feedback': <Map<String, dynamic>>[
            <String, dynamic>{
              'recommendationId': 'rec-1',
              'submittedAt': submittedAt,
            },
          ],
        },
      },
    );

    final Map<String, dynamic> session = Map<String, dynamic>.from(
      body['session'] as Map,
    );
    final Map<String, dynamic> segment = Map<String, dynamic>.from(
      (session['segments'] as List<dynamic>).single as Map,
    );
    final Map<String, dynamic> feedback = Map<String, dynamic>.from(
      (session['feedback'] as List<dynamic>).single as Map,
    );

    expect(session['startedAt'], startedAt.toIso8601String());
    expect(session['endedAt'], endedAt.toIso8601String());
    expect(segment['startedAt'], startedAt.toIso8601String());
    expect(segment['endedAt'], endedAt.toIso8601String());
    expect(feedback['submittedAt'], submittedAt.toIso8601String());
  });

  test('concurrent post requests share a single session refresh', () async {
    final Completer<void> refreshGate = Completer<void>();
    int refreshCalls = 0;
    int apiCalls = 0;
    final _SeededSessionStore sessionStore = _SeededSessionStore(
      session: CloudBaseSession(
        accessToken: 'stale-access',
        refreshToken: 'refresh-token',
        subject: 'cloud-user',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
        deviceId: 'device-1',
      ),
    );
    final http.Client httpClient = MockClient((http.Request request) async {
      if (request.url.path == '/auth/v1/token') {
        refreshCalls += 1;
        await refreshGate.future;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'access_token': 'fresh-access',
            'refresh_token': 'fresh-refresh',
            'sub': 'cloud-user',
            'expires_in': 7200,
            'token_type': 'Bearer',
          }),
          200,
        );
      }
      if (request.url.path == '/api/test') {
        apiCalls += 1;
        expect(_authorizationHeader(request), 'Bearer fresh-access');
        return http.Response(jsonEncode(<String, dynamic>{'ok': true}), 200);
      }
      throw StateError('Unexpected path: ${request.url.path}');
    });
    final CloudBaseAppApiClient client = CloudBaseAppApiClient(
      environment: _environment,
      sessionStore: sessionStore,
      authClient: CloudBaseAuthClient(
        environment: _environment,
        httpClient: httpClient,
      ),
      httpClient: httpClient,
    );

    final Future<Map<String, dynamic>> first = client.post('/api/test');
    final Future<Map<String, dynamic>> second = client.post('/api/test');

    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(refreshCalls, 1);
    refreshGate.complete();

    final List<Map<String, dynamic>> results = await Future.wait(
      <Future<Map<String, dynamic>>>[first, second],
    );

    expect(results, hasLength(2));
    expect(apiCalls, 2);
    expect(refreshCalls, 1);
    expect(sessionStore.currentSession?.accessToken, 'fresh-access');
  });

  test(
    'refresh rechecks durable storage before using a stale in-memory session',
    () async {
      int refreshCalls = 0;
      final _SeededSessionStore sessionStore = _SeededSessionStore(
        session: CloudBaseSession(
          accessToken: 'stale-memory-access',
          refreshToken: 'stale-memory-refresh',
          subject: 'cloud-user',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
          deviceId: 'device-1',
        ),
        persistedSession: CloudBaseSession(
          accessToken: 'fresh-persisted-access',
          refreshToken: 'fresh-persisted-refresh',
          subject: 'cloud-user',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          deviceId: 'device-1',
        ),
      );
      final http.Client httpClient = MockClient((http.Request request) async {
        if (request.url.path == '/auth/v1/token') {
          refreshCalls += 1;
          throw StateError('stale in-memory refresh must not be sent');
        }
        if (request.url.path == '/api/test') {
          expect(
            _authorizationHeader(request),
            'Bearer fresh-persisted-access',
          );
          return http.Response(jsonEncode(<String, dynamic>{'ok': true}), 200);
        }
        throw StateError('Unexpected path: ${request.url.path}');
      });
      final CloudBaseAppApiClient client = CloudBaseAppApiClient(
        environment: _environment,
        sessionStore: sessionStore,
        authClient: CloudBaseAuthClient(
          environment: _environment,
          httpClient: httpClient,
        ),
        httpClient: httpClient,
      );

      final Map<String, dynamic> payload = await client.post('/api/test');

      expect(payload['ok'], isTrue);
      expect(refreshCalls, 0);
      expect(
        sessionStore.currentSession?.accessToken,
        'fresh-persisted-access',
      );
    },
  );

  test(
    'refresh rejection adopts a token rotated by another client instance',
    () async {
      int refreshCalls = 0;
      final _SeededSessionStore sessionStore = _SeededSessionStore(
        session: CloudBaseSession(
          accessToken: 'stale-access',
          refreshToken: 'stale-refresh',
          subject: 'cloud-user',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
          deviceId: 'device-1',
        ),
      );
      final http.Client httpClient = MockClient((http.Request request) async {
        if (request.url.path == '/auth/v1/token') {
          refreshCalls += 1;
          sessionStore.replacePersistedSession(
            CloudBaseSession(
              accessToken: 'concurrent-fresh-access',
              refreshToken: 'concurrent-fresh-refresh',
              subject: 'cloud-user',
              expiresAt: DateTime.now().add(const Duration(hours: 1)),
              deviceId: 'device-1',
            ),
          );
          return http.Response(
            jsonEncode(<String, dynamic>{
              'error': 'unauthenticated',
              'error_description': 'token hash not match',
            }),
            401,
          );
        }
        if (request.url.path == '/api/test') {
          expect(
            _authorizationHeader(request),
            'Bearer concurrent-fresh-access',
          );
          return http.Response(jsonEncode(<String, dynamic>{'ok': true}), 200);
        }
        throw StateError('Unexpected path: ${request.url.path}');
      });
      final CloudBaseAppApiClient client = CloudBaseAppApiClient(
        environment: _environment,
        sessionStore: sessionStore,
        authClient: CloudBaseAuthClient(
          environment: _environment,
          httpClient: httpClient,
        ),
        httpClient: httpClient,
      );

      final Map<String, dynamic> payload = await client.post('/api/test');

      expect(payload['ok'], isTrue);
      expect(refreshCalls, 1);
      expect(
        sessionStore.currentSession?.accessToken,
        'concurrent-fresh-access',
      );
    },
  );

  test(
    'post retries with the latest stored session after a stale-token 401',
    () async {
      int refreshCalls = 0;
      int apiCalls = 0;
      final _SeededSessionStore sessionStore = _SeededSessionStore(
        session: CloudBaseSession(
          accessToken: 'stale-access',
          refreshToken: 'refresh-token',
          subject: 'cloud-user',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          deviceId: 'device-1',
        ),
      );
      final http.Client httpClient = MockClient((http.Request request) async {
        if (request.url.path == '/auth/v1/token') {
          refreshCalls += 1;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'access_token': 'fresh-access',
              'refresh_token': 'fresh-refresh',
              'sub': 'cloud-user',
              'expires_in': 7200,
              'token_type': 'Bearer',
            }),
            200,
          );
        }
        if (request.url.path == '/api/test') {
          apiCalls += 1;
          final String authorization = _authorizationHeader(request);
          if (authorization == 'Bearer stale-access') {
            await sessionStore.writeSession(
              CloudBaseSession(
                accessToken: 'fresh-access',
                refreshToken: 'fresh-refresh',
                subject: 'cloud-user',
                expiresAt: DateTime.now().add(const Duration(hours: 1)),
                deviceId: 'device-1',
              ),
            );
            return http.Response(
              jsonEncode(<String, dynamic>{
                'code': 'unauthenticated',
                'message': 'token hash not match',
              }),
              401,
            );
          }
          expect(authorization, 'Bearer fresh-access');
          return http.Response(jsonEncode(<String, dynamic>{'ok': true}), 200);
        }
        throw StateError('Unexpected path: ${request.url.path}');
      });
      final CloudBaseAppApiClient client = CloudBaseAppApiClient(
        environment: _environment,
        sessionStore: sessionStore,
        authClient: CloudBaseAuthClient(
          environment: _environment,
          httpClient: httpClient,
        ),
        httpClient: httpClient,
      );

      final Map<String, dynamic> payload = await client.post('/api/test');

      expect(payload['ok'], isTrue);
      expect(apiCalls, 2);
      expect(refreshCalls, 0);
      expect(sessionStore.currentSession?.accessToken, 'fresh-access');
    },
  );

  test(
    'post refreshes after the legacy 400 auth error and preserves omitted refresh fields',
    () async {
      int refreshCalls = 0;
      int apiCalls = 0;
      final DateTime previousExpiry = DateTime.now().add(
        const Duration(hours: 1),
      );
      final _SeededSessionStore sessionStore = _SeededSessionStore(
        session: CloudBaseSession(
          accessToken: 'expired-access',
          refreshToken: 'existing-refresh',
          subject: 'cloud-user',
          expiresAt: previousExpiry,
          deviceId: 'device-1',
          scope: 'profile offline_access',
          tokenType: 'CustomBearer',
        ),
      );
      final http.Client httpClient = MockClient((http.Request request) async {
        if (request.url.path == '/auth/v1/token') {
          refreshCalls += 1;
          final Map<String, dynamic> body =
              jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['grant_type'], 'refresh_token');
          expect(body['refresh_token'], 'existing-refresh');
          return http.Response(
            jsonEncode(<String, dynamic>{
              'access_token': 'fresh-access',
              'expires_in': 3600,
            }),
            200,
          );
        }
        if (request.url.path == '/api/test') {
          apiCalls += 1;
          if (_authorizationHeader(request) == 'Bearer expired-access') {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'code': 'APP_API_ERROR',
                'message': 'CloudBase auth verification failed with 401.',
              }),
              400,
            );
          }
          expect(_authorizationHeader(request), 'Bearer fresh-access');
          return http.Response(jsonEncode(<String, dynamic>{'ok': true}), 200);
        }
        throw StateError('Unexpected path: ${request.url.path}');
      });
      final CloudBaseAppApiClient client = CloudBaseAppApiClient(
        environment: _environment,
        sessionStore: sessionStore,
        authClient: CloudBaseAuthClient(
          environment: _environment,
          httpClient: httpClient,
        ),
        httpClient: httpClient,
      );

      final Map<String, dynamic> payload = await client.post('/api/test');

      expect(payload['ok'], isTrue);
      expect(apiCalls, 2);
      expect(refreshCalls, 1);
      final CloudBaseSession? refreshed = sessionStore.currentSession;
      expect(refreshed?.accessToken, 'fresh-access');
      expect(refreshed?.refreshToken, 'existing-refresh');
      expect(refreshed?.subject, 'cloud-user');
      expect(refreshed?.scope, 'profile offline_access');
      expect(refreshed?.tokenType, 'CustomBearer');
      expect(refreshed?.expiresAt.isAfter(previousExpiry), isTrue);
    },
  );

  test(
    'postSse refreshes and retries when the stream request is unauthorized',
    () async {
      int refreshCalls = 0;
      int sseCalls = 0;
      final _SeededSessionStore sessionStore = _SeededSessionStore(
        session: CloudBaseSession(
          accessToken: 'stale-access',
          refreshToken: 'refresh-token',
          subject: 'cloud-user',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          deviceId: 'device-1',
        ),
      );
      final http.Client httpClient = MockClient((http.Request request) async {
        if (request.url.path == '/auth/v1/token') {
          refreshCalls += 1;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'access_token': 'fresh-access',
              'refresh_token': 'fresh-refresh',
              'sub': 'cloud-user',
              'expires_in': 7200,
            }),
            200,
          );
        }
        if (request.url.path == '/api/assistant/stream') {
          sseCalls += 1;
          if (_authorizationHeader(request) == 'Bearer stale-access') {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'code': 'UNAUTHENTICATED',
                'message': 'token expired',
              }),
              401,
            );
          }
          expect(_authorizationHeader(request), 'Bearer fresh-access');
          return http.Response('event: complete\ndata: {"ok":true}\n\n', 200);
        }
        throw StateError('Unexpected path: ${request.url.path}');
      });
      final CloudBaseAppApiClient client = CloudBaseAppApiClient(
        environment: _environment,
        sessionStore: sessionStore,
        authClient: CloudBaseAuthClient(
          environment: _environment,
          httpClient: httpClient,
        ),
        httpClient: httpClient,
      );

      final Stream<CloudBaseSseFrame> stream = await client.postSse(
        '/api/assistant/stream',
      );
      final List<CloudBaseSseFrame> frames = await stream.toList();

      expect(refreshCalls, 1);
      expect(sseCalls, 2);
      expect(frames, hasLength(1));
      expect(frames.single.event, 'complete');
      expect(frames.single.data, '{"ok":true}');
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

class _SeededSessionStore extends CloudBaseSessionStore {
  _SeededSessionStore({
    CloudBaseSession? session,
    CloudBaseSession? persistedSession,
  }) : _session =
           session ??
           CloudBaseSession(
             accessToken: 'access-token',
             refreshToken: 'refresh-token',
             subject: 'cloud-user',
             expiresAt: DateTime.now().add(const Duration(hours: 1)),
             deviceId: 'device-1',
           ),
       _persistedSession = persistedSession;

  CloudBaseSession _session;
  CloudBaseSession? _persistedSession;

  CloudBaseSession? get currentSession => _session;

  void replacePersistedSession(CloudBaseSession session) {
    _persistedSession = session;
  }

  @override
  Future<CloudBaseSession?> readSession() async => _session;

  @override
  Future<CloudBaseSession?> readPersistedSession() async {
    final CloudBaseSession persisted = _persistedSession ?? _session;
    _session = persisted;
    return persisted;
  }

  @override
  Future<void> writeSession(CloudBaseSession session) async {
    _session = session;
    _persistedSession = session;
  }
}

String _authorizationHeader(http.BaseRequest request) {
  return request.headers['authorization'] ?? request.headers['Authorization']!;
}
