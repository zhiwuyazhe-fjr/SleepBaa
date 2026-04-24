import 'dart:async';
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

class CloudBaseSseFrame {
  const CloudBaseSseFrame({required this.event, required this.data});

  final String event;
  final String data;
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
  Future<CloudBaseSession>? _sessionRefreshInFlight;

  bool get isConfigured => _environment.hasCloudBaseAppApi;

  Future<Map<String, dynamic>> bootstrap() {
    return post('/api/app/bootstrap', body: const <String, dynamic>{});
  }

  Future<CloudBaseSession> refreshSession(
    CloudBaseSession existing, {
    bool force = false,
  }) {
    return _refreshSession(existing, force: force);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic> body = const <String, dynamic>{},
  }) async {
    final Map<String, dynamic> normalizedBody = _normalizeJsonMap(body);
    CloudBaseSession session = await _requireSession();
    http.Response response = await _sendJsonPost(
      path,
      session: session,
      body: normalizedBody,
    );

    if (response.statusCode == 401 && session.refreshToken.isNotEmpty) {
      session = await _recoverUnauthorizedSession(session);
      response = await _sendJsonPost(
        path,
        session: session,
        body: normalizedBody,
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

  Future<Stream<CloudBaseSseFrame>> postSse(
    String path, {
    Map<String, dynamic> body = const <String, dynamic>{},
  }) async {
    final Map<String, dynamic> normalizedBody = _normalizeJsonMap(body);
    CloudBaseSession session = await _requireSession();
    http.StreamedResponse response = await _sendStreamPost(
      path,
      session: session,
      body: normalizedBody,
    );

    if (response.statusCode == 401 && session.refreshToken.isNotEmpty) {
      session = await _recoverUnauthorizedSession(session);
      response = await _sendStreamPost(
        path,
        session: session,
        body: normalizedBody,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String bodyText = await response.stream.bytesToString();
      final Map<String, dynamic> payload = _decodeApiPayload(bodyText);
      throw CloudBaseAppApiException(
        message:
            payload['message'] as String? ??
            payload['error'] as String? ??
            'CloudBase app API SSE request failed.',
        statusCode: response.statusCode,
        code: payload['code'] as String?,
        body: payload,
      );
    }

    return _parseSseFrames(response.stream);
  }

  Future<http.Response> _sendJsonPost(
    String path, {
    required CloudBaseSession session,
    required Map<String, dynamic> body,
  }) {
    return _httpClient.post(
      _uri(path),
      headers: _headers(session.accessToken, session.deviceId),
      body: jsonEncode(body),
    );
  }

  Future<http.StreamedResponse> _sendStreamPost(
    String path, {
    required CloudBaseSession session,
    required Map<String, dynamic> body,
  }) {
    final http.Request request = http.Request('POST', _uri(path));
    request.headers.addAll(_headers(session.accessToken, session.deviceId));
    request.headers['Connection'] = 'close';
    request.persistentConnection = false;
    request.body = jsonEncode(body);
    return _httpClient.send(request);
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

  Future<CloudBaseSession> _recoverUnauthorizedSession(
    CloudBaseSession requestSession,
  ) async {
    final CloudBaseSession? latest = await _sessionStore.readSession();
    if (latest != null &&
        latest.accessToken != requestSession.accessToken &&
        !latest.isExpired) {
      return latest;
    }
    return _refreshSession(latest ?? requestSession, force: true);
  }

  Future<CloudBaseSession> _refreshSession(
    CloudBaseSession existing, {
    bool force = false,
  }) async {
    final Future<CloudBaseSession>? inFlight = _sessionRefreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final Future<CloudBaseSession> refreshFuture = Future<CloudBaseSession>(
      () async {
        final CloudBaseSession? latest = await _sessionStore.readSession();
        final CloudBaseSession candidate = latest ?? existing;
        if (!force && !candidate.isExpired) {
          return candidate;
        }
        return _performSessionRefresh(candidate);
      },
    );
    _sessionRefreshInFlight = refreshFuture;
    try {
      return await refreshFuture;
    } finally {
      if (identical(_sessionRefreshInFlight, refreshFuture)) {
        _sessionRefreshInFlight = null;
      }
    }
  }

  Future<CloudBaseSession> _performSessionRefresh(
    CloudBaseSession existing,
  ) async {
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
      'Accept': 'application/json, text/event-stream',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
      'x-device-id': deviceId,
    };
  }
}

Stream<CloudBaseSseFrame> _parseSseFrames(Stream<List<int>> source) async* {
  String? eventName;
  final List<String> dataLines = <String>[];

  await for (final String line
      in utf8.decoder.bind(source).transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (eventName != null || dataLines.isNotEmpty) {
        yield CloudBaseSseFrame(
          event: eventName ?? 'message',
          data: dataLines.join('\n'),
        );
        eventName = null;
        dataLines.clear();
      }
      continue;
    }
    if (line.startsWith('event:')) {
      eventName = line.substring('event:'.length).trim();
      continue;
    }
    if (line.startsWith('data:')) {
      dataLines.add(line.substring('data:'.length).trimLeft());
    }
  }

  if (eventName != null || dataLines.isNotEmpty) {
    yield CloudBaseSseFrame(
      event: eventName ?? 'message',
      data: dataLines.join('\n'),
    );
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

Map<String, dynamic> _normalizeJsonMap(Map<String, dynamic> value) {
  return <String, dynamic>{
    for (final MapEntry<String, dynamic> entry in value.entries)
      entry.key: _normalizeJsonValue(entry.value),
  };
}

dynamic _normalizeJsonValue(dynamic value) {
  if (value == null || value is num || value is bool || value is String) {
    return value;
  }
  if (value is DateTime) {
    return value.toIso8601String();
  }
  if (value is Map) {
    return <String, dynamic>{
      for (final MapEntry<dynamic, dynamic> entry in value.entries)
        entry.key.toString(): _normalizeJsonValue(entry.value),
    };
  }
  if (value is Iterable) {
    return value.map(_normalizeJsonValue).toList(growable: false);
  }
  return value;
}
