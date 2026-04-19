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
  _SeededSessionStore();

  CloudBaseSession _session = CloudBaseSession(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    subject: 'cloud-user',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
    deviceId: 'device-1',
  );

  @override
  Future<CloudBaseSession?> readSession() async => _session;

  @override
  Future<void> writeSession(CloudBaseSession session) async {
    _session = session;
  }
}
