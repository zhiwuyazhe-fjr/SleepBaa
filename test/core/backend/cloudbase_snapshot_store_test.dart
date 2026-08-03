import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sleep_dorm_app/core/backend/app_environment.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_app_api_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_auth_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_session_store.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_snapshot_cache_store.dart';
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

  test('bound snapshots must contain the authenticated dorm member', () async {
    final Map<String, dynamic> incomplete = _boundPayload();
    final Map<String, dynamic> root = _rootOf(incomplete);
    (root['dorm'] as Map<String, dynamic>)['members'] =
        const <Map<String, dynamic>>[];
    final CloudBaseSnapshotStore store = _buildStore(
      MockClient((http.Request request) async {
        return http.Response(jsonEncode(incomplete), 200);
      }),
    );

    await store.refresh();

    expect(store.hasPayload, isFalse);
    expect(store.lastError, contains('is missing from dorm'));
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
                  : _unboundPayload(uid: 'cloud-user', preserveAvatar: true),
            ),
            200,
          );
        }),
      );

      await store.refresh();
      await store.refresh(allowDormBindingRemoval: true);

      final Map<String, dynamic> root = _rootOf(store.payload);
      final Map<String, dynamic> user = Map<String, dynamic>.from(
        root['user'] as Map,
      );
      expect(user['dormId'], isNull);
      expect(store.lastError, isNull);
    },
  );

  test('leaving a dorm never authorizes avatar removal', () async {
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
    await store.refresh(allowDormBindingRemoval: true);

    final Map<String, dynamic> root = _rootOf(store.payload);
    expect((root['user'] as Map)['dormId'], 'dorm-1');
    expect(
      (root['user'] as Map)['avatarStoragePath'],
      'cloud://avatars/cloud-user.png',
    );
    expect(store.lastError, contains('remove the persisted avatar'));
  });

  test(
    'durable snapshot protects a recreated app from an empty bootstrap',
    () async {
      final _MemorySnapshotCache cache = _MemorySnapshotCache();
      final CloudBaseSnapshotStore firstStore = _buildStore(
        MockClient((http.Request request) async {
          return http.Response(jsonEncode(_boundPayload()), 200);
        }),
        cache: cache,
      );
      await firstStore.refresh();

      final CloudBaseSnapshotStore recreatedStore = _buildStore(
        MockClient((http.Request request) async {
          return http.Response(
            jsonEncode(_unboundPayload(uid: 'cloud-user')),
            200,
          );
        }),
        cache: cache,
      );
      await recreatedStore.refresh();

      final Map<String, dynamic> root = _rootOf(recreatedStore.payload);
      expect((root['user'] as Map)['dormId'], 'dorm-1');
      expect((root['dorm'] as Map)['id'], 'dorm-1');
      expect(recreatedStore.lastError, contains('attempted to remove dorm'));
    },
  );
}

CloudBaseSnapshotStore _buildStore(
  http.Client httpClient, {
  CloudBaseSnapshotCache? cache,
}) {
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
    cacheStore: cache ?? _MemorySnapshotCache(),
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
        'members': <Map<String, dynamic>>[
          <String, dynamic>{
            'uid': 'cloud-user',
            'name': 'Tester',
            'status': 'quiet',
            'sleepModeActive': false,
          },
        ],
      },
    },
  };
}

Map<String, dynamic> _unboundPayload({
  required String uid,
  bool preserveAvatar = false,
}) {
  return <String, dynamic>{
    'data': <String, dynamic>{
      'user': <String, dynamic>{
        'uid': uid,
        'displayName': 'Dorm Member',
        'tagline': 'Sleep companion',
        'role': 'Dorm member',
        'dormId': null,
        'avatarUrl': preserveAvatar
            ? 'https://cdn.example.com/cloud-user.png'
            : null,
        'avatarStoragePath': preserveAvatar
            ? 'cloud://avatars/cloud-user.png'
            : null,
      },
      'dorm': const <String, dynamic>{},
    },
  };
}

Map<String, dynamic> _rootOf(Map<String, dynamic> payload) {
  return Map<String, dynamic>.from(payload['data'] as Map);
}

class _MemorySnapshotCache implements CloudBaseSnapshotCache {
  Map<String, dynamic>? payload;

  @override
  Future<Map<String, dynamic>?> read() async {
    final Map<String, dynamic>? current = payload;
    return current == null ? null : jsonDecode(jsonEncode(current));
  }

  @override
  Future<void> write(Map<String, dynamic> next) async {
    payload = Map<String, dynamic>.from(jsonDecode(jsonEncode(next)) as Map);
  }

  @override
  Future<void> clear() async {
    payload = null;
  }
}

class _SnapshotSessionStore implements CloudBaseSessionStore {
  CloudBaseSession? session = CloudBaseSession(
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

  @override
  Future<String> ensureDeviceId() async => 'device-1';

  @override
  Future<void> clearSession() async {
    session = null;
  }

  @override
  Future<void> clearAll() async {
    session = null;
  }
}
