import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sleep_dorm_app/core/backend/app_environment.dart';

String normalizeCloudBasePhoneNumber(
  String phoneNumber, {
  String defaultCountryCode = '+86',
}) {
  final String trimmed = phoneNumber.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final String normalized = trimmed.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (RegExp(r'^\+[1-9][0-9]{0,3}\s[0-9]{4,20}$').hasMatch(normalized)) {
    return normalized;
  }

  final RegExpMatch? explicitCountryCode = RegExp(
    r'^\+([1-9][0-9]{0,3})[- ]([0-9]{4,20})$',
  ).firstMatch(normalized);
  if (explicitCountryCode != null) {
    return '+${explicitCountryCode.group(1)} ${explicitCountryCode.group(2)}';
  }

  final String digitsOnly = normalized.replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.isEmpty) {
    return normalized;
  }

  final String normalizedCountryCode = defaultCountryCode.startsWith('+')
      ? defaultCountryCode
      : '+$defaultCountryCode';
  final String countryDigits = normalizedCountryCode.replaceAll('+', '');

  if (digitsOnly.startsWith(countryDigits) &&
      digitsOnly.length > countryDigits.length + 3) {
    return '$normalizedCountryCode ${digitsOnly.substring(countryDigits.length)}';
  }

  return '$normalizedCountryCode $digitsOnly';
}

class CloudBaseAuthException implements Exception {
  const CloudBaseAuthException({
    required this.message,
    this.statusCode,
    this.code,
    this.body,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, dynamic>? body;

  @override
  String toString() {
    final String status = statusCode == null ? '' : ' [$statusCode]';
    final String remoteCode = code == null ? '' : ' {$code}';
    return 'CloudBaseAuthException$status$remoteCode: $message';
  }
}

class CloudBaseAuthTokenResponse {
  const CloudBaseAuthTokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.subject,
    this.scope,
    this.tokenType = 'Bearer',
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String subject;
  final String? scope;
  final String tokenType;
}

class CloudBasePhoneVerificationStart {
  const CloudBasePhoneVerificationStart({
    required this.verificationId,
    required this.expiresIn,
    required this.isUser,
  });

  final String verificationId;
  final int expiresIn;
  final bool isUser;
}

class CloudBasePhoneVerificationResult {
  const CloudBasePhoneVerificationResult({
    required this.verificationToken,
    required this.expiresIn,
  });

  final String verificationToken;
  final int expiresIn;
}

class CloudBaseUserInfo {
  const CloudBaseUserInfo({
    required this.subject,
    this.name,
    this.picture,
    this.phoneNumber,
  });

  final String subject;
  final String? name;
  final String? picture;
  final String? phoneNumber;
}

class CloudBaseAuthClient {
  CloudBaseAuthClient({
    required AppEnvironment environment,
    http.Client? httpClient,
  }) : _environment = environment,
       _httpClient = httpClient ?? http.Client();

  final AppEnvironment _environment;
  final http.Client _httpClient;

  Future<CloudBaseAuthTokenResponse> signInAnonymously({
    required String deviceId,
  }) async {
    final Map<String, dynamic> data = await _send(
      method: 'POST',
      path: '/auth/v1/signin/anonymously',
      deviceId: deviceId,
      body: const <String, dynamic>{},
      includePublishableKey: true,
    );
    return _tokenFromMap(data);
  }

  Future<CloudBasePhoneVerificationStart> sendPhoneVerificationCode({
    required String phoneNumber,
    String target = 'ANY',
    String? deviceId,
  }) async {
    final String normalizedPhoneNumber = normalizeCloudBasePhoneNumber(
      phoneNumber,
    );
    final Map<String, dynamic> data = await _send(
      method: 'POST',
      path: '/auth/v1/verification',
      deviceId: deviceId,
      body: <String, dynamic>{
        'phone_number': normalizedPhoneNumber,
        'target': target,
      },
      includePublishableKey: true,
    );
    return CloudBasePhoneVerificationStart(
      verificationId: data['verification_id'] as String? ?? '',
      expiresIn: (data['expires_in'] as num?)?.toInt() ?? 600,
      isUser: data['is_user'] as bool? ?? false,
    );
  }

  Future<CloudBasePhoneVerificationResult> verifyPhoneCode({
    required String verificationId,
    required String code,
    String? deviceId,
  }) async {
    final Map<String, dynamic> data = await _send(
      method: 'POST',
      path: '/auth/v1/verification/verify',
      deviceId: deviceId,
      body: <String, dynamic>{
        'verification_id': verificationId,
        'verification_code': code,
      },
      includePublishableKey: true,
    );
    return CloudBasePhoneVerificationResult(
      verificationToken: data['verification_token'] as String? ?? '',
      expiresIn: (data['expires_in'] as num?)?.toInt() ?? 600,
    );
  }

  Future<CloudBaseAuthTokenResponse> signInWithVerificationToken({
    required String verificationToken,
    String? deviceId,
  }) async {
    final Map<String, dynamic> data = await _send(
      method: 'POST',
      path: '/auth/v1/signin',
      deviceId: deviceId,
      body: <String, dynamic>{'verification_token': verificationToken},
      includePublishableKey: true,
    );
    return _tokenFromMap(data);
  }

  Future<CloudBaseAuthTokenResponse> signUpWithVerificationToken({
    required String verificationToken,
    String? deviceId,
  }) async {
    final Map<String, dynamic> data = await _send(
      method: 'POST',
      path: '/auth/v1/signup',
      deviceId: deviceId,
      body: <String, dynamic>{'verification_token': verificationToken},
      includePublishableKey: true,
    );
    return _tokenFromMap(data);
  }

  Future<CloudBaseAuthTokenResponse> refreshAccessToken({
    required String refreshToken,
    String? deviceId,
  }) async {
    final Map<String, dynamic> data = await _send(
      method: 'POST',
      path: '/auth/v1/token',
      deviceId: deviceId,
      body: <String, dynamic>{
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      },
      includePublishableKey: true,
    );
    return _tokenFromMap(data);
  }

  Future<CloudBaseUserInfo> getCurrentUser({
    required String accessToken,
    String? deviceId,
  }) async {
    final Map<String, dynamic> data = await _send(
      method: 'GET',
      path: '/auth/v1/user/me',
      accessToken: accessToken,
      deviceId: deviceId,
    );
    return CloudBaseUserInfo(
      subject:
          data['sub'] as String? ??
          data['user_id'] as String? ??
          data['id'] as String? ??
          '',
      name: data['name'] as String? ?? data['username'] as String?,
      picture: data['picture'] as String?,
      phoneNumber: data['phone_number'] as String?,
    );
  }

  Future<Map<String, dynamic>> _send({
    required String method,
    required String path,
    String? accessToken,
    String? deviceId,
    Map<String, dynamic>? body,
    bool includePublishableKey = false,
  }) async {
    final String? baseUrl = _environment.cloudbaseAuthBaseUrl;
    if (baseUrl == null || baseUrl.isEmpty) {
      throw const CloudBaseAuthException(
        message: 'CloudBase auth base URL is missing.',
      );
    }
    final Uri uri = Uri.parse(baseUrl).resolve(_stripLeadingSlash(path));
    final Map<String, String> headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (deviceId != null && deviceId.isNotEmpty) 'x-device-id': deviceId,
      if (_environment.cloudbaseClientId?.isNotEmpty ?? false)
        'x-cloudbase-client-id': _environment.cloudbaseClientId!,
    };
    final String? authorization =
        accessToken ??
        (includePublishableKey ? _environment.cloudbasePublishableKey : null);
    if (authorization != null && authorization.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authorization';
    }

    late final http.Response response;
    switch (method) {
      case 'GET':
        response = await _httpClient.get(uri, headers: headers);
      case 'POST':
        response = await _httpClient.post(
          uri,
          headers: headers,
          body: jsonEncode(body ?? const <String, dynamic>{}),
        );
      default:
        throw CloudBaseAuthException(
          message: 'Unsupported auth method: $method',
        );
    }

    final Map<String, dynamic> payload = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudBaseAuthException(
        message:
            payload['error_description'] as String? ??
            payload['message'] as String? ??
            'CloudBase auth request failed.',
        statusCode: response.statusCode,
        code: payload['error'] as String? ?? payload['code'] as String?,
        body: payload,
      );
    }
    return payload;
  }

  CloudBaseAuthTokenResponse _tokenFromMap(Map<String, dynamic> map) {
    return CloudBaseAuthTokenResponse(
      accessToken: map['access_token'] as String? ?? '',
      refreshToken: map['refresh_token'] as String? ?? '',
      expiresIn: (map['expires_in'] as num?)?.toInt() ?? 7200,
      subject:
          map['sub'] as String? ??
          map['user_id'] as String? ??
          map['id'] as String? ??
          '',
      scope: map['scope'] as String?,
      tokenType: map['token_type'] as String? ?? 'Bearer',
    );
  }
}

Map<String, dynamic> _decode(String body) {
  if (body.trim().isEmpty) {
    return <String, dynamic>{};
  }
  final Object? decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  if (decoded is Map) {
    return Map<String, dynamic>.from(decoded);
  }
  return <String, dynamic>{};
}

String _stripLeadingSlash(String value) {
  return value.startsWith('/') ? value.substring(1) : value;
}
