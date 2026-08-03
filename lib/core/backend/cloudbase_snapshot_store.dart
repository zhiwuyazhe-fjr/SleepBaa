import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_app_api_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_snapshot_cache_store.dart';

class CloudBaseSnapshotRejectedException implements Exception {
  const CloudBaseSnapshotRejectedException(this.message);

  final String message;

  @override
  String toString() => 'CloudBase snapshot rejected: $message';
}

class CloudBaseSnapshotStore extends ChangeNotifier {
  CloudBaseSnapshotStore({
    required CloudBaseAppApiClient appApiClient,
    CloudBaseSnapshotCache? cacheStore,
  }) : _appApiClient = appApiClient,
       _cacheStore = cacheStore ?? CloudBaseSnapshotCacheStore();

  final CloudBaseAppApiClient _appApiClient;
  final CloudBaseSnapshotCache _cacheStore;

  Map<String, dynamic> _payload = <String, dynamic>{};
  bool _isRefreshing = false;
  String? _lastError;
  bool _refreshQueued = false;
  bool _allowDormBindingRemovalQueued = false;
  Future<void>? _refreshFuture;
  Future<void>? _cacheHydrationFuture;
  bool _cacheHydrated = false;
  int _revision = 0;
  bool _lastCommitAllowsDormBindingRemoval = false;
  String _anchorUid = '';
  String _anchorDormId = '';
  bool _anchorHasAvatar = false;

  Map<String, dynamic> get payload => _payload;
  bool get isRefreshing => _isRefreshing;
  String? get lastError => _lastError;
  bool get hasPayload => _payload.isNotEmpty;
  int get revision => _revision;
  bool get lastCommitAllowsDormBindingRemoval =>
      _lastCommitAllowsDormBindingRemoval;

  void setAccountAnchor({
    required String uid,
    String? dormId,
    bool hasPersistedAvatar = false,
  }) {
    final String normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      return;
    }
    if (_anchorUid.isNotEmpty && _anchorUid != normalizedUid) {
      return;
    }
    _anchorUid = normalizedUid;
    final String normalizedDormId = dormId?.trim() ?? '';
    if (normalizedDormId.isNotEmpty) {
      _anchorDormId = normalizedDormId;
    }
    _anchorHasAvatar = _anchorHasAvatar || hasPersistedAvatar;
  }

  Future<void> hydrateFromCache() {
    final Future<void>? inFlight = _cacheHydrationFuture;
    if (inFlight != null) {
      return inFlight;
    }
    if (_cacheHydrated) {
      return Future<void>.value();
    }
    final Future<void> hydration = _hydrateFromCache();
    _cacheHydrationFuture = hydration;
    return hydration.whenComplete(() {
      if (identical(_cacheHydrationFuture, hydration)) {
        _cacheHydrationFuture = null;
      }
    });
  }

  Future<void> refresh({bool allowDormBindingRemoval = false}) async {
    if (!_appApiClient.isConfigured) {
      return;
    }
    await hydrateFromCache();
    final Future<void>? inFlightRefresh = _refreshFuture;
    if (inFlightRefresh != null) {
      _refreshQueued = true;
      _allowDormBindingRemovalQueued =
          _allowDormBindingRemovalQueued || allowDormBindingRemoval;
      await inFlightRefresh;
      return;
    }

    _allowDormBindingRemovalQueued = allowDormBindingRemoval;
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

  Future<void> _hydrateFromCache() async {
    _cacheHydrated = true;
    if (_payload.isNotEmpty) {
      return;
    }
    final Map<String, dynamic>? cached = await _cacheStore.read();
    if (cached == null || cached.isEmpty) {
      return;
    }
    try {
      await _validateBootstrapPayload(cached, allowDormBindingRemoval: false);
      _commitPayload(cached, allowDormBindingRemoval: false);
      notifyListeners();
    } catch (_) {
      await _cacheStore.clear();
    }
  }

  Future<void> _runRefreshLoop() async {
    do {
      _refreshQueued = false;
      final bool allowDormBindingRemoval = _allowDormBindingRemovalQueued;
      _allowDormBindingRemovalQueued = false;
      _isRefreshing = true;
      _lastError = null;
      notifyListeners();
      try {
        final Map<String, dynamic> nextPayload = await _appApiClient
            .bootstrap();
        await _validateBootstrapPayload(
          nextPayload,
          allowDormBindingRemoval: allowDormBindingRemoval,
        );
        _commitPayload(
          nextPayload,
          allowDormBindingRemoval: allowDormBindingRemoval,
        );
        await _cacheStore.write(_accountSnapshotOf(nextPayload));
      } catch (error) {
        // Never replace the last committed account snapshot with a failed or
        // structurally incomplete bootstrap response.
        _lastError = error.toString();
      } finally {
        _isRefreshing = false;
        notifyListeners();
      }
    } while (_refreshQueued);
  }

  void _commitPayload(
    Map<String, dynamic> nextPayload, {
    required bool allowDormBindingRemoval,
  }) {
    _payload = nextPayload;
    _lastCommitAllowsDormBindingRemoval = allowDormBindingRemoval;
    _revision += 1;
    final Map<String, dynamic> root = _rootOf(nextPayload);
    final Map<String, dynamic> user = _mapOf(root['user']);
    if (allowDormBindingRemoval && _stringOf(user['dormId']).isEmpty) {
      _anchorDormId = '';
    }
    setAccountAnchor(
      uid: _stringOf(user['uid']),
      dormId: _stringOf(user['dormId']),
      hasPersistedAvatar: _hasAvatar(user),
    );
  }

  Future<void> _validateBootstrapPayload(
    Map<String, dynamic> nextPayload, {
    required bool allowDormBindingRemoval,
  }) async {
    final Map<String, dynamic> nextRoot = _rootOf(nextPayload);
    final Map<String, dynamic> nextUser = _mapOf(nextRoot['user']);
    final String nextUid = _stringOf(nextUser['uid']);
    if (nextUid.isEmpty) {
      throw const CloudBaseSnapshotRejectedException(
        'bootstrap payload has no authenticated user',
      );
    }

    final String expectedSubject =
        (await _appApiClient.currentSessionSubject())?.trim() ?? '';
    if (expectedSubject.isNotEmpty && nextUid != expectedSubject) {
      throw CloudBaseSnapshotRejectedException(
        'user mismatch: expected $expectedSubject, received $nextUid',
      );
    }
    if (_anchorUid.isNotEmpty && nextUid != _anchorUid) {
      throw CloudBaseSnapshotRejectedException(
        'account anchor mismatch: expected $_anchorUid, received $nextUid',
      );
    }

    final Map<String, dynamic> currentRoot = _rootOf(_payload);
    final Map<String, dynamic> currentUser = _mapOf(currentRoot['user']);
    final String currentUid = _stringOf(currentUser['uid']);
    if (currentUid.isNotEmpty && currentUid != nextUid) {
      throw CloudBaseSnapshotRejectedException(
        'snapshot attempted to switch from $currentUid to $nextUid',
      );
    }

    final String nextDormId = _stringOf(nextUser['dormId']);
    final Map<String, dynamic> nextDorm = _mapOf(nextRoot['dorm']);
    final String nextDormRecordId = _stringOf(nextDorm['id']);
    if (nextDormId.isNotEmpty) {
      if (nextDormRecordId != nextDormId) {
        throw CloudBaseSnapshotRejectedException(
          'bound user $nextUid has no matching dorm snapshot',
        );
      }
      final List<Map<String, dynamic>> members = _listOfMaps(
        nextDorm['members'],
      );
      if (members.isEmpty ||
          !members.any(
            (Map<String, dynamic> member) =>
                _stringOf(member['uid']) == nextUid,
          )) {
        throw CloudBaseSnapshotRejectedException(
          'bound user $nextUid is missing from dorm $nextDormId',
        );
      }
    }

    final String currentDormId = _stringOf(currentUser['dormId']);
    final String protectedDormId = currentDormId.isNotEmpty
        ? currentDormId
        : _anchorDormId;
    if (!allowDormBindingRemoval && protectedDormId.isNotEmpty) {
      if (nextDormId.isEmpty) {
        throw CloudBaseSnapshotRejectedException(
          'periodic refresh attempted to remove dorm $protectedDormId',
        );
      }
      if (nextDormId != protectedDormId) {
        throw CloudBaseSnapshotRejectedException(
          'periodic refresh attempted to switch dorm from '
          '$protectedDormId to $nextDormId',
        );
      }
    }

    final bool currentHasAvatar = _hasAvatar(currentUser) || _anchorHasAvatar;
    if (currentHasAvatar && !_hasAvatar(nextUser)) {
      throw const CloudBaseSnapshotRejectedException(
        'periodic refresh attempted to remove the persisted avatar',
      );
    }
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
    _lastCommitAllowsDormBindingRemoval = false;
    _revision += 1;
    notifyListeners();
  }

  void upsertSleepCaptureRecord(Map<String, dynamic> record) {
    applyAssistantSurfacePatch(<String, dynamic>{
      'sleepCaptureRecords': <Map<String, dynamic>>[record],
    });
  }

  Future<void> clear() async {
    _payload = <String, dynamic>{};
    _lastError = null;
    _revision += 1;
    _lastCommitAllowsDormBindingRemoval = false;
    _anchorUid = '';
    _anchorDormId = '';
    _anchorHasAvatar = false;
    _cacheHydrated = true;
    await _cacheStore.clear();
    notifyListeners();
  }

  Map<String, dynamic> get _rootData => _rootOf(_payload);
}

Map<String, dynamic> _accountSnapshotOf(Map<String, dynamic> payload) {
  final Map<String, dynamic> root = _rootOf(payload);
  return <String, dynamic>{
    'data': <String, dynamic>{
      'user': _mapOf(root['user']),
      'dorm': _mapOf(root['dorm']),
    },
  };
}

bool _hasAvatar(Map<String, dynamic> user) {
  return _stringOf(user['avatarStoragePath']).isNotEmpty ||
      _stringOf(user['avatarUrl']).isNotEmpty;
}

Map<String, dynamic> _rootOf(Map<String, dynamic> payload) {
  if (payload['data'] is Map<String, dynamic>) {
    return Map<String, dynamic>.from(payload['data'] as Map<String, dynamic>);
  }
  if (payload['data'] is Map) {
    return Map<String, dynamic>.from(payload['data'] as Map);
  }
  return Map<String, dynamic>.from(payload);
}

String _stringOf(dynamic value) => value?.toString().trim() ?? '';

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
