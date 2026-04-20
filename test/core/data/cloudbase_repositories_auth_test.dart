import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sleep_dorm_app/core/backend/app_environment.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_app_api_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_auth_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_session_store.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_snapshot_store.dart';
import 'package:sleep_dorm_app/core/data/cloudbase_repositories.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

void main() {
  test(
    'cloudbase auth repository reroutes registered phones away from signup send-code',
    () async {
      final CloudBaseAuthRepository repository = _buildHarness(
        MockClient((http.Request request) async {
          if (request.url.path == '/auth/v1/user/me') {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'sub': 'tester',
                'name': 'Tester',
                'phone_number': '+86 13800138000',
              }),
              200,
            );
          }
          final Map<String, dynamic> body =
              jsonDecode(request.body) as Map<String, dynamic>;
          expect(request.url.path, '/auth/v1/verification');
          expect(body['target'], 'NOT_USER');
          expect(body['phone_number'], '+86 13800138000');
          return http.Response(
            jsonEncode(<String, dynamic>{
              'verification_id': 'verification-id',
              'expires_in': 600,
              'is_user': true,
            }),
            200,
          );
        }),
      ).repository;

      await expectLater(
        repository.sendPhoneVerificationCode(
          '13800138000',
          target: PhoneVerificationTarget.newUser,
        ),
        throwsA(
          isA<AuthPhoneTargetMismatchException>().having(
            (AuthPhoneTargetMismatchException error) => error.message,
            'message',
            '该手机号已注册，请直接登录。',
          ),
        ),
      );

      expect(repository.lastAuthError, '该手机号已注册，请直接登录。');
    },
  );

  test(
    'cloudbase auth repository reroutes unknown phones away from login send-code',
    () async {
      final CloudBaseAuthRepository repository = _buildHarness(
        MockClient((http.Request request) async {
          if (request.url.path == '/auth/v1/user/me') {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'sub': 'tester',
                'name': 'Tester',
                'phone_number': '+86 13900139000',
              }),
              200,
            );
          }
          final Map<String, dynamic> body =
              jsonDecode(request.body) as Map<String, dynamic>;
          expect(request.url.path, '/auth/v1/verification');
          expect(body['target'], 'USER');
          expect(body['phone_number'], '+86 13900139000');
          return http.Response(
            jsonEncode(<String, dynamic>{
              'verification_id': 'verification-id',
              'expires_in': 600,
              'is_user': false,
            }),
            200,
          );
        }),
      ).repository;

      await expectLater(
        repository.sendPhoneVerificationCode(
          '13900139000',
          target: PhoneVerificationTarget.existingUser,
        ),
        throwsA(
          isA<AuthPhoneTargetMismatchException>().having(
            (AuthPhoneTargetMismatchException error) => error.message,
            'message',
            '未找到该手机号，请先注册。',
          ),
        ),
      );

      expect(repository.lastAuthError, '未找到该手机号，请先注册。');
    },
  );

  test(
    'ensureAuthenticated keeps session when snapshot refresh fails transiently',
    () async {
      int bootstrapCalls = 0;
      int userMeCalls = 0;
      final _AuthHarness harness = _buildHarness(
        MockClient((http.Request request) async {
          if (request.url.path == '/auth/v1/user/me') {
            userMeCalls += 1;
            return http.Response(
              jsonEncode(<String, dynamic>{
                'sub': 'tester',
                'name': 'Tester',
                'phone_number': '+86 13800138000',
              }),
              200,
            );
          }
          if (request.url.path == '/api/app/bootstrap') {
            bootstrapCalls += 1;
            // First bootstrap succeeds, second one simulates a transient 503.
            if (bootstrapCalls >= 2) {
              return http.Response('service unavailable', 503);
            }
            return http.Response(
              jsonEncode(<String, dynamic>{
                'user': <String, dynamic>{
                  'uid': 'tester',
                  'displayName': 'Tester',
                  'tagline': 'tagline',
                  'role': 'role',
                  'phoneNumber': '+86 13800138000',
                  'phoneLinkedAt': DateTime.now().toIso8601String(),
                  'showDormPulseBadge': true,
                },
              }),
              200,
            );
          }
          throw StateError('Unexpected path: ${request.url.path}');
        }),
      );
      final CloudBaseAuthRepository repository = harness.repository;

      // Initial bootstrap establishes a verified session.
      await repository.ensureAuthenticated();
      expect(repository.hasVerifiedPhoneIdentity, isTrue);
      expect(repository.currentUser.phoneNumber, '+86 13800138000');
      expect(repository.lastAuthError, isNull);

      // A subsequent ensureAuthenticated should short-circuit via the
      // revalidation window and not trigger an additional user/bootstrap hit.
      await repository.ensureAuthenticated();
      expect(bootstrapCalls, 1);
      expect(userMeCalls, 1);

      // Forcing a revalidation hits the failing snapshot endpoint, but must
      // keep the existing session intact and only surface a soft warning.
      await repository.retryAuthentication();
      expect(repository.hasVerifiedPhoneIdentity, isTrue);
      expect(repository.currentUser.phoneNumber, '+86 13800138000');
      expect(repository.lastAuthError, isNotNull);
      expect(bootstrapCalls, greaterThanOrEqualTo(2));
    },
  );

  test(
    'ensureAuthenticated clears session when refresh token is rejected with 401',
    () async {
      final _FakeSessionStore sessionStore = _FakeSessionStore();
      sessionStore._session = CloudBaseSession(
        accessToken: 'stale-access',
        refreshToken: 'stale-refresh',
        subject: 'tester',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
        deviceId: 'test-device-id',
      );
      const AppEnvironment environment = AppEnvironment(
        target: AppBackendTarget.production,
        appIdPrefix: 'com.dormsleep.app',
        cloudbaseEnvId: 'demo-env',
        cloudbaseAuthBaseUrl: 'https://example.com',
        cloudbaseAppApiBaseUrl: 'https://example.com',
        cloudbasePublishableKey: 'publishable-key',
        cloudbaseClientId: 'demo-env',
      );
      final http.Client httpClient = MockClient((http.Request request) async {
        if (request.url.path == '/auth/v1/token') {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'error': 'invalid_grant',
              'error_description': 'refresh token expired',
            }),
            401,
          );
        }
        throw StateError('Unexpected path: ${request.url.path}');
      });
      final CloudBaseAuthClient authClient = CloudBaseAuthClient(
        environment: environment,
        httpClient: httpClient,
      );
      final CloudBaseAppApiClient appApiClient = CloudBaseAppApiClient(
        environment: environment,
        sessionStore: sessionStore,
        authClient: authClient,
        httpClient: httpClient,
      );
      final CloudBaseSnapshotStore snapshotStore = CloudBaseSnapshotStore(
        appApiClient: appApiClient,
      );
      final CloudBaseAuthRepository repository = CloudBaseAuthRepository(
        environment: environment,
        authClient: authClient,
        appApiClient: appApiClient,
        sessionStore: sessionStore,
        snapshotStore: snapshotStore,
      );

      await repository.ensureAuthenticated();

      expect(repository.hasVerifiedPhoneIdentity, isFalse);
      expect(repository.isAuthenticated, isFalse);
      expect(sessionStore._session, isNull);
      expect(repository.lastAuthError, contains('登录状态已失效'));
    },
  );

  test(
    'ensureAuthenticated reuses the same in-flight authentication work',
    () async {
      final Completer<void> refreshGate = Completer<void>();
      int refreshCalls = 0;
      int userMeCalls = 0;
      int bootstrapCalls = 0;
      final _AuthHarness harness = _buildHarness(
        MockClient((http.Request request) async {
          if (request.url.path == '/auth/v1/token') {
            refreshCalls += 1;
            await refreshGate.future;
            return http.Response(
              jsonEncode(<String, dynamic>{
                'access_token': 'fresh-access',
                'refresh_token': 'fresh-refresh',
                'sub': 'tester',
                'expires_in': 7200,
                'token_type': 'Bearer',
              }),
              200,
            );
          }
          if (request.url.path == '/auth/v1/user/me') {
            userMeCalls += 1;
            expect(
              request.headers['authorization'] ??
                  request.headers['Authorization'],
              'Bearer fresh-access',
            );
            return http.Response(
              jsonEncode(<String, dynamic>{
                'sub': 'tester',
                'name': 'Tester',
                'phone_number': '+86 13800138000',
              }),
              200,
            );
          }
          if (request.url.path == '/api/app/bootstrap') {
            bootstrapCalls += 1;
            expect(
              request.headers['authorization'] ??
                  request.headers['Authorization'],
              'Bearer fresh-access',
            );
            return http.Response(
              jsonEncode(<String, dynamic>{
                'user': <String, dynamic>{
                  'uid': 'tester',
                  'displayName': 'Tester',
                  'tagline': 'tagline',
                  'role': 'role',
                  'phoneNumber': '+86 13800138000',
                  'phoneLinkedAt': DateTime.now().toIso8601String(),
                  'showDormPulseBadge': true,
                },
              }),
              200,
            );
          }
          throw StateError('Unexpected path: ${request.url.path}');
        }),
      );
      harness.sessionStore._session = CloudBaseSession(
        accessToken: 'stale-access',
        refreshToken: 'stale-refresh',
        subject: 'tester',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
        deviceId: 'test-device-id',
      );
      final CloudBaseAuthRepository repository = harness.repository;

      final Future<UserProfile> first = repository.ensureAuthenticated();
      final Future<UserProfile> second = repository.ensureAuthenticated();

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(refreshCalls, 1);
      refreshGate.complete();

      final List<UserProfile> users = await Future.wait(<Future<UserProfile>>[
        first,
        second,
      ]);

      expect(users, hasLength(2));
      expect(users.first.uid, 'tester');
      expect(users.last.uid, 'tester');
      expect(refreshCalls, 1);
      expect(userMeCalls, 1);
      expect(bootstrapCalls, 1);
    },
  );

  test(
    'cloudbase auth repository keeps dorm badge visibility off after queued snapshot refresh',
    () async {
      final Completer<void> firstBootstrapCompleter = Completer<void>();
      int bootstrapCount = 0;
      final _AuthHarness harness = _buildHarness(
        MockClient((http.Request request) async {
          if (request.url.path == '/auth/v1/user/me') {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'sub': 'tester',
                'name': 'Tester',
                'phone_number': '+86 13800138000',
              }),
              200,
            );
          }
          if (request.url.path == '/api/app/bootstrap') {
            bootstrapCount += 1;
            if (bootstrapCount == 1) {
              await firstBootstrapCompleter.future;
              return http.Response(
                jsonEncode(<String, dynamic>{
                  'user': <String, dynamic>{
                    'uid': 'tester',
                    'displayName': 'Tester',
                    'tagline': 'tagline',
                    'role': 'role',
                    'showDormPulseBadge': true,
                  },
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode(<String, dynamic>{
                'user': <String, dynamic>{
                  'uid': 'tester',
                  'displayName': 'Tester',
                  'tagline': 'tagline',
                  'role': 'role',
                  'showDormPulseBadge': false,
                },
              }),
              200,
            );
          }
          if (request.url.path == '/api/profile/save') {
            final Map<String, dynamic> body =
                jsonDecode(request.body) as Map<String, dynamic>;
            expect(
              (body['profile'] as Map<String, dynamic>)['showDormPulseBadge'],
              isFalse,
            );
            return http.Response(
              jsonEncode(<String, dynamic>{'ok': true}),
              200,
            );
          }
          throw StateError('Unexpected path: ${request.url.path}');
        }),
      );
      final CloudBaseAuthRepository repository = harness.repository;
      final Future<void> backgroundRefresh = harness.snapshotStore.refresh();
      final Future<void> saveFuture = repository.updateDormBadgeVisibility(
        showDormPulseBadge: false,
      );

      firstBootstrapCompleter.complete();
      await backgroundRefresh;
      await saveFuture;

      expect(bootstrapCount, greaterThanOrEqualTo(2));
      expect(repository.currentUser.showDormPulseBadge, isFalse);
    },
  );

  test(
    'cloudbase auth repository maps invalid password sign-in to credential guidance',
    () async {
      final CloudBaseAuthRepository repository = _buildHarness(
        MockClient((http.Request request) async {
          if (request.url.path == '/auth/v1/signin') {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'error': 'invalid_credentials',
                'error_description': 'invalid credentials',
              }),
              401,
            );
          }
          throw StateError('Unexpected path: ${request.url.path}');
        }),
      ).repository;

      await expectLater(
        repository.signInWithPassword(
          phoneNumber: '13800138000',
          password: 'wrongpass',
        ),
        throwsA(
          isA<AuthFlowException>().having(
            (AuthFlowException error) => error.message,
            'message',
            '请检查手机号和密码。',
          ),
        ),
      );

      expect(repository.lastAuthError, '请检查手机号和密码。');
    },
  );

  test(
    'cloudbase auth repository maps signup send-code registered-phone errors to login guidance',
    () async {
      final CloudBaseAuthRepository repository = _buildHarness(
        MockClient((http.Request request) async {
          if (request.url.path == '/auth/v1/verification') {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'error': 'user_exists',
                'error_description': 'phone already registered',
              }),
              409,
            );
          }
          throw StateError('Unexpected path: ${request.url.path}');
        }),
      ).repository;

      await expectLater(
        repository.sendPhoneVerificationCode(
          '13800138000',
          target: PhoneVerificationTarget.newUser,
        ),
        throwsA(
          isA<AuthPhoneTargetMismatchException>().having(
            (AuthPhoneTargetMismatchException error) => error.message,
            'message',
            '该手机号已注册，请直接登录。',
          ),
        ),
      );

      expect(repository.lastAuthError, '该手机号已注册，请直接登录。');
    },
  );
}

_AuthHarness _buildHarness(http.Client httpClient) {
  const AppEnvironment environment = AppEnvironment(
    target: AppBackendTarget.production,
    appIdPrefix: 'com.dormsleep.app',
    cloudbaseEnvId: 'demo-env',
    cloudbaseAuthBaseUrl: 'https://example.com',
    cloudbaseAppApiBaseUrl: 'https://example.com',
    cloudbasePublishableKey: 'publishable-key',
    cloudbaseClientId: 'demo-env',
  );
  final _FakeSessionStore sessionStore = _FakeSessionStore();
  final CloudBaseAuthClient authClient = CloudBaseAuthClient(
    environment: environment,
    httpClient: httpClient,
  );
  final CloudBaseAppApiClient appApiClient = CloudBaseAppApiClient(
    environment: environment,
    sessionStore: sessionStore,
    authClient: authClient,
    httpClient: httpClient,
  );
  final CloudBaseSnapshotStore snapshotStore = CloudBaseSnapshotStore(
    appApiClient: appApiClient,
  );
  return _AuthHarness(
    repository: CloudBaseAuthRepository(
      environment: environment,
      authClient: authClient,
      appApiClient: appApiClient,
      sessionStore: sessionStore,
      snapshotStore: snapshotStore,
    ),
    snapshotStore: snapshotStore,
    sessionStore: sessionStore,
  );
}

class _AuthHarness {
  const _AuthHarness({
    required this.repository,
    required this.snapshotStore,
    required this.sessionStore,
  });

  final CloudBaseAuthRepository repository;
  final CloudBaseSnapshotStore snapshotStore;
  final _FakeSessionStore sessionStore;
}

class _FakeSessionStore extends CloudBaseSessionStore {
  _FakeSessionStore()
    : _session = CloudBaseSession(
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        subject: 'tester',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        deviceId: 'test-device-id',
      );

  CloudBaseSession? _session;

  @override
  Future<String> ensureDeviceId() async => 'test-device-id';

  @override
  Future<CloudBaseSession?> readSession() async => _session;

  @override
  Future<void> writeSession(CloudBaseSession session) async {
    _session = session;
  }

  @override
  Future<void> clearSession() async {
    _session = null;
  }

  @override
  Future<void> clearAll() async {
    _session = null;
  }
}
