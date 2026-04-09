import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sleep_dorm_app/core/backend/app_environment.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_auth_client.dart';

void main() {
  group('normalizeCloudBasePhoneNumber', () {
    test('adds +86 prefix for mainland China numbers', () {
      expect(normalizeCloudBasePhoneNumber('13800138000'), '+86 13800138000');
    });

    test('keeps an already normalized phone number', () {
      expect(
        normalizeCloudBasePhoneNumber('+86 13800138000'),
        '+86 13800138000',
      );
    });

    test('normalizes explicit country code with dash separator', () {
      expect(
        normalizeCloudBasePhoneNumber('+86-13800138000'),
        '+86 13800138000',
      );
    });
  });

  test(
    'cloudBaseUsernameFromPhone builds a valid auth username from phone digits',
    () {
      expect(cloudBaseUsernameFromPhone('13800138000'), 'u8613800138000');
      expect(
        cloudBaseUsernameFromPhone('+86 13800138000'),
        'u8613800138000',
      );
    },
  );

  group('CloudBaseAuthClient request payloads', () {
    test('sign up sends phone number and initial password', () async {
      late Map<String, dynamic> body;
      final CloudBaseAuthClient client = CloudBaseAuthClient(
        environment: _environment,
        httpClient: MockClient((http.Request request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'access_token': 'access-token',
              'refresh_token': 'refresh-token',
              'expires_in': 7200,
              'sub': 'user-1',
            }),
            200,
          );
        }),
      );

      await client.signUpWithVerificationToken(
        phoneNumber: '13800138000',
        verificationToken: 'verification-token',
        password: 'secret123',
      );

      expect(body['phone_number'], '+86 13800138000');
      expect(body['username'], 'u8613800138000');
      expect(body['verification_token'], 'verification-token');
      expect(body['password'], 'secret123');
    });

    test(
      'verification sign in sends only verification token payload',
      () async {
        late Map<String, dynamic> body;
        final CloudBaseAuthClient client = CloudBaseAuthClient(
          environment: _environment,
          httpClient: MockClient((http.Request request) async {
            body = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode(<String, dynamic>{
                'access_token': 'access-token',
                'refresh_token': 'refresh-token',
                'expires_in': 7200,
                'sub': 'user-1',
              }),
              200,
            );
          }),
        );

        await client.signInWithVerificationToken(
          verificationToken: 'verification-token',
        );

        expect(body['verification_token'], 'verification-token');
        expect(body.containsKey('username'), isFalse);
      },
    );

    test('password sign in retries alternate phone payload shapes', () async {
      final List<Map<String, dynamic>> bodies = <Map<String, dynamic>>[];
      int callCount = 0;
      final CloudBaseAuthClient client = CloudBaseAuthClient(
        environment: _environment,
        httpClient: MockClient((http.Request request) async {
          callCount += 1;
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          if (callCount < 6) {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'error': 'invalid_credentials',
                'error_description': 'retry',
              }),
              400,
            );
          }
          return http.Response(
            jsonEncode(<String, dynamic>{
              'access_token': 'access-token',
              'refresh_token': 'refresh-token',
              'expires_in': 7200,
              'sub': 'user-1',
            }),
            200,
          );
        }),
      );

      await client.signInWithPassword(
        phoneNumber: '13800138000',
        password: 'secret123',
      );

      expect(callCount, 6);
      expect(bodies[0]['username'], 'u8613800138000');
      expect(bodies[1]['username'], '8613800138000');
      expect(bodies[2]['username'], '+8613800138000');
      expect(bodies[3]['username'], '+86 13800138000');
      expect(bodies[4]['phone_number'], '+86 13800138000');
      expect(bodies[5]['phone'], '+86 13800138000');
    });

    test(
      'reset password sends verification token and confirmed password',
      () async {
        late Map<String, dynamic> body;
        final CloudBaseAuthClient client = CloudBaseAuthClient(
          environment: _environment,
          httpClient: MockClient((http.Request request) async {
            body = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response('{}', 200);
          }),
        );

        await client.resetPasswordWithVerificationToken(
          phoneNumber: '13800138000',
          verificationToken: 'verification-token',
          newPassword: 'secret123',
        );

        expect(body['phone_number'], '+86 13800138000');
        expect(body['verification_token'], 'verification-token');
        expect(body['new_password'], 'secret123');
        expect(body['confirm_password'], 'secret123');
      },
    );

    test('send verification code forwards captcha token header', () async {
      late String? captchaHeader;
      final CloudBaseAuthClient client = CloudBaseAuthClient(
        environment: _environment,
        httpClient: MockClient((http.Request request) async {
          captchaHeader = request.headers['x-captcha-token'];
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

      await client.sendPhoneVerificationCode(
        phoneNumber: '13800138000',
        captchaToken: 'captcha-proof',
      );

      expect(captchaHeader, 'captcha-proof');
    });

    test(
      'verify captcha uses the official verify endpoint and key field',
      () async {
        late Uri uri;
        late Map<String, dynamic> body;
        final CloudBaseAuthClient client = CloudBaseAuthClient(
          environment: _environment,
          httpClient: MockClient((http.Request request) async {
            uri = request.url;
            body = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode(<String, dynamic>{'captcha_token': 'captcha-proof'}),
              200,
            );
          }),
        );

        final String token = await client.verifyCaptchaChallenge(
          token: 'captcha-token',
          code: 'abcd',
        );

        expect(uri.path, '/auth/v1/captcha/data/verify');
        expect(body['token'], 'captcha-token');
        expect(body['key'], 'abcd');
        expect(token, 'captcha-proof');
      },
    );
  });
}

const AppEnvironment _environment = AppEnvironment(
  target: AppBackendTarget.production,
  appIdPrefix: 'com.dormsleep.app',
  cloudbaseEnvId: 'demo-env',
  cloudbaseAuthBaseUrl: 'https://example.com',
  cloudbasePublishableKey: 'publishable-key',
  cloudbaseClientId: 'demo-env',
);
