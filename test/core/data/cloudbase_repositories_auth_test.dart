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
      final CloudBaseAuthRepository repository = _buildRepository(
        MockClient((http.Request request) async {
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
      );

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
      final CloudBaseAuthRepository repository = _buildRepository(
        MockClient((http.Request request) async {
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
      );

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
}

CloudBaseAuthRepository _buildRepository(http.Client httpClient) {
  const AppEnvironment environment = AppEnvironment(
    target: AppBackendTarget.production,
    appIdPrefix: 'com.dormsleep.app',
    cloudbaseEnvId: 'demo-env',
    cloudbaseAuthBaseUrl: 'https://example.com',
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
  );
  final CloudBaseSnapshotStore snapshotStore = CloudBaseSnapshotStore(
    appApiClient: appApiClient,
  );
  return CloudBaseAuthRepository(
    environment: environment,
    authClient: authClient,
    appApiClient: appApiClient,
    sessionStore: sessionStore,
    snapshotStore: snapshotStore,
  );
}

class _FakeSessionStore extends CloudBaseSessionStore {
  _FakeSessionStore();

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
