import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sleep_dorm_app/core/backend/app_environment.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_auth_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_session_store.dart';

class CloudBaseAppApiException implements Exception {
  const CloudBaseAppApiException({
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
    return 'CloudBaseAppApiException$status$remoteCode: $message';
  }
}

class CloudBaseAppApiClient {
  CloudBaseAppApiClient({
    required AppEnvironment environment,
    required CloudBaseSessionStore sessionStore,
    required CloudBaseAuthClient authClient,
    http.Client? httpClient,
  }) : _environment = environment,
       _sessionStore = sessionStore,
       _authClient = authClient,
       _httpClient = httpClient ?? http.Client();

  final AppEnvironment _environment;
  final CloudBaseSessionStore _sessionStore;
  final CloudBaseAuthClient _authClient;
  final http.Client _httpClient;

  bool get isConfigured => _environment.hasCloudBaseAppApi;

  Future<Map<String, dynamic>> bootstrap() {
    return post('/api/app/bootstrap', body: const <String, dynamic>{});
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic> body = const <String, dynamic>{},
  }) async {
    CloudBaseSession session = await _requireSession();
    http.Response response = await _httpClient.post(
      _uri(path),
      headers: _headers(session.accessToken, session.deviceId),
      body: jsonEncode(body),
    );

    if (response.statusCode == 401 && session.refreshToken.isNotEmpty) {
      session = await _refreshSession(session);
      response = await _httpClient.post(
        _uri(path),
        headers: _headers(session.accessToken, session.deviceId),
        body: jsonEncode(body),
      );
    }

    final Map<String, dynamic> payload = _decodeApiPayload(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudBaseAppApiException(
        message:
            payload['message'] as String? ??
            payload['error'] as String? ??
            'CloudBase app API request failed.',
        statusCode: response.statusCode,
        code: payload['code'] as String?,
        body: payload,
      );
    }
    return payload;
  }

  Future<CloudBaseSession> _requireSession() async {
    if (!_environment.hasCloudBaseAppApi) {
      throw const CloudBaseAppApiException(
        message: 'CloudBase app API base URL is missing.',
      );
    }
    final CloudBaseSession? existing = await _sessionStore.readSession();
    if (existing == null) {
      throw const CloudBaseAppApiException(
        message: 'CloudBase session is missing. Authenticate first.',
      );
    }
    if (!existing.isExpired) {
      return existing;
    }
    return _refreshSession(existing);
  }

  Future<CloudBaseSession> _refreshSession(CloudBaseSession existing) async {
    final CloudBaseAuthTokenResponse refreshed = await _authClient
        .refreshAccessToken(
          refreshToken: existing.refreshToken,
          deviceId: existing.deviceId,
        );
    final CloudBaseSession next = existing.copyWith(
      accessToken: refreshed.accessToken,
      refreshToken: refreshed.refreshToken,
      subject: refreshed.subject,
      scope: refreshed.scope,
      tokenType: refreshed.tokenType,
      expiresAt: DateTime.now().add(Duration(seconds: refreshed.expiresIn)),
    );
    await _sessionStore.writeSession(next);
    return next;
  }

  Uri _uri(String path) {
    final String baseUrl = _environment.cloudbaseAppApiBaseUrl!;
    final String normalizedBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return Uri.parse(normalizedBase).resolve(_stripLeadingSlash(path));
  }

  Map<String, String> _headers(String accessToken, String deviceId) {
    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
      'x-device-id': deviceId,
    };
  }
}

Map<String, dynamic> _decodeApiPayload(String body) {
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
  return <String, dynamic>{'data': decoded};
}

String _stripLeadingSlash(String value) {
  return value.startsWith('/') ? value.substring(1) : value;
}
