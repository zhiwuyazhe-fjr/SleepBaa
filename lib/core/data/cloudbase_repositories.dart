import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/core/backend/app_environment.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_app_api_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_auth_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_session_store.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_snapshot_store.dart';
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

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) test) {
  for (final T value in values) {
    if (test(value)) {
      return value;
    }
  }
  return null;
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

AudioTrack? _trackForAction(String actionId, String? trackId) {
  final Map<String, NightRecommendation> catalog =
      <String, NightRecommendation>{
        for (final NightRecommendation item in buildDefaultRecommendations())
          item.id: item,
      };
  final AudioTrack? catalogTrack = catalog[actionId]?.track;
  if (catalogTrack != null) {
    return catalogTrack;
  }
  if (trackId == null || trackId.isEmpty) {
    return null;
  }
  return AudioTrack(
    id: trackId,
    title: '\u52a9\u7720\u97f3\u9891',
    subtitle: 'AI \u4e3a\u4f60\u63a8\u8350\u7684\u653e\u677e\u97f3\u8f68',
    duration: const Duration(minutes: 45),
  );
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
  return DormMember(
    uid: _stringOf(map['uid']),
    name: _stringOf(map['name']),
    status:
        _firstWhereOrNull(DormMemberStatus.values, (DormMemberStatus status) {
          return status.name == _stringOf(map['status']);
        }) ??
        DormMemberStatus.quiet,
    sleepModeActive: map['sleepModeActive'] as bool? ?? false,
    lastActiveAt: _dateOf(map['lastActiveAt']),
    note: _stringOf(map['note']),
    avatarUrl: map['avatarUrl'] as String?,
  );
}

DormRule _dormRuleFromMap(Map<String, dynamic> map) {
  return DormRule(
    id: _stringOf(map['id']),
    title: _stringOf(map['title']),
    detail: _stringOf(map['detail']),
  );
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
  final Map<String, dynamic> pending = _mapOf(sleepCapture['pendingMemoBanner']);
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
      sleepCaptureRecords: _mapListOf(root['sleepCaptureRecords'])
          .map(ModelSerializers.sleepCaptureRecordFromMap)
          .toList(growable: false),
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
    required CloudBaseSessionStore sessionStore,
    required CloudBaseSnapshotStore snapshotStore,
  }) : _environment = environment,
       _authClient = authClient,
       _appApiClient = appApiClient,
       _sessionStore = sessionStore,
       _snapshotStore = snapshotStore {
    _snapshotStore.addListener(_syncFromSnapshot);
    _currentUser = buildDefaultUserProfile().copyWith(uid: '', dormId: null);
  }

  final AppEnvironment _environment;
  final CloudBaseAuthClient _authClient;
  final CloudBaseAppApiClient _appApiClient;
  final CloudBaseSessionStore _sessionStore;
  final CloudBaseSnapshotStore _snapshotStore;

  late UserProfile _currentUser;
  bool _isAuthenticating = false;
  String? _lastAuthError;

  @override
  UserProfile get currentUser => _currentUser;

  @override
  bool get isAuthenticated => _currentUser.uid.isNotEmpty;

  @override
  bool get hasVerifiedPhoneIdentity =>
      _currentUser.uid.isNotEmpty &&
      (_currentUser.phoneNumber?.trim().isNotEmpty == true);

  @override
  bool get isAuthenticating => _isAuthenticating;

  @override
  String? get lastAuthError => _lastAuthError;

  UserProfile _signedOutProfile() {
    return buildDefaultUserProfile().copyWith(
      uid: '',
      clearDormId: true,
      clearPhoneNumber: true,
      clearPhoneLinkedAt: true,
      clearAvatar: true,
    );
  }

  Future<UserProfile> _clearSessionAndReset({
    String? message,
    bool clearAll = false,
  }) async {
    if (clearAll) {
      await _sessionStore.clearAll();
    } else {
      await _sessionStore.clearSession();
    }
    _snapshotStore.clear();
    _currentUser = _signedOutProfile();
    _lastAuthError = message;
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

  Future<void> _persistVerifiedPhoneIdentityIfNeeded() async {
    if (!_appApiClient.isConfigured || !hasVerifiedPhoneIdentity) {
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
  Future<UserProfile> ensureAuthenticated() async {
    if (_isAuthenticating) {
      return _currentUser;
    }
    if (!_environment.usesCloudBase) {
      return _currentUser.uid.isNotEmpty
          ? _currentUser
          : buildDefaultUserProfile();
    }
    _isAuthenticating = true;
    _lastAuthError = null;
    notifyListeners();
    try {
      if (!_environment.hasCloudBaseAuthConfig) {
        _lastAuthError =
            'CloudBase \u9274\u6743\u914d\u7f6e\u4e0d\u5b8c\u6574\uff0c\u5f53\u524d\u65e0\u6cd5\u6062\u590d\u767b\u5f55\u72b6\u6001\u3002';
        return _currentUser;
      }
      final String restoredDeviceId = await _sessionStore.ensureDeviceId();
      CloudBaseSession? restoredSession = await _sessionStore.readSession();
      if (restoredSession == null) {
        return _clearSessionAndReset();
      }
      if (restoredSession.isExpired) {
        try {
          final CloudBaseAuthTokenResponse refreshed = await _authClient
              .refreshAccessToken(
                refreshToken: restoredSession.refreshToken,
                deviceId: restoredDeviceId,
              );
          restoredSession = CloudBaseSession(
            accessToken: refreshed.accessToken,
            refreshToken: refreshed.refreshToken,
            subject: refreshed.subject,
            expiresAt: DateTime.now().add(
              Duration(seconds: refreshed.expiresIn),
            ),
            deviceId: restoredDeviceId,
            scope: refreshed.scope,
            tokenType: refreshed.tokenType,
          );
          await _sessionStore.writeSession(restoredSession);
        } catch (_) {
          return _clearSessionAndReset(
            message:
                '\u767b\u5f55\u72b6\u6001\u5df2\u5931\u6548\uff0c\u8bf7\u91cd\u65b0\u4f7f\u7528\u624b\u673a\u53f7\u767b\u5f55\u3002',
          );
        }
      }
      final CloudBaseUserInfo? restoredInfo =
          !hasVerifiedPhoneIdentity || _currentUser.uid.isEmpty
          ? await _readCurrentCloudBaseUser(restoredSession)
          : null;
      if (_currentUser.uid.isEmpty) {
        _currentUser = buildDefaultUserProfile().copyWith(
          uid: restoredSession.subject,
          displayName:
              restoredInfo?.name ?? buildDefaultUserProfile().displayName,
          phoneNumber: restoredInfo?.phoneNumber,
          phoneLinkedAt: restoredInfo?.phoneNumber?.trim().isNotEmpty == true
              ? DateTime.now()
              : null,
          avatarUrl: restoredInfo?.picture,
          clearDormId: true,
        );
      } else if ((_currentUser.phoneNumber?.trim().isNotEmpty != true) &&
          restoredInfo?.phoneNumber?.trim().isNotEmpty == true) {
        _currentUser = _currentUser.copyWith(
          phoneNumber: restoredInfo!.phoneNumber,
          phoneLinkedAt: DateTime.now(),
          avatarUrl: restoredInfo.picture ?? _currentUser.avatarUrl,
        );
      }
      if (_appApiClient.isConfigured) {
        await _snapshotStore.refresh();
      }
      _syncFromSnapshot();
      if (!hasVerifiedPhoneIdentity) {
        return _clearSessionAndReset(
          message:
              '\u5f53\u524d\u767b\u5f55\u72b6\u6001\u7f3a\u5c11\u5df2\u9a8c\u8bc1\u624b\u673a\u53f7\uff0c\u8bf7\u91cd\u65b0\u4f7f\u7528\u624b\u673a\u53f7\u767b\u5f55\u3002',
        );
      }
      return _currentUser;
    } catch (error) {
      return _clearSessionAndReset(message: error.toString());
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  @override
  Future<UserProfile> retryAuthentication() async {
    _lastAuthError = null;
    notifyListeners();
    return ensureAuthenticated();
  }

  @override
  Future<void> signOut() async {
    await _clearSessionAndReset(clearAll: false);
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
          body: <String, dynamic>{
            'profile': ModelSerializers.userProfileToMap(next),
          },
        );
        await _snapshotStore.refresh();
      } catch (error) {
        _lastAuthError = error.toString();
        notifyListeners();
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
          'profile': ModelSerializers.userProfileToMap(profile),
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
    _currentUser = (await ensureAuthenticated()).copyWith(
      avatarPath: avatarPath,
      avatarBytes: avatarBytes,
      avatarUrl: avatarPath ?? _currentUser.avatarUrl,
      avatarStoragePath: _currentUser.avatarStoragePath,
    );
    notifyListeners();
    if (_appApiClient.isConfigured) {
      try {
        await _appApiClient.post(
          '/api/profile/avatar',
          body: <String, dynamic>{
            'avatarPath': avatarPath,
            'avatarBase64': avatarBytes == null
                ? null
                : base64Encode(avatarBytes),
            'fileName': avatarPath?.split('/').last.split('\\').last,
          },
        );
        await _snapshotStore.refresh();
      } catch (error) {
        _lastAuthError = error.toString();
        notifyListeners();
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
    final String deviceId = await _sessionStore.ensureDeviceId();
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
      _throwAuthFlowError(
        _phoneAuthErrorMessage(error, action: 'sendCode', target: target),
      );
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
  Future<void> signInWithPassword({
    required String phoneNumber,
    required String password,
    String? captchaToken,
  }) async {
    _requireCloudBaseAuthConfig();
    final String normalizedPhoneNumber = normalizeCloudBasePhoneNumber(
      phoneNumber,
    );
    final String deviceId = await _sessionStore.ensureDeviceId();
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
    final String verifiedDeviceId = await _sessionStore.ensureDeviceId();
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
    final String verifiedDeviceId = await _sessionStore.ensureDeviceId();
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
    _requireCloudBaseAuthConfig();
    final String requestedPhoneNumber = normalizeCloudBasePhoneNumber(
      phoneNumber,
    );
    final String verifiedDeviceId = await _sessionStore.ensureDeviceId();
    try {
      final CloudBasePhoneVerificationResult verificationResult =
          await _authClient.verifyPhoneCode(
            verificationId: verificationId,
            code: code,
            deviceId: verifiedDeviceId,
          );
      await _authClient.resetPasswordWithVerificationToken(
        phoneNumber: requestedPhoneNumber,
        verificationToken: verificationResult.verificationToken,
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
    final String deviceId = await _sessionStore.ensureDeviceId();
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
    final String deviceId = await _sessionStore.ensureDeviceId();
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
    await _sessionStore.writeSession(
      CloudBaseSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        subject: session.subject,
        expiresAt: DateTime.now().add(Duration(seconds: session.expiresIn)),
        deviceId: deviceId,
        scope: session.scope,
        tokenType: session.tokenType,
      ),
    );
    _lastAuthError = null;
    CloudBaseUserInfo? info;
    try {
      info = await _authClient.getCurrentUser(
        accessToken: session.accessToken,
        deviceId: deviceId,
      );
    } catch (_) {
      info = null;
    }
    final bool hadCurrentUser = _currentUser.uid.isNotEmpty;
    final UserProfile baseProfile = hadCurrentUser
        ? _currentUser
        : buildDefaultUserProfile().copyWith(
            uid: session.subject,
            clearDormId: true,
          );
    _currentUser = baseProfile.copyWith(
      uid: session.subject,
      displayName: info?.name ?? baseProfile.displayName,
      phoneNumber: info?.phoneNumber ?? requestedPhoneNumber,
      phoneLinkedAt: DateTime.now(),
      avatarUrl: info?.picture ?? baseProfile.avatarUrl,
      clearDormId: !hadCurrentUser,
    );
    notifyListeners();
    await _persistVerifiedPhoneIdentityIfNeeded();
    await _safeRefreshSnapshot();
    _syncFromSnapshot();
    if (!hasVerifiedPhoneIdentity) {
      await _clearSessionAndReset(
        message:
            '\u624b\u673a\u53f7\u540c\u6b65\u5931\u8d25\uff0c\u8bf7\u91cd\u65b0\u767b\u5f55\u3002',
      );
      notifyListeners();
      throw const AuthFlowException(
        '\u624b\u673a\u53f7\u540c\u6b65\u5931\u8d25\uff0c\u8bf7\u91cd\u65b0\u767b\u5f55\u3002',
      );
    }
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
    if (message.contains('verification') ||
        message.contains('otp') ||
        message.contains('code') ||
        code.contains('verification')) {
      return '\u9a8c\u8bc1\u7801\u9519\u8bef\u6216\u5df2\u8fc7\u671f\uff0c\u8bf7\u91cd\u65b0\u83b7\u53d6\u540e\u518d\u8bd5\u3002';
    }
    if (message.contains('already') ||
        message.contains('exists') ||
        message.contains('registered') ||
        code.contains('already')) {
      return '\u8fd9\u4e2a\u624b\u673a\u53f7\u5df2\u7ecf\u6ce8\u518c\uff0c\u8bf7\u76f4\u63a5\u767b\u5f55\u3002';
    }
    if (message.contains('not found') ||
        code.contains('not_found') ||
        code.contains('user_not_found')) {
      return '\u672a\u627e\u5230\u8fd9\u4e2a\u624b\u673a\u53f7\u5bf9\u5e94\u7684\u8d26\u53f7\uff0c\u8bf7\u5148\u6ce8\u518c\u3002';
    }
    if (message.contains('password') || code.contains('password')) {
      if (action == 'passwordSignIn') {
        return '\u624b\u673a\u53f7\u6216\u5bc6\u7801\u4e0d\u6b63\u786e\uff0c\u8bf7\u91cd\u8bd5\u3002';
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
    if (message.contains('phone') || code.contains('phone')) {
      return switch (target ?? PhoneVerificationTarget.any) {
        PhoneVerificationTarget.newUser =>
          '\u8fd9\u4e2a\u624b\u673a\u53f7\u5df2\u7ecf\u6ce8\u518c\uff0c\u8bf7\u76f4\u63a5\u767b\u5f55\u3002',
        PhoneVerificationTarget.existingUser =>
          '\u672a\u627e\u5230\u8fd9\u4e2a\u624b\u673a\u53f7\u5bf9\u5e94\u7684\u8d26\u53f7\uff0c\u8bf7\u5148\u6ce8\u518c\u3002',
        PhoneVerificationTarget.any =>
          '\u624b\u673a\u53f7\u6821\u9a8c\u5931\u8d25\uff0c\u8bf7\u786e\u8ba4\u8f93\u5165\u65e0\u8bef\u3002',
      };
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
    final _SnapshotData snapshot = _SnapshotData.fromPayload(
      _snapshotStore.payload,
      _currentUser.uid,
    );
    if (snapshot.user.uid.isEmpty) {
      return;
    }
    final String? snapshotPhone = snapshot.user.phoneNumber;
    final DateTime? snapshotPhoneLinkedAt = snapshot.user.phoneLinkedAt;
    _currentUser = _currentUser.copyWith(
      uid: snapshot.user.uid,
      displayName: snapshot.user.displayName,
      tagline: snapshot.user.tagline,
      role: snapshot.user.role,
      dormId: snapshot.user.dormId,
      phoneNumber: snapshotPhone?.trim().isNotEmpty == true
          ? snapshotPhone
          : _currentUser.phoneNumber,
      phoneLinkedAt: snapshotPhoneLinkedAt ?? _currentUser.phoneLinkedAt,
      avatarUrl: snapshot.user.avatarUrl,
      avatarPath: snapshot.user.avatarPath,
      avatarStoragePath: snapshot.user.avatarStoragePath,
      avatarFallbackSeed: snapshot.user.avatarFallbackSeed,
    );
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
  }) : _authRepository = authRepository,
       _snapshotStore = snapshotStore,
       _appApiClient = appApiClient {
    _snapshotStore.addListener(_applySnapshot);
    _settings = buildDefaultUserSettings();
  }

  final AuthRepository _authRepository;
  final CloudBaseSnapshotStore _snapshotStore;
  final CloudBaseAppApiClient _appApiClient;

  late UserSettings _settings;
  NightMood? _pendingMoodOverride;

  @override
  UserSettings get currentSettings => _settings;

  void replaceLocalSettings(UserSettings settings) {
    _settings = settings;
    notifyListeners();
  }

  @override
  Future<void> saveSettings(UserSettings settings) async {
    final NightMood? previousMood = _settings.selectedNightMood;
    if (previousMood != settings.selectedNightMood) {
      _pendingMoodOverride = settings.selectedNightMood;
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
    final _SnapshotData snapshot = _SnapshotData.fromPayload(
      _snapshotStore.payload,
      _authRepository.currentUser.uid,
    );
    final UserSettings incoming = snapshot.settings;
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
    notifyListeners();
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
       _tonightRecommendations = buildDefaultRecommendations() {
    _snapshotStore.addListener(_applySnapshot);
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
        return;
      } catch (_) {
        // Fall back to local defaults below.
      }
    }
    _tonightRecommendations = buildDefaultRecommendations()
        .map(
          (NightRecommendation item) =>
              item.copyWith(executionState: RecommendationExecutionState.idle),
        )
        .toList(growable: false);
    notifyListeners();
  }

  @override
  Future<void> setRecommendationState(
    String recommendationId,
    RecommendationExecutionState state,
  ) async {
    _tonightRecommendations = _tonightRecommendations
        .map((NightRecommendation item) {
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
    _tonightRecommendations = actions
        .map(_recommendationFromAction)
        .toList(growable: false);
    notifyListeners();
  }

  @override
  void dispose() {
    _snapshotStore.removeListener(_applySnapshot);
    super.dispose();
  }
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

  List<SleepSession> _sessions = const <SleepSession>[];

  @override
  SleepSession? get activeSession {
    try {
      return _sessions.lastWhere(
        (SleepSession session) => session.status == SleepSessionStatus.active,
      );
    } on StateError {
      return null;
    }
  }

  @override
  List<SleepSession> get sessions => List<SleepSession>.unmodifiable(_sessions);

  @override
  SleepSession? get latestAwaitingFeedbackSession {
    final List<SleepSession> pending =
        _sessions
            .where(
              (SleepSession session) =>
                  session.status == SleepSessionStatus.awaitingFeedback,
            )
            .toList()
          ..sort(
            (SleepSession a, SleepSession b) =>
                b.startedAt.compareTo(a.startedAt),
          );
    return pending.isEmpty ? null : pending.first;
  }

  @override
  List<SleepSession> recentSessions({int count = 7}) {
    final List<SleepSession> items = List<SleepSession>.from(_sessions)
      ..sort(
        (SleepSession a, SleepSession b) => a.startedAt.compareTo(b.startedAt),
      );
    return items.reversed.take(count).toList().reversed.toList();
  }

  @override
  List<SleepSession> sessionsForMonth(DateTime month) {
    return _sessions
        .where((SleepSession session) {
          return session.startedAt.year == month.year &&
              session.startedAt.month == month.month;
        })
        .toList(growable: false);
  }

  @override
  Future<SleepSession> startSleepSession({
    required List<NightRecommendation> recommendationSnapshot,
    required String? dormId,
  }) async {
    final SleepSession? existing = activeSession;
    if (existing != null) {
      return existing;
    }

    final UserProfile user = await _authRepository.ensureAuthenticated();
    if (_appApiClient.isConfigured) {
      try {
        await _appApiClient.post(
          '/api/sleep/enter',
          body: <String, dynamic>{
            'dormId': dormId,
            'recommendationSnapshot': recommendationSnapshot
                .map(ModelSerializers.recommendationToMap)
                .toList(growable: false),
            'selectedRecommendationIds': recommendationSnapshot
                .where(
                  (NightRecommendation item) =>
                      item.executionState != RecommendationExecutionState.idle,
                )
                .map((NightRecommendation item) => item.id)
                .toList(growable: false),
          },
        );
        await _snapshotStore.refresh();
        return activeSession ?? _sessions.last;
      } catch (_) {
        // Fall back to local session creation.
      }
    }

    final DateTime now = DateTime.now();
    final SleepSession session = SleepSession(
      id: IdGenerator.next('session'),
      uid: user.uid,
      startedAt: now,
      endedAt: null,
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
      awakenings: const <NightAwakeningEntry>[],
      feedback: const <RecommendationFeedback>[],
      summary: null,
      updatedAt: now,
    );
    _upsertLocalSession(session);
    return session;
  }

  @override
  Future<void> updateActiveSession({
    bool? sleepModeActive,
    SleepSessionStatus? status,
    DateTime? endedAt,
    List<String>? selectedRecommendationIds,
  }) async {
    final SleepSession? existing = activeSession;
    if (existing == null) {
      return;
    }
    final SleepSession next = existing.copyWith(
      sleepModeActive: sleepModeActive,
      status: status,
      endedAt: endedAt,
      selectedRecommendationIds:
          selectedRecommendationIds ?? existing.selectedRecommendationIds,
      updatedAt: DateTime.now(),
    );
    await saveSession(next);
  }

  @override
  Future<void> saveSession(SleepSession session) async {
    _upsertLocalSession(session);
    if (!_appApiClient.isConfigured) {
      return;
    }
    try {
      await _appApiClient.post(
        session.status == SleepSessionStatus.active
            ? '/api/sleep/enter'
            : '/api/sleep/exit',
        body: <String, dynamic>{
          'session': ModelSerializers.sleepSessionToMap(session),
        },
      );
      await _snapshotStore.refresh();
    } catch (_) {
      // Keep local state if network sync fails.
    }
  }

  void _upsertLocalSession(SleepSession session) {
    final int index = _sessions.indexWhere(
      (SleepSession item) => item.id == session.id,
    );
    if (index == -1) {
      _sessions = <SleepSession>[..._sessions, session];
    } else {
      final List<SleepSession> next = List<SleepSession>.from(_sessions);
      next[index] = session;
      _sessions = next;
    }
    _sessions = List<SleepSession>.from(_sessions)
      ..sort(
        (SleepSession a, SleepSession b) => a.startedAt.compareTo(b.startedAt),
      );
    notifyListeners();
  }

  void _applySnapshot() {
    final _SnapshotData snapshot = _SnapshotData.fromPayload(
      _snapshotStore.payload,
      _authRepository.currentUser.uid,
    );
    _sessions = List<SleepSession>.from(snapshot.sessions)
      ..sort(
        (SleepSession a, SleepSession b) => a.startedAt.compareTo(b.startedAt),
      );
    notifyListeners();
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
    await _sleepSessionRepository.saveSession(
      session.copyWith(
        status: SleepSessionStatus.completed,
        summary: summary,
        feedback: recommendationFeedback,
        updatedAt: DateTime.now(),
      ),
    );
    if (_appApiClient.isConfigured) {
      try {
        await _appApiClient.post(
          '/api/feedback/morning',
          body: <String, dynamic>{
            'sessionId': session.id,
            'summary': ModelSerializers.morningSummaryToMap(summary),
            'recommendationFeedback': recommendationFeedback
                .map(ModelSerializers.recommendationFeedbackToMap)
                .toList(growable: false),
          },
        );
        await _snapshotStore.refresh();
      } catch (_) {
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
    final List<SleepCaptureRecord> matches = _records
        .where((SleepCaptureRecord item) => item.type == type)
        .toList()
      ..sort(
        (SleepCaptureRecord a, SleepCaptureRecord b) =>
            b.createdAt.compareTo(a.createdAt),
      );
    return List<SleepCaptureRecord>.unmodifiable(matches);
  }

  @override
  List<SleepCaptureRecord> recordsForSession(String sessionId) {
    final List<SleepCaptureRecord> matches = _records
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
      title: title ?? _buildTitle(type: type, now: now, content: normalizedContent),
      outline:
          outline ?? _buildOutline(type: type, content: normalizedContent),
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
  }) : _authRepository = authRepository,
       _snapshotStore = snapshotStore {
    _snapshotStore.addListener(_applySnapshot);
  }

  final AuthRepository _authRepository;
  final CloudBaseSnapshotStore _snapshotStore;
  List<NotificationItem> _notifications = const <NotificationItem>[];
  final Set<String> _tokens = <String>{};

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
    _notifications = _notifications
        .map((NotificationItem item) {
          if (item.id != notificationId) {
            return item;
          }
          return item.copyWith(readAt: DateTime.now());
        })
        .toList(growable: false);
    notifyListeners();
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

  @override
  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    _tokens.add('$platform:$token');
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
  final StreamController<Dorm> _dormController =
      StreamController<Dorm>.broadcast();
  final StreamController<List<DormMember>> _membersController =
      StreamController<List<DormMember>>.broadcast();
  final StreamController<List<DormRule>> _rulesController =
      StreamController<List<DormRule>>.broadcast();
  final StreamController<List<DormEvent>> _eventsController =
      StreamController<List<DormEvent>>.broadcast();

  Dorm _currentDorm;

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
  Future<void> createDorm({
    required String name,
    String? overview,
    DormRulesSettings? rulesSettings,
  }) async {
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
    );
    _emitCurrentState();
    notifyListeners();
  }

  @override
  Future<void> updateCurrentUserStatus({
    required String uid,
    required DormMemberStatus status,
    required bool sleepModeActive,
    required String note,
  }) async {
    if (_currentDorm.id.isEmpty) {
      return;
    }
    _currentDorm = _currentDorm.copyWith(
      members: _currentDorm.members
          .map((DormMember member) {
            if (member.uid != uid) {
              return member;
            }
            return member.copyWith(
              status: status,
              sleepModeActive: sleepModeActive,
              lastActiveAt: DateTime.now(),
              note: note,
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
          detail: note,
          createdAt: DateTime.now(),
          actorUid: uid,
        ),
        ..._currentDorm.events,
      ],
    );
    _emitCurrentState();
    notifyListeners();
  }

  @override
  Future<void> saveRules(DormRulesSettings settings) async {
    if (_currentDorm.id.isEmpty) {
      return;
    }
    _currentDorm = _currentDorm.copyWith(
      rulesSettings: settings,
      rules: buildDormSummaryRules(settings),
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
        await _snapshotStore.refresh();
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
  Future<void> sendGentleReminder({required String targetUid}) async {
    if (_currentDorm.id.isEmpty || targetUid.trim().isEmpty) {
      return;
    }
    if (_appApiClient.isConfigured) {
      try {
        await _authRepository.ensureAuthenticated();
        await _appApiClient.post(
          '/api/dorm/reminders/gentle',
          body: <String, dynamic>{'targetUid': targetUid.trim()},
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
    _currentDorm = _currentDorm.copyWith(
      events: <DormEvent>[
        DormEvent(
          id: IdGenerator.next('dorm-event'),
          type: DormEventType.notification,
          title: '\u5df2\u53d1\u9001\u59d4\u5a49\u63d0\u9192',
          detail:
              '\u5df2\u5411 ${target.name} \u53d1\u9001\u4e00\u6761\u7ad9\u5185\u63d0\u9192\u3002',
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
    _currentDorm = snapshot.dorm;
    _emitCurrentState();
    notifyListeners();
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
    if (profileReport == null) {
      return _fallback.currentReport;
    }
    final Map<String, dynamic> summaryCard = _mapListOf(profileReport['cards'])
        .firstWhere(
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
      generatedAt: _dateOf(profileReport['generatedAt']),
    );
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
    final List<AssistantMessage> sorted =
        List<AssistantMessage>.from(
          _messagesByThread[threadId] ?? const <AssistantMessage>[],
        )..sort(
          (AssistantMessage a, AssistantMessage b) =>
              a.createdAt.compareTo(b.createdAt),
        );
    return List<AssistantMessage>.unmodifiable(sorted);
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

  Map<String, List<AssistantMessage>> _copyMessagesByThread() {
    return <String, List<AssistantMessage>>{
      for (final MapEntry<String, List<AssistantMessage>> entry
          in _messagesByThread.entries)
        entry.key: List<AssistantMessage>.from(entry.value),
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
        if (!_threads.any(
          (AssistantThread item) => item.id == remoteThread.id,
        )) {
          _optimisticThreadIds.add(remoteThread.id);
          _upsertLocalThread(remoteThread);
        } else {
          _optimisticThreadIds.remove(remoteThread.id);
        }
        _currentThreadId = remoteThread.id;
        notifyListeners();
        return currentThread ?? remoteThread;
      } catch (_) {
        // Fall back to local state.
      }
    }
    _threads = <AssistantThread>[localThread, ..._threads];
    _messagesByThread[localThread.id] = <AssistantMessage>[];
    _currentThreadId = localThread.id;
    notifyListeners();
    return localThread;
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
      ..addAll(snapshot.messagesByThread);
    _optimisticThreadIds.removeWhere(
      (String threadId) =>
          _threads.any((AssistantThread item) => item.id == threadId),
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
