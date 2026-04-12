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
       _cache = cache ?? DormLocationAnchorCache();

  final AuthRepository _authRepository;
  final DormRepository _dormRepository;
  final DormLocationAnchorCache _cache;

  bool _isSyncing = false;

  Future<DormLocationAnchor?> captureCurrentLocationAnchor({
    double radiusMeters = 100,
    bool requestPermission = true,
  }) async {
    final String uid = (await _authRepository.ensureAuthenticated()).uid;
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
    _isSyncing = true;
    try {
      final UserProfile currentUser = await _authRepository.ensureAuthenticated();
      final Dorm dorm = _dormRepository.currentDorm;
      if (dorm.id.isEmpty) {
        return;
      }
      final DormLocationAnchor? anchor =
          dorm.locationAnchor ??
          await _cache.read(uid: currentUser.uid, dormId: dorm.id);
      if (dorm.id.isEmpty || anchor == null) {
        return;
      }
      if (dorm.locationAnchor != null) {
        unawaited(_cache.save(uid: currentUser.uid, dormId: dorm.id, anchor: anchor));
      }
      if (dorm.locationAnchor == null) {
        unawaited(_dormRepository.saveDormLocationAnchor(anchor));
      }
      final Position? position = await _readCurrentPosition(
        requestPermission: false,
      );
      if (position == null) {
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
      final DormMember? currentMember = dorm.members.cast<DormMember?>().firstWhere(
        (DormMember? member) => member?.uid == _authRepository.currentUser.uid,
        orElse: () => null,
      );
      if (currentMember != null &&
          currentMember.presenceStatus == nextPresence) {
        return;
      }
      await _dormRepository.updateCurrentUserStatus(
        uid: currentUser.uid,
        presenceStatus: nextPresence,
      );
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> saveCurrentLocationAsDormAnchor() async {
    final DormLocationAnchor? anchor = await captureCurrentLocationAnchor();
    if (anchor == null) {
      return;
    }
    await persistDormLocationAnchor(anchor);
  }

  Future<void> persistDormLocationAnchor(DormLocationAnchor anchor) async {
    final UserProfile currentUser = await _authRepository.ensureAuthenticated();
    final String dormId = _dormRepository.currentDorm.id;
    await _dormRepository.saveDormLocationAnchor(anchor);
    if (dormId.trim().isEmpty) {
      return;
    }
    await _cache.save(uid: currentUser.uid, dormId: dormId, anchor: anchor);
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

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }
}
