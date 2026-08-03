import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/core/backend/app_environment.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_app_api_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_auth_profile_cache_store.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_auth_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_session_coordinator.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_session_store.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_snapshot_store.dart';
import 'package:sleep_dorm_app/core/backend/user_settings_cache_store.dart';
import 'package:sleep_dorm_app/core/backend/verified_phone_identity_store.dart';
import 'package:sleep_dorm_app/core/data/backend_contract.dart';
import 'package:sleep_dorm_app/core/data/in_memory_repositories.dart';
import 'package:sleep_dorm_app/core/data/model_serializers.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/utils/id_generator.dart';

Map<String, dynamic> _mapOf(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _mapListOf(dynamic value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return value
      .map((dynamic item) => _mapOf(item))
      .where((Map<String, dynamic> item) => item.isNotEmpty)
      .toList(growable: false);
}

List<String> _stringListOf(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }
  return value.map((dynamic item) => item.toString()).toList(growable: false);
}

String _stringOf(dynamic value, [String fallback = '']) {
  return value is String ? value : fallback;
}

DateTime _dateOf(dynamic value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  if (value is Map) {
    final dynamic seconds = value['_seconds'] ?? value['seconds'];
    final dynamic nanoseconds = value['_nanoseconds'] ?? value['nanoseconds'];
    if (seconds is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        (seconds.toDouble() * 1000).round(),
        isUtc: true,
      ).add(
        Duration(
          microseconds: nanoseconds is num
              ? (nanoseconds.toDouble() / 1000).round()
              : 0,
        ),
      );
    }
  }
  return DateTime.now();
}

NotificationCategory _notificationCategoryOf(dynamic value) {
  final String name = _stringOf(value);
  return NotificationCategory.values.firstWhere(
    (NotificationCategory item) => item.name == name,
    orElse: () => NotificationCategory.system,
  );
}

NotificationItem _notificationFromMap(Map<String, dynamic> map) {
  return NotificationItem(
    id: _stringOf(map['id']),
    category: _notificationCategoryOf(map['category']),
    title: _stringOf(map['title']),
    body: _stringOf(map['body']),
    createdAt: _dateOf(map['createdAt']),
    route: _stringOf(map['route']),
    readAt: map['readAt'] == null ? null : _dateOf(map['readAt']),
    ownerUid: _stringOf(map['ownerUid']).isEmpty
        ? null
        : _stringOf(map['ownerUid']),
  );
}

double _doubleOf(dynamic value, [double fallback = 0]) {
  if (value is num) {
    return value.toDouble();
  }
  return fallback;
}

double? _nullableDoubleOf(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return null;
}

SleepTrendSeries _sleepTrendSeriesFromCard(
  Map<String, dynamic> card, {
  required String metricKey,
  required String unit,
}) {
  final Map<String, dynamic> payload = _mapOf(card['payload']);
  final List<SleepTrendPoint> points = _mapListOf(payload['points'])
      .map(
        (Map<String, dynamic> point) => SleepTrendPoint(
          dateKey: _stringOf(point['dateKey']),
          weekdayLabel: _stringOf(point['weekdayLabel']),
          value: _nullableDoubleOf(point['value']),
        ),
      )
      .where((SleepTrendPoint point) => point.dateKey.isNotEmpty)
      .toList(growable: false);
  return SleepTrendSeries(
    metricKey: _stringOf(payload['metricKey'], metricKey),
    unit: _stringOf(payload['unit'], unit),
    points: points,
  );
}

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) test) {
  for (final T value in values) {
    if (test(value)) {
      return value;
    }
  }
  return null;
}

UserProfile _blankCloudBaseUserProfile({
  String uid = '',
  String? phoneNumber,
  DateTime? phoneLinkedAt,
}) {
  return UserProfile(
    uid: uid,
    displayName: '',
    tagline: '',
    role: '',
    phoneNumber: phoneNumber,
    phoneLinkedAt: phoneLinkedAt,
    avatarFallbackSeed: '',
  );
}

Map<String, dynamic> _profileSavePatch(UserProfile profile) {
  return <String, dynamic>{
    'uid': profile.uid,
    'displayName': profile.displayName,
    'tagline': profile.tagline,
    'role': profile.role,
    'earnedBadgeIds': profile.earnedBadgeIds,
    'equippedBadgeId': profile.equippedBadgeId,
    'showDormPulseBadge': profile.showDormPulseBadge,
    'selectedDormBadgeId': profile.selectedDormBadgeId,
    'dormId': profile.dormId,
    'phoneNumber': profile.phoneNumber,
    'phoneLinkedAt': profile.phoneLinkedAt?.toIso8601String(),
    'avatarFallbackSeed': profile.avatarFallbackSeed,
  };
}

String? _nonEmptyString(dynamic value) {
  if (value is! String) {
    return null;
  }
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : value;
}

String _avatarResourceKey(String? url) {
  final String trimmed = url?.trim() ?? '';
  if (trimmed.isEmpty) {
    return '';
  }
  final Uri? parsed = Uri.tryParse(trimmed);
  if (parsed == null || !parsed.hasScheme) {
    return trimmed.split('?').first.split('#').first;
  }
  return Uri(
    scheme: parsed.scheme,
    host: parsed.host,
    port: parsed.hasPort ? parsed.port : null,
    path: parsed.path,
  ).toString();
}

String? _stableDisplayedAvatarUrl({
  required String? displayedUrl,
  required String? nextUrl,
  String? displayedStoragePath,
  String? nextStoragePath,
}) {
  final String current = displayedUrl?.trim() ?? '';
  final String incoming = nextUrl?.trim() ?? '';
  if (incoming.isEmpty) {
    return null;
  }
  if (current.isEmpty) {
    return incoming;
  }
  final String currentStorage = displayedStoragePath?.trim() ?? '';
  final String incomingStorage = nextStoragePath?.trim() ?? '';
  if (currentStorage.isNotEmpty && currentStorage == incomingStorage) {
    return displayedUrl;
  }
  if (_avatarResourceKey(current) == _avatarResourceKey(incoming)) {
    return displayedUrl;
  }
  return incoming;
}

String? _avatarUrlForSnapshotMerge({
  required UserProfile currentUser,
  required UserProfile snapshotUser,
  required bool preferFreshSnapshotForCachedProfile,
}) {
  final String incoming = snapshotUser.avatarUrl?.trim() ?? '';
  final String currentStorage = currentUser.avatarStoragePath?.trim() ?? '';
  final String incomingStorage = snapshotUser.avatarStoragePath?.trim() ?? '';
  if (preferFreshSnapshotForCachedProfile &&
      incoming.isNotEmpty &&
      currentStorage.isNotEmpty &&
      currentStorage == incomingStorage) {
    return snapshotUser.avatarUrl;
  }
  return _stableDisplayedAvatarUrl(
    displayedUrl: currentUser.avatarUrl,
    nextUrl: snapshotUser.avatarUrl,
    displayedStoragePath: currentUser.avatarStoragePath,
    nextStoragePath: snapshotUser.avatarStoragePath,
  );
}

Dorm _mergeStableDormAvatarUrls(Dorm currentDorm, Dorm nextDorm) {
  if (currentDorm.members.isEmpty || nextDorm.members.isEmpty) {
    return nextDorm;
  }
  final Map<String, DormMember> currentByUid = <String, DormMember>{
    for (final DormMember member in currentDorm.members) member.uid: member,
  };
  return nextDorm.copyWith(
    members: nextDorm.members
        .map((DormMember nextMember) {
          final DormMember? currentMember = currentByUid[nextMember.uid];
          if (currentMember == null) {
            return nextMember;
          }
          final String currentAvatarUrl = currentMember.avatarUrl?.trim() ?? '';
          final String nextAvatarUrl = nextMember.avatarUrl?.trim() ?? '';
          if (nextAvatarUrl.isEmpty && currentAvatarUrl.isNotEmpty) {
            return nextMember.copyWith(avatarUrl: currentMember.avatarUrl);
          }
          final String? stableAvatarUrl = _stableDisplayedAvatarUrl(
            displayedUrl: currentMember.avatarUrl,
            nextUrl: nextMember.avatarUrl,
          );
          return nextMember.copyWith(
            avatarUrl: stableAvatarUrl,
            clearAvatarUrl: stableAvatarUrl == null,
          );
        })
        .toList(growable: false),
  );
}

Dorm _mergeNewerDormHeartbeatFields(Dorm currentDorm, Dorm nextDorm) {
  if (currentDorm.members.isEmpty || nextDorm.members.isEmpty) {
    return nextDorm;
  }
  final Map<String, DormMember> currentByUid = <String, DormMember>{
    for (final DormMember member in currentDorm.members) member.uid: member,
  };
  return nextDorm.copyWith(
    members: nextDorm.members
        .map((DormMember nextMember) {
          final DormMember? currentMember = currentByUid[nextMember.uid];
          if (currentMember == null) {
            return nextMember;
          }
          final DateTime? currentHeartbeatAt = currentMember.appLastSeenAt;
          final DateTime? nextHeartbeatAt = nextMember.appLastSeenAt;
          final bool keepCurrentHeartbeat =
              currentHeartbeatAt != null &&
              (nextHeartbeatAt == null ||
                  currentHeartbeatAt.isAfter(nextHeartbeatAt));
          if (!keepCurrentHeartbeat) {
            return nextMember;
          }
          return nextMember.copyWith(
            appOnline: currentMember.appOnline,
            appLastSeenAt: currentHeartbeatAt,
          );
        })
        .toList(growable: false),
  );
}

class _PendingDormMemberStatusOverride {
  const _PendingDormMemberStatusOverride({
    this.status,
    this.presenceStatus,
    this.sleepModeActive,
    this.note,
  });

  final DormMemberStatus? status;
  final DormPresenceStatus? presenceStatus;
  final bool? sleepModeActive;
  final String? note;

  bool matches(DormMember member) {
    if (status != null && member.status != status) {
      return false;
    }
    if (presenceStatus != null && member.presenceStatus != presenceStatus) {
      return false;
    }
    if (sleepModeActive != null && member.sleepModeActive != sleepModeActive) {
      return false;
    }
    if (note != null && member.note != note) {
      return false;
    }
    return true;
  }

  DormMember apply(DormMember member) {
    return member.copyWith(
      status: status,
      presenceStatus: presenceStatus,
      sleepModeActive: sleepModeActive,
      note: note,
    );
  }
}

class _PendingDormEnvironmentOverride {
  const _PendingDormEnvironmentOverride({
    this.noiseDb,
    this.lightLabel,
    this.quietLabel,
  });

  final int? noiseDb;
  final String? lightLabel;
  final String? quietLabel;

  _PendingDormEnvironmentOverride merge(_PendingDormEnvironmentOverride next) {
    return _PendingDormEnvironmentOverride(
      noiseDb: next.noiseDb ?? noiseDb,
      lightLabel: next.lightLabel ?? lightLabel,
      quietLabel: next.quietLabel ?? quietLabel,
    );
  }

  bool matches(Dorm dorm) {
    if (noiseDb != null && dorm.noiseDb != noiseDb) {
      return false;
    }
    if (lightLabel != null && dorm.lightLabel != lightLabel) {
      return false;
    }
    if (quietLabel != null && dorm.quietLabel != quietLabel) {
      return false;
    }
    return true;
  }

  Dorm apply(Dorm dorm) {
    return dorm.copyWith(
      noiseDb: noiseDb,
      lightLabel: lightLabel,
      quietLabel: quietLabel,
    );
  }
}

Dorm _applyPendingDormStatusOverrides(
  Dorm dorm,
  Map<String, _PendingDormMemberStatusOverride> pending,
) {
  if (pending.isEmpty || dorm.members.isEmpty) {
    return dorm;
  }
  return dorm.copyWith(
    members: dorm.members
        .map((DormMember member) {
          final _PendingDormMemberStatusOverride? override =
              pending[member.uid];
          return override == null ? member : override.apply(member);
        })
        .toList(growable: false),
  );
}

Map<String, _PendingDormMemberStatusOverride>
_retainUnacknowledgedDormStatusOverrides(
  Dorm snapshotDorm,
  Map<String, _PendingDormMemberStatusOverride> pending,
) {
  if (pending.isEmpty || snapshotDorm.members.isEmpty) {
    return Map<String, _PendingDormMemberStatusOverride>.from(pending);
  }
  final Map<String, DormMember> snapshotByUid = <String, DormMember>{
    for (final DormMember member in snapshotDorm.members) member.uid: member,
  };
  final Map<String, _PendingDormMemberStatusOverride> remaining =
      <String, _PendingDormMemberStatusOverride>{};
  pending.forEach((String uid, _PendingDormMemberStatusOverride override) {
    final DormMember? snapshotMember = snapshotByUid[uid];
    if (snapshotMember == null || !override.matches(snapshotMember)) {
      remaining[uid] = override;
    }
  });
  return remaining;
}

Map<String, Map<String, dynamic>> _cardSnapshotsFromPayload(dynamic value) {
  if (value is Map) {
    return value.map<String, Map<String, dynamic>>(
      (dynamic key, dynamic item) =>
          MapEntry<String, Map<String, dynamic>>(key.toString(), _mapOf(item)),
    );
  }
  if (value is List) {
    return <String, Map<String, dynamic>>{
      for (final Map<String, dynamic> item in _mapListOf(value))
        _stringOf(item['surfaceId'], _stringOf(item['id'])): item,
    };
  }
  return <String, Map<String, dynamic>>{};
}

IconData _iconForAction(String actionId, RecommendationType type) {
  final Map<String, NightRecommendation> catalog =
      <String, NightRecommendation>{
        for (final NightRecommendation item in buildDefaultRecommendations())
          item.id: item,
      };
  return catalog[actionId]?.icon ??
      (type == RecommendationType.audio
          ? Icons.dark_mode_rounded
          : Icons.task_alt_rounded);
}

Map<String, AudioTrack> _remoteAudioTrackCatalog = <String, AudioTrack>{};

const int _cloudBaseTonightRecommendationLimit = 6;

List<AudioTrack> _defaultAudioCatalog() {
  return buildDefaultRecommendations()
      .where((NightRecommendation item) => _isPlayableTrack(item.track))
      .map((NightRecommendation item) => item.track!)
      .toList(growable: false);
}

AudioTrack? _firstRemoteAudioTrack() {
  if (_remoteAudioTrackCatalog.isEmpty) {
    return null;
  }
  return _remoteAudioTrackCatalog.values.first;
}

bool _isPlayableTrack(AudioTrack? track) {
  if (track == null) {
    return false;
  }
  final String assetPath = track.assetPath?.trim() ?? '';
  final String sourceUrl = track.sourceUrl?.trim() ?? '';
  return assetPath.isNotEmpty || sourceUrl.isNotEmpty;
}

AudioTrack? _mergeTrackWithRemoteCatalog(AudioTrack? track, {String? trackId}) {
  final String resolvedTrackId = (trackId?.trim().isNotEmpty ?? false)
      ? trackId!.trim()
      : track?.id ?? '';
  if (resolvedTrackId.isEmpty) {
    return track;
  }
  final AudioTrack? remoteTrack = _remoteAudioTrackCatalog[resolvedTrackId];
  if (remoteTrack == null) {
    return track;
  }
  if (track == null) {
    return remoteTrack;
  }
  return track.copyWith(
    title: remoteTrack.title,
    subtitle: remoteTrack.subtitle,
    duration: remoteTrack.duration,
    sourceUrl: remoteTrack.sourceUrl,
    storageFileId: remoteTrack.storageFileId,
  );
}

AudioTrack? _resolveTrackWithRemoteFallback(
  AudioTrack? track, {
  String? trackId,
}) {
  final AudioTrack? hydratedTrack = _mergeTrackWithRemoteCatalog(
    track,
    trackId: trackId,
  );
  if (_isPlayableTrack(hydratedTrack)) {
    return hydratedTrack;
  }
  if (_isPlayableTrack(track)) {
    return track;
  }
  final AudioTrack? fallbackTrack = _firstRemoteAudioTrack();
  if (fallbackTrack == null) {
    return hydratedTrack ?? track;
  }
  if (hydratedTrack == null) {
    return fallbackTrack;
  }
  return hydratedTrack.copyWith(
    id: fallbackTrack.id,
    title: fallbackTrack.title,
    subtitle: fallbackTrack.subtitle,
    duration: fallbackTrack.duration,
    sourceUrl: fallbackTrack.sourceUrl,
    storageFileId: fallbackTrack.storageFileId,
  );
}

AudioTrack? _trackForAction(String actionId, String? trackId) {
  final Map<String, NightRecommendation> catalog =
      <String, NightRecommendation>{
        for (final NightRecommendation item in buildDefaultRecommendations())
          item.id: item,
      };
  final AudioTrack? catalogTrack = catalog[actionId]?.track;
  final AudioTrack? hydratedCatalogTrack = _resolveTrackWithRemoteFallback(
    catalogTrack,
    trackId: trackId,
  );
  if (hydratedCatalogTrack != null) {
    return hydratedCatalogTrack;
  }
  if (catalogTrack != null) {
    return catalogTrack;
  }
  if (trackId == null || trackId.isEmpty) {
    return _firstRemoteAudioTrack();
  }
  return _resolveTrackWithRemoteFallback(
        AudioTrack(
          id: trackId,
          title: '\u52a9\u7720\u97f3\u9891',
          subtitle: 'AI \u4e3a\u4f60\u63a8\u8350\u7684\u653e\u677e\u97f3\u8f68',
          duration: const Duration(minutes: 45),
        ),
        trackId: trackId,
      ) ??
      AudioTrack(
        id: trackId,
        title: '\u52a9\u7720\u97f3\u9891',
        subtitle: 'AI \u4e3a\u4f60\u63a8\u8350\u7684\u653e\u677e\u97f3\u8f68',
        duration: const Duration(minutes: 45),
      );
}

DormMemberStatus _activityStatusFromStorage(Map<String, dynamic> map) {
  final String rawStatus = _stringOf(map['status']);
  if (rawStatus == DormMemberStatus.active.name) {
    return DormMemberStatus.active;
  }
  return DormMemberStatus.quiet;
}

DormPresenceStatus _presenceStatusFromStorage(Map<String, dynamic> map) {
  final String rawPresence = _stringOf(map['presenceStatus']);
  if (rawPresence == DormPresenceStatus.returned.name) {
    return DormPresenceStatus.returned;
  }
  if (rawPresence == DormPresenceStatus.away.name) {
    return DormPresenceStatus.away;
  }
  if (rawPresence == DormPresenceStatus.unknown.name) {
    return DormPresenceStatus.unknown;
  }
  final String rawStatus = _stringOf(map['status']);
  if (rawStatus == DormMemberStatus.away.name) {
    return DormPresenceStatus.away;
  }
  return DormPresenceStatus.unknown;
}

bool _sleepModeFromStorage(Map<String, dynamic> map) {
  if (map.containsKey('sleepModeActive')) {
    return map['sleepModeActive'] as bool? ?? false;
  }
  return _stringOf(map['status']) == DormMemberStatus.sleeping.name;
}

NightRecommendation _recommendationFromAction(Map<String, dynamic> action) {
  final String actionId = _stringOf(action['id'], 'generated-action');
  final RecommendationType type = _stringOf(action['type']) == 'audio'
      ? RecommendationType.audio
      : RecommendationType.quickAction;
  final Map<String, NightRecommendation> catalog =
      <String, NightRecommendation>{
        for (final NightRecommendation item in buildDefaultRecommendations())
          item.id: item,
      };
  final NightRecommendation? known = catalog[actionId];
  return NightRecommendation(
    id: actionId,
    title:
        known?.title ?? _stringOf(action['title'], '\u4eca\u665a\u884c\u52a8'),
    subtitle:
        known?.subtitle ??
        _stringOf(
          action['subtitle'],
          '\u5148\u6309\u4eca\u665a\u5efa\u8bae\u505a\u4e00\u4e2a\u5c0f\u52a8\u4f5c\u3002',
        ),
    type: type,
    icon: _iconForAction(actionId, type),
    tags: _stringListOf(action['tags']).isNotEmpty
        ? _stringListOf(action['tags'])
        : (known?.tags ?? const <String>[]),
    executionState: RecommendationExecutionState.idle,
    track: _trackForAction(actionId, action['trackId'] as String?),
  );
}

Dorm _unboundDorm() {
  return Dorm(
    id: '',
    name: '\u672a\u52a0\u5165\u5bbf\u820d',
    overview:
        '\u4f60\u8fd8\u6ca1\u6709\u52a0\u5165\u5bbf\u820d\uff0c\u5148\u521b\u5efa\u5bbf\u820d\u6216\u4f7f\u7528\u9080\u8bf7\u7801\u52a0\u5165\u5427\u3002',
    noiseDb: 0,
    status: DormStatus.active,
    archivedAt: null,
    lightLabel: '\u672a\u8bbe\u7f6e',
    quietLabel: '\u672a\u52a0\u5165',
    rules: const <DormRule>[],
    members: const <DormMember>[],
    rulesSettings: buildDefaultDormRulesSettings(),
    events: const <DormEvent>[],
    invites: const <DormInvite>[],
  );
}

DormMember _dormMemberFromMap(Map<String, dynamic> map) {
  final int? noise = map['noiseDb'] == null
      ? null
      : (map['noiseDb'] as num?)?.round();
  return DormMember(
    uid: _stringOf(map['uid']),
    name: _stringOf(map['name']),
    status: _activityStatusFromStorage(map),
    presenceStatus: _presenceStatusFromStorage(map),
    sleepModeActive: _sleepModeFromStorage(map),
    appOnline: map['appOnline'] as bool? ?? false,
    appLastSeenAt: map['appLastSeenAt'] == null
        ? null
        : _dateOf(map['appLastSeenAt']),
    lastActiveAt: _dateOf(map['lastActiveAt']),
    note: _stringOf(map['note']),
    avatarUrl: map['avatarUrl'] as String?,
    displayBadgeId: map['displayBadgeId'] as String?,
    noiseDb: noise,
  );
}

DormLocationAnchor? _dormLocationAnchorFromMap(dynamic value) {
  if (value is! Map) {
    return null;
  }
  final Map<String, dynamic> map = Map<String, dynamic>.from(value);
  if (!map.containsKey('latitude') || !map.containsKey('longitude')) {
    return null;
  }
  return ModelSerializers.dormLocationAnchorFromMap(map);
}

DormRule _dormRuleFromMap(Map<String, dynamic> map) {
  return ModelSerializers.dormRuleFromMap(map);
}

DormPendingRuleProposal? _dormPendingRuleProposalFromMap(dynamic value) {
  if (value is! Map) {
    return null;
  }
  final Map<String, dynamic> map = Map<String, dynamic>.from(value);
  if (map.isEmpty) {
    return null;
  }
  return ModelSerializers.dormPendingRuleProposalFromMap(map);
}

DormEvent _dormEventFromMap(Map<String, dynamic> map) {
  return DormEvent(
    id: _stringOf(map['id']),
    type:
        _firstWhereOrNull(DormEventType.values, (DormEventType type) {
          return type.name == _stringOf(map['type']);
        }) ??
        DormEventType.system,
    title: _stringOf(map['title']),
    detail: _stringOf(map['detail']),
    createdAt: _dateOf(map['createdAt']),
    actorUid: map['actorUid'] as String?,
  );
}

DormInvite _dormInviteFromMap(Map<String, dynamic> map) {
  return DormInvite(
    id: _stringOf(map['id']),
    dormId: _stringOf(map['dormId']),
    code: _stringOf(map['code']),
    createdByUid: _stringOf(map['createdByUid']),
    createdAt: _dateOf(map['createdAt']),
    expiresAt: _dateOf(map['expiresAt']),
    status:
        _firstWhereOrNull(
          DormInviteStatus.values,
          (DormInviteStatus status) => status.name == _stringOf(map['status']),
        ) ??
        DormInviteStatus.pending,
    acceptedByUid: map['acceptedByUid'] as String?,
    acceptedAt: map['acceptedAt'] == null ? null : _dateOf(map['acceptedAt']),
  );
}

Dorm _dormFromMap(Map<String, dynamic> map, String currentUserId) {
  if (map.isEmpty) {
    return _unboundDorm();
  }
  final DormRulesSettings settings = map['rulesSettings'] is Map
      ? ModelSerializers.dormRulesSettingsFromMap(
          Map<String, dynamic>.from(map['rulesSettings'] as Map),
        )
      : buildDefaultDormRulesSettings();
  if (_stringOf(map['id']).isEmpty) {
    return _unboundDorm();
  }
  final List<String> earnedDormBadgeIds =
      (map['earnedDormBadgeIds'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false);
  return Dorm(
    id: _stringOf(map['id']),
    name: _stringOf(map['name'], '\u5bbf\u820d'),
    overview: _stringOf(
      map['overview'],
      '\u5df2\u52a0\u5165\u5bbf\u820d\u534f\u4f5c\u7a7a\u95f4\u3002',
    ),
    noiseDb: (map['noiseDb'] as num?)?.toInt() ?? 32,
    status:
        _firstWhereOrNull(DormStatus.values, (DormStatus status) {
          return status.name == _stringOf(map['status']);
        }) ??
        DormStatus.active,
    archivedAt: map['archivedAt'] == null ? null : _dateOf(map['archivedAt']),
    lightLabel: _stringOf(map['lightLabel'], '\u5e73\u7a33'),
    quietLabel: _stringOf(map['quietLabel'], '\u826f\u597d'),
    rules: _mapListOf(
      map['rules'],
    ).map(_dormRuleFromMap).toList(growable: false),
    members: _mapListOf(
      map['members'],
    ).map(_dormMemberFromMap).toList(growable: false),
    rulesSettings: settings,
    events: _mapListOf(
      map['events'],
    ).map(_dormEventFromMap).toList(growable: false),
    invites: _mapListOf(
      map['invites'],
    ).map(_dormInviteFromMap).toList(growable: false),
    locationAnchor: _dormLocationAnchorFromMap(map['locationAnchor']),
    earnedDormBadgeIds: earnedDormBadgeIds.isEmpty
        ? const <String>['no-trouble-room', 'no-wake-room']
        : earnedDormBadgeIds,
    pendingRuleProposal: _dormPendingRuleProposalFromMap(
      map['pendingRuleProposal'],
    ),
  );
}

Map<String, List<AssistantMessage>> _assistantMessagesFromPayload(
  dynamic value,
) {
  if (value is Map) {
    return value.map<String, List<AssistantMessage>>(
      (dynamic key, dynamic item) => MapEntry<String, List<AssistantMessage>>(
        key.toString(),
        _mapListOf(
          item,
        ).map(ModelSerializers.assistantMessageFromMap).toList(growable: false),
      ),
    );
  }
  final List<Map<String, dynamic>> items = _mapListOf(value);
  final Map<String, List<AssistantMessage>> grouped =
      <String, List<AssistantMessage>>{};
  for (final Map<String, dynamic> item in items) {
    final AssistantMessage message = ModelSerializers.assistantMessageFromMap(
      item,
    );
    grouped
        .putIfAbsent(message.threadId, () => <AssistantMessage>[])
        .add(message);
  }
  return grouped;
}

PendingSleepMemoBanner? _pendingSleepMemoBannerFromUserState(
  Map<String, dynamic> userState,
) {
  final Map<String, dynamic> sleepCapture = _mapOf(userState['sleepCapture']);
  final Map<String, dynamic> pending = _mapOf(
    sleepCapture['pendingMemoBanner'],
  );
  if (pending.isEmpty) {
    return null;
  }
  return ModelSerializers.pendingSleepMemoBannerFromMap(pending);
}

class _SnapshotData {
  const _SnapshotData({
    required this.user,
    required this.settings,
    required this.dorm,
    required this.sessions,
    required this.dreams,
    required this.sleepCaptureRecords,
    required this.pendingSleepMemoBanner,
    required this.notifications,
    required this.threads,
    required this.messagesByThread,
    required this.cardSnapshots,
    required this.userState,
  });

  final UserProfile user;
  final UserSettings settings;
  final Dorm dorm;
  final List<SleepSession> sessions;
  final List<DreamEntry> dreams;
  final List<SleepCaptureRecord> sleepCaptureRecords;
  final PendingSleepMemoBanner? pendingSleepMemoBanner;
  final List<NotificationItem> notifications;
  final List<AssistantThread> threads;
  final Map<String, List<AssistantMessage>> messagesByThread;
  final Map<String, Map<String, dynamic>> cardSnapshots;
  final Map<String, dynamic> userState;

  factory _SnapshotData.fromPayload(
    Map<String, dynamic> payload,
    String fallbackUid,
  ) {
    final Map<String, dynamic> root = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : payload;
    final UserProfile user = ModelSerializers.userProfileFromMap(
      _mapOf(root['user']).isEmpty
          ? ModelSerializers.userProfileToMap(
              buildDefaultUserProfile().copyWith(
                uid: fallbackUid.isEmpty
                    ? buildDefaultUserProfile().uid
                    : fallbackUid,
                clearDormId: true,
              ),
            )
          : _mapOf(root['user']),
    );
    return _SnapshotData(
      user: user,
      userState: _mapOf(root['userState']),
      settings: ModelSerializers.userSettingsFromMap(
        _mapOf(root['settings']).isEmpty
            ? ModelSerializers.userSettingsToMap(buildDefaultUserSettings())
            : _mapOf(root['settings']),
      ),
      dorm: _dormFromMap(_mapOf(root['dorm']), user.uid),
      sessions: _mapListOf(
        root['sleepSessions'],
      ).map(ModelSerializers.sleepSessionFromMap).toList(growable: false),
      dreams: _mapListOf(
        root['dreamEntries'],
      ).map(ModelSerializers.dreamEntryFromMap).toList(growable: false),
      sleepCaptureRecords: _mapListOf(
        root['sleepCaptureRecords'],
      ).map(ModelSerializers.sleepCaptureRecordFromMap).toList(growable: false),
      pendingSleepMemoBanner: _pendingSleepMemoBannerFromUserState(
        _mapOf(root['userState']),
      ),
      notifications: _mapListOf(
        root['notifications'],
      ).map(_notificationFromMap).toList(growable: false),
      threads: _mapListOf(
        root['assistantThreads'],
      ).map(ModelSerializers.assistantThreadFromMap).toList(growable: false),
      messagesByThread: _assistantMessagesFromPayload(
        root['assistantMessages'],
      ),
      cardSnapshots: _cardSnapshotsFromPayload(root['cardSnapshots']),
    );
  }
}

class CloudBaseAuthRepository extends ChangeNotifier implements AuthRepository {
  CloudBaseAuthRepository({
    required AppEnvironment environment,
    required CloudBaseAuthClient authClient,
    required CloudBaseAppApiClient appApiClient,
    required CloudBaseSnapshotStore snapshotStore,
    VerifiedPhoneIdentityStore? verifiedPhoneStore,
    CloudBaseAuthProfileCacheStore? authProfileCacheStore,
  }) : _environment = environment,
       _authClient = authClient,
       _appApiClient = appApiClient,
       _sessionCoordinator = appApiClient.sessionCoordinator,
       _snapshotStore = snapshotStore,
       _verifiedPhoneStore = verifiedPhoneStore ?? VerifiedPhoneIdentityStore(),
       _authProfileCacheStore =
           authProfileCacheStore ?? CloudBaseAuthProfileCacheStore() {
    _snapshotStore.addListener(_syncFromSnapshot);
    _currentUser = _signedOutProfile();
  }

  final AppEnvironment _environment;
  final CloudBaseAuthClient _authClient;
  final CloudBaseAppApiClient _appApiClient;
  final CloudBaseSessionCoordinator _sessionCoordinator;
  final CloudBaseSnapshotStore _snapshotStore;
  final VerifiedPhoneIdentityStore _verifiedPhoneStore;
  final CloudBaseAuthProfileCacheStore _authProfileCacheStore;

  late UserProfile _currentUser;
  bool _isAuthenticating = false;
  Future<UserProfile>? _authenticationInFlight;
  bool _hasCompletedInitialAuthBootstrap = false;
  String? _lastAuthError;
  DateTime? _lastSuccessfulAuthAt;
  VerifiedPhoneIdentity? _cachedVerifiedIdentity;
  UserProfile? _cachedAuthProfile;
  bool _currentUserRestoredFromAuthProfileCache = false;
  bool _hasPendingEquippedBadgeId = false;
  String? _pendingEquippedBadgeId;
  bool _hasPendingSelectedDormBadgeId = false;
  String? _pendingSelectedDormBadgeId;
  static const Duration _authRevalidationInterval = Duration(minutes: 5);

  @override
  UserProfile get currentUser => _currentUser;

  @override
  bool get isAuthenticated => _currentUser.uid.isNotEmpty;

  @override
  bool get hasVerifiedPhoneIdentity {
    if (_currentUser.uid.isEmpty) {
      return false;
    }
    if (_currentUser.phoneNumber?.trim().isNotEmpty == true) {
      return true;
    }
    final VerifiedPhoneIdentity? cached = _cachedVerifiedIdentity;
    return cached != null &&
        cached.subject == _currentUser.uid &&
        cached.phoneNumber.trim().isNotEmpty;
  }

  bool _phoneIdentityResolvableFromLocalProfile() {
    if (_currentUser.phoneNumber?.trim().isNotEmpty == true) {
      return true;
    }
    final VerifiedPhoneIdentity? cached = _cachedVerifiedIdentity;
    return cached != null &&
        cached.subject == _currentUser.uid &&
        cached.phoneNumber.trim().isNotEmpty;
  }

  void _mergePhoneFromCachedVerifiedIdentity() {
    final VerifiedPhoneIdentity? v = _cachedVerifiedIdentity;
    if (v == null || v.subject != _currentUser.uid) {
      return;
    }
    if (_currentUser.phoneNumber?.trim().isNotEmpty == true) {
      return;
    }
    _currentUser = _currentUser.copyWith(
      phoneNumber: v.phoneNumber,
      phoneLinkedAt: v.phoneLinkedAt ?? DateTime.now(),
    );
  }

  Future<void> _loadCachedAuthProfile() async {
    _cachedAuthProfile = await _authProfileCacheStore.read();
  }

  VerifiedPhoneIdentity? _identityFromCachedProfile() {
    final UserProfile? profile = _cachedAuthProfile;
    final String phone = profile?.phoneNumber?.trim() ?? '';
    if (profile == null || profile.uid.trim().isEmpty || phone.isEmpty) {
      return null;
    }
    return VerifiedPhoneIdentity(
      subject: profile.uid,
      phoneNumber: phone,
      phoneLinkedAt: profile.phoneLinkedAt,
    );
  }

  UserProfile _seedCloudBaseProfile({
    required String uid,
    String? phoneNumber,
    DateTime? phoneLinkedAt,
  }) {
    final UserProfile? cached = _cachedAuthProfile;
    final String? normalizedPhone = phoneNumber?.trim().isNotEmpty == true
        ? phoneNumber
        : null;
    if (cached != null && cached.uid == uid) {
      final String fallbackSeed =
          cached.avatarFallbackSeed?.trim().isNotEmpty == true
          ? cached.avatarFallbackSeed!
          : cached.displayName;
      _currentUserRestoredFromAuthProfileCache = true;
      return cached.copyWith(
        uid: uid,
        phoneNumber: normalizedPhone ?? cached.phoneNumber,
        phoneLinkedAt: phoneLinkedAt ?? cached.phoneLinkedAt,
        avatarFallbackSeed: fallbackSeed,
      );
    }
    _currentUserRestoredFromAuthProfileCache = false;
    return _blankCloudBaseUserProfile(
      uid: uid,
      phoneNumber: normalizedPhone,
      phoneLinkedAt: phoneLinkedAt,
    );
  }

  Future<void> _persistCurrentUserToAuthProfileCache() async {
    if (_currentUser.uid.trim().isEmpty) {
      return;
    }
    final String fallbackSeed =
        _currentUser.avatarFallbackSeed?.trim().isNotEmpty == true
        ? _currentUser.avatarFallbackSeed!
        : _currentUser.displayName;
    final UserProfile profile = _currentUser.copyWith(
      avatarFallbackSeed: fallbackSeed,
    );
    await _authProfileCacheStore.write(profile);
    _cachedAuthProfile = profile;
  }

  Future<void> _clearAuthProfileCache() async {
    _cachedAuthProfile = null;
    await _authProfileCacheStore.clear();
  }

  @override
  bool get isAuthenticating => _isAuthenticating;

  @override
  bool get hasCompletedInitialAuthBootstrap =>
      _hasCompletedInitialAuthBootstrap;

  @override
  String? get lastAuthError => _lastAuthError;

  UserProfile _signedOutProfile() {
    return _blankCloudBaseUserProfile().copyWith(
      clearDormId: true,
      clearPhoneNumber: true,
      clearPhoneLinkedAt: true,
      clearAvatar: true,
      clearEquippedBadge: true,
      clearSelectedDormBadgeId: true,
      earnedBadgeIds: const <String>[],
    );
  }

  Future<UserProfile> _signOutAndReset() async {
    await _verifiedPhoneStore.clear();
    _cachedVerifiedIdentity = null;
    await _clearAuthProfileCache();
    await _sessionCoordinator.signOut();
    _snapshotStore.clear();
    _currentUser = _signedOutProfile();
    _currentUserRestoredFromAuthProfileCache = false;
    _lastAuthError = null;
    _lastSuccessfulAuthAt = null;
    return _currentUser;
  }

  Future<CloudBaseUserInfo?> _readCurrentCloudBaseUser(
    CloudBaseSession session,
  ) async {
    try {
      return await _authClient.getCurrentUser(
        accessToken: session.accessToken,
        deviceId: session.deviceId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistVerifiedPhoneIdentityLocally() async {
    if (_currentUser.uid.isEmpty ||
        _currentUser.phoneNumber?.trim().isEmpty == true) {
      return;
    }
    final VerifiedPhoneIdentity identity = VerifiedPhoneIdentity(
      subject: _currentUser.uid,
      phoneNumber: _currentUser.phoneNumber!.trim(),
      phoneLinkedAt: _currentUser.phoneLinkedAt,
    );
    await _verifiedPhoneStore.write(identity);
    _cachedVerifiedIdentity = identity;
  }

  Future<void> _persistVerifiedPhoneIdentityIfNeeded() async {
    await _persistVerifiedPhoneIdentityLocally();
    if (_cachedVerifiedIdentity == null || !_appApiClient.isConfigured) {
      return;
    }
    try {
      await _appApiClient.post(
        '/api/profile/save',
        body: <String, dynamic>{
          'profile': <String, dynamic>{
            'phoneNumber': _currentUser.phoneNumber,
            'phoneLinkedAt':
                _currentUser.phoneLinkedAt?.toIso8601String() ??
                DateTime.now().toIso8601String(),
          },
        },
      );
      await _snapshotStore.refresh();
      _syncFromSnapshot();
    } catch (_) {
      // The server bootstrap flow will retry this repair on the next read.
    }
  }

  @override
  Future<UserProfile> signInAnonymously() => ensureAuthenticated();

  @override
  Future<UserProfile> ensureAuthenticated() => _ensureAuthenticated();

  Future<UserProfile> _ensureAuthenticated({bool forceRefresh = false}) async {
    final Future<UserProfile>? inFlight = _authenticationInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final Future<UserProfile> authenticationFuture = _performAuthentication(
      forceRefresh: forceRefresh,
    );
    _authenticationInFlight = authenticationFuture;
    try {
      return await authenticationFuture;
    } finally {
      if (identical(_authenticationInFlight, authenticationFuture)) {
        _authenticationInFlight = null;
      }
    }
  }

  Future<UserProfile> _performAuthentication({
    required bool forceRefresh,
  }) async {
    if (!_environment.usesCloudBase) {
      _hasCompletedInitialAuthBootstrap = true;
      return _currentUser.uid.isNotEmpty
          ? _currentUser
          : buildDefaultUserProfile();
    }
    if (!forceRefresh && _canReuseCachedAuthState()) {
      return _currentUser;
    }

    _isAuthenticating = true;
    _lastAuthError = null;
    notifyListeners();
    try {
      if (!_environment.hasCloudBaseAuthConfig) {
        _lastAuthError =
            'CloudBase authentication is not configured. The local account remains signed in.';
        return _currentUser;
      }

      _cachedVerifiedIdentity = await _verifiedPhoneStore.read();
      await _loadCachedAuthProfile();
      _cachedVerifiedIdentity ??= _identityFromCachedProfile();
      if (_cachedVerifiedIdentity != null) {
        await _verifiedPhoneStore.write(_cachedVerifiedIdentity!);
      }

      CloudBaseSession? storedSession = await _sessionCoordinator
          .restoreSession();
      final String principalSubject =
          _cachedVerifiedIdentity?.subject ??
          _cachedAuthProfile?.uid ??
          storedSession?.subject ??
          '';
      if (principalSubject.isEmpty) {
        _currentUser = _signedOutProfile();
        return _currentUser;
      }

      final VerifiedPhoneIdentity? identity = _cachedVerifiedIdentity;
      if (_currentUser.uid != principalSubject) {
        _currentUser = _seedCloudBaseProfile(
          uid: principalSubject,
          phoneNumber: identity?.subject == principalSubject
              ? identity?.phoneNumber
              : _cachedAuthProfile?.phoneNumber,
          phoneLinkedAt: identity?.subject == principalSubject
              ? identity?.phoneLinkedAt
              : _cachedAuthProfile?.phoneLinkedAt,
        );
      }
      _mergePhoneFromCachedVerifiedIdentity();
      _lastSuccessfulAuthAt = DateTime.now();

      // Versions before the account-integrity fix could persist a token/session
      // record `id` as the user subject after refresh. The durable verified
      // phone/profile identity is the account anchor. A still-valid token must
      // also confirm that identity before its local metadata is repaired.
      if (storedSession != null &&
          storedSession.subject.trim() != principalSubject) {
        final bool tokenNeedsRefresh = !DateTime.now().isBefore(
          storedSession.expiresAt.subtract(const Duration(minutes: 5)),
        );
        if (!tokenNeedsRefresh) {
          final CloudBaseUserInfo? storedTokenUser =
              await _readCurrentCloudBaseUser(storedSession);
          if (storedTokenUser == null ||
              storedTokenUser.subject.trim() != principalSubject) {
            _lastAuthError = _transientAuthWarningMessage();
            return _currentUser;
          }
        }
        try {
          await _sessionCoordinator.installSession(
            storedSession.copyWith(subject: principalSubject),
          );
          storedSession = await _sessionCoordinator.restoreSession();
        } catch (_) {
          _lastAuthError = _transientAuthWarningMessage();
          return _currentUser;
        }
      }

      if (storedSession == null || storedSession.subject != principalSubject) {
        _lastAuthError = _transientAuthWarningMessage();
        return _currentUser;
      }

      CloudBaseSession activeSession = storedSession;
      bool tokenAvailable = true;
      try {
        activeSession = await _sessionCoordinator.requireFreshSession();
      } catch (_) {
        // Transport credentials are replaceable. Their failure must never
        // delete or sign out the durable account principal.
        tokenAvailable = false;
        _lastAuthError = _transientAuthWarningMessage();
      }

      if (!tokenAvailable) {
        return _currentUser;
      }

      final CloudBaseUserInfo? restoredInfo =
          !_phoneIdentityResolvableFromLocalProfile()
          ? await _readCurrentCloudBaseUser(activeSession)
          : null;
      if (restoredInfo != null) {
        _currentUser = _currentUser.copyWith(
          uid: principalSubject,
          displayName: restoredInfo.name?.trim().isNotEmpty == true
              ? restoredInfo.name
              : _currentUser.displayName,
          phoneNumber: restoredInfo.phoneNumber?.trim().isNotEmpty == true
              ? restoredInfo.phoneNumber
              : _currentUser.phoneNumber,
          phoneLinkedAt: restoredInfo.phoneNumber?.trim().isNotEmpty == true
              ? (_currentUser.phoneLinkedAt ?? DateTime.now())
              : _currentUser.phoneLinkedAt,
          avatarUrl: restoredInfo.picture?.trim().isNotEmpty == true
              ? restoredInfo.picture
              : _currentUser.avatarUrl,
        );
      }
      _mergePhoneFromCachedVerifiedIdentity();
      await _persistVerifiedPhoneIdentityLocally();
      await _persistCurrentUserToAuthProfileCache();

      if (_appApiClient.isConfigured) {
        try {
          await _snapshotStore.refresh();
          _syncFromSnapshot();
          _mergePhoneFromCachedVerifiedIdentity();
          await _persistVerifiedPhoneIdentityLocally();
          await _persistCurrentUserToAuthProfileCache();
          if (_snapshotStore.lastError != null) {
            _lastAuthError = _transientAuthWarningMessage();
          } else {
            _lastAuthError = null;
          }
        } catch (_) {
          _lastAuthError = _transientAuthWarningMessage();
        }
      }
      return _currentUser;
    } catch (_) {
      _lastAuthError = _transientAuthWarningMessage();
      return _currentUser;
    } finally {
      _isAuthenticating = false;
      _hasCompletedInitialAuthBootstrap = true;
      notifyListeners();
    }
  }

  bool _canReuseCachedAuthState() {
    if (!_hasCompletedInitialAuthBootstrap) {
      return false;
    }
    if (!hasVerifiedPhoneIdentity) {
      return false;
    }
    final DateTime? lastSuccess = _lastSuccessfulAuthAt;
    if (lastSuccess == null) {
      return false;
    }
    return DateTime.now().difference(lastSuccess) < _authRevalidationInterval;
  }

  String _transientAuthWarningMessage() {
    return '\u7f51\u7edc\u6ce2\u52a8\u5bfc\u81f4\u767b\u5f55\u72b6\u6001\u540c\u6b65\u5931\u8d25\uff0c\u5df2\u4fdd\u7559\u767b\u5f55\u72b6\u6001\uff0c\u7a0d\u540e\u4f1a\u81ea\u52a8\u91cd\u8bd5\u3002';
  }

  @override
  Future<UserProfile> retryAuthentication() async {
    _lastAuthError = null;
    _lastSuccessfulAuthAt = null;
    notifyListeners();
    return _ensureAuthenticated(forceRefresh: true);
  }

  @override
  Future<void> signOut() async {
    await _signOutAndReset();
    notifyListeners();
  }

  @override
  Future<void> updateProfile({
    required String displayName,
    required String tagline,
    required String role,
  }) async {
    final UserProfile next = (await ensureAuthenticated()).copyWith(
      displayName: displayName,
      tagline: tagline,
      role: role,
      avatarFallbackSeed: displayName,
    );
    _currentUser = next;
    notifyListeners();
    if (_appApiClient.isConfigured) {
      try {
        await _appApiClient.post(
          '/api/profile/save',
          body: <String, dynamic>{'profile': _profileSavePatch(next)},
        );
        await _snapshotStore.refresh();
      } catch (error) {
        _lastAuthError = error.toString();
        notifyListeners();
      }
    }
  }

  @override
  Future<void> updateBadgePreferences({
    required List<String> earnedBadgeIds,
    String? equippedBadgeId,
    bool clearEquippedBadge = false,
  }) async {
    final UserProfile next =
        (_currentUser.uid.isNotEmpty
                ? _currentUser
                : await ensureAuthenticated())
            .copyWith(
              earnedBadgeIds: earnedBadgeIds,
              equippedBadgeId: equippedBadgeId,
              clearEquippedBadge: clearEquippedBadge,
            );
    if (_appApiClient.isConfigured) {
      _hasPendingEquippedBadgeId = true;
      _pendingEquippedBadgeId = next.equippedBadgeId;
    }
    _currentUser = next;
    notifyListeners();
    if (_appApiClient.isConfigured) {
      try {
        await _appApiClient.post(
          '/api/profile/save',
          body: <String, dynamic>{
            'profile': <String, dynamic>{
              'earnedBadgeIds': next.earnedBadgeIds,
              'equippedBadgeId': next.equippedBadgeId,
            },
          },
        );
        await _snapshotStore.refresh();
        _currentUser = _currentUser.copyWith(
          earnedBadgeIds: next.earnedBadgeIds,
          equippedBadgeId: next.equippedBadgeId,
          clearEquippedBadge: next.equippedBadgeId == null,
        );
        notifyListeners();
      } catch (error) {
        _lastAuthError = error.toString();
        notifyListeners();
        rethrow;
      }
    }
  }

  @override
  Future<void> updateDormBadgeVisibility({
    required bool showDormPulseBadge,
  }) async {
    final UserProfile next =
        (_currentUser.uid.isNotEmpty
                ? _currentUser
                : await ensureAuthenticated())
            .copyWith(showDormPulseBadge: showDormPulseBadge);
    _currentUser = next;
    notifyListeners();
    if (_appApiClient.isConfigured) {
      try {
        await _appApiClient.post(
          '/api/profile/save',
          body: <String, dynamic>{
            'profile': <String, dynamic>{
              'showDormPulseBadge': next.showDormPulseBadge,
            },
          },
        );
        await _snapshotStore.refresh();
        _currentUser = _currentUser.copyWith(
          showDormPulseBadge: next.showDormPulseBadge,
        );
        notifyListeners();
      } catch (error) {
        _lastAuthError = error.toString();
        notifyListeners();
        rethrow;
      }
    }
  }

  @override
  Future<void> updateDormBadgeSelection({
    String? selectedDormBadgeId,
    bool clearSelectedDormBadgeId = false,
  }) async {
    final UserProfile next =
        (_currentUser.uid.isNotEmpty
                ? _currentUser
                : await ensureAuthenticated())
            .copyWith(
              selectedDormBadgeId: selectedDormBadgeId,
              clearSelectedDormBadgeId: clearSelectedDormBadgeId,
            );
    if (_appApiClient.isConfigured) {
      _hasPendingSelectedDormBadgeId = true;
      _pendingSelectedDormBadgeId = next.selectedDormBadgeId;
    }
    _currentUser = next;
    notifyListeners();
    if (_appApiClient.isConfigured) {
      try {
        await _appApiClient.post(
          '/api/profile/save',
          body: <String, dynamic>{
            'profile': <String, dynamic>{
              'selectedDormBadgeId': next.selectedDormBadgeId,
            },
          },
        );
        await _snapshotStore.refresh();
        _currentUser = _currentUser.copyWith(
          selectedDormBadgeId: next.selectedDormBadgeId,
          clearSelectedDormBadgeId: next.selectedDormBadgeId == null,
        );
        notifyListeners();
      } catch (error) {
        _lastAuthError = error.toString();
        notifyListeners();
        rethrow;
      }
    }
  }

  Future<void> saveProfileBundle({
    required UserProfile profile,
    required UserSettings settings,
  }) async {
    _currentUser = profile;
    notifyListeners();
    if (!_appApiClient.isConfigured) {
      return;
    }
    try {
      await _appApiClient.post(
        '/api/profile/save',
        body: <String, dynamic>{
          'profile': _profileSavePatch(profile),
          'settings': ModelSerializers.userSettingsToMap(settings),
        },
      );
      await _snapshotStore.refresh();
      _syncFromSnapshot();
    } catch (error) {
      _lastAuthError = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  @override
  Future<void> updateAvatar({
    required String? avatarPath,
    required Uint8List? avatarBytes,
  }) async {
    final UserProfile previous = await ensureAuthenticated();
    _currentUser = previous.copyWith(
      avatarPath: avatarPath,
      avatarBytes: avatarBytes,
      avatarUrl: previous.avatarUrl,
      avatarStoragePath: previous.avatarStoragePath,
    );
    notifyListeners();
    if (_appApiClient.isConfigured) {
      try {
        final Map<String, dynamic> result = await _appApiClient.post(
          '/api/profile/avatar',
          body: <String, dynamic>{
            'avatarPath': avatarPath,
            'avatarBase64': avatarBytes == null
                ? null
                : base64Encode(avatarBytes),
            'fileName': avatarPath?.split('/').last.split('\\').last,
          },
        );
        final Map<String, dynamic> resultProfile =
            _mapOf(result['profile']).isNotEmpty
            ? _mapOf(result['profile'])
            : result;
        final String? nextAvatarUrl = _nonEmptyString(
          resultProfile['avatarUrl'],
        );
        final String? nextAvatarStoragePath = _nonEmptyString(
          resultProfile['avatarStoragePath'],
        );
        if (avatarBytes != null &&
            (nextAvatarStoragePath == null || nextAvatarUrl == null)) {
          throw const CloudBaseAppApiException(
            message: 'Avatar upload did not return a persisted file.',
          );
        }
        await _snapshotStore.refresh();
        _currentUser = _currentUser.copyWith(
          avatarPath:
              _nonEmptyString(resultProfile['avatarPath']) ?? avatarPath,
          avatarBytes: avatarBytes,
          avatarUrl: nextAvatarUrl ?? _currentUser.avatarUrl,
          avatarStoragePath:
              nextAvatarStoragePath ?? _currentUser.avatarStoragePath,
        );
        await _persistCurrentUserToAuthProfileCache();
        notifyListeners();
      } catch (error) {
        _currentUser = previous;
        _lastAuthError = error.toString();
        notifyListeners();
        rethrow;
      }
    }
  }

  @override
  Future<PhoneVerificationChallenge> sendPhoneVerificationCode(
    String phoneNumber, {
    PhoneVerificationTarget target = PhoneVerificationTarget.any,
    String? captchaToken,
  }) async {
    _requireCloudBaseAuthConfig();
    final String normalizedPhoneNumber = normalizeCloudBasePhoneNumber(
      phoneNumber,
    );
    final String deviceId = await _sessionCoordinator.ensureDeviceId();
    try {
      final CloudBasePhoneVerificationStart result = await _authClient
          .sendPhoneVerificationCode(
            phoneNumber: normalizedPhoneNumber,
            deviceId: deviceId,
            target: _verificationTargetValue(target),
            captchaToken: captchaToken,
          );
      final PhoneVerificationChallenge challenge = PhoneVerificationChallenge(
        verificationId: result.verificationId,
        expiresIn: result.expiresIn,
        isExistingUser: result.isUser,
      );
      if (target == PhoneVerificationTarget.newUser &&
          challenge.isExistingUser) {
        _throwPhoneTargetMismatch('该手机号已注册，请直接登录。');
      }
      if (target == PhoneVerificationTarget.existingUser &&
          !challenge.isExistingUser) {
        _throwPhoneTargetMismatch('未找到该手机号，请先注册。');
      }
      _lastAuthError = null;
      notifyListeners();
      return challenge;
    } on AuthPhoneTargetMismatchException {
      rethrow;
    } on CloudBaseAuthException catch (error) {
      if (_isCaptchaRequired(error)) {
        _throwCaptchaRequired();
      }
      final String userMessage = _phoneAuthErrorMessage(
        error,
        action: 'sendCode',
        target: target,
      );
      if (_isSendCodeTargetMismatchMessage(userMessage, target)) {
        _throwPhoneTargetMismatch(userMessage);
      }
      _throwAuthFlowError(userMessage);
    } catch (error) {
      _throwAuthFlowError(
        _unexpectedPhoneAuthError(
          error,
          fallbackMessage:
              '\u9a8c\u8bc1\u7801\u53d1\u9001\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5\u3002',
        ),
      );
    }
  }

  @override
  Future<PhoneVerificationProof> verifyPhoneCode({
    required String verificationId,
    required String code,
  }) async {
    _requireCloudBaseAuthConfig();
    final String verifiedDeviceId = await _sessionCoordinator.ensureDeviceId();
    try {
      final CloudBasePhoneVerificationResult verificationResult =
          await _authClient.verifyPhoneCode(
            verificationId: verificationId,
            code: code,
            deviceId: verifiedDeviceId,
          );
      return PhoneVerificationProof(
        verificationToken: verificationResult.verificationToken,
        expiresIn: verificationResult.expiresIn,
      );
    } on CloudBaseAuthException catch (error) {
      _throwAuthFlowError(_phoneAuthErrorMessage(error, action: 'verifyCode'));
    } catch (error) {
      _throwAuthFlowError(
        _unexpectedPhoneAuthError(error, fallbackMessage: '验证码校验失败，请稍后再试。'),
      );
    }
  }

  @override
  Future<void> signInWithPassword({
    required String phoneNumber,
    required String password,
    String? captchaToken,
  }) async {
    _requireCloudBaseAuthConfig();
    final String normalizedPhoneNumber = normalizeCloudBasePhoneNumber(
      phoneNumber,
    );
    final String deviceId = await _sessionCoordinator.ensureDeviceId();
    try {
      final CloudBaseAuthTokenResponse session = await _authClient
          .signInWithPassword(
            phoneNumber: normalizedPhoneNumber,
            password: password,
            deviceId: deviceId,
            captchaToken: captchaToken,
          );
      await _completePhoneAuthentication(
        session: session,
        deviceId: deviceId,
        requestedPhoneNumber: normalizedPhoneNumber,
      );
    } on CloudBaseAuthException catch (error) {
      if (_isCaptchaRequired(error)) {
        _throwCaptchaRequired();
      }
      _throwAuthFlowError(
        _phoneAuthErrorMessage(error, action: 'passwordSignIn'),
      );
    } catch (error) {
      _throwAuthFlowError(
        _unexpectedPhoneAuthError(
          error,
          fallbackMessage:
              '\u5bc6\u7801\u767b\u5f55\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5\u3002',
        ),
      );
    }
  }

  @override
  Future<void> signInWithPhoneCode({
    required String phoneNumber,
    required String verificationId,
    required String code,
    String? captchaToken,
  }) async {
    _requireCloudBaseAuthConfig();
    final String requestedPhoneNumber = normalizeCloudBasePhoneNumber(
      phoneNumber,
    );
    final String verifiedDeviceId = await _sessionCoordinator.ensureDeviceId();
    try {
      final CloudBasePhoneVerificationResult verificationResult =
          await _authClient.verifyPhoneCode(
            verificationId: verificationId,
            code: code,
            deviceId: verifiedDeviceId,
          );
      final CloudBaseAuthTokenResponse session = await _authClient
          .signInWithVerificationToken(
            verificationToken: verificationResult.verificationToken,
            deviceId: verifiedDeviceId,
            captchaToken: captchaToken,
          );
      await _completePhoneAuthentication(
        session: session,
        deviceId: verifiedDeviceId,
        requestedPhoneNumber: requestedPhoneNumber,
      );
    } on CloudBaseAuthException catch (error) {
      if (_isCaptchaRequired(error)) {
        _throwCaptchaRequired();
      }
      _throwAuthFlowError(_phoneAuthErrorMessage(error, action: 'codeSignIn'));
    } catch (error) {
      _throwAuthFlowError(
        _unexpectedPhoneAuthError(
          error,
          fallbackMessage:
              '\u9a8c\u8bc1\u7801\u767b\u5f55\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5\u3002',
        ),
      );
    }
  }

  @override
  Future<void> registerWithPhone({
    required String phoneNumber,
    required String verificationId,
    required String code,
    required String password,
  }) async {
    _requireCloudBaseAuthConfig();
    final String requestedPhoneNumber = normalizeCloudBasePhoneNumber(
      phoneNumber,
    );
    final String verifiedDeviceId = await _sessionCoordinator.ensureDeviceId();
    try {
      final CloudBasePhoneVerificationResult verificationResult =
          await _authClient.verifyPhoneCode(
            verificationId: verificationId,
            code: code,
            deviceId: verifiedDeviceId,
          );
      final CloudBaseAuthTokenResponse session = await _authClient
          .signUpWithVerificationToken(
            phoneNumber: requestedPhoneNumber,
            verificationToken: verificationResult.verificationToken,
            password: password,
            deviceId: verifiedDeviceId,
          );
      await _completePhoneAuthentication(
        session: session,
        deviceId: verifiedDeviceId,
        requestedPhoneNumber: requestedPhoneNumber,
      );
    } on CloudBaseAuthException catch (error) {
      _throwAuthFlowError(_phoneAuthErrorMessage(error, action: 'register'));
    } catch (error) {
      _throwAuthFlowError(
        _unexpectedPhoneAuthError(
          error,
          fallbackMessage:
              '\u6ce8\u518c\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5\u3002',
        ),
      );
    }
  }

  @override
  Future<void> resetPasswordWithPhone({
    required String phoneNumber,
    required String verificationId,
    required String code,
    required String newPassword,
  }) async {
    final PhoneVerificationProof proof = await verifyPhoneCode(
      verificationId: verificationId,
      code: code,
    );
    await resetPasswordWithVerificationToken(
      phoneNumber: phoneNumber,
      verificationToken: proof.verificationToken,
      newPassword: newPassword,
    );
  }

  @override
  Future<void> resetPasswordWithVerificationToken({
    required String phoneNumber,
    required String verificationToken,
    required String newPassword,
  }) async {
    _requireCloudBaseAuthConfig();
    final String requestedPhoneNumber = normalizeCloudBasePhoneNumber(
      phoneNumber,
    );
    final String verifiedDeviceId = await _sessionCoordinator.ensureDeviceId();
    try {
      await _authClient.resetPasswordWithVerificationToken(
        phoneNumber: requestedPhoneNumber,
        verificationToken: verificationToken,
        newPassword: newPassword,
        deviceId: verifiedDeviceId,
      );
      final CloudBaseAuthTokenResponse session = await _authClient
          .signInWithPassword(
            phoneNumber: requestedPhoneNumber,
            password: newPassword,
            deviceId: verifiedDeviceId,
          );
      await _completePhoneAuthentication(
        session: session,
        deviceId: verifiedDeviceId,
        requestedPhoneNumber: requestedPhoneNumber,
      );
    } on CloudBaseAuthException catch (error) {
      _throwAuthFlowError(
        _phoneAuthErrorMessage(error, action: 'resetPassword'),
      );
    } catch (error) {
      _throwAuthFlowError(
        _unexpectedPhoneAuthError(
          error,
          fallbackMessage:
              '\u91cd\u7f6e\u5bc6\u7801\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5\u3002',
        ),
      );
    }
  }

  @override
  Future<void> authenticateWithPhone({
    required String phoneNumber,
    required String verificationId,
    required String code,
    required bool isExistingUser,
  }) async {
    if (!isExistingUser) {
      throw const AuthFlowException(
        '\u65b0\u8d26\u53f7\u9700\u8981\u901a\u8fc7\u6ce8\u518c\u5165\u53e3\u5b8c\u6210\u521b\u5efa\u5e76\u8bbe\u7f6e\u5bc6\u7801\u3002',
      );
    }
    await signInWithPhoneCode(
      phoneNumber: phoneNumber,
      verificationId: verificationId,
      code: code,
    );
  }

  @override
  Future<AuthCaptchaChallenge> createCaptchaChallenge() async {
    _requireCloudBaseAuthConfig();
    final String deviceId = await _sessionCoordinator.ensureDeviceId();
    try {
      final CloudBaseCaptchaChallenge challenge = await _authClient
          .createCaptchaChallenge(deviceId: deviceId);
      return AuthCaptchaChallenge(
        token: challenge.token,
        imageData: challenge.imageData,
        expiresIn: challenge.expiresIn,
      );
    } on CloudBaseAuthException catch (error) {
      _throwAuthFlowError(
        _phoneAuthErrorMessage(error, action: 'captchaChallenge'),
      );
    } catch (error) {
      _throwAuthFlowError(
        _unexpectedPhoneAuthError(
          error,
          fallbackMessage:
              '\u56fe\u5f62\u9a8c\u8bc1\u7801\u52a0\u8f7d\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5\u3002',
        ),
      );
    }
  }

  @override
  Future<String> verifyCaptchaChallenge({
    required String token,
    required String code,
  }) async {
    _requireCloudBaseAuthConfig();
    final String deviceId = await _sessionCoordinator.ensureDeviceId();
    try {
      final String captchaToken = await _authClient.verifyCaptchaChallenge(
        token: token,
        code: code,
        deviceId: deviceId,
      );
      if (captchaToken.trim().isEmpty) {
        throw const AuthFlowException(
          '\u56fe\u5f62\u9a8c\u8bc1\u5931\u8d25\uff0c\u8bf7\u91cd\u65b0\u8f93\u5165\u3002',
        );
      }
      _lastAuthError = null;
      notifyListeners();
      return captchaToken;
    } on CloudBaseAuthException catch (error) {
      _throwAuthFlowError(
        _phoneAuthErrorMessage(error, action: 'captchaVerify'),
      );
    } catch (error) {
      _throwAuthFlowError(
        _unexpectedPhoneAuthError(
          error,
          fallbackMessage:
              '\u56fe\u5f62\u9a8c\u8bc1\u5931\u8d25\uff0c\u8bf7\u91cd\u65b0\u8f93\u5165\u3002',
        ),
      );
    }
  }

  void _requireCloudBaseAuthConfig() {
    if (_environment.hasCloudBaseAuthConfig) {
      return;
    }
    throw const AuthFlowException(
      'CloudBase \u624b\u673a\u53f7\u8ba4\u8bc1\u5c1a\u672a\u5b8c\u6210\u914d\u7f6e\u3002',
    );
  }

  String _verificationTargetValue(PhoneVerificationTarget target) {
    return switch (target) {
      PhoneVerificationTarget.any => 'ANY',
      PhoneVerificationTarget.existingUser => 'USER',
      PhoneVerificationTarget.newUser => 'NOT_USER',
    };
  }

  Future<void> _completePhoneAuthentication({
    required CloudBaseAuthTokenResponse session,
    required String deviceId,
    required String requestedPhoneNumber,
  }) async {
    CloudBaseUserInfo? info;
    try {
      info = await _authClient.getCurrentUser(
        accessToken: session.accessToken,
        deviceId: deviceId,
      );
    } catch (_) {
      info = null;
    }

    final String tokenSubject = session.subject.trim();
    final String verifiedSubject = info?.subject.trim() ?? '';
    if (tokenSubject.isNotEmpty &&
        verifiedSubject.isNotEmpty &&
        tokenSubject != verifiedSubject) {
      throw const AuthFlowException('登录凭证身份不一致，请重新登录。');
    }
    final String resolvedSubject = verifiedSubject.isNotEmpty
        ? verifiedSubject
        : tokenSubject;
    if (resolvedSubject.isEmpty) {
      throw const AuthFlowException('登录成功但未能确认账号身份，请重试。');
    }

    if (_currentUser.uid.isNotEmpty && _currentUser.uid != resolvedSubject) {
      _snapshotStore.clear();
    }
    await _sessionCoordinator.installSession(
      CloudBaseSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        subject: resolvedSubject,
        expiresAt: DateTime.now().add(Duration(seconds: session.expiresIn)),
        deviceId: deviceId,
        scope: session.scope,
        tokenType: session.tokenType.trim().isEmpty
            ? 'Bearer'
            : session.tokenType.trim(),
      ),
    );
    _lastAuthError = null;
    final bool hadCurrentUser = _currentUser.uid.isNotEmpty;
    final UserProfile baseProfile =
        hadCurrentUser && _currentUser.uid == resolvedSubject
        ? _currentUser
        : _seedCloudBaseProfile(
            uid: resolvedSubject,
            phoneNumber: requestedPhoneNumber,
            phoneLinkedAt: DateTime.now(),
          );
    _currentUser = baseProfile.copyWith(
      uid: resolvedSubject,
      displayName: info?.name ?? baseProfile.displayName,
      phoneNumber: info?.phoneNumber ?? requestedPhoneNumber,
      phoneLinkedAt: DateTime.now(),
      avatarUrl: info?.picture ?? baseProfile.avatarUrl,
    );
    _lastSuccessfulAuthAt = DateTime.now();
    _hasCompletedInitialAuthBootstrap = true;
    notifyListeners();
    await _persistVerifiedPhoneIdentityIfNeeded();
    await _persistCurrentUserToAuthProfileCache();
    await _safeRefreshSnapshot();
    _syncFromSnapshot();
  }

  Future<void> _safeRefreshSnapshot() async {
    if (!_appApiClient.isConfigured) {
      return;
    }
    try {
      await _snapshotStore.refresh();
    } catch (_) {
      // Snapshot refresh should not block a successful auth result.
    }
  }

  Never _throwAuthFlowError(String message) {
    _lastAuthError = _normalizePhoneAuthenticationError(message);
    notifyListeners();
    throw AuthFlowException(_lastAuthError!);
  }

  Never _throwPhoneTargetMismatch(String message) {
    _lastAuthError = _normalizePhoneAuthenticationError(message);
    notifyListeners();
    throw AuthPhoneTargetMismatchException(_lastAuthError!);
  }

  Never _throwCaptchaRequired() {
    _lastAuthError =
        '\u9700\u8981\u5148\u5b8c\u6210\u56fe\u5f62\u9a8c\u8bc1\u7801\u9a8c\u8bc1\u3002';
    notifyListeners();
    throw const AuthCaptchaRequiredException();
  }

  bool _isCaptchaRequired(CloudBaseAuthException error) {
    final String message = error.message.toLowerCase();
    final String code = (error.code ?? '').toLowerCase();
    return message.contains('captcha_required') ||
        message.contains('captcha required') ||
        code.contains('captcha_required');
  }

  String _phoneAuthErrorMessage(
    CloudBaseAuthException error, {
    required String action,
    PhoneVerificationTarget? target,
  }) {
    final String message = error.message.toLowerCase();
    final String code = (error.code ?? '').toLowerCase();
    final int? statusCode = error.statusCode;
    if (_isPasswordCredentialError(message, code, statusCode)) {
      return '\u8bf7\u68c0\u67e5\u624b\u673a\u53f7\u548c\u5bc6\u7801\u3002';
    }
    if (_isVerificationFailure(message, code)) {
      return '\u9a8c\u8bc1\u7801\u9519\u8bef\u6216\u5df2\u8fc7\u671f\uff0c\u8bf7\u91cd\u65b0\u83b7\u53d6\u540e\u518d\u8bd5\u3002';
    }
    if (message.contains('already') ||
        message.contains('exists') ||
        message.contains('duplicate') ||
        message.contains('registered') ||
        code.contains('already') ||
        code.contains('exists') ||
        code.contains('registered') ||
        code.contains('duplicate')) {
      return '\u8be5\u624b\u673a\u53f7\u5df2\u6ce8\u518c\uff0c\u8bf7\u76f4\u63a5\u767b\u5f55\u3002';
    }
    if (message.contains('not found') ||
        message.contains('not registered') ||
        code.contains('not_found') ||
        code.contains('user_not_found')) {
      return '\u672a\u627e\u5230\u8be5\u624b\u673a\u53f7\uff0c\u8bf7\u5148\u6ce8\u518c\u3002';
    }
    if (message.contains('password') || code.contains('password')) {
      if (action == 'passwordSignIn') {
        return '\u8bf7\u68c0\u67e5\u624b\u673a\u53f7\u548c\u5bc6\u7801\u3002';
      }
      return '\u5bc6\u7801\u6821\u9a8c\u5931\u8d25\uff0c\u8bf7\u68c0\u67e5\u540e\u91cd\u8bd5\u3002';
    }
    if (message.contains('captcha') || code.contains('captcha')) {
      return '\u9700\u8981\u5148\u5b8c\u6210\u56fe\u5f62\u9a8c\u8bc1\u7801\u9a8c\u8bc1\u3002';
    }
    if (message.contains('limit') ||
        message.contains('too many') ||
        code.contains('rate_limit')) {
      return '\u64cd\u4f5c\u8fc7\u4e8e\u9891\u7e41\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5\u3002';
    }
    return switch (action) {
      'sendCode' =>
        '\u9a8c\u8bc1\u7801\u53d1\u9001\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5\u3002',
      'passwordSignIn' =>
        '\u5bc6\u7801\u767b\u5f55\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5\u3002',
      'codeSignIn' =>
        '\u9a8c\u8bc1\u7801\u767b\u5f55\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5\u3002',
      'register' =>
        '\u6ce8\u518c\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5\u3002',
      'resetPassword' =>
        '\u91cd\u7f6e\u5bc6\u7801\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5\u3002',
      'captchaChallenge' =>
        '\u56fe\u5f62\u9a8c\u8bc1\u7801\u52a0\u8f7d\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5\u3002',
      'captchaVerify' =>
        '\u56fe\u5f62\u9a8c\u8bc1\u5931\u8d25\uff0c\u8bf7\u91cd\u65b0\u8f93\u5165\u3002',
      _ =>
        '\u624b\u673a\u53f7\u8ba4\u8bc1\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5\u3002',
    };
  }

  bool _isSendCodeTargetMismatchMessage(
    String message,
    PhoneVerificationTarget target,
  ) {
    return switch (target) {
      PhoneVerificationTarget.newUser =>
        message ==
            '\u8be5\u624b\u673a\u53f7\u5df2\u6ce8\u518c\uff0c\u8bf7\u76f4\u63a5\u767b\u5f55\u3002',
      PhoneVerificationTarget.existingUser =>
        message ==
            '\u672a\u627e\u5230\u8be5\u624b\u673a\u53f7\uff0c\u8bf7\u5148\u6ce8\u518c\u3002',
      PhoneVerificationTarget.any => false,
    };
  }

  bool _isPasswordCredentialError(
    String message,
    String code,
    int? statusCode,
  ) {
    return message.contains('password') ||
        message.contains('credential') ||
        message.contains('invalid login') ||
        message.contains('invalid_credentials') ||
        code.contains('password') ||
        code.contains('credential') ||
        code.contains('unauthorized') ||
        code.contains('invalid_credentials') ||
        statusCode == 401;
  }

  bool _isVerificationFailure(String message, String code) {
    return message.contains('verification code') ||
        message.contains('verification_code') ||
        message.contains('verification token') ||
        message.contains('otp') ||
        message.contains('one-time code') ||
        message.contains('invalid code') ||
        message.contains('code expired') ||
        message.contains('expired code') ||
        message.contains('sms code') ||
        code.contains('verification') ||
        code.contains('otp');
  }

  String _unexpectedPhoneAuthError(
    Object error, {
    required String fallbackMessage,
  }) {
    if (error is AuthFlowException) {
      return error.message;
    }
    final String normalized = _normalizePhoneAuthenticationError(
      error.toString(),
    );
    if (normalized.isEmpty || normalized == 'Bad state') {
      return fallbackMessage;
    }
    return normalized;
  }

  String _normalizePhoneAuthenticationError(String message) {
    final String cleaned = message
        .replaceFirst(RegExp(r'^Bad state:\s*'), '')
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .trim();
    return cleaned.isEmpty
        ? '\u624b\u673a\u53f7\u8ba4\u8bc1\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5\u3002'
        : cleaned;
  }

  void _syncFromSnapshot() {
    if (_snapshotStore.isRefreshing || !_snapshotStore.hasPayload) {
      return;
    }
    final Map<String, dynamic> root = _snapshotStore.payload['data'] is Map
        ? Map<String, dynamic>.from(_snapshotStore.payload['data'] as Map)
        : _snapshotStore.payload;
    final Map<String, dynamic> rawUser = _mapOf(root['user']);
    final String rawSnapshotUid = _stringOf(rawUser['uid']);
    if (rawSnapshotUid.isEmpty) {
      return;
    }
    if (_currentUser.uid.isNotEmpty && _currentUser.uid != rawSnapshotUid) {
      _lastAuthError = _transientAuthWarningMessage();
      return;
    }
    final _SnapshotData snapshot = _SnapshotData.fromPayload(
      _snapshotStore.payload,
      _currentUser.uid,
    );
    if (snapshot.user.uid.isEmpty) {
      return;
    }
    final String? snapshotPhone = snapshot.user.phoneNumber;
    final DateTime? snapshotPhoneLinkedAt = snapshot.user.phoneLinkedAt;
    final String? snapshotAvatarUrl = _avatarUrlForSnapshotMerge(
      currentUser: _currentUser,
      snapshotUser: snapshot.user,
      preferFreshSnapshotForCachedProfile:
          _currentUserRestoredFromAuthProfileCache,
    );
    final bool hasEquippedBadgeSnapshot = rawUser.containsKey(
      'equippedBadgeId',
    );
    String? nextEquippedBadgeId = hasEquippedBadgeSnapshot
        ? snapshot.user.equippedBadgeId
        : _currentUser.equippedBadgeId;
    bool clearEquippedBadge =
        hasEquippedBadgeSnapshot && snapshot.user.equippedBadgeId == null;
    if (_hasPendingEquippedBadgeId) {
      if (hasEquippedBadgeSnapshot &&
          snapshot.user.equippedBadgeId == _pendingEquippedBadgeId) {
        _hasPendingEquippedBadgeId = false;
        _pendingEquippedBadgeId = null;
      } else {
        nextEquippedBadgeId = _pendingEquippedBadgeId;
        clearEquippedBadge = _pendingEquippedBadgeId == null;
      }
    }
    final bool hasSelectedDormBadgeSnapshot = rawUser.containsKey(
      'selectedDormBadgeId',
    );
    String? nextSelectedDormBadgeId = hasSelectedDormBadgeSnapshot
        ? snapshot.user.selectedDormBadgeId
        : _currentUser.selectedDormBadgeId;
    bool clearSelectedDormBadgeId =
        hasSelectedDormBadgeSnapshot &&
        snapshot.user.selectedDormBadgeId == null;
    if (_hasPendingSelectedDormBadgeId) {
      if (hasSelectedDormBadgeSnapshot &&
          snapshot.user.selectedDormBadgeId == _pendingSelectedDormBadgeId) {
        _hasPendingSelectedDormBadgeId = false;
        _pendingSelectedDormBadgeId = null;
      } else {
        nextSelectedDormBadgeId = _pendingSelectedDormBadgeId;
        clearSelectedDormBadgeId = _pendingSelectedDormBadgeId == null;
      }
    }
    _currentUser = _currentUser.copyWith(
      uid: rawSnapshotUid,
      displayName: rawUser.containsKey('displayName')
          ? snapshot.user.displayName
          : _currentUser.displayName,
      tagline: rawUser.containsKey('tagline')
          ? snapshot.user.tagline
          : _currentUser.tagline,
      role: rawUser.containsKey('role')
          ? snapshot.user.role
          : _currentUser.role,
      earnedBadgeIds: rawUser.containsKey('earnedBadgeIds')
          ? snapshot.user.earnedBadgeIds
          : _currentUser.earnedBadgeIds,
      equippedBadgeId: nextEquippedBadgeId,
      clearEquippedBadge: clearEquippedBadge,
      showDormPulseBadge: rawUser.containsKey('showDormPulseBadge')
          ? snapshot.user.showDormPulseBadge
          : _currentUser.showDormPulseBadge,
      selectedDormBadgeId: nextSelectedDormBadgeId,
      clearSelectedDormBadgeId: clearSelectedDormBadgeId,
      dormId: snapshot.user.dormId,
      clearDormId:
          rawUser.containsKey('dormId') && snapshot.user.dormId == null,
      phoneNumber: snapshotPhone?.trim().isNotEmpty == true
          ? snapshotPhone
          : _currentUser.phoneNumber,
      phoneLinkedAt: snapshotPhoneLinkedAt ?? _currentUser.phoneLinkedAt,
      avatarUrl: snapshotAvatarUrl,
      avatarPath: snapshot.user.avatarPath,
      avatarStoragePath: snapshot.user.avatarStoragePath,
      avatarFallbackSeed: snapshot.user.avatarFallbackSeed,
    );
    _currentUserRestoredFromAuthProfileCache = false;
    _mergePhoneFromCachedVerifiedIdentity();
    unawaited(_persistCurrentUserToAuthProfileCache());
    notifyListeners();
  }

  @override
  void dispose() {
    _snapshotStore.removeListener(_syncFromSnapshot);
    super.dispose();
  }
}

class CloudBaseUserSettingsRepository extends ChangeNotifier
    implements UserSettingsRepository {
  CloudBaseUserSettingsRepository({
    required AuthRepository authRepository,
    required CloudBaseSnapshotStore snapshotStore,
    required CloudBaseAppApiClient appApiClient,
    UserSettings? initialSettings,
    UserSettingsCacheStore? cacheStore,
  }) : _authRepository = authRepository,
       _snapshotStore = snapshotStore,
       _appApiClient = appApiClient,
       _cacheStore = cacheStore {
    _snapshotStore.addListener(_applySnapshot);
    _settings = initialSettings ?? buildDefaultUserSettings();
    _lastSnapshotSettings = _settings;
  }

  final AuthRepository _authRepository;
  final CloudBaseSnapshotStore _snapshotStore;
  final CloudBaseAppApiClient _appApiClient;
  final UserSettingsCacheStore? _cacheStore;

  late UserSettings _settings;
  UserSettings? _lastSnapshotSettings;
  UserSettings? _pendingSettingsSave;
  NightMood? _pendingMoodOverride;
  List<String>? _pendingHomeQuickActionIds;
  bool? _pendingShowHomeQuickActions;

  @override
  UserSettings get currentSettings => _settings;

  @override
  void replaceLocalSettings(UserSettings settings) {
    _settings = settings;
    _cacheSettings(settings);
    notifyListeners();
  }

  @override
  Future<void> saveSettings(UserSettings settings) async {
    final UserSettings previousRemoteSettings =
        _lastSnapshotSettings ?? _settings;
    final NightMood? previousMood = previousRemoteSettings.selectedNightMood;
    final List<String> previousQuickActionIds = _settings.homeQuickActionIds;
    final bool previousShowHomeQuickActions = _settings.showHomeQuickActions;
    if (previousMood != settings.selectedNightMood) {
      _pendingMoodOverride = settings.selectedNightMood;
    }
    _pendingSettingsSave = settings;
    if (!_sameStringList(previousQuickActionIds, settings.homeQuickActionIds)) {
      _pendingHomeQuickActionIds = normalizeHomeQuickActionIds(
        settings.homeQuickActionIds,
      );
    }
    if (previousShowHomeQuickActions != settings.showHomeQuickActions) {
      _pendingShowHomeQuickActions = settings.showHomeQuickActions;
    }
    replaceLocalSettings(settings);
    if (!_appApiClient.isConfigured) {
      return;
    }
    try {
      await _authRepository.ensureAuthenticated();
      await _appApiClient.post(
        '/api/profile/save',
        body: <String, dynamic>{
          'settings': ModelSerializers.userSettingsToMap(settings),
        },
      );
      if (previousMood != settings.selectedNightMood) {
        await _appApiClient.post(
          '/api/profile/night-mood',
          body: <String, dynamic>{
            'selectedNightMood': settings.selectedNightMood?.name,
            'source': 'settings_save',
          },
        );
      }
      await _snapshotStore.refresh();
      if (_pendingMoodOverride == settings.selectedNightMood) {
        _pendingMoodOverride = null;
      }
    } catch (_) {
      // Keep local state so theme and flows can continue updating.
    }
  }

  void _applySnapshot() {
    if (_snapshotStore.isRefreshing || !_snapshotStore.hasPayload) {
      return;
    }
    final _SnapshotData snapshot = _SnapshotData.fromPayload(
      _snapshotStore.payload,
      _authRepository.currentUser.uid,
    );
    UserSettings incoming = _mergeEveningEncouragementIfServerOmitted(
      snapshot.settings,
    );
    _lastSnapshotSettings = incoming;
    incoming = _mergePendingSettingsSave(incoming);
    incoming = _mergePendingHomeQuickActionsIfServerOmitted(incoming);
    incoming = _mergePendingHomeQuickActionsVisibilityIfServerOmitted(incoming);
    if (_pendingMoodOverride != null &&
        incoming.selectedNightMood != _pendingMoodOverride &&
        _settings.selectedNightMood == _pendingMoodOverride) {
      _settings = incoming.copyWith(selectedNightMood: _pendingMoodOverride);
    } else {
      _settings = incoming;
      if (_pendingMoodOverride == incoming.selectedNightMood) {
        _pendingMoodOverride = null;
      }
    }
    _cacheSettings(_settings);
    notifyListeners();
  }

  void _cacheSettings(UserSettings settings) {
    final UserSettingsCacheStore? cacheStore = _cacheStore;
    if (cacheStore == null) {
      return;
    }
    unawaited(cacheStore.write(settings));
  }

  UserSettings _mergePendingSettingsSave(UserSettings incoming) {
    final UserSettings? pending = _pendingSettingsSave;
    if (pending == null) {
      return incoming;
    }
    if (_sameUserSettings(incoming, pending)) {
      _pendingSettingsSave = null;
      return incoming;
    }
    if (_sameUserSettings(_settings, pending)) {
      return pending;
    }
    _pendingSettingsSave = null;
    return incoming;
  }

  /// Remote snapshot may omit `eveningEncouragement*` until the backend persists them;
  /// keep the last local quote so the profile card does not clear after refresh.
  UserSettings _mergeEveningEncouragementIfServerOmitted(
    UserSettings incoming,
  ) {
    final String? prevLine = _settings.eveningEncouragementLine;
    final String? prevKey = _settings.eveningEncouragementPeriodKey;
    final NightMood? prevSnap = _settings.eveningEncouragementMoodSnapshot;
    if (prevLine != null &&
        prevKey != null &&
        incoming.eveningEncouragementLine == null) {
      return incoming.copyWith(
        eveningEncouragementPeriodKey: prevKey,
        eveningEncouragementLine: prevLine,
        eveningEncouragementMoodSnapshot: prevSnap,
      );
    }
    return incoming;
  }

  UserSettings _mergePendingHomeQuickActionsIfServerOmitted(
    UserSettings incoming,
  ) {
    final List<String>? pending = _pendingHomeQuickActionIds;
    if (pending == null) {
      return incoming;
    }
    if (_sameStringList(incoming.homeQuickActionIds, pending)) {
      _pendingHomeQuickActionIds = null;
      return incoming;
    }
    if (_sameStringList(_settings.homeQuickActionIds, pending)) {
      return incoming.copyWith(homeQuickActionIds: pending);
    }
    _pendingHomeQuickActionIds = null;
    return incoming;
  }

  UserSettings _mergePendingHomeQuickActionsVisibilityIfServerOmitted(
    UserSettings incoming,
  ) {
    final bool? pending = _pendingShowHomeQuickActions;
    if (pending == null) {
      return incoming;
    }
    if (incoming.showHomeQuickActions == pending) {
      _pendingShowHomeQuickActions = null;
      return incoming;
    }
    if (_settings.showHomeQuickActions == pending) {
      return incoming.copyWith(showHomeQuickActions: pending);
    }
    _pendingShowHomeQuickActions = null;
    return incoming;
  }

  bool _sameStringList(List<String> first, List<String> second) {
    if (first.length != second.length) {
      return false;
    }
    for (var index = 0; index < first.length; index += 1) {
      if (first[index] != second[index]) {
        return false;
      }
    }
    return true;
  }

  bool _sameUserSettings(UserSettings first, UserSettings second) {
    return first.sleepGoalHours == second.sleepGoalHours &&
        first.bedtimeReminderEnabled == second.bedtimeReminderEnabled &&
        first.morningReminderEnabled == second.morningReminderEnabled &&
        first.dormAlertsEnabled == second.dormAlertsEnabled &&
        first.bedtimeReminder == second.bedtimeReminder &&
        first.preferredTrackTitle == second.preferredTrackTitle &&
        first.smartSuggestionsEnabled == second.smartSuggestionsEnabled &&
        _sameStringList(first.homeQuickActionIds, second.homeQuickActionIds) &&
        first.showHomeQuickActions == second.showHomeQuickActions &&
        first.hapticFeedbackEnabled == second.hapticFeedbackEnabled &&
        first.themeMode == second.themeMode &&
        first.assistantReplyMotionLevel == second.assistantReplyMotionLevel &&
        first.selectedNightMood == second.selectedNightMood &&
        first.eveningEncouragementPeriodKey ==
            second.eveningEncouragementPeriodKey &&
        first.eveningEncouragementLine == second.eveningEncouragementLine &&
        first.eveningEncouragementMoodSnapshot ==
            second.eveningEncouragementMoodSnapshot;
  }

  @override
  void dispose() {
    _snapshotStore.removeListener(_applySnapshot);
    super.dispose();
  }
}

class CloudBaseRecommendationRepository extends ChangeNotifier
    implements RecommendationRepository {
  CloudBaseRecommendationRepository({
    required AuthRepository authRepository,
    required UserSettingsRepository settingsRepository,
    required CloudBaseSnapshotStore snapshotStore,
    required CloudBaseAppApiClient appApiClient,
  }) : _authRepository = authRepository,
       _settingsRepository = settingsRepository,
       _snapshotStore = snapshotStore,
       _appApiClient = appApiClient,
       _tonightRecommendations = buildDefaultTonightRecommendations() {
    _snapshotStore.addListener(_applySnapshot);
    unawaited(_refreshAudioCatalog(hydrateCurrentRecommendations: true));
  }

  final AuthRepository _authRepository;
  final UserSettingsRepository _settingsRepository;
  final CloudBaseSnapshotStore _snapshotStore;
  final CloudBaseAppApiClient _appApiClient;

  List<NightRecommendation> _tonightRecommendations;

  @override
  List<NightRecommendation> get tonightRecommendations =>
      List<NightRecommendation>.unmodifiable(_tonightRecommendations);

  @override
  List<AudioTrack> get audioCatalog {
    final List<AudioTrack> remoteTracks = _remoteAudioTrackCatalog.values
        .where(_isPlayableTrack)
        .toList(growable: false);
    if (remoteTracks.isNotEmpty) {
      return List<AudioTrack>.unmodifiable(remoteTracks);
    }
    return List<AudioTrack>.unmodifiable(_defaultAudioCatalog());
  }

  @override
  Future<void> resetForTonight() async {
    if (_appApiClient.isConfigured) {
      try {
        await _authRepository.ensureAuthenticated();
        await _appApiClient.post(
          '/api/profile/night-mood',
          body: <String, dynamic>{
            'selectedNightMood':
                _settingsRepository.currentSettings.selectedNightMood?.name,
            'source': 'recommendation_reset',
            'forceRefresh': true,
          },
        );
        await _snapshotStore.refresh();
        unawaited(_refreshAudioCatalog(hydrateCurrentRecommendations: true));
        return;
      } catch (_) {
        // Fall back to local defaults below.
      }
    }
    _tonightRecommendations = buildDefaultTonightRecommendations()
        .map(
          (NightRecommendation item) =>
              item.copyWith(executionState: RecommendationExecutionState.idle),
        )
        .toList(growable: false);
    unawaited(_refreshAudioCatalog(hydrateCurrentRecommendations: true));
    notifyListeners();
  }

  @override
  Future<void> refreshAudioCatalog() async {
    await _refreshAudioCatalog(hydrateCurrentRecommendations: true);
  }

  @override
  Future<AudioTrack?> resolvePlayableTrack({
    NightRecommendation? recommendation,
    bool forceRefresh = false,
  }) async {
    AudioTrack? resolvedTrack = _resolveTrackFromRecommendation(recommendation);
    if (!forceRefresh && _isPlayableTrack(resolvedTrack)) {
      return resolvedTrack;
    }
    if (_appApiClient.isConfigured) {
      await _refreshAudioCatalog(hydrateCurrentRecommendations: true);
      resolvedTrack = _resolveTrackFromRecommendation(recommendation);
    }
    return resolvedTrack;
  }

  @override
  Future<void> setRecommendationState(
    String recommendationId,
    RecommendationExecutionState state,
  ) async {
    _tonightRecommendations = _tonightRecommendations
        .map((NightRecommendation item) {
          if (item.type == RecommendationType.audio &&
              item.id != recommendationId &&
              state == RecommendationExecutionState.playing) {
            return item.copyWith(
              executionState: RecommendationExecutionState.idle,
            );
          }
          if (item.id != recommendationId) {
            return item;
          }
          return item.copyWith(executionState: state);
        })
        .toList(growable: false);
    notifyListeners();
  }

  void _applySnapshot() {
    final _SnapshotData snapshot = _SnapshotData.fromPayload(
      _snapshotStore.payload,
      _authRepository.currentUser.uid,
    );
    final List<Map<String, dynamic>> actions = _mapListOf(
      _mapOf(snapshot.userState['tonightPlan'])['recommendedActions'],
    );
    if (actions.isEmpty) {
      return;
    }
    final Map<String, RecommendationExecutionState> previousStates =
        <String, RecommendationExecutionState>{
          for (final NightRecommendation item in _tonightRecommendations)
            item.id: item.executionState,
        };
    _tonightRecommendations = actions
        .take(_cloudBaseTonightRecommendationLimit)
        .map(_recommendationFromAction)
        .map(
          (NightRecommendation item) =>
              item.copyWith(executionState: previousStates[item.id]),
        )
        .toList(growable: false);
    if (_hasAudioRecommendations(_tonightRecommendations)) {
      unawaited(_refreshAudioCatalog(hydrateCurrentRecommendations: true));
    }
    notifyListeners();
  }

  bool _hasAudioRecommendations(List<NightRecommendation> items) {
    return items.any(
      (NightRecommendation item) => item.type == RecommendationType.audio,
    );
  }

  AudioTrack? _resolveTrackFromRecommendation(
    NightRecommendation? recommendation,
  ) {
    if (recommendation != null) {
      return _resolveTrackWithRemoteFallback(
        recommendation.track,
        trackId: recommendation.track?.id,
      );
    }
    final NightRecommendation? fallbackRecommendation = _firstWhereOrNull(
      _tonightRecommendations,
      (NightRecommendation item) => item.type == RecommendationType.audio,
    );
    return _resolveTrackWithRemoteFallback(
      fallbackRecommendation?.track,
      trackId: fallbackRecommendation?.track?.id,
    );
  }

  void _hydrateRecommendationsWithRemoteCatalog() {
    _tonightRecommendations = _tonightRecommendations
        .map((NightRecommendation item) {
          if (item.type != RecommendationType.audio) {
            return item;
          }
          final AudioTrack? track = _resolveTrackWithRemoteFallback(
            item.track,
            trackId: item.track?.id,
          );
          if (track == item.track) {
            return item;
          }
          return item.copyWith(track: track);
        })
        .toList(growable: false);
  }

  Future<void> _refreshAudioCatalog({
    required bool hydrateCurrentRecommendations,
  }) async {
    if (!_appApiClient.isConfigured) {
      return;
    }
    try {
      await _authRepository.ensureAuthenticated();
      final Map<String, dynamic> payload = await _appApiClient.post(
        '/api/media/audio-catalog',
        body: const <String, dynamic>{},
      );
      final Map<String, AudioTrack> nextCatalog =
          <String, AudioTrack>{
            for (final Map<String, dynamic> item in _mapListOf(
              payload['tracks'],
            ))
              _stringOf(item['id']): ModelSerializers.audioTrackFromMap(item),
          }..removeWhere(
            (String key, AudioTrack value) =>
                key.isEmpty || (value.sourceUrl?.trim().isEmpty ?? true),
          );
      if (nextCatalog.isEmpty) {
        return;
      }
      _remoteAudioTrackCatalog = nextCatalog;
      if (!hydrateCurrentRecommendations) {
        return;
      }
      _hydrateRecommendationsWithRemoteCatalog();
      notifyListeners();
    } catch (_) {
      // Audio catalog hydration is best-effort and should not block the page.
    }
  }

  @override
  void dispose() {
    _snapshotStore.removeListener(_applySnapshot);
    super.dispose();
  }
}

class _SerializedRemoteSyncQueue {
  Future<void> _tail = Future<void>.value();

  void enqueue(Future<void> Function() task) {
    final Future<void> next = _tail.then((_) => task());
    _tail = next.catchError((Object error, StackTrace stackTrace) {});
  }
}

bool _isActiveSleepSession(SleepSession session) {
  return session.status == SleepSessionStatus.active && session.endedAt == null;
}

SleepSession _normalizeSleepSession(SleepSession session) {
  SleepSession normalized = session;
  if (normalized.status == SleepSessionStatus.active &&
      normalized.endedAt != null) {
    normalized = normalized.copyWith(
      status: SleepSessionStatus.awaitingFeedback,
      sleepModeActive: false,
    );
  }
  if (normalized.status != SleepSessionStatus.active ||
      !normalized.sleepModeActive) {
    return _repairInactiveSleepSession(normalized);
  }
  return normalized;
}

SleepSession _normalizeSleepSessionForPhase(
  SleepSession session, {
  required String currentPhase,
  required String activeSessionId,
}) {
  final SleepSession normalized = _normalizeSleepSession(session);
  if (normalized.status != SleepSessionStatus.active) {
    return normalized;
  }
  final bool isCurrentSleepModeSession =
      currentPhase == 'sleep_mode' &&
      (activeSessionId.isEmpty || activeSessionId == normalized.id);
  if (isCurrentSleepModeSession) {
    return normalized;
  }
  return _repairInactiveSleepSession(
    normalized.copyWith(
      status: SleepSessionStatus.awaitingFeedback,
      sleepModeActive: false,
    ),
  );
}

SleepSession _repairInactiveSleepSession(SleepSession session) {
  final List<SleepSegment> segments = _normalizedSleepSegments(session);
  final DateTime? resolvedEndAt = _resolvedInactiveSessionEndAt(
    session,
    segments,
  );
  if (resolvedEndAt == null) {
    return session;
  }

  bool changed = false;
  final int openIndex = segments.lastIndexWhere(
    (SleepSegment segment) => segment.isOpen,
  );
  if (openIndex != -1) {
    segments[openIndex] = segments[openIndex].copyWith(endedAt: resolvedEndAt);
    changed = true;
  }

  final int trackedDurationMinutes = session.isTrackingLocked
      ? session.trackedDurationMinutes
      : _closedSegmentsDurationMinutes(segments);
  if (trackedDurationMinutes != session.trackedDurationMinutes) {
    changed = true;
  }
  if (session.endedAt == null) {
    changed = true;
  }
  if (!changed) {
    return session;
  }
  return session.copyWith(
    endedAt: resolvedEndAt,
    segments: segments,
    trackedDurationMinutes: trackedDurationMinutes,
  );
}

List<SleepSegment> _normalizedSleepSegments(SleepSession session) {
  if (session.segments.isNotEmpty) {
    return List<SleepSegment>.from(session.segments);
  }
  return <SleepSegment>[
    SleepSegment(
      startedAt: session.startedAt,
      endedAt: session.sleepModeActive ? null : session.endedAt,
    ),
  ];
}

DateTime? _resolvedInactiveSessionEndAt(
  SleepSession session,
  List<SleepSegment> segments,
) {
  if (session.endedAt != null) {
    return session.endedAt;
  }
  for (int index = segments.length - 1; index >= 0; index--) {
    final DateTime? endedAt = segments[index].endedAt;
    if (endedAt != null) {
      return endedAt;
    }
  }
  return null;
}

int _closedSegmentsDurationMinutes(List<SleepSegment> segments) {
  return segments.fold<int>(
    0,
    (int total, SleepSegment segment) =>
        total + sleepSegmentDurationMinutes(segment),
  );
}

bool _isValidAwaitingFeedbackSession(SleepSession session) {
  return canSubmitMorningFeedbackForSession(session);
}

class CloudBaseSleepSessionRepository extends ChangeNotifier
    implements SleepSessionRepository {
  CloudBaseSleepSessionRepository({
    required AuthRepository authRepository,
    required CloudBaseSnapshotStore snapshotStore,
    required CloudBaseAppApiClient appApiClient,
  }) : _authRepository = authRepository,
       _snapshotStore = snapshotStore,
       _appApiClient = appApiClient {
    _snapshotStore.addListener(_applySnapshot);
  }

  final AuthRepository _authRepository;
  final CloudBaseSnapshotStore _snapshotStore;
  final CloudBaseAppApiClient _appApiClient;
  final _SerializedRemoteSyncQueue _remoteSyncQueue =
      _SerializedRemoteSyncQueue();

  List<SleepSession> _sessions = const <SleepSession>[];
  String _currentPhase = '';
  String _activeSessionId = '';
  int _latestRemoteSyncId = 0;
  bool _hasObservedInitialSessionLookup = false;
  bool _hasCompletedInitialSessionLookup = false;

  @override
  SleepSession? get activeSession {
    if (_currentPhase.isNotEmpty && _currentPhase != 'sleep_mode') {
      return null;
    }
    if (_activeSessionId.isNotEmpty) {
      final SleepSession? activeById = _firstWhereOrNull(
        _sessions,
        (SleepSession session) => session.id == _activeSessionId,
      );
      if (activeById != null && _isActiveSleepSession(activeById)) {
        return activeById;
      }
      return null;
    }
    try {
      return _sessions.lastWhere(_isActiveSleepSession);
    } on StateError {
      return null;
    }
  }

  @override
  List<SleepSession> get sessions => List<SleepSession>.unmodifiable(_sessions);

  @override
  bool get isReadyForSessionLookup {
    if (!_appApiClient.isConfigured || _snapshotStore.hasPayload) {
      return true;
    }
    return _hasCompletedInitialSessionLookup;
  }

  @override
  SleepSession? get latestAwaitingFeedbackSession {
    final List<SleepSession> pending =
        _latestSleepDaySessions(_sessions)
            .where(
              (SleepSession session) =>
                  _isValidAwaitingFeedbackSession(session),
            )
            .toList()
          ..sort(
            (SleepSession a, SleepSession b) =>
                b.sleepDayDate.compareTo(a.sleepDayDate),
          );
    return pending.isEmpty ? null : pending.first;
  }

  @override
  List<SleepSession> recentSessions({int count = 7}) {
    final List<SleepSession> items = _latestSleepDaySessions(_sessions);
    return items.reversed.take(count).toList().reversed.toList();
  }

  @override
  List<SleepSession> sessionsForMonth(DateTime month) {
    return _latestSleepDaySessions(
      _sessions.where((SleepSession session) {
        return session.sleepDayDate.year == month.year &&
            session.sleepDayDate.month == month.month;
      }),
    );
  }

  @override
  Future<SleepSession> startOrResumeSleepSession({
    required List<NightRecommendation> recommendationSnapshot,
    required String? dormId,
    DateTime? at,
  }) async {
    final DateTime moment = at ?? DateTime.now();
    final String sleepDayKey = sleepDayKeyFromDate(moment);
    final SleepSession? currentActive = activeSession;
    if (currentActive != null && currentActive.sleepDayKey == sleepDayKey) {
      return currentActive;
    }

    final UserProfile user = _authRepository.currentUser.uid.isNotEmpty
        ? _authRepository.currentUser
        : await _authRepository.ensureAuthenticated();
    final SleepSession? existing = sessionForSleepDayKey(sleepDayKey);
    if (existing != null) {
      final SleepSession resumed = _resumeSession(
        existing,
        at: moment,
        dormId: dormId,
        recommendationSnapshot: recommendationSnapshot,
      );
      await saveSession(resumed);
      return resumed;
    }

    final SleepSession session = SleepSession(
      id: IdGenerator.next('session'),
      uid: user.uid,
      startedAt: moment,
      endedAt: null,
      sleepDayKey: sleepDayKey,
      status: SleepSessionStatus.active,
      sleepModeActive: true,
      dormId: dormId,
      recommendations: recommendationSnapshot,
      selectedRecommendationIds: recommendationSnapshot
          .where(
            (NightRecommendation item) =>
                item.executionState != RecommendationExecutionState.idle,
          )
          .map((NightRecommendation item) => item.id)
          .toList(growable: false),
      segments: <SleepSegment>[SleepSegment(startedAt: moment, endedAt: null)],
      trackedDurationMinutes: 0,
      awakenings: const <NightAwakeningEntry>[],
      feedback: const <RecommendationFeedback>[],
      summary: null,
      updatedAt: moment,
    );
    _upsertLocalSession(session);
    if (_appApiClient.isConfigured) {
      _enqueueSessionSync(session: session, path: '/api/sleep/enter');
    }
    return session;
  }

  @override
  Future<SleepSession?> pauseActiveSleepSession({DateTime? at}) async {
    final SleepSession? existing = activeSession;
    if (existing == null) {
      return null;
    }
    final SleepSession paused = _closeActiveSession(
      existing,
      at: at ?? DateTime.now(),
      targetStatus: existing.hasSubmittedFeedback
          ? SleepSessionStatus.completed
          : SleepSessionStatus.paused,
    );
    await saveSession(paused);
    return paused;
  }

  @override
  Future<SleepSession?> finishActiveSleepSession({DateTime? at}) async {
    final SleepSession? existing = activeSession;
    if (existing == null) {
      return null;
    }
    final SleepSession finished = _closeActiveSession(
      existing,
      at: at ?? DateTime.now(),
      targetStatus: existing.hasSubmittedFeedback
          ? SleepSessionStatus.completed
          : SleepSessionStatus.awaitingFeedback,
    );
    await saveSession(finished);
    return finished;
  }

  @override
  Future<void> saveSession(
    SleepSession session, {
    bool syncRemote = true,
  }) async {
    _upsertLocalSession(session);
    if (!_appApiClient.isConfigured || !syncRemote) {
      return;
    }
    _enqueueSessionSync(session: session, path: _pathForSessionSync(session));
  }

  @override
  SleepSession? sessionForSleepDayKey(String sleepDayKey) {
    final List<SleepSession> matches =
        _sessions
            .where((SleepSession session) => session.sleepDayKey == sleepDayKey)
            .toList()
          ..sort(_compareSleepSessions);
    return matches.isEmpty ? null : matches.last;
  }

  @override
  Future<List<SleepSession>> archivePastCutoffSessions({
    required DateTime now,
  }) async {
    final String currentSleepDayKey = sleepDayKeyFromDate(now);
    final List<SleepSession> staleSessions =
        _sessions
            .where(
              (SleepSession session) =>
                  !session.hasSubmittedFeedback &&
                  session.sleepDayKey != currentSleepDayKey,
            )
            .toList()
          ..sort(_compareSleepSessions);
    final List<SleepSession> archived = <SleepSession>[];
    for (final SleepSession session in staleSessions) {
      if (session.status != SleepSessionStatus.active &&
          session.status != SleepSessionStatus.paused) {
        continue;
      }
      final SleepSession normalized = _archivePastCutoffSession(
        session,
        now: now,
      );
      if (normalized.id == session.id &&
          normalized.status == session.status &&
          normalized.updatedAt == session.updatedAt &&
          normalized.displayEndAt == session.displayEndAt) {
        continue;
      }
      await saveSession(normalized);
      archived.add(normalized);
    }
    return archived;
  }

  SleepSession _resumeSession(
    SleepSession session, {
    required DateTime at,
    required String? dormId,
    required List<NightRecommendation> recommendationSnapshot,
  }) {
    if (session.sleepModeActive) {
      return session;
    }
    final List<SleepSegment> segments = _normalizedSegments(session);
    if (segments.isEmpty || !segments.last.isOpen) {
      segments.add(SleepSegment(startedAt: at, endedAt: null));
    }
    final List<NightRecommendation> recommendations =
        session.recommendations.isNotEmpty
        ? session.recommendations
        : recommendationSnapshot;
    final List<String> selectedRecommendationIds =
        session.selectedRecommendationIds.isNotEmpty
        ? session.selectedRecommendationIds
        : recommendationSnapshot
              .where(
                (NightRecommendation item) =>
                    item.executionState != RecommendationExecutionState.idle,
              )
              .map((NightRecommendation item) => item.id)
              .toList(growable: false);
    return session.copyWith(
      startedAt: segments.first.startedAt,
      clearEndedAt: true,
      sleepModeActive: true,
      status: session.hasSubmittedFeedback
          ? SleepSessionStatus.completed
          : SleepSessionStatus.active,
      dormId: dormId ?? session.dormId,
      recommendations: recommendations,
      selectedRecommendationIds: selectedRecommendationIds,
      segments: segments,
      updatedAt: at,
    );
  }

  SleepSession _closeActiveSession(
    SleepSession session, {
    required DateTime at,
    required SleepSessionStatus targetStatus,
  }) {
    final List<SleepSegment> segments = _normalizedSegments(session);
    int trackedDurationMinutes = session.trackedDurationMinutes;
    if (segments.isNotEmpty && segments.last.isOpen) {
      final SleepSegment closed = segments.last.copyWith(endedAt: at);
      segments[segments.length - 1] = closed;
      if (!session.isTrackingLocked) {
        trackedDurationMinutes += sleepSegmentDurationMinutes(closed);
      }
    }
    return session.copyWith(
      startedAt: segments.isNotEmpty
          ? segments.first.startedAt
          : session.startedAt,
      endedAt: at,
      status: targetStatus,
      sleepModeActive: false,
      segments: segments,
      trackedDurationMinutes: session.isTrackingLocked
          ? session.trackedDurationMinutes
          : trackedDurationMinutes,
      updatedAt: at,
    );
  }

  SleepSession _archivePastCutoffSession(
    SleepSession session, {
    required DateTime now,
  }) {
    switch (session.status) {
      case SleepSessionStatus.paused:
        return session.copyWith(
          status: SleepSessionStatus.awaitingFeedback,
          sleepModeActive: false,
          updatedAt: now,
        );
      case SleepSessionStatus.active:
        return _closeActiveSession(
          session,
          at: _sleepDayCutoff(session),
          targetStatus: SleepSessionStatus.awaitingFeedback,
        );
      case SleepSessionStatus.drafted:
      case SleepSessionStatus.awaitingFeedback:
      case SleepSessionStatus.completed:
        return session;
    }
  }

  String _pathForSessionSync(SleepSession session) {
    if (session.sleepModeActive) {
      return '/api/sleep/enter';
    }
    if (session.status == SleepSessionStatus.paused) {
      return '/api/sleep/pause';
    }
    return '/api/sleep/exit';
  }

  void _enqueueSessionSync({
    required SleepSession session,
    required String path,
  }) {
    final int syncId = ++_latestRemoteSyncId;
    final Map<String, dynamic> body = <String, dynamic>{
      'session': ModelSerializers.sleepSessionToMap(session),
    };
    _remoteSyncQueue.enqueue(() async {
      try {
        await _appApiClient.post(path, body: body);
        if (syncId == _latestRemoteSyncId) {
          await _snapshotStore.refresh();
        }
      } catch (error) {
        debugPrint(
          'CloudBase sleep session sync failed for ${session.id}: $error',
        );
      }
    });
  }

  void _upsertLocalSession(SleepSession session) {
    final SleepSession normalized = _normalizeSleepSession(session);
    _applyLocalSleepPhase(normalized);
    final int index = _sessions.indexWhere(
      (SleepSession item) => item.id == normalized.id,
    );
    if (index == -1) {
      _sessions = <SleepSession>[..._sessions, normalized];
    } else {
      final List<SleepSession> next = List<SleepSession>.from(_sessions);
      next[index] = normalized;
      _sessions = next;
    }
    _sessions = List<SleepSession>.from(_sessions)..sort(_compareSleepSessions);
    notifyListeners();
  }

  static List<SleepSegment> _normalizedSegments(SleepSession session) {
    if (session.segments.isNotEmpty) {
      return List<SleepSegment>.from(session.segments);
    }
    return <SleepSegment>[
      SleepSegment(
        startedAt: session.startedAt,
        endedAt: session.sleepModeActive ? null : session.endedAt,
      ),
    ];
  }

  static List<SleepSession> _latestSleepDaySessions(
    Iterable<SleepSession> sessions,
  ) {
    final Map<String, SleepSession> latestByKey = <String, SleepSession>{};
    for (final SleepSession session in sessions) {
      final SleepSession? existing = latestByKey[session.sleepDayKey];
      if (existing == null || _compareSleepSessions(existing, session) < 0) {
        latestByKey[session.sleepDayKey] = session;
      }
    }
    final List<SleepSession> items = latestByKey.values.toList()
      ..sort(_compareSleepSessions);
    return items;
  }

  static int _compareSleepSessions(SleepSession a, SleepSession b) {
    final int dayCompare = a.sleepDayDate.compareTo(b.sleepDayDate);
    if (dayCompare != 0) {
      return dayCompare;
    }
    final DateTime aTimestamp = a.updatedAt ?? a.displayStartAt;
    final DateTime bTimestamp = b.updatedAt ?? b.displayStartAt;
    return aTimestamp.compareTo(bTimestamp);
  }

  static DateTime _sleepDayCutoff(SleepSession session) {
    final DateTime sleepDayDate = session.sleepDayDate;
    return DateTime(
      sleepDayDate.year,
      sleepDayDate.month,
      sleepDayDate.day,
      20,
    );
  }

  void _applySnapshot() {
    if (_snapshotStore.isRefreshing) {
      _hasObservedInitialSessionLookup = true;
    } else if (_hasObservedInitialSessionLookup ||
        _snapshotStore.hasPayload ||
        _snapshotStore.lastError != null) {
      _hasCompletedInitialSessionLookup = true;
    }
    final _SnapshotData snapshot = _SnapshotData.fromPayload(
      _snapshotStore.payload,
      _authRepository.currentUser.uid,
    );
    _currentPhase = _stringOf(snapshot.userState['currentPhase']);
    _activeSessionId = _stringOf(snapshot.userState['activeSessionId']);
    final List<SleepSession> snapshotSessions = snapshot.sessions
        .map(
          (SleepSession session) => _normalizeSleepSessionForPhase(
            session,
            currentPhase: _currentPhase,
            activeSessionId: _activeSessionId,
          ),
        )
        .toList(growable: false);
    _sessions = _mergeSnapshotSessions(
      previousLocalSessions: _sessions,
      snapshotSessions: snapshotSessions,
    )..sort(_compareSleepSessions);
    notifyListeners();
  }

  static List<SleepSession> _mergeSnapshotSessions({
    required List<SleepSession> previousLocalSessions,
    required List<SleepSession> snapshotSessions,
  }) {
    final Map<String, SleepSession> mergedById = <String, SleepSession>{
      for (final SleepSession session in snapshotSessions) session.id: session,
    };
    for (final SleepSession localSession in previousLocalSessions) {
      final SleepSession? snapshotSession = mergedById[localSession.id];
      if (snapshotSession == null) {
        mergedById[localSession.id] = localSession;
        continue;
      }
      if (_shouldPreferLocalSession(localSession, snapshotSession)) {
        mergedById[localSession.id] = localSession;
      }
    }
    return mergedById.values.toList(growable: false);
  }

  static bool _shouldPreferLocalSession(
    SleepSession localSession,
    SleepSession snapshotSession,
  ) {
    if (_shouldPreferCompleteClosedLocalSession(
      localSession,
      snapshotSession,
    )) {
      return true;
    }
    final DateTime localTimestamp =
        localSession.updatedAt ??
        localSession.displayEndAt ??
        localSession.displayStartAt;
    final DateTime snapshotTimestamp =
        snapshotSession.updatedAt ??
        snapshotSession.displayEndAt ??
        snapshotSession.displayStartAt;
    if (localTimestamp.isAfter(snapshotTimestamp)) {
      return true;
    }
    if (snapshotTimestamp.isAfter(localTimestamp)) {
      return false;
    }
    if (localSession.hasSubmittedFeedback &&
        !snapshotSession.hasSubmittedFeedback) {
      return true;
    }
    if (localSession.status == SleepSessionStatus.completed &&
        snapshotSession.status != SleepSessionStatus.completed) {
      return true;
    }
    if (localSession.feedback.length > snapshotSession.feedback.length) {
      return true;
    }
    return false;
  }

  static bool _shouldPreferCompleteClosedLocalSession(
    SleepSession localSession,
    SleepSession snapshotSession,
  ) {
    if (!canSubmitMorningFeedbackForSession(localSession) ||
        canSubmitMorningFeedbackForSession(snapshotSession) ||
        snapshotSession.sleepModeActive) {
      return false;
    }
    final DateTime? localEndAt = resolveMorningFeedbackSessionEndAt(
      localSession,
    );
    final DateTime? snapshotEndAt = resolveMorningFeedbackSessionEndAt(
      snapshotSession,
    );
    if (localEndAt == null || snapshotEndAt != null) {
      return false;
    }
    return snapshotSession.openSegment != null ||
        snapshotSession.trackedDurationMinutes <
            localSession.trackedDurationMinutes;
  }

  void _applyLocalSleepPhase(SleepSession session) {
    if (_isActiveSleepSession(session) && session.sleepModeActive) {
      _currentPhase = 'sleep_mode';
      _activeSessionId = session.id;
      return;
    }
    if (session.status == SleepSessionStatus.awaitingFeedback) {
      _currentPhase = 'morning_feedback';
      _activeSessionId = session.id;
      return;
    }
    if (_activeSessionId == session.id) {
      _currentPhase = 'home_pre_sleep';
      _activeSessionId = '';
    }
  }

  @override
  void dispose() {
    _snapshotStore.removeListener(_applySnapshot);
    super.dispose();
  }
}

class CloudBaseFeedbackRepository extends ChangeNotifier
    implements FeedbackRepository {
  CloudBaseFeedbackRepository({
    required SleepSessionRepository sleepSessionRepository,
    required CloudBaseAppApiClient appApiClient,
    required CloudBaseSnapshotStore snapshotStore,
  }) : _sleepSessionRepository = sleepSessionRepository,
       _appApiClient = appApiClient,
       _snapshotStore = snapshotStore;

  final SleepSessionRepository _sleepSessionRepository;
  final CloudBaseAppApiClient _appApiClient;
  final CloudBaseSnapshotStore _snapshotStore;

  @override
  Future<void> submitFeedback({
    required SleepSession session,
    required MorningSummary summary,
    required List<RecommendationFeedback> recommendationFeedback,
  }) async {
    final SleepSession completedSession = session.copyWith(
      status: SleepSessionStatus.completed,
      sleepModeActive: false,
      summary: summary,
      feedback: recommendationFeedback,
      updatedAt: DateTime.now(),
    );
    await _sleepSessionRepository.saveSession(
      completedSession,
      syncRemote: false,
    );
    if (_appApiClient.isConfigured) {
      try {
        await _appApiClient.post(
          '/api/feedback/morning',
          body: <String, dynamic>{
            'sessionId': completedSession.id,
            'session': ModelSerializers.sleepSessionToMap(completedSession),
            'summary': ModelSerializers.morningSummaryToMap(summary),
            'feedback': recommendationFeedback
                .map(ModelSerializers.recommendationFeedbackToMap)
                .toList(growable: false),
          },
        );
        await _snapshotStore.refresh();
      } catch (error) {
        debugPrint(
          'CloudBase morning feedback sync failed for ${completedSession.id}: '
          '$error',
        );
        // Local state is already updated.
      }
    }
    notifyListeners();
  }
}

class CloudBaseSleepCaptureRepository extends ChangeNotifier
    implements SleepCaptureRepository {
  CloudBaseSleepCaptureRepository({
    required AuthRepository authRepository,
    required CloudBaseSnapshotStore snapshotStore,
    required CloudBaseAppApiClient appApiClient,
  }) : _authRepository = authRepository,
       _snapshotStore = snapshotStore,
       _appApiClient = appApiClient {
    _snapshotStore.addListener(_applySnapshot);
  }

  final AuthRepository _authRepository;
  final CloudBaseSnapshotStore _snapshotStore;
  final CloudBaseAppApiClient _appApiClient;

  List<SleepCaptureRecord> _records = const <SleepCaptureRecord>[];
  PendingSleepMemoBanner? _pendingSleepMemoBanner;

  @override
  PendingSleepMemoBanner? get pendingSleepMemoBanner => _pendingSleepMemoBanner;

  @override
  List<SleepCaptureRecord> recordsByType(SleepCaptureType type) {
    final List<SleepCaptureRecord> matches =
        _records.where((SleepCaptureRecord item) => item.type == type).toList()
          ..sort(
            (SleepCaptureRecord a, SleepCaptureRecord b) =>
                b.createdAt.compareTo(a.createdAt),
          );
    return List<SleepCaptureRecord>.unmodifiable(matches);
  }

  @override
  List<SleepCaptureRecord> recordsForSession(String sessionId) {
    final List<SleepCaptureRecord> matches =
        _records
            .where((SleepCaptureRecord item) => item.sessionId == sessionId)
            .toList()
          ..sort(
            (SleepCaptureRecord a, SleepCaptureRecord b) =>
                b.createdAt.compareTo(a.createdAt),
          );
    return List<SleepCaptureRecord>.unmodifiable(matches);
  }

  @override
  Future<SleepCaptureRecord> addRecord({
    required SleepCaptureType type,
    required String sessionId,
    required String content,
    String? recordId,
    String? title,
    String? outline,
    DateTime? createdAt,
  }) async {
    final DateTime now = createdAt ?? DateTime.now();
    final String normalizedContent = content.trim();
    final SleepCaptureRecord localRecord = SleepCaptureRecord(
      id: recordId ?? IdGenerator.next('sleep-capture'),
      type: type,
      sessionId: sessionId,
      createdAt: now,
      title:
          title ??
          _buildTitle(type: type, now: now, content: normalizedContent),
      outline: outline ?? _buildOutline(type: type, content: normalizedContent),
      content: normalizedContent,
    );
    _upsertLocalRecord(localRecord);
    if (!_appApiClient.isConfigured) {
      return localRecord;
    }
    try {
      await _authRepository.ensureAuthenticated();
      final Map<String, dynamic> response = await _appApiClient.post(
        '/api/sleep-capture/save',
        body: <String, dynamic>{
          'record': ModelSerializers.sleepCaptureRecordToMap(localRecord),
        },
      );
      final Map<String, dynamic> recordMap = _mapOf(response['record']).isEmpty
          ? response
          : _mapOf(response['record']);
      final SleepCaptureRecord remoteRecord =
          ModelSerializers.sleepCaptureRecordFromMap(recordMap);
      _upsertLocalRecord(remoteRecord);
      await _snapshotStore.refresh();
      return remoteRecord;
    } catch (_) {
      return localRecord;
    }
  }

  @override
  Future<void> showPendingBannerForSession(String sessionId) async {
    final PendingSleepMemoBanner? localBanner = _buildPendingBannerForSession(
      sessionId,
    );
    _pendingSleepMemoBanner = localBanner;
    notifyListeners();
    if (!_appApiClient.isConfigured) {
      return;
    }
    try {
      await _authRepository.ensureAuthenticated();
      final Map<String, dynamic> response = await _appApiClient.post(
        '/api/sleep-capture/banner/show',
        body: <String, dynamic>{'sessionId': sessionId},
      );
      final Map<String, dynamic> bannerMap = _mapOf(
        response['pendingMemoBanner'] ?? response['banner'],
      );
      _pendingSleepMemoBanner = bannerMap.isEmpty
          ? null
          : ModelSerializers.pendingSleepMemoBannerFromMap(bannerMap);
      notifyListeners();
      await _snapshotStore.refresh();
    } catch (_) {
      // Keep local banner state if remote sync fails.
    }
  }

  @override
  Future<void> clearPendingBanner() async {
    _pendingSleepMemoBanner = null;
    notifyListeners();
    if (!_appApiClient.isConfigured) {
      return;
    }
    try {
      await _authRepository.ensureAuthenticated();
      await _appApiClient.post(
        '/api/sleep-capture/banner/clear',
        body: const <String, dynamic>{},
      );
      await _snapshotStore.refresh();
    } catch (_) {
      // Keep local clear state even if remote sync fails.
    }
  }

  void _upsertLocalRecord(SleepCaptureRecord record) {
    final int index = _records.indexWhere(
      (SleepCaptureRecord item) => item.id == record.id,
    );
    if (index == -1) {
      _records = <SleepCaptureRecord>[record, ..._records];
    } else {
      final List<SleepCaptureRecord> next = List<SleepCaptureRecord>.from(
        _records,
      );
      next[index] = record;
      _records = next;
    }
    notifyListeners();
  }

  PendingSleepMemoBanner? _buildPendingBannerForSession(String sessionId) {
    final List<SleepCaptureRecord> memoRecords = recordsForSession(sessionId)
        .where((SleepCaptureRecord item) => item.type == SleepCaptureType.memo)
        .toList(growable: false);
    final List<PendingSleepMemoGroup> carryoverGroups =
        (_pendingSleepMemoBanner?.groups ?? const <PendingSleepMemoGroup>[])
            .map(
              (PendingSleepMemoGroup group) => PendingSleepMemoGroup(
                sessionId: group.sessionId,
                label: '上次睡眠模式（未查收）',
                items: group.items,
                isCarryover: true,
              ),
            )
            .toList(growable: false);
    final List<PendingSleepMemoGroup> nextGroups = <PendingSleepMemoGroup>[
      ...carryoverGroups,
      if (memoRecords.isNotEmpty)
        PendingSleepMemoGroup(
          sessionId: sessionId,
          label: carryoverGroups.isEmpty ? '本次睡眠模式' : '本次睡眠模式（新）',
          items: memoRecords.map(_buildBannerLine).toList(growable: false),
          isCarryover: false,
        ),
    ];
    if (nextGroups.isEmpty) {
      return null;
    }
    return PendingSleepMemoBanner(
      title: '事记内容查收',
      subtitle: '点击查看或 30min 后自动消除。',
      groups: nextGroups,
      createdAt: DateTime.now(),
    );
  }

  String _buildTitle({
    required SleepCaptureType type,
    required DateTime now,
    required String content,
  }) {
    final String hh = now.hour.toString().padLeft(2, '0');
    final String mm = now.minute.toString().padLeft(2, '0');
    final String prefix = type == SleepCaptureType.dream ? '梦记' : '事记';
    final String seed = _firstMeaningfulFragment(content);
    return '$prefix $hh:$mm · ${seed.isEmpty ? '新的记录' : seed}';
  }

  String _buildOutline({
    required SleepCaptureType type,
    required String content,
  }) {
    final List<String> fragments = content
        .split(RegExp(r'[。！？\n]'))
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
    if (fragments.isEmpty) {
      return type == SleepCaptureType.dream
          ? '记录了一段尚待补充的梦境片段。'
          : '记录了一段待整理的夜间事记。';
    }
    final String lead = fragments.first;
    if (type == SleepCaptureType.dream) {
      return 'AI整理：梦里重点出现了“${_truncate(lead, 22)}”，适合稍后回看情绪和场景。';
    }
    return 'AI整理：这段事记主要围绕“${_truncate(lead, 24)}”，可在清醒后继续展开。';
  }

  String _buildBannerLine(SleepCaptureRecord record) {
    final String cleanedContent = record.content
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleanedContent.isEmpty) {
      return '有一条新的事记等你稍后回看。';
    }
    return cleanedContent;
  }

  String _firstMeaningfulFragment(String content) {
    final List<String> fragments = content
        .split(RegExp(r'[，。！？\n]'))
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
    return fragments.isEmpty ? '' : _truncate(fragments.first, 10);
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }

  void _applySnapshot() {
    final _SnapshotData snapshot = _SnapshotData.fromPayload(
      _snapshotStore.payload,
      _authRepository.currentUser.uid,
    );
    _records = List<SleepCaptureRecord>.from(snapshot.sleepCaptureRecords)
      ..sort(
        (SleepCaptureRecord a, SleepCaptureRecord b) =>
            b.createdAt.compareTo(a.createdAt),
      );
    _pendingSleepMemoBanner = snapshot.pendingSleepMemoBanner;
    notifyListeners();
  }

  @override
  void dispose() {
    _snapshotStore.removeListener(_applySnapshot);
    super.dispose();
  }
}

class CloudBaseNotificationRepository extends ChangeNotifier
    implements NotificationRepository {
  CloudBaseNotificationRepository({
    required AuthRepository authRepository,
    required CloudBaseSnapshotStore snapshotStore,
    required CloudBaseAppApiClient appApiClient,
  }) : _authRepository = authRepository,
       _snapshotStore = snapshotStore,
       _appApiClient = appApiClient {
    _snapshotStore.addListener(_applySnapshot);
  }

  final AuthRepository _authRepository;
  final CloudBaseSnapshotStore _snapshotStore;
  final CloudBaseAppApiClient _appApiClient;
  List<NotificationItem> _notifications = const <NotificationItem>[];

  @override
  List<NotificationItem> get notifications {
    final List<NotificationItem> sorted =
        List<NotificationItem>.from(_notifications)..sort(
          (NotificationItem a, NotificationItem b) =>
              b.createdAt.compareTo(a.createdAt),
        );
    return List<NotificationItem>.unmodifiable(sorted);
  }

  @override
  List<NotificationItem> unreadNotifications() {
    return notifications
        .where((NotificationItem item) => !item.isRead)
        .toList(growable: false);
  }

  @override
  Future<void> markRead(String notificationId) async {
    final DateTime readAt = DateTime.now();
    _notifications = _notifications
        .map((NotificationItem item) {
          if (item.id != notificationId) {
            return item;
          }
          return item.copyWith(readAt: readAt);
        })
        .toList(growable: false);
    notifyListeners();
    if (_appApiClient.isConfigured) {
      try {
        await _authRepository.ensureAuthenticated();
        await _appApiClient.post(
          '/api/notifications/read',
          body: <String, dynamic>{
            'notificationId': notificationId,
            'readAt': readAt.toIso8601String(),
          },
        );
      } catch (_) {
        // Keep the in-memory state responsive even if the remote sync fails.
      }
    }
  }

  @override
  Future<void> markAllRead() async {
    final List<NotificationItem> unread = unreadNotifications();
    if (unread.isEmpty) {
      return;
    }
    final DateTime readAt = DateTime.now();
    _notifications = _notifications
        .map((NotificationItem item) {
          return item.isRead ? item : item.copyWith(readAt: readAt);
        })
        .toList(growable: false);
    notifyListeners();

    if (!_appApiClient.isConfigured) {
      return;
    }
    try {
      await _authRepository.ensureAuthenticated();
      await Future.wait(
        unread.map((NotificationItem item) {
          return _appApiClient.post(
            '/api/notifications/read',
            body: <String, dynamic>{
              'notificationId': item.id,
              'readAt': readAt.toIso8601String(),
            },
          );
        }),
      );
    } catch (_) {
      // Keep the local batch action responsive even if remote sync fails.
    }
  }

  @override
  Future<void> upsertNotification(NotificationItem notification) async {
    final int index = _notifications.indexWhere((NotificationItem item) {
      return item.id == notification.id;
    });
    if (index == -1) {
      _notifications = <NotificationItem>[notification, ..._notifications];
    } else {
      final List<NotificationItem> next = List<NotificationItem>.from(
        _notifications,
      );
      next[index] = notification;
      _notifications = next;
    }
    notifyListeners();
  }

  void _applySnapshot() {
    final _SnapshotData snapshot = _SnapshotData.fromPayload(
      _snapshotStore.payload,
      _authRepository.currentUser.uid,
    );
    _notifications = snapshot.notifications;
    notifyListeners();
  }

  @override
  void dispose() {
    _snapshotStore.removeListener(_applySnapshot);
    super.dispose();
  }
}

class CloudBaseDormRepository extends ChangeNotifier implements DormRepository {
  CloudBaseDormRepository({
    required AuthRepository authRepository,
    required CloudBaseSnapshotStore snapshotStore,
    required CloudBaseAppApiClient appApiClient,
  }) : _authRepository = authRepository,
       _snapshotStore = snapshotStore,
       _appApiClient = appApiClient,
       _currentDorm = _unboundDorm() {
    _snapshotStore.addListener(_applySnapshot);
    _emitCurrentState();
  }

  final AuthRepository _authRepository;
  final CloudBaseSnapshotStore _snapshotStore;
  final CloudBaseAppApiClient _appApiClient;
  final _SerializedRemoteSyncQueue _statusSyncQueue =
      _SerializedRemoteSyncQueue();
  final StreamController<Dorm> _dormController =
      StreamController<Dorm>.broadcast();
  final StreamController<List<DormMember>> _membersController =
      StreamController<List<DormMember>>.broadcast();
  final StreamController<List<DormRule>> _rulesController =
      StreamController<List<DormRule>>.broadcast();
  final StreamController<List<DormEvent>> _eventsController =
      StreamController<List<DormEvent>>.broadcast();
  final Set<String> _readDormStatusRecordIds = <String>{};

  Dorm _currentDorm;
  int _latestStatusSyncId = 0;
  final Map<String, _PendingDormMemberStatusOverride> _pendingStatusOverrides =
      <String, _PendingDormMemberStatusOverride>{};
  _PendingDormEnvironmentOverride? _pendingEnvironmentOverride;

  @override
  Dorm get currentDorm => _currentDorm;

  @override
  Stream<Dorm> watchDorm() => _dormController.stream;

  @override
  Stream<List<DormMember>> watchMembers() => _membersController.stream;

  @override
  Stream<List<DormRule>> watchRules() => _rulesController.stream;

  @override
  Stream<List<DormEvent>> watchEvents() => _eventsController.stream;

  @override
  bool isDormStatusRecordRead(String recordId) {
    return _readDormStatusRecordIds.contains(recordId);
  }

  @override
  Future<void> markDormStatusRecordRead(String recordId) async {
    final String normalizedRecordId = recordId.trim();
    if (normalizedRecordId.isEmpty ||
        !_readDormStatusRecordIds.add(normalizedRecordId)) {
      return;
    }
    notifyListeners();
  }

  @override
  Future<void> createDorm({
    required String name,
    String? overview,
    DormRulesSettings? rulesSettings,
    DormLocationAnchor? locationAnchor,
  }) async {
    _readDormStatusRecordIds.clear();
    if (_appApiClient.isConfigured) {
      try {
        await _appApiClient.post(
          '/api/dorm/create',
          body: <String, dynamic>{
            'name': name,
            if (overview != null && overview.trim().isNotEmpty)
              'overview': overview.trim(),
            if (rulesSettings != null)
              'rulesSettings': ModelSerializers.dormRulesSettingsToMap(
                rulesSettings,
              ),
            if (locationAnchor != null)
              'locationAnchor': ModelSerializers.dormLocationAnchorToMap(
                locationAnchor,
              ),
          },
        );
        await _snapshotStore.refresh();
        return;
      } catch (_) {
        // Fall back to local state when CloudBase app-api is unavailable.
      }
    }
    final DormRulesSettings nextRules =
        rulesSettings ?? buildDefaultDormRulesSettings();
    final DateTime now = DateTime.now();
    _currentDorm = Dorm(
      id: IdGenerator.next('dorm'),
      name: name,
      overview:
          overview ??
          '\u65b0\u5bbf\u820d\u5df2\u7ecf\u521b\u5efa\uff0c\u63a5\u4e0b\u6765\u53ef\u4ee5\u9080\u8bf7\u820d\u53cb\u52a0\u5165\u3002',
      noiseDb: 28,
      lightLabel: '\u9002\u4e2d',
      quietLabel: '\u53ef\u4f18\u5316',
      rules: buildDormSummaryRules(nextRules),
      members: <DormMember>[
        DormMember(
          uid: _authRepository.currentUser.uid,
          name: _authRepository.currentUser.displayName,
          status: DormMemberStatus.quiet,
          presenceStatus: locationAnchor == null
              ? DormPresenceStatus.unknown
              : DormPresenceStatus.returned,
          sleepModeActive: false,
          lastActiveAt: now,
          note:
              '\u5df2\u521b\u5efa\u5bbf\u820d\uff0c\u7b49\u5f85\u9080\u8bf7\u820d\u53cb\u52a0\u5165\u3002',
          avatarUrl: _authRepository.currentUser.avatarUrl,
        ),
      ],
      rulesSettings: nextRules,
      events: <DormEvent>[
        DormEvent(
          id: IdGenerator.next('dorm-event'),
          type: DormEventType.system,
          title: '\u5bbf\u820d\u5df2\u521b\u5efa',
          detail:
              '\u4f60\u73b0\u5728\u53ef\u4ee5\u751f\u6210\u9080\u8bf7\u7801\u5e76\u9080\u8bf7\u820d\u53cb\u52a0\u5165\u3002',
          createdAt: now,
          actorUid: _authRepository.currentUser.uid,
        ),
      ],
      invites: const <DormInvite>[],
      locationAnchor: locationAnchor,
    );
    _emitCurrentState();
    notifyListeners();
  }

  @override
  Future<void> updateCurrentUserStatus({
    required String uid,
    DormMemberStatus? status,
    DormPresenceStatus? presenceStatus,
    bool? sleepModeActive,
    String? note,
  }) async {
    if (_currentDorm.id.isEmpty) {
      return;
    }
    final DormMember? currentMember = _firstWhereOrNull(
      _currentDorm.members,
      (DormMember member) => member.uid == uid,
    );
    if (currentMember == null) {
      return;
    }
    final DateTime now = DateTime.now();
    final String nextNote = note ?? currentMember.note;
    _pendingStatusOverrides[uid] = _PendingDormMemberStatusOverride(
      status: status,
      presenceStatus: presenceStatus,
      sleepModeActive: sleepModeActive,
      note: note,
    );
    _currentDorm = _currentDorm.copyWith(
      members: _currentDorm.members
          .map((DormMember member) {
            if (member.uid != uid) {
              return member;
            }
            return member.copyWith(
              status: status ?? member.status,
              presenceStatus: presenceStatus ?? member.presenceStatus,
              sleepModeActive: sleepModeActive ?? member.sleepModeActive,
              lastActiveAt: now,
              note: nextNote,
            );
          })
          .toList(growable: false),
      events: <DormEvent>[
        DormEvent(
          id: IdGenerator.next('dorm-event'),
          type: DormEventType.memberStatus,
          title: uid == _authRepository.currentUser.uid
              ? '\u4f60\u5df2\u66f4\u65b0\u72b6\u6001'
              : '\u820d\u53cb\u66f4\u65b0\u4e86\u72b6\u6001',
          detail: nextNote,
          createdAt: now,
          actorUid: uid,
        ),
        ..._currentDorm.events,
      ],
    );
    _emitCurrentState();
    notifyListeners();
    if (_appApiClient.isConfigured) {
      final Map<String, dynamic> body = <String, dynamic>{'uid': uid};
      if (status != null) {
        body['status'] = status.name;
      }
      if (presenceStatus != null) {
        body['presenceStatus'] = presenceStatus.name;
      }
      if (sleepModeActive != null) {
        body['sleepModeActive'] = sleepModeActive;
      }
      if (note != null) {
        body['note'] = note;
      }
      _enqueueStatusSync(body);
    }
  }

  void _enqueueStatusSync(Map<String, dynamic> body) {
    final int syncId = ++_latestStatusSyncId;
    _statusSyncQueue.enqueue(() async {
      try {
        await _appApiClient.post('/api/dorm/member/status', body: body);
        if (syncId == _latestStatusSyncId) {
          await _snapshotStore.refresh();
        }
      } catch (error) {
        debugPrint('CloudBase dorm status sync failed: $error');
      }
    });
  }

  @override
  Future<void> updateCurrentUserOnlineStatus({
    required String uid,
    required bool online,
  }) async {
    if (_currentDorm.id.isEmpty) {
      return;
    }
    final DateTime now = DateTime.now();
    bool updatedLocalMember = false;
    _currentDorm = _currentDorm.copyWith(
      members: _currentDorm.members
          .map((DormMember member) {
            if (member.uid != uid) {
              return member;
            }
            updatedLocalMember = true;
            return member.copyWith(appOnline: online, appLastSeenAt: now);
          })
          .toList(growable: false),
    );
    if (updatedLocalMember) {
      _emitCurrentState();
      notifyListeners();
    }
    if (!_appApiClient.isConfigured) {
      return;
    }
    try {
      await _authRepository.ensureAuthenticated();
      await _appApiClient.post(
        '/api/dorm/member/heartbeat',
        body: <String, dynamic>{'online': online},
      );
    } catch (error) {
      debugPrint('CloudBase dorm heartbeat sync failed: $error');
    }
  }

  @override
  void hydrateCurrentDormLocationAnchor(DormLocationAnchor anchor) {
    if (_currentDorm.id.isEmpty) {
      return;
    }
    _currentDorm = _currentDorm.copyWith(locationAnchor: anchor);
    _emitCurrentState();
    notifyListeners();
  }

  @override
  Future<void> saveDormLocationAnchor(DormLocationAnchor anchor) async {
    if (_currentDorm.id.isEmpty) {
      return;
    }
    if (_appApiClient.isConfigured) {
      try {
        await _appApiClient.post(
          '/api/dorm/location-anchor',
          body: ModelSerializers.dormLocationAnchorToMap(anchor),
        );
        await _snapshotStore.refresh();
        return;
      } catch (_) {
        // Fall back to local state when the backend is unavailable.
      }
    }
    _currentDorm = _currentDorm.copyWith(locationAnchor: anchor);
    _emitCurrentState();
    notifyListeners();
  }

  @override
  Future<void> updateDormEnvironment({
    int? noiseDb,
    String? lightLabel,
    String? quietLabel,
  }) async {
    if (_currentDorm.id.isEmpty) {
      return;
    }
    final _PendingDormEnvironmentOverride nextEnvironment =
        _PendingDormEnvironmentOverride(
          noiseDb: noiseDb,
          lightLabel: lightLabel,
          quietLabel: quietLabel,
        );
    _pendingEnvironmentOverride =
        _pendingEnvironmentOverride?.merge(nextEnvironment) ?? nextEnvironment;
    _currentDorm = nextEnvironment.apply(_currentDorm);
    _emitCurrentState();
    notifyListeners();
    if (_appApiClient.isConfigured) {
      try {
        await _appApiClient.post(
          '/api/dorm/environment',
          body: <String, dynamic>{
            ...?noiseDb == null ? null : <String, dynamic>{'noiseDb': noiseDb},
            ...?lightLabel == null
                ? null
                : <String, dynamic>{'lightLabel': lightLabel},
            ...?quietLabel == null
                ? null
                : <String, dynamic>{'quietLabel': quietLabel},
          },
        );
        await _snapshotStore.refresh();
        return;
      } catch (error) {
        debugPrint('CloudBase dorm environment sync failed: $error');
        return;
      }
    }
  }

  @override
  Future<void> saveRules(DormRulesSettings settings) async {
    if (_currentDorm.id.isEmpty) {
      return;
    }
    if (_currentDorm.pendingRuleProposal != null) {
      return;
    }
    if (_appApiClient.isConfigured) {
      try {
        await _appApiClient.post(
          '/api/dorm/rules',
          body: <String, dynamic>{
            'rulesSettings': ModelSerializers.dormRulesSettingsToMap(settings),
          },
        );
        await _snapshotStore.refresh();
        return;
      } catch (_) {
        // Fall back to local state when app-api is unavailable.
      }
    }
    final DateTime now = DateTime.now();
    final List<DormRule> proposedRules = buildDormSummaryRules(settings);
    final DormPendingRuleProposal proposal = DormPendingRuleProposal(
      id: IdGenerator.next('rule-proposal'),
      proposedSettings: settings,
      proposedRules: proposedRules,
      proposerUid: _authRepository.currentUser.uid,
      proposerName: _currentUserDisplayName(),
      createdAt: now,
      reviewerUids: _currentDorm.members
          .map((DormMember member) => member.uid)
          .toList(growable: false),
      approvedUids: <String>[_authRepository.currentUser.uid],
    );
    if (_isProposalFullyApproved(proposal)) {
      _currentDorm = _currentDorm.copyWith(
        rulesSettings: settings,
        rules: proposedRules,
        events: <DormEvent>[
          DormEvent(
            id: IdGenerator.next('dorm-event'),
            type: DormEventType.ruleUpdate,
            title: '宿舍公约已更新',
            detail: '安静时段：${settings.quietHours}',
            createdAt: now,
            actorUid: _authRepository.currentUser.uid,
          ),
          ..._currentDorm.events,
        ],
      );
    } else {
      _currentDorm = _currentDorm.copyWith(
        pendingRuleProposal: proposal,
        events: <DormEvent>[
          DormEvent(
            id: IdGenerator.next('dorm-event'),
            type: DormEventType.ruleUpdate,
            title: '有新宿舍公约待确认',
            detail: '${proposal.proposerName} 提交了新的宿舍规则，等待室友确认。',
            createdAt: now,
            actorUid: _authRepository.currentUser.uid,
          ),
          ..._currentDorm.events,
        ],
      );
    }
    _emitCurrentState();
    notifyListeners();
  }

  @override
  Future<void> approvePendingRules() async {
    final DormPendingRuleProposal? proposal = _currentDorm.pendingRuleProposal;
    final String currentUserId = _authRepository.currentUser.uid;
    if (proposal == null || !proposal.needsReviewFrom(currentUserId)) {
      return;
    }
    if (_appApiClient.isConfigured) {
      try {
        await _appApiClient.post(
          '/api/dorm/rules/approve',
          body: <String, dynamic>{'proposalId': proposal.id},
        );
        await _snapshotStore.refresh();
        return;
      } catch (_) {
        // Fall back to local state when app-api is unavailable.
      }
    }
    final DormPendingRuleProposal nextProposal = proposal.copyWith(
      approvedUids: <String>{
        ...proposal.approvedUids,
        currentUserId,
      }.toList(growable: false),
    );
    if (_isProposalFullyApproved(nextProposal)) {
      _currentDorm = _currentDorm.copyWith(
        rulesSettings: nextProposal.proposedSettings,
        rules: nextProposal.proposedRules,
        clearPendingRuleProposal: true,
        events: <DormEvent>[
          DormEvent(
            id: IdGenerator.next('dorm-event'),
            type: DormEventType.ruleUpdate,
            title: '新宿舍公约已生效',
            detail: '全部室友已同意，新的宿舍公约开始执行。',
            createdAt: DateTime.now(),
            actorUid: currentUserId,
          ),
          ..._currentDorm.events,
        ],
      );
    } else {
      _currentDorm = _currentDorm.copyWith(
        pendingRuleProposal: nextProposal,
        events: <DormEvent>[
          DormEvent(
            id: IdGenerator.next('dorm-event'),
            type: DormEventType.ruleUpdate,
            title: '室友已同意新公约',
            detail: '${_currentUserDisplayName()} 已同意这次规则调整。',
            createdAt: DateTime.now(),
            actorUid: currentUserId,
          ),
          ..._currentDorm.events,
        ],
      );
    }
    _emitCurrentState();
    notifyListeners();
  }

  @override
  Future<void> rejectPendingRules({required String reason}) async {
    final DormPendingRuleProposal? proposal = _currentDorm.pendingRuleProposal;
    final String currentUserId = _authRepository.currentUser.uid;
    final String trimmedReason = reason.trim();
    if (proposal == null ||
        !proposal.needsReviewFrom(currentUserId) ||
        trimmedReason.isEmpty) {
      return;
    }
    if (_appApiClient.isConfigured) {
      try {
        await _appApiClient.post(
          '/api/dorm/rules/reject',
          body: <String, dynamic>{
            'proposalId': proposal.id,
            'reason': trimmedReason,
          },
        );
        await _snapshotStore.refresh();
        return;
      } catch (_) {
        // Fall back to local state when app-api is unavailable.
      }
    }
    _currentDorm = _currentDorm.copyWith(
      clearPendingRuleProposal: true,
      events: <DormEvent>[
        DormEvent(
          id: IdGenerator.next('dorm-event'),
          type: DormEventType.ruleUpdate,
          title: '新宿舍公约未通过',
          detail: '${_currentUserDisplayName()} 提出异议：$trimmedReason',
          createdAt: DateTime.now(),
          actorUid: currentUserId,
        ),
        ..._currentDorm.events,
      ],
    );
    _emitCurrentState();
    notifyListeners();
  }

  @override
  Future<DormInvite> createInvite() async {
    if (_currentDorm.id.isEmpty) {
      throw StateError(
        '\u8bf7\u5148\u521b\u5efa\u5bbf\u820d\u6216\u52a0\u5165\u5bbf\u820d\uff0c\u518d\u9080\u8bf7\u820d\u53cb\u3002',
      );
    }
    if (_appApiClient.isConfigured) {
      try {
        final Map<String, dynamic> data = await _appApiClient.post(
          '/api/dorm/invite/create',
          body: const <String, dynamic>{},
        );
        final DormInvite invite = DormInvite(
          id: _stringOf(data['inviteId'], IdGenerator.next('invite')),
          dormId: _stringOf(data['dormId'], _currentDorm.id),
          code: _stringOf(data['inviteCode']),
          createdByUid: _authRepository.currentUser.uid,
          createdAt: data['createdAt'] == null
              ? DateTime.now()
              : _dateOf(data['createdAt']),
          expiresAt: data['expiresAt'] == null
              ? DateTime.now().add(const Duration(days: 3))
              : _dateOf(data['expiresAt']),
          status: DormInviteStatus.pending,
        );
        await _snapshotStore.refresh();
        return invite;
      } catch (_) {
        // Fall back to local invite creation.
      }
    }
    final DormInvite invite = DormInvite(
      id: IdGenerator.next('invite'),
      dormId: _currentDorm.id,
      code:
          'DORM-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      createdByUid: _authRepository.currentUser.uid,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 3)),
      status: DormInviteStatus.pending,
    );
    _currentDorm = _currentDorm.copyWith(
      invites: <DormInvite>[invite, ..._currentDorm.invites],
    );
    _emitCurrentState();
    notifyListeners();
    return invite;
  }

  @override
  Future<void> acceptInvite(String inviteCode) async {
    if (_appApiClient.isConfigured) {
      try {
        await _appApiClient.post(
          '/api/dorm/invite/accept',
          body: <String, dynamic>{'inviteCode': inviteCode},
        );
        await _snapshotStore.refresh();
        return;
      } catch (_) {
        // Fall back to local dorm state.
      }
    }
    _currentDorm = _currentDorm.copyWith(
      invites: _currentDorm.invites
          .map((DormInvite invite) {
            if (invite.code != inviteCode) {
              return invite;
            }
            return invite.copyWith(
              status: DormInviteStatus.accepted,
              acceptedByUid: _authRepository.currentUser.uid,
              acceptedAt: DateTime.now(),
            );
          })
          .toList(growable: false),
      members:
          _currentDorm.members.any(
            (DormMember member) =>
                member.uid == _authRepository.currentUser.uid,
          )
          ? _currentDorm.members
          : <DormMember>[
              DormMember(
                uid: _authRepository.currentUser.uid,
                name: _authRepository.currentUser.displayName,
                status: DormMemberStatus.quiet,
                presenceStatus: DormPresenceStatus.unknown,
                sleepModeActive: false,
                lastActiveAt: DateTime.now(),
                note:
                    '\u5df2\u901a\u8fc7\u9080\u8bf7\u7801\u52a0\u5165\u5bbf\u820d\u3002',
                avatarUrl: _authRepository.currentUser.avatarUrl,
              ),
              ..._currentDorm.members,
            ],
    );
    _emitCurrentState();
    notifyListeners();
  }

  @override
  Future<void> renameDorm(String name) async {
    if (_currentDorm.id.isEmpty) {
      return;
    }
    if (_appApiClient.isConfigured) {
      try {
        await _appApiClient.post(
          '/api/dorm/rename',
          body: <String, dynamic>{'name': name},
        );
        await _snapshotStore.refresh();
        return;
      } catch (_) {
        // Fall back to local state when the backend is unavailable.
      }
    }
    _currentDorm = _currentDorm.copyWith(name: name);
    _emitCurrentState();
    notifyListeners();
  }

  @override
  Future<void> leaveDorm() async {
    if (_currentDorm.id.isEmpty) {
      return;
    }
    if (_appApiClient.isConfigured) {
      try {
        await _appApiClient.post('/api/dorm/leave');
        await _snapshotStore.refresh(allowDestructiveAccountChanges: true);
        return;
      } catch (_) {
        // Fall back to local state when the backend is unavailable.
      }
    }
    final List<DormMember> remainingMembers = _currentDorm.members
        .where(
          (DormMember member) => member.uid != _authRepository.currentUser.uid,
        )
        .toList(growable: false);
    _currentDorm = remainingMembers.isEmpty
        ? _currentDorm.copyWith(
            members: const <DormMember>[],
            status: DormStatus.archived,
            archivedAt: DateTime.now(),
            invites: _currentDorm.invites
                .map(
                  (DormInvite invite) =>
                      invite.copyWith(status: DormInviteStatus.revoked),
                )
                .toList(growable: false),
          )
        : _currentDorm.copyWith(members: remainingMembers);
    _emitCurrentState();
    notifyListeners();
  }

  @override
  Future<void> refreshDormSnapshot() async {
    if (!_appApiClient.isConfigured) {
      return;
    }
    try {
      await _authRepository.ensureAuthenticated();
      await _snapshotStore.refresh();
    } catch (_) {
      // Keep showing last known dorm; next poll will retry.
    }
  }

  @override
  Future<void> sendGentleReminder({
    required String targetUid,
    bool anonymous = true,
    required String message,
  }) async {
    final String trimmedMessage = message.trim();
    if (_currentDorm.id.isEmpty ||
        targetUid.trim().isEmpty ||
        trimmedMessage.isEmpty) {
      return;
    }
    if (_appApiClient.isConfigured) {
      try {
        await _authRepository.ensureAuthenticated();
        await _appApiClient.post(
          '/api/dorm/reminders/gentle',
          body: <String, dynamic>{
            'targetUid': targetUid.trim(),
            'anonymous': anonymous,
            'message': trimmedMessage,
          },
        );
        await _snapshotStore.refresh();
        return;
      } catch (_) {
        // Fall back to local event logging below.
      }
    }
    final DormMember? target = _firstWhereOrNull<DormMember>(
      _currentDorm.members,
      (DormMember member) => member.uid == targetUid,
    );
    if (target == null) {
      return;
    }
    final String senderName = anonymous
        ? '您的舍友'
        : _authRepository.currentUser.displayName;
    _currentDorm = _currentDorm.copyWith(
      events: <DormEvent>[
        DormEvent(
          id: IdGenerator.next('dorm-event'),
          type: DormEventType.notification,
          title: '\u5df2\u53d1\u9001\u59d4\u5a49\u63d0\u9192',
          detail:
              '\u5df2\u7531 $senderName \u5411 ${target.name} \u53d1\u9001\u4e00\u6761\u7ad9\u5185\u63d0\u9192\uff1a$trimmedMessage',
          createdAt: DateTime.now(),
          actorUid: _authRepository.currentUser.uid,
        ),
        ..._currentDorm.events,
      ],
    );
    _emitCurrentState();
    notifyListeners();
  }

  void _applySnapshot() {
    final _SnapshotData snapshot = _SnapshotData.fromPayload(
      _snapshotStore.payload,
      _authRepository.currentUser.uid,
    );
    Dorm mergedDorm = _mergeNewerDormHeartbeatFields(
      _currentDorm,
      _mergeStableDormAvatarUrls(_currentDorm, snapshot.dorm),
    );
    mergedDorm = _mergePendingDormEnvironment(mergedDorm);
    final Map<String, _PendingDormMemberStatusOverride> remainingOverrides =
        _retainUnacknowledgedDormStatusOverrides(
          snapshot.dorm,
          _pendingStatusOverrides,
        );
    _pendingStatusOverrides
      ..clear()
      ..addAll(remainingOverrides);
    _currentDorm = _applyPendingDormStatusOverrides(
      mergedDorm,
      _pendingStatusOverrides,
    );
    _emitCurrentState();
    notifyListeners();
  }

  Dorm _mergePendingDormEnvironment(Dorm incoming) {
    final _PendingDormEnvironmentOverride? pending =
        _pendingEnvironmentOverride;
    if (pending == null) {
      return incoming;
    }
    if (pending.matches(incoming)) {
      _pendingEnvironmentOverride = null;
      return incoming;
    }
    if (pending.matches(_currentDorm)) {
      return pending.apply(incoming);
    }
    _pendingEnvironmentOverride = null;
    return incoming;
  }

  void _emitCurrentState() {
    if (_dormController.isClosed) {
      return;
    }
    _dormController.add(_currentDorm);
    _membersController.add(List<DormMember>.unmodifiable(_currentDorm.members));
    _rulesController.add(List<DormRule>.unmodifiable(_currentDorm.rules));
    _eventsController.add(List<DormEvent>.unmodifiable(_currentDorm.events));
  }

  bool _isProposalFullyApproved(DormPendingRuleProposal proposal) {
    return proposal.reviewerUids.every(proposal.approvedUids.contains);
  }

  String _currentUserDisplayName() {
    return _authRepository.currentUser.displayName.isEmpty
        ? '室友'
        : _authRepository.currentUser.displayName;
  }

  @override
  void dispose() {
    _snapshotStore.removeListener(_applySnapshot);
    _dormController.close();
    _membersController.close();
    _rulesController.close();
    _eventsController.close();
    super.dispose();
  }
}

class CloudBaseDreamRepository extends ChangeNotifier
    implements DreamRepository {
  CloudBaseDreamRepository({
    required AuthRepository authRepository,
    required CloudBaseSnapshotStore snapshotStore,
    required CloudBaseAppApiClient appApiClient,
  }) : _authRepository = authRepository,
       _snapshotStore = snapshotStore,
       _appApiClient = appApiClient {
    _snapshotStore.addListener(_applySnapshot);
  }

  final AuthRepository _authRepository;
  final CloudBaseSnapshotStore _snapshotStore;
  final CloudBaseAppApiClient _appApiClient;
  List<DreamEntry> _entries = const <DreamEntry>[];

  @override
  List<DreamEntry> get entries => List<DreamEntry>.unmodifiable(_entries);

  @override
  DreamEntry? get latestEntry => _entries.isEmpty ? null : _entries.first;

  @override
  Future<void> saveDreamEntry(DreamEntry entry) async {
    final int index = _entries.indexWhere(
      (DreamEntry item) => item.id == entry.id,
    );
    if (index == -1) {
      _entries = <DreamEntry>[entry, ..._entries];
    } else {
      final List<DreamEntry> next = List<DreamEntry>.from(_entries);
      next[index] = entry;
      _entries = next;
    }
    notifyListeners();
    if (_appApiClient.isConfigured) {
      try {
        await _authRepository.ensureAuthenticated();
        await _appApiClient.post(
          '/api/dream/save',
          body: <String, dynamic>{
            'entry': ModelSerializers.dreamEntryToMap(entry),
          },
        );
        await _snapshotStore.refresh();
      } catch (_) {
        // Keep local state.
      }
    }
  }

  @override
  Future<void> deleteDreamEntry(String entryId) async {
    _entries = _entries.where((DreamEntry item) => item.id != entryId).toList();
    notifyListeners();
  }

  void _applySnapshot() {
    final _SnapshotData snapshot = _SnapshotData.fromPayload(
      _snapshotStore.payload,
      _authRepository.currentUser.uid,
    );
    _entries = List<DreamEntry>.from(
      snapshot.dreams,
    )..sort((DreamEntry a, DreamEntry b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  @override
  void dispose() {
    _snapshotStore.removeListener(_applySnapshot);
    super.dispose();
  }
}

class CloudBaseInsightsRepository extends ChangeNotifier
    implements InsightsRepository {
  CloudBaseInsightsRepository({
    required AuthRepository authRepository,
    required CloudBaseSnapshotStore snapshotStore,
    required CloudBaseAppApiClient appApiClient,
    required SleepSessionRepository sleepSessionRepository,
    required DormRepository dormRepository,
    required DreamRepository dreamRepository,
  }) : _authRepository = authRepository,
       _snapshotStore = snapshotStore,
       _appApiClient = appApiClient,
       _sleepSessionRepository = sleepSessionRepository,
       _fallback = InMemoryInsightsRepository(
         sleepSessionRepository: sleepSessionRepository,
         dormRepository: dormRepository,
         dreamRepository: dreamRepository,
       ) {
    _snapshotStore.addListener(_applySnapshot);
    _fallback.addListener(notifyListeners);
  }

  final AuthRepository _authRepository;
  final CloudBaseSnapshotStore _snapshotStore;
  final CloudBaseAppApiClient _appApiClient;
  final SleepSessionRepository _sleepSessionRepository;
  final InMemoryInsightsRepository _fallback;

  Map<String, Map<String, dynamic>> _snapshotData =
      <String, Map<String, dynamic>>{};

  @override
  List<SleepInsight> get interferenceInsights {
    final Map<String, dynamic>? homePreSleep =
        _snapshotData[BackendSurfaceIds.homePreSleep];
    if (homePreSleep == null) {
      return _fallback.interferenceInsights;
    }
    final DateTime createdAt = _dateOf(homePreSleep['generatedAt']);
    final List<SleepInsight> insights = _mapListOf(homePreSleep['cards'])
        .where(
          (Map<String, dynamic> card) => card['type'] == 'interference_factor',
        )
        .map(
          (Map<String, dynamic> card) => SleepInsight(
            id: _stringOf(card['id'], 'factor'),
            category: InsightCategory.interference,
            title: _stringOf(card['title'], '\u5e72\u6270\u56e0\u5b50'),
            summary: _stringOf(card['subtitle']),
            metricLabel: _stringOf(card['metric']),
            createdAt: createdAt,
          ),
        )
        .toList(growable: false);
    return insights.isEmpty ? _fallback.interferenceInsights : insights;
  }

  @override
  SleepReport get currentReport {
    final Map<String, dynamic>? profileReport =
        _snapshotData[BackendSurfaceIds.profileReport];
    if (_shouldPreferFallbackProfileReport(profileReport)) {
      return _fallback.currentReport;
    }
    final Map<String, dynamic> resolvedProfileReport = profileReport!;
    final Map<String, dynamic> summaryCard =
        _mapListOf(resolvedProfileReport['cards']).firstWhere(
          (Map<String, dynamic> card) => card['type'] == 'sleep_report_summary',
          orElse: () => <String, dynamic>{},
        );
    final Map<String, dynamic> payload = _mapOf(summaryCard['payload']);
    if (payload.isEmpty) {
      return _fallback.currentReport;
    }
    return SleepReport(
      title: _stringOf(summaryCard['title'], '\u7761\u7720\u5468\u62a5'),
      averageSleepHours: _doubleOf(payload['averageSleepHours']),
      averageSleepQuality: _doubleOf(payload['averageSleepQuality']),
      averageRestedLevel: _doubleOf(payload['averageRestedLevel']),
      calmNights: _doubleOf(payload['calmNights']).round(),
      dreamEntriesCount: _doubleOf(payload['dreamEntriesCount']).round(),
      highlights: _stringListOf(payload['highlights']),
      generatedAt: _dateOf(resolvedProfileReport['generatedAt']),
    );
  }

  @override
  SleepTrendSeries get profileSleepDurationTrend {
    final Map<String, dynamic>? profileReport =
        _snapshotData[BackendSurfaceIds.profileReport];
    if (_shouldPreferFallbackProfileReport(profileReport)) {
      return _fallback.profileSleepDurationTrend;
    }
    final Map<String, dynamic> resolvedProfileReport = profileReport!;
    final Map<String, dynamic> card = _mapListOf(resolvedProfileReport['cards'])
        .firstWhere(
          (Map<String, dynamic> item) => item['type'] == 'sleep_duration_trend',
          orElse: () => <String, dynamic>{},
        );
    if (card.isEmpty) {
      return _fallback.profileSleepDurationTrend;
    }
    final SleepTrendSeries series = _sleepTrendSeriesFromCard(
      card,
      metricKey: 'sleep_duration',
      unit: 'hours',
    );
    return series.points.isEmpty ? _fallback.profileSleepDurationTrend : series;
  }

  @override
  SleepTrendSeries get profileSleepQualityTrend {
    final Map<String, dynamic>? profileReport =
        _snapshotData[BackendSurfaceIds.profileReport];
    if (_shouldPreferFallbackProfileReport(profileReport)) {
      return _fallback.profileSleepQualityTrend;
    }
    final Map<String, dynamic> resolvedProfileReport = profileReport!;
    final Map<String, dynamic> card = _mapListOf(resolvedProfileReport['cards'])
        .firstWhere(
          (Map<String, dynamic> item) => item['type'] == 'sleep_quality_trend',
          orElse: () => <String, dynamic>{},
        );
    if (card.isEmpty) {
      return _fallback.profileSleepQualityTrend;
    }
    final SleepTrendSeries series = _sleepTrendSeriesFromCard(
      card,
      metricKey: 'sleep_quality',
      unit: 'score',
    );
    return series.points.isEmpty ? _fallback.profileSleepQualityTrend : series;
  }

  @override
  Future<void> refresh() async {
    if (_appApiClient.isConfigured) {
      try {
        await _authRepository.ensureAuthenticated();
        await _appApiClient.post(
          '/api/cards/refresh',
          body: <String, dynamic>{
            'surfaces': <String>[
              BackendSurfaceIds.homePreSleep,
              BackendSurfaceIds.profileReport,
            ],
          },
        );
        await _snapshotStore.refresh();
        return;
      } catch (_) {
        // Fall back to local derived report.
      }
    }
    await _fallback.refresh();
  }

  void _applySnapshot() {
    final _SnapshotData snapshot = _SnapshotData.fromPayload(
      _snapshotStore.payload,
      _authRepository.currentUser.uid,
    );
    _snapshotData = snapshot.cardSnapshots;
    notifyListeners();
  }

  bool _shouldPreferFallbackProfileReport(Map<String, dynamic>? profileReport) {
    if (profileReport == null) {
      return true;
    }
    final dynamic generatedAt = profileReport['generatedAt'];
    if (generatedAt == null) {
      return true;
    }
    final DateTime snapshotGeneratedAt = _dateOf(generatedAt);
    final DateTime? latestLocalCompletedAt = _latestLocalCompletedSessionAt();
    if (latestLocalCompletedAt == null) {
      return false;
    }
    return latestLocalCompletedAt.isAfter(snapshotGeneratedAt);
  }

  DateTime? _latestLocalCompletedSessionAt() {
    DateTime? latest;
    for (final SleepSession session in _sleepSessionRepository.sessions) {
      if (!session.hasSubmittedFeedback) {
        continue;
      }
      final DateTime timestamp =
          session.updatedAt ?? session.displayEndAt ?? session.displayStartAt;
      if (latest == null || timestamp.isAfter(latest)) {
        latest = timestamp;
      }
    }
    return latest;
  }

  @override
  void dispose() {
    _snapshotStore.removeListener(_applySnapshot);
    _fallback.removeListener(notifyListeners);
    _fallback.dispose();
    super.dispose();
  }
}

class CloudBaseAssistantRepository extends ChangeNotifier
    implements AssistantRepository {
  CloudBaseAssistantRepository({
    required AuthRepository authRepository,
    required CloudBaseSnapshotStore snapshotStore,
    required CloudBaseAppApiClient appApiClient,
  }) : _authRepository = authRepository,
       _snapshotStore = snapshotStore,
       _appApiClient = appApiClient {
    final String userId = authRepository.currentUser.uid;
    _assistantProfile = buildDefaultAssistantProfile(userId);
    final AssistantThread thread = AssistantThread(
      id: 'thread-default',
      userId: userId,
      title: '\u4eca\u665a\u7761\u524d\u804a\u804a',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 10)),
    );
    _threads = <AssistantThread>[thread];
    _currentThreadId = thread.id;
    _messagesByThread[thread.id] = <AssistantMessage>[
      AssistantMessage(
        id: 'msg-welcome',
        threadId: thread.id,
        role: AssistantMessageRole.assistant,
        content:
            '\u6211\u5df2\u7ecf\u51c6\u5907\u597d\u966a\u4f60\u8bb0\u5f55\u4eca\u665a\u7684\u72b6\u6001\uff0c\u6211\u4eec\u5148\u4ece\u6700\u5c0f\u3001\u6700\u5bb9\u6613\u6267\u884c\u7684\u4e00\u6b65\u5f00\u59cb\u3002',
        createdAt: DateTime.now().subtract(const Duration(minutes: 9)),
      ),
    ];
    _snapshotStore.addListener(_applySnapshot);
  }

  final AuthRepository _authRepository;
  final CloudBaseSnapshotStore _snapshotStore;
  final CloudBaseAppApiClient _appApiClient;
  late AssistantProfile _assistantProfile;
  List<AssistantThread> _threads = const <AssistantThread>[];
  final Map<String, List<AssistantMessage>> _messagesByThread =
      <String, List<AssistantMessage>>{};
  final Map<String, AssistantThreadTurnState> _turnStatesByThread =
      <String, AssistantThreadTurnState>{};
  final Set<String> _optimisticThreadIds = <String>{};
  String? _currentThreadId;

  String get _userId => _authRepository.currentUser.uid;

  @override
  AssistantProfile get assistantProfile => _assistantProfile;

  @override
  List<AssistantThread> get threads {
    final List<AssistantThread> sorted = List<AssistantThread>.from(_threads)
      ..sort(
        (AssistantThread a, AssistantThread b) =>
            b.updatedAt.compareTo(a.updatedAt),
      );
    return List<AssistantThread>.unmodifiable(sorted);
  }

  @override
  AssistantThread? get currentThread {
    final String? threadId = _currentThreadId;
    if (threadId == null) {
      return null;
    }
    try {
      return _threads.firstWhere((AssistantThread item) => item.id == threadId);
    } on StateError {
      return null;
    }
  }

  @override
  List<AssistantMessage> messagesForThread(String threadId) {
    return List<AssistantMessage>.unmodifiable(
      List<AssistantMessage>.from(
        _messagesByThread[threadId] ?? const <AssistantMessage>[],
      ),
    );
  }

  @override
  AssistantThreadTurnState? turnStateForThread(String threadId) {
    return _turnStatesByThread[threadId];
  }

  void _upsertLocalThread(AssistantThread thread) {
    final int index = _threads.indexWhere(
      (AssistantThread item) => item.id == thread.id,
    );
    if (index == -1) {
      _threads = <AssistantThread>[thread, ..._threads];
    } else {
      final List<AssistantThread> next = List<AssistantThread>.from(_threads);
      next[index] = thread;
      _threads = next;
    }
    _messagesByThread.putIfAbsent(thread.id, () => <AssistantMessage>[]);
  }

  void _replaceLocalThreadId({
    required String previousThreadId,
    required AssistantThread nextThread,
  }) {
    final List<AssistantThread> filtered = _threads
        .where(
          (AssistantThread item) =>
              item.id != previousThreadId && item.id != nextThread.id,
        )
        .toList(growable: false);
    _threads = <AssistantThread>[nextThread, ...filtered];

    final List<AssistantMessage> previousMessages = List<AssistantMessage>.from(
      _messagesByThread.remove(previousThreadId) ??
          _messagesByThread[nextThread.id] ??
          const <AssistantMessage>[],
    );
    _messagesByThread[nextThread.id] = previousMessages
        .map(
          (AssistantMessage item) => item.threadId == nextThread.id
              ? item
              : item.copyWith(threadId: nextThread.id),
        )
        .toList(growable: false);

    final AssistantThreadTurnState? previousTurnState = _turnStatesByThread
        .remove(previousThreadId);
    if (previousTurnState != null) {
      _turnStatesByThread[nextThread.id] = previousTurnState.copyWith(
        threadId: nextThread.id,
      );
    }
  }

  Map<String, List<AssistantMessage>> _copyMessagesByThread() {
    return <String, List<AssistantMessage>>{
      for (final MapEntry<String, List<AssistantMessage>> entry
          in _messagesByThread.entries)
        entry.key: List<AssistantMessage>.from(entry.value),
    };
  }

  List<AssistantMessage> _mergeThreadMessages({
    required List<AssistantMessage> snapshotMessages,
    required List<AssistantMessage> localMessages,
  }) {
    if (localMessages.isEmpty) {
      return List<AssistantMessage>.unmodifiable(snapshotMessages);
    }
    final Map<String, AssistantMessage> snapshotById =
        <String, AssistantMessage>{
          for (final AssistantMessage message in snapshotMessages)
            message.id: message,
        };
    final List<AssistantMessage> merged = <AssistantMessage>[
      for (final AssistantMessage message in localMessages)
        snapshotById.remove(message.id) ?? message,
    ];
    for (final AssistantMessage remoteOnly in snapshotMessages) {
      if (!snapshotById.containsKey(remoteOnly.id)) {
        continue;
      }
      final int insertIndex = merged.indexWhere(
        (AssistantMessage message) =>
            message.createdAt.isAfter(remoteOnly.createdAt),
      );
      if (insertIndex == -1) {
        merged.add(remoteOnly);
      } else {
        merged.insert(insertIndex, remoteOnly);
      }
      snapshotById.remove(remoteOnly.id);
    }
    return List<AssistantMessage>.unmodifiable(merged);
  }

  Map<String, List<AssistantMessage>> _mergeSnapshotMessagesByThread({
    required List<AssistantThread> snapshotThreads,
    required Map<String, List<AssistantMessage>> snapshotMessagesByThread,
    required Map<String, List<AssistantMessage>> previousMessagesByThread,
  }) {
    return <String, List<AssistantMessage>>{
      for (final AssistantThread thread in snapshotThreads)
        if ((snapshotMessagesByThread[thread.id] ?? const <AssistantMessage>[])
                .isNotEmpty ||
            (previousMessagesByThread[thread.id] ?? const <AssistantMessage>[])
                .isNotEmpty)
          thread.id: _mergeThreadMessages(
            snapshotMessages:
                snapshotMessagesByThread[thread.id] ??
                const <AssistantMessage>[],
            localMessages:
                previousMessagesByThread[thread.id] ??
                const <AssistantMessage>[],
          ),
    };
  }

  @override
  Future<AssistantThread> createThread({String? title}) async {
    final AssistantThread localThread = AssistantThread(
      id: IdGenerator.next('assistant-thread'),
      userId: _userId,
      title: title ?? '\u65b0\u5efa\u5bf9\u8bdd',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _optimisticThreadIds.add(localThread.id);
    _upsertLocalThread(localThread);
    _currentThreadId = localThread.id;
    notifyListeners();
    if (_appApiClient.isConfigured) {
      try {
        await _authRepository.ensureAuthenticated();
        final Map<String, dynamic> data = await _appApiClient.post(
          '/api/assistant/threads',
          body: <String, dynamic>{
            if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
          },
        );
        await _snapshotStore.refresh();
        final AssistantThread remoteThread = localThread.copyWith(
          id: _stringOf(data['id'], localThread.id),
          userId: _stringOf(data['userId'], localThread.userId),
          title: _stringOf(data['title'], localThread.title),
          createdAt: data['createdAt'] == null
              ? localThread.createdAt
              : _dateOf(data['createdAt']),
          updatedAt: data['updatedAt'] == null
              ? localThread.updatedAt
              : _dateOf(data['updatedAt']),
        );
        _replaceLocalThreadId(
          previousThreadId: localThread.id,
          nextThread: remoteThread,
        );
        _optimisticThreadIds.remove(localThread.id);
        _currentThreadId = remoteThread.id;
        notifyListeners();
        return currentThread ?? remoteThread;
      } catch (_) {
        return currentThread ?? localThread;
      }
    }
    _optimisticThreadIds.remove(localThread.id);
    return currentThread ?? localThread;
  }

  @override
  Future<void> renameThread({
    required String threadId,
    required String title,
  }) async {
    if (_appApiClient.isConfigured) {
      try {
        await _authRepository.ensureAuthenticated();
        await _appApiClient.post(
          '/api/assistant/threads/$threadId',
          body: <String, dynamic>{'_method': 'PATCH', 'title': title},
        );
        await _snapshotStore.refresh();
        return;
      } catch (_) {
        // Fall back to local state.
      }
    }
    _threads = _threads
        .map(
          (AssistantThread item) => item.id == threadId
              ? item.copyWith(title: title, updatedAt: DateTime.now())
              : item,
        )
        .toList(growable: false);
    notifyListeners();
  }

  @override
  Future<void> deleteThread(String threadId) async {
    if (_appApiClient.isConfigured) {
      try {
        await _authRepository.ensureAuthenticated();
        await _appApiClient.post(
          '/api/assistant/threads/$threadId/delete',
          body: const <String, dynamic>{},
        );
        await _snapshotStore.refresh();
        return;
      } catch (_) {
        // Fall back to local state.
      }
    }
    _threads = _threads
        .where((AssistantThread item) => item.id != threadId)
        .toList(growable: false);
    _messagesByThread.remove(threadId);
    _turnStatesByThread.remove(threadId);
    if (_currentThreadId == threadId) {
      _currentThreadId = _threads.isEmpty ? null : _threads.first.id;
    }
    notifyListeners();
  }

  @override
  Future<void> selectMostRecentThread() async {
    _currentThreadId = threads.isEmpty ? null : threads.first.id;
    notifyListeners();
  }

  @override
  Future<AssistantThread> ensureThread({String? title}) async {
    if (currentThread != null) {
      return currentThread!;
    }
    if (threads.isNotEmpty) {
      await selectMostRecentThread();
      return currentThread!;
    }
    if (_appApiClient.isConfigured) {
      return createThread(title: title ?? '新的睡前陪伴对话');
    }
    final AssistantThread thread = AssistantThread(
      id: IdGenerator.next('assistant-thread'),
      userId: _userId,
      title: title ?? '\u65b0\u7684\u7761\u524d\u966a\u4f34\u5bf9\u8bdd',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _threads = <AssistantThread>[thread, ..._threads];
    _currentThreadId = thread.id;
    _messagesByThread[thread.id] = <AssistantMessage>[];
    notifyListeners();
    return thread;
  }

  @override
  Future<bool> tryStartThreadTurn({
    required String threadId,
    required String turnId,
  }) async {
    final AssistantThreadTurnState? current = _turnStatesByThread[threadId];
    if (current != null && current.status != AssistantThreadTurnStatus.idle) {
      return false;
    }
    _turnStatesByThread[threadId] = AssistantThreadTurnState(
      threadId: threadId,
      turnId: turnId,
      status: AssistantThreadTurnStatus.streaming,
      startedAt: DateTime.now(),
    );
    notifyListeners();
    return true;
  }

  @override
  Future<void> markThreadTurnFinalizing({
    required String threadId,
    required String turnId,
  }) async {
    final AssistantThreadTurnState? current = _turnStatesByThread[threadId];
    if (current == null || current.turnId != turnId) {
      return;
    }
    _turnStatesByThread[threadId] = current.copyWith(
      status: AssistantThreadTurnStatus.finalizing,
    );
    notifyListeners();
  }

  @override
  Future<void> finishThreadTurn({
    required String threadId,
    required String turnId,
  }) async {
    final AssistantThreadTurnState? current = _turnStatesByThread[threadId];
    if (current == null || current.turnId != turnId) {
      return;
    }
    _turnStatesByThread[threadId] = current.copyWith(
      status: AssistantThreadTurnStatus.idle,
    );
    notifyListeners();
  }

  @override
  Future<void> sendUserMessage({
    required String threadId,
    required String content,
    String? messageId,
  }) async {
    final AssistantMessage message = AssistantMessage(
      id: messageId ?? IdGenerator.next('assistant-msg'),
      threadId: threadId,
      role: AssistantMessageRole.user,
      content: content,
      createdAt: DateTime.now(),
    );
    final List<AssistantMessage> next = List<AssistantMessage>.from(
      _messagesByThread[threadId] ?? const <AssistantMessage>[],
    )..add(message);
    _messagesByThread[threadId] = next;
    _touchThread(threadId);
    notifyListeners();
  }

  @override
  Future<void> addAssistantMessage({
    required String threadId,
    required String content,
    String? messageId,
    AssistantMessageStatus status = AssistantMessageStatus.complete,
    AssistantReplySourceMode? sourceMode,
    String? provider,
    String? model,
    String? errorMessage,
  }) async {
    final AssistantMessage message = AssistantMessage(
      id: messageId ?? IdGenerator.next('assistant-msg'),
      threadId: threadId,
      role: AssistantMessageRole.assistant,
      content: content,
      createdAt: DateTime.now(),
      status: status,
      sourceMode: sourceMode,
      provider: provider,
      model: model,
      errorMessage: errorMessage,
    );
    final List<AssistantMessage> next = List<AssistantMessage>.from(
      _messagesByThread[threadId] ?? const <AssistantMessage>[],
    )..add(message);
    _messagesByThread[threadId] = next;
    _touchThread(threadId);
    notifyListeners();
  }

  @override
  Future<void> updateAssistantMessage({
    required String threadId,
    required String messageId,
    String? content,
    AssistantMessageStatus? status,
    AssistantReplySourceMode? sourceMode,
    String? provider,
    String? model,
    String? errorMessage,
  }) async {
    final List<AssistantMessage> next = List<AssistantMessage>.from(
      _messagesByThread[threadId] ?? const <AssistantMessage>[],
    );
    final int index = next.indexWhere(
      (AssistantMessage item) => item.id == messageId,
    );
    if (index == -1) {
      return;
    }
    next[index] = next[index].copyWith(
      content: content,
      status: status,
      sourceMode: sourceMode,
      provider: provider,
      model: model,
      errorMessage: errorMessage,
    );
    _messagesByThread[threadId] = next;
    _touchThread(threadId);
    notifyListeners();
  }

  @override
  Future<void> setCurrentThread(String threadId) async {
    _currentThreadId = threadId;
    notifyListeners();
  }

  @override
  Future<void> updateAssistantProfileName(String assistantName) async {
    _assistantProfile = _assistantProfile.copyWith(
      assistantName: assistantName,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  void _touchThread(String threadId) {
    _threads = _threads
        .map((AssistantThread item) {
          if (item.id != threadId) {
            return item;
          }
          return item.copyWith(updatedAt: DateTime.now());
        })
        .toList(growable: false);
  }

  void _applySnapshot() {
    final List<AssistantThread> previousThreads = List<AssistantThread>.from(
      _threads,
    );
    final Map<String, List<AssistantMessage>> previousMessagesByThread =
        _copyMessagesByThread();
    final String? previousCurrentThreadId = _currentThreadId;
    final _SnapshotData snapshot = _SnapshotData.fromPayload(
      _snapshotStore.payload,
      _userId,
    );
    _threads = snapshot.threads;
    _messagesByThread
      ..clear()
      ..addAll(
        _mergeSnapshotMessagesByThread(
          snapshotThreads: snapshot.threads,
          snapshotMessagesByThread: snapshot.messagesByThread,
          previousMessagesByThread: previousMessagesByThread,
        ),
      );
    _optimisticThreadIds.removeWhere(
      (String threadId) =>
          _threads.any((AssistantThread item) => item.id == threadId),
    );
    _turnStatesByThread.removeWhere(
      (String threadId, AssistantThreadTurnState _) =>
          !_threads.any((AssistantThread item) => item.id == threadId) &&
          !_optimisticThreadIds.contains(threadId),
    );
    final String latestThreadId = _stringOf(
      snapshot.userState['latestThreadId'],
    );
    if (previousCurrentThreadId != null &&
        _threads.any(
          (AssistantThread item) => item.id == previousCurrentThreadId,
        )) {
      _currentThreadId = previousCurrentThreadId;
    } else if (previousCurrentThreadId != null &&
        _optimisticThreadIds.contains(previousCurrentThreadId)) {
      final AssistantThread? optimisticThread = _firstWhereOrNull(
        previousThreads,
        (AssistantThread item) => item.id == previousCurrentThreadId,
      );
      if (optimisticThread != null) {
        _upsertLocalThread(optimisticThread);
        _messagesByThread[optimisticThread.id] = List<AssistantMessage>.from(
          previousMessagesByThread[optimisticThread.id] ??
              const <AssistantMessage>[],
        );
        _currentThreadId = optimisticThread.id;
      } else if (latestThreadId.isNotEmpty &&
          _threads.any((AssistantThread item) => item.id == latestThreadId)) {
        _currentThreadId = latestThreadId;
      } else {
        _currentThreadId = _threads.isEmpty ? null : _threads.first.id;
      }
    } else if (latestThreadId.isNotEmpty &&
        _threads.any((AssistantThread item) => item.id == latestThreadId)) {
      _currentThreadId = latestThreadId;
    } else if (_currentThreadId == null ||
        !_threads.any((AssistantThread item) => item.id == _currentThreadId)) {
      _currentThreadId = _threads.isEmpty ? null : _threads.first.id;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _snapshotStore.removeListener(_applySnapshot);
    super.dispose();
  }
}
