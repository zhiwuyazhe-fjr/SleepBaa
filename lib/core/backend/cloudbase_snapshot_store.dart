import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_app_api_client.dart';

class CloudBaseSnapshotStore extends ChangeNotifier {
  CloudBaseSnapshotStore({required CloudBaseAppApiClient appApiClient})
    : _appApiClient = appApiClient;

  final CloudBaseAppApiClient _appApiClient;

  Map<String, dynamic> _payload = <String, dynamic>{};
  bool _isRefreshing = false;
  String? _lastError;
  bool _refreshQueued = false;
  Future<void>? _refreshFuture;

  Map<String, dynamic> get payload => _payload;
  bool get isRefreshing => _isRefreshing;
  String? get lastError => _lastError;
  bool get hasPayload => _payload.isNotEmpty;

  Future<void> refresh() async {
    if (!_appApiClient.isConfigured) {
      return;
    }
    final Future<void>? inFlightRefresh = _refreshFuture;
    if (inFlightRefresh != null) {
      _refreshQueued = true;
      await inFlightRefresh;
      return;
    }

    final Completer<void> refreshCompleter = Completer<void>();
    final Future<void> refreshFuture = refreshCompleter.future;
    _refreshFuture = refreshFuture;
    try {
      await _runRefreshLoop();
      refreshCompleter.complete();
    } catch (error, stackTrace) {
      refreshCompleter.completeError(error, stackTrace);
      rethrow;
    } finally {
      _refreshFuture = null;
    }
    await refreshFuture;
  }

  Future<void> _runRefreshLoop() async {
    do {
      _refreshQueued = false;
      _isRefreshing = true;
      _lastError = null;
      notifyListeners();
      try {
        _payload = await _appApiClient.bootstrap();
      } catch (error) {
        _lastError = error.toString();
      } finally {
        _isRefreshing = false;
        notifyListeners();
      }
    } while (_refreshQueued);
  }

  void clear() {
    _payload = <String, dynamic>{};
    _lastError = null;
    notifyListeners();
  }
}
