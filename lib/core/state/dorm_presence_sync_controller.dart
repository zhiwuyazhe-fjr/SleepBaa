import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/state/dorm_location_anchor_cache.dart';

class DormPresenceSyncController {
  DormPresenceSyncController({
    required AuthRepository authRepository,
    required DormRepository dormRepository,
    DormLocationAnchorCache? cache,
  }) : _authRepository = authRepository,
       _dormRepository = dormRepository,
       _cache = cache ?? DormLocationAnchorCache() {
    _dormRepository.addListener(_handleDormChanged);
  }

  final AuthRepository _authRepository;
  final DormRepository _dormRepository;
  final DormLocationAnchorCache _cache;

  bool _isSyncing = false;
  bool _isRestoringAnchor = false;
  DormLocationAnchor? _pendingAnchor;
  String? _pendingAnchorDormId;

  Future<DormLocationAnchor?> captureCurrentLocationAnchor({
    double radiusMeters = 100,
    bool requestPermission = true,
  }) async {
    if (_authRepository.currentUser.uid.trim().isEmpty) {
      return null;
    }
    final String uid = _authRepository.currentUser.uid;
    final Position? position = await _readCurrentPosition(
      requestPermission: requestPermission,
    );
    if (position == null) {
      return null;
    }
    return DormLocationAnchor(
      latitude: position.latitude,
      longitude: position.longitude,
      radiusMeters: radiusMeters,
      recordedAt: DateTime.now(),
      recordedByUid: uid,
    );
  }

  Future<void> syncPresenceFromCurrentLocation() async {
    if (_isSyncing) {
      return;
    }
    if (!_authRepository.hasVerifiedPhoneIdentity) {
      return;
    }
    _isSyncing = true;
    try {
      final UserProfile currentUser = _authRepository.currentUser;
      if (currentUser.uid.trim().isEmpty) {
        return;
      }
      await restoreCachedLocationAnchor();
      final Dorm dorm = _dormRepository.currentDorm;
      if (dorm.id.isEmpty) {
        return;
      }
      final DormLocationAnchor? anchor =
          dorm.locationAnchor ??
          _pendingAnchorForDorm(dorm.id) ??
          await resolveEffectiveLocationAnchor();
      if (anchor == null) {
        return;
      }
      final Position? position = await _readCurrentPosition(
        requestPermission: false,
      );
      if (position == null) {
        await _updateCurrentUserPresenceIfChanged(
          uid: currentUser.uid,
          dorm: dorm,
          presenceStatus: DormPresenceStatus.unknown,
        );
        return;
      }
      final double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        anchor.latitude,
        anchor.longitude,
      );
      final DormPresenceStatus nextPresence = distance <= anchor.radiusMeters
          ? DormPresenceStatus.returned
          : DormPresenceStatus.away;
      await _updateCurrentUserPresenceIfChanged(
        uid: currentUser.uid,
        dorm: dorm,
        presenceStatus: nextPresence,
      );
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _updateCurrentUserPresenceIfChanged({
    required String uid,
    required Dorm dorm,
    required DormPresenceStatus presenceStatus,
  }) async {
    DormMember? currentMember;
    for (final DormMember member in dorm.members) {
      if (member.uid == uid) {
        currentMember = member;
        break;
      }
    }
    if (currentMember != null &&
        currentMember.presenceStatus == presenceStatus) {
      return;
    }
    await _dormRepository.updateCurrentUserStatus(
      uid: uid,
      presenceStatus: presenceStatus,
    );
  }

  Future<void> restoreCachedLocationAnchor() async {
    if (_isRestoringAnchor) {
      return;
    }
    if (_authRepository.currentUser.uid.trim().isEmpty) {
      return;
    }
    _isRestoringAnchor = true;
    try {
      final UserProfile currentUser = _authRepository.currentUser;
      final Dorm dorm = _dormRepository.currentDorm;
      final String dormId = dorm.id.trim();
      if (dormId.isEmpty) {
        return;
      }
      final DormLocationAnchor? anchor =
          dorm.locationAnchor ??
          await _cache.read(uid: currentUser.uid, dormId: dorm.id);
      if (anchor == null) {
        return;
      }
      _pendingAnchor = anchor;
      _pendingAnchorDormId = dorm.id;
      _applyPendingAnchor(currentUser.uid);
    } finally {
      _isRestoringAnchor = false;
    }
  }

  Future<DormLocationAnchor?> resolveEffectiveLocationAnchor() async {
    await restoreCachedLocationAnchor();
    final Dorm dorm = _dormRepository.currentDorm;
    return dorm.locationAnchor ?? _pendingAnchorForDorm(dorm.id);
  }

  Future<void> saveCurrentLocationAsDormAnchor() async {
    final DormLocationAnchor? anchor = await captureCurrentLocationAnchor();
    if (anchor == null) {
      return;
    }
    await persistDormLocationAnchor(anchor);
  }

  Future<void> persistDormLocationAnchor(DormLocationAnchor anchor) async {
    if (_authRepository.currentUser.uid.trim().isEmpty) {
      return;
    }
    final UserProfile currentUser = _authRepository.currentUser;
    final String dormId = _dormRepository.currentDorm.id;
    if (dormId.trim().isEmpty) {
      return;
    }
    _pendingAnchor = anchor;
    _pendingAnchorDormId = dormId;
    await _cache.save(uid: currentUser.uid, dormId: dormId, anchor: anchor);
    _applyPendingAnchor(currentUser.uid);
    try {
      await _dormRepository.saveDormLocationAnchor(anchor);
    } catch (_) {
      // Keep local cache as the source of truth until the next sync retries.
    }
  }

  void _handleDormChanged() {
    final String uid = _authRepository.currentUser.uid.trim();
    if (uid.isEmpty) {
      return;
    }
    _applyPendingAnchor(uid);
  }

  void _applyPendingAnchor(String uid) {
    final Dorm dorm = _dormRepository.currentDorm;
    if (dorm.id.trim().isEmpty) {
      return;
    }
    if (dorm.locationAnchor != null) {
      _clearPendingAnchorIfForDorm(dorm.id);
      unawaited(
        _cache.save(uid: uid, dormId: dorm.id, anchor: dorm.locationAnchor!),
      );
      return;
    }
    final DormLocationAnchor? anchor = _pendingAnchor;
    if (anchor == null || _pendingAnchorDormId != dorm.id) {
      return;
    }
    _pendingAnchor = null;
    _pendingAnchorDormId = null;
    _dormRepository.hydrateCurrentDormLocationAnchor(anchor);
    unawaited(_cache.save(uid: uid, dormId: dorm.id, anchor: anchor));
    unawaited(_dormRepository.saveDormLocationAnchor(anchor));
  }

  DormLocationAnchor? _pendingAnchorForDorm(String dormId) {
    return _pendingAnchorDormId == dormId ? _pendingAnchor : null;
  }

  void _clearPendingAnchorIfForDorm(String dormId) {
    if (_pendingAnchorDormId != dormId) {
      return;
    }
    _pendingAnchor = null;
    _pendingAnchorDormId = null;
  }

  void dispose() {
    _dormRepository.removeListener(_handleDormChanged);
  }

  Future<Position?> _readCurrentPosition({
    required bool requestPermission,
  }) async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }
}
