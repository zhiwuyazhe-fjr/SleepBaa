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

  void applyAssistantSurfacePatch(Map<String, dynamic> patch) {
    final Map<String, dynamic> root = _rootData;
    final Map<String, dynamic> next = Map<String, dynamic>.from(root);

    if (patch['userState'] is Map) {
      next['userState'] = _deepMergeMaps(
        _mapOf(next['userState']),
        _mapOf(patch['userState']),
      );
    }
    if (patch['cardSnapshots'] is Map) {
      next['cardSnapshots'] = <String, dynamic>{
        ..._mapOf(next['cardSnapshots']),
        ..._mapOf(patch['cardSnapshots']),
      };
    }
    if (patch['sleepCaptureRecords'] is List) {
      next['sleepCaptureRecords'] = _mergeById(
        _listOfMaps(next['sleepCaptureRecords']),
        _listOfMaps(patch['sleepCaptureRecords']),
      );
    }

    _payload = _payload['data'] is Map<String, dynamic> || _payload.isEmpty
        ? <String, dynamic>{..._payload, 'data': next}
        : next;
    notifyListeners();
  }

  void upsertSleepCaptureRecord(Map<String, dynamic> record) {
    applyAssistantSurfacePatch(<String, dynamic>{
      'sleepCaptureRecords': <Map<String, dynamic>>[record],
    });
  }

  void clear() {
    _payload = <String, dynamic>{};
    _lastError = null;
    notifyListeners();
  }

  Map<String, dynamic> get _rootData {
    if (_payload['data'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(_payload['data'] as Map<String, dynamic>);
    }
    if (_payload['data'] is Map) {
      return Map<String, dynamic>.from(_payload['data'] as Map);
    }
    return Map<String, dynamic>.from(_payload);
  }
}

Map<String, dynamic> _mapOf(dynamic value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _listOfMaps(dynamic value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return value
      .whereType<Object>()
      .map(_mapOf)
      .where((Map<String, dynamic> item) => item.isNotEmpty)
      .toList(growable: false);
}

Map<String, dynamic> _deepMergeMaps(
  Map<String, dynamic> current,
  Map<String, dynamic> patch,
) {
  final Map<String, dynamic> next = Map<String, dynamic>.from(current);
  for (final MapEntry<String, dynamic> entry in patch.entries) {
    if (entry.value is Map && current[entry.key] is Map) {
      next[entry.key] = _deepMergeMaps(
        _mapOf(current[entry.key]),
        _mapOf(entry.value),
      );
    } else {
      next[entry.key] = entry.value;
    }
  }
  return next;
}

List<Map<String, dynamic>> _mergeById(
  List<Map<String, dynamic>> current,
  List<Map<String, dynamic>> patch,
) {
  final Map<String, Map<String, dynamic>> byId = <String, Map<String, dynamic>>{
    for (final Map<String, dynamic> item in current)
      (item['id']?.toString() ?? '${item.hashCode}'): item,
  };
  for (final Map<String, dynamic> item in patch) {
    final String id = item['id']?.toString() ?? '${item.hashCode}';
    byId[id] = item;
  }
  return byId.values.toList(growable: false);
}
