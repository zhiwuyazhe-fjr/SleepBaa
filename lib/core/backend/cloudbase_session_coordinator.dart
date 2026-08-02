import 'dart:async';

import 'package:sleep_dorm_app/core/backend/cloudbase_auth_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_session_store.dart';

class CloudBaseSessionMissingException implements Exception {
  const CloudBaseSessionMissingException();

  @override
  String toString() => 'CloudBase session is missing.';
}

/// Single owner for the complete access/refresh-token lifecycle.
///
/// Token failures never delete durable account or session data. Only
/// [signOut] is allowed to remove the stored session.
class CloudBaseSessionCoordinator {
  CloudBaseSessionCoordinator({
    required CloudBaseSessionStore sessionStore,
    required CloudBaseAuthClient authClient,
    DateTime Function()? clock,
    Duration refreshAhead = const Duration(minutes: 5),
    List<Duration> concurrentRefreshBackoff = const <Duration>[
      Duration(milliseconds: 50),
      Duration(milliseconds: 150),
      Duration(milliseconds: 350),
      Duration(milliseconds: 800),
    ],
  }) : _sessionStore = sessionStore,
       _authClient = authClient,
       _clock = clock ?? DateTime.now,
       _refreshAhead = refreshAhead,
       _concurrentRefreshBackoff = concurrentRefreshBackoff;

  final CloudBaseSessionStore _sessionStore;
  final CloudBaseAuthClient _authClient;
  final DateTime Function() _clock;
  final Duration _refreshAhead;
  final List<Duration> _concurrentRefreshBackoff;

  CloudBaseSession? _currentSession;
  Future<CloudBaseSession>? _refreshInFlight;

  CloudBaseSessionStore get sessionStore => _sessionStore;

  Future<String> ensureDeviceId() => _sessionStore.ensureDeviceId();

  Future<CloudBaseSession?> restoreSession() async {
    final CloudBaseSession? durable = await _sessionStore
        .readPersistedSession();
    if (durable != null) {
      _currentSession = durable;
    }
    return durable ?? _currentSession;
  }

  Future<void> installSession(CloudBaseSession session) async {
    await _sessionStore.writeSession(session);
    _currentSession = await _sessionStore.readSession() ?? session;
  }

  Future<CloudBaseSession> requireFreshSession({bool force = false}) async {
    final CloudBaseSession? session = await restoreSession();
    if (session == null) {
      throw const CloudBaseSessionMissingException();
    }
    return refreshSession(session, force: force);
  }

  Future<CloudBaseSession> refreshSession(
    CloudBaseSession existing, {
    bool force = false,
  }) async {
    final Future<CloudBaseSession>? inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final Future<CloudBaseSession> refreshFuture = _refresh(
      existing,
      force: force,
    );
    _refreshInFlight = refreshFuture;
    try {
      return await refreshFuture;
    } finally {
      if (identical(_refreshInFlight, refreshFuture)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<CloudBaseSession> _refresh(
    CloudBaseSession existing, {
    required bool force,
  }) async {
    final CloudBaseSession candidate = await restoreSession() ?? existing;
    final bool changed = !_sameTokens(candidate, existing);
    if (changed && !_needsRefresh(candidate)) {
      return candidate;
    }
    if (!force && !_needsRefresh(candidate)) {
      return candidate;
    }

    late final CloudBaseAuthTokenResponse refreshed;
    try {
      refreshed = await _authClient.refreshAccessToken(
        refreshToken: candidate.refreshToken,
        deviceId: candidate.deviceId,
      );
    } on CloudBaseAuthException catch (error) {
      if (_isRefreshTokenRejected(error)) {
        final CloudBaseSession? recovered = await _waitForRotatedSession(
          candidate,
        );
        if (recovered != null) {
          return recovered;
        }
      }
      rethrow;
    }

    final String accessToken = refreshed.accessToken.trim();
    if (accessToken.isEmpty) {
      throw const CloudBaseAuthException(
        message: 'CloudBase refresh response did not include an access token.',
      );
    }
    final int expiresIn = refreshed.expiresIn > 0 ? refreshed.expiresIn : 7200;
    final CloudBaseSession next = candidate.copyWith(
      accessToken: accessToken,
      refreshToken: refreshed.refreshToken.trim().isEmpty
          ? candidate.refreshToken
          : refreshed.refreshToken.trim(),
      subject: refreshed.subject.trim().isEmpty
          ? candidate.subject
          : refreshed.subject.trim(),
      scope: refreshed.scope ?? candidate.scope,
      tokenType: refreshed.tokenType.trim().isEmpty
          ? candidate.tokenType
          : refreshed.tokenType.trim(),
      expiresAt: _clock().add(Duration(seconds: expiresIn)),
    );
    await installSession(next);
    return _currentSession ?? next;
  }

  Future<CloudBaseSession?> _waitForRotatedSession(
    CloudBaseSession failed,
  ) async {
    for (final Duration delay in _concurrentRefreshBackoff) {
      await Future<void>.delayed(delay);
      final CloudBaseSession? latest = await restoreSession();
      if (latest != null &&
          !_sameTokens(latest, failed) &&
          !_isAccessTokenExpired(latest)) {
        return latest;
      }
    }
    return null;
  }

  bool _needsRefresh(CloudBaseSession session) {
    return !_clock().isBefore(session.expiresAt.subtract(_refreshAhead));
  }

  bool _isAccessTokenExpired(CloudBaseSession session) {
    return !_clock().isBefore(session.expiresAt);
  }

  bool _sameTokens(CloudBaseSession a, CloudBaseSession b) {
    return a.accessToken == b.accessToken &&
        a.refreshToken == b.refreshToken &&
        a.subject == b.subject;
  }

  Future<void> signOut() async {
    _currentSession = null;
    await _sessionStore.clearSession();
  }
}

bool _isRefreshTokenRejected(CloudBaseAuthException error) {
  final String details = <String>[
    error.code ?? '',
    error.message,
    error.body?['code']?.toString() ?? '',
    error.body?['message']?.toString() ?? '',
    error.body?['error']?.toString() ?? '',
    error.body?['error_description']?.toString() ?? '',
  ].join(' ').toLowerCase();
  return details.contains('invalid_grant') ||
      details.contains('token hash not match') ||
      details.contains('invalid refresh token') ||
      details.contains('refresh token expired') ||
      details.contains('refresh_token_expired') ||
      details.contains('token_revoked');
}
