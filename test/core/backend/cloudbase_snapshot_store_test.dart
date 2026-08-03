import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sleep_dorm_app/core/backend/app_environment.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_app_api_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_auth_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_session_store.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_snapshot_store.dart';

void main() {
  test(
    'periodic refresh preserves dorm and avatar on destructive regression',
    () async {
      int bootstrapCalls = 0;
      final CloudBaseSnapshotStore store = _buildStore(
        MockClient((http.Request request) async {
          bootstrapCalls += 1;
          return http.Response(
            jsonEncode(
              bootstrapCalls == 1
                  ? _boundPayload()
                  : _unboundPayload(uid: 'cloud-user'),
            ),
            200,
          );
        }),
      );

      await store.refresh();
      await store.refresh();

      final Map<String, dynamic> root = _rootOf(store.payload);
      final Map<String, dynamic> user = Map<String, dynamic>.from(
        root['user'] as Map,
      );
      final Map<String, dynamic> dorm = Map<String, dynamic>.from(
        root['dorm'] as Map,
      );
      expect(user['dormId'], 'dorm-1');
      expect(user['avatarStoragePath'], 'cloud://avatars/cloud-user.png');
      expect(dorm['id'], 'dorm-1');
      expect(store.lastError, contains('attempted to remove dorm'));
    },
  );

  test('snapshot cannot switch to another authenticated user', () async {
    int bootstrapCalls = 0;
    final CloudBaseSnapshotStore store = _buildStore(
      MockClient((http.Request request) async {
        bootstrapCalls += 1;
        return http.Response(
          jsonEncode(
            bootstrapCalls == 1
                ? _boundPayload()
                : _unboundPayload(uid: 'different-user'),
          ),
          200,
        );
      }),
    );

    await store.refresh();
    await store.refresh();

    final Map<String, dynamic> root = _rootOf(store.payload);
    final Map<String, dynamic> user = Map<String, dynamic>.from(
      root['user'] as Map,
    );
    expect(user['uid'], 'cloud-user');
    expect(store.lastError, contains('user mismatch'));
  });

  test(
    'explicit leave refresh can accept a bound-to-unbound transition',
    () async {
      int bootstrapCalls = 0;
      final CloudBaseSnapshotStore store = _buildStore(
        MockClient((http.Request request) async {
          bootstrapCalls += 1;
          return http.Response(
            jsonEncode(
              bootstrapCalls == 1
                  ? _boundPayload()
                  : _unboundPayload(uid: 'cloud-user'),
            ),
            200,
          );
        }),
      );

      await store.refresh();
      await store.refresh(allowDestructiveAccountChanges: true);

      final Map<String, dynamic> root = _rootOf(store.payload);
      final Map<String, dynamic> user = Map<String, dynamic>.from(
        root['user'] as Map,
      );
      expect(user['dormId'], isNull);
      expect(store.lastError, isNull);
    },
  );
}

CloudBaseSnapshotStore _buildStore(http.Client httpClient) {
  const AppEnvironment environment = AppEnvironment(
    target: AppBackendTarget.production,
    appIdPrefix: 'com.dormsleep.app',
    cloudbaseEnvId: 'demo-env',
    cloudbaseAuthBaseUrl: 'https://example.com',
    cloudbaseAppApiBaseUrl: 'https://example.com',
    cloudbasePublishableKey: 'publishable-key',
    cloudbaseClientId: 'demo-env',
  );
  final _SnapshotSessionStore sessionStore = _SnapshotSessionStore();
  final CloudBaseAuthClient authClient = CloudBaseAuthClient(
    environment: environment,
    httpClient: httpClient,
  );
  return CloudBaseSnapshotStore(
    appApiClient: CloudBaseAppApiClient(
      environment: environment,
      sessionStore: sessionStore,
      authClient: authClient,
      httpClient: httpClient,
    ),
  );
}

Map<String, dynamic> _boundPayload() {
  return <String, dynamic>{
    'data': <String, dynamic>{
      'user': <String, dynamic>{
        'uid': 'cloud-user',
        'displayName': 'Tester',
        'tagline': 'tagline',
        'role': 'role',
        'dormId': 'dorm-1',
        'avatarUrl': 'https://cdn.example.com/cloud-user.png',
        'avatarStoragePath': 'cloud://avatars/cloud-user.png',
      },
      'dorm': <String, dynamic>{
        'id': 'dorm-1',
        'name': 'Dorm',
        'members': <Map<String, dynamic>>[],
      },
    },
  };
}

Map<String, dynamic> _unboundPayload({required String uid}) {
  return <String, dynamic>{
    'data': <String, dynamic>{
      'user': <String, dynamic>{
        'uid': uid,
        'displayName': 'Dorm Member',
        'tagline': 'Sleep companion',
        'role': 'Dorm member',
        'dormId': null,
        'avatarUrl': null,
        'avatarStoragePath': null,
      },
      'dorm': <String, dynamic>{'id': '', 'members': <Map<String, dynamic>>[]},
    },
  };
}

Map<String, dynamic> _rootOf(Map<String, dynamic> payload) {
  return Map<String, dynamic>.from(payload['data'] as Map);
}

class _SnapshotSessionStore extends CloudBaseSessionStore {
  CloudBaseSession session = CloudBaseSession(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    subject: 'cloud-user',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
    deviceId: 'device-1',
  );

  @override
  Future<CloudBaseSession?> readSession() async => session;

  @override
  Future<CloudBaseSession?> readPersistedSession() async => session;

  @override
  Future<void> writeSession(CloudBaseSession next) async {
    session = next;
  }
}
