import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/routes.dart';
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
    title: '助眠音频',
    subtitle: 'AI 为你推荐的放松音轨',
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
    title: known?.title ?? _stringOf(action['title'], '今晚行动'),
    subtitle: known?.subtitle ?? _stringOf(action['subtitle'], '先按今晚建议做一个小动作。'),
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
    name: '未加入宿舍',
    overview: '你还没有加入宿舍，先创建宿舍或使用邀请码加入吧。',
    noiseDb: 0,
    status: DormStatus.active,
    archivedAt: null,
    lightLabel: '未设置',
    quietLabel: '未加入',
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
    name: _stringOf(map['name'], '宿舍'),
    overview: _stringOf(map['overview'], '已加入宿舍协作空间。'),
    noiseDb: (map['noiseDb'] as num?)?.toInt() ?? 32,
    status:
        _firstWhereOrNull(DormStatus.values, (DormStatus status) {
          return status.name == _stringOf(map['status']);
        }) ??
        DormStatus.active,
    archivedAt: map['archivedAt'] == null ? null : _dateOf(map['archivedAt']),
    lightLabel: _stringOf(map['lightLabel'], '平稳'),
    quietLabel: _stringOf(map['quietLabel'], '良好'),
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

NotificationItem _notificationFromMap(Map<String, dynamic> map) {
  return NotificationItem(
    id: _stringOf(map['id']),
    category:
        _firstWhereOrNull(
          NotificationCategory.values,
          (NotificationCategory category) =>
              category.name == _stringOf(map['category']),
        ) ??
        NotificationCategory.system,
    title: _stringOf(map['title']),
    body: _stringOf(map['body']),
    createdAt: _dateOf(map['createdAt']),
    route: _stringOf(map['route'], AppRoutes.home),
    readAt: map['readAt'] == null ? null : _dateOf(map['readAt']),
    ownerUid: map['ownerUid'] as String?,
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

class _SnapshotData {
  const _SnapshotData({
    required this.user,
    required this.settings,
    required this.dorm,
    required this.sessions,
    required this.dreams,
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
      userState: _mapOf(root['userState']),
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
  bool get isAuthenticating => _isAuthenticating;

  @override
  String? get lastAuthError => _lastAuthError;

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
        _currentUser = buildDefaultUserProfile().copyWith(
          uid: _currentUser.uid.isEmpty
              ? IdGenerator.next('cloudbase-local')
              : _currentUser.uid,
        );
        _lastAuthError = 'CloudBase 鉴权尚未配置完整，当前先回退到本地模式。';
        return _currentUser;
      }

      final String deviceId = await _sessionStore.ensureDeviceId();
      CloudBaseSession? session = await _sessionStore.readSession();
      if (session == null) {
        final CloudBaseAuthTokenResponse token = await _authClient
            .signInAnonymously(deviceId: deviceId);
        session = CloudBaseSession(
          accessToken: token.accessToken,
          refreshToken: token.refreshToken,
          subject: token.subject,
          expiresAt: DateTime.now().add(Duration(seconds: token.expiresIn)),
          deviceId: deviceId,
          scope: token.scope,
          tokenType: token.tokenType,
        );
        await _sessionStore.writeSession(session);
      }

      if (_appApiClient.isConfigured) {
        await _snapshotStore.refresh();
      }
      _syncFromSnapshot();

      if (_currentUser.uid.isEmpty) {
        CloudBaseUserInfo? info;
        try {
          info = await _authClient.getCurrentUser(
            accessToken: session.accessToken,
            deviceId: session.deviceId,
          );
        } catch (_) {
          info = null;
        }
        _currentUser = buildDefaultUserProfile().copyWith(
          uid: session.subject,
          displayName: info?.name ?? buildDefaultUserProfile().displayName,
          avatarUrl: info?.picture,
        );
      }

      return _currentUser;
    } catch (error) {
      _lastAuthError = error.toString();
      if (_currentUser.uid.isEmpty) {
        _currentUser = buildDefaultUserProfile().copyWith(
          uid: IdGenerator.next('cloudbase-fallback'),
        );
      }
      return _currentUser;
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
            'avatarBase64': avatarBytes == null ? null : base64Encode(avatarBytes),
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
    String phoneNumber,
  ) async {
    final UserProfile user = await ensureAuthenticated();
    if (!_environment.hasCloudBaseAuthConfig) {
      throw StateError('CloudBase 手机号登录尚未配置。');
    }
    final String normalizedPhoneNumber = normalizeCloudBasePhoneNumber(
      phoneNumber,
    );
    final String deviceId = await _sessionStore.ensureDeviceId();
    final CloudBasePhoneVerificationStart result = await _authClient
        .sendPhoneVerificationCode(
          phoneNumber: normalizedPhoneNumber,
          deviceId: deviceId,
        );
    _currentUser = user;
    notifyListeners();
    return PhoneVerificationChallenge(
      verificationId: result.verificationId,
      expiresIn: result.expiresIn,
      isExistingUser: result.isUser,
    );
  }

  @override
  Future<void> recoverWithPhone({
    required String phoneNumber,
    required String verificationId,
    required String code,
  }) async {
    await ensureAuthenticated();
    final String normalizedPhoneNumber = normalizeCloudBasePhoneNumber(
      phoneNumber,
    );
    final String deviceId = await _sessionStore.ensureDeviceId();
    final CloudBasePhoneVerificationResult verification = await _authClient
        .verifyPhoneCode(
          verificationId: verificationId,
          code: code,
          deviceId: deviceId,
        );
    CloudBaseAuthTokenResponse phoneSession;
    try {
      phoneSession = await _authClient.signInWithVerificationToken(
        verificationToken: verification.verificationToken,
        deviceId: deviceId,
      );
    } on CloudBaseAuthException catch (error) {
      if (error.statusCode != 404) {
        rethrow;
      }
      phoneSession = await _authClient.signUpWithVerificationToken(
        verificationToken: verification.verificationToken,
        deviceId: deviceId,
      );
    }
    await _appApiClient.post(
      '/api/auth/recover-phone-account',
      body: <String, dynamic>{
        'phoneNumber': normalizedPhoneNumber,
        'verificationToken': verification.verificationToken,
        'phoneAccessToken': phoneSession.accessToken,
      },
    );
    await _sessionStore.writeSession(
      CloudBaseSession(
        accessToken: phoneSession.accessToken,
        refreshToken: phoneSession.refreshToken,
        subject: phoneSession.subject,
        expiresAt: DateTime.now().add(Duration(seconds: phoneSession.expiresIn)),
        deviceId: deviceId,
        scope: phoneSession.scope,
        tokenType: phoneSession.tokenType,
      ),
    );
    await _snapshotStore.refresh();
    _syncFromSnapshot();
  }

  void _syncFromSnapshot() {
    final _SnapshotData snapshot = _SnapshotData.fromPayload(
      _snapshotStore.payload,
      _currentUser.uid,
    );
    if (snapshot.user.uid.isEmpty) {
      return;
    }
    _currentUser = _currentUser.copyWith(
      uid: snapshot.user.uid,
      displayName: snapshot.user.displayName,
      tagline: snapshot.user.tagline,
      role: snapshot.user.role,
      dormId: snapshot.user.dormId,
      phoneNumber: snapshot.user.phoneNumber,
      phoneLinkedAt: snapshot.user.phoneLinkedAt,
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
      overview: overview ?? '新宿舍已经创建，接下来可以邀请舍友加入。',
      noiseDb: 28,
      lightLabel: '适中',
      quietLabel: '可优化',
      rules: buildDormSummaryRules(nextRules),
      members: <DormMember>[
        DormMember(
          uid: _authRepository.currentUser.uid,
          name: _authRepository.currentUser.displayName,
          status: DormMemberStatus.quiet,
          sleepModeActive: false,
          lastActiveAt: now,
          note: '已创建宿舍，等待邀请舍友加入。',
          avatarUrl: _authRepository.currentUser.avatarUrl,
        ),
      ],
      rulesSettings: nextRules,
      events: <DormEvent>[
        DormEvent(
          id: IdGenerator.next('dorm-event'),
          type: DormEventType.system,
          title: '宿舍已创建',
          detail: '你现在可以生成邀请码并邀请舍友加入。',
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
          title: uid == _authRepository.currentUser.uid ? '你已更新状态' : '舍友更新了状态',
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
      throw StateError('请先创建宿舍或加入宿舍，再邀请舍友。');
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
                note: '已通过邀请码加入宿舍。',
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
                  (DormInvite invite) => invite.copyWith(
                    status: DormInviteStatus.revoked,
                  ),
                )
                .toList(growable: false),
          )
        : _currentDorm.copyWith(members: remainingMembers);
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
            title: _stringOf(card['title'], '干扰因子'),
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
      title: _stringOf(summaryCard['title'], '睡眠周报'),
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
    final AssistantThread thread = AssistantThread(
      id: 'thread-default',
      userId: userId,
      title: '今晚睡前聊聊',
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
        content: '我已经准备好陪你记录今晚的状态，我们先从最小、最容易执行的一步开始。',
        createdAt: DateTime.now().subtract(const Duration(minutes: 9)),
      ),
    ];
    _snapshotStore.addListener(_applySnapshot);
  }

  final AuthRepository _authRepository;
  final CloudBaseSnapshotStore _snapshotStore;
  final CloudBaseAppApiClient _appApiClient;
  List<AssistantThread> _threads = const <AssistantThread>[];
  final Map<String, List<AssistantMessage>> _messagesByThread =
      <String, List<AssistantMessage>>{};
  String? _currentThreadId;

  String get _userId => _authRepository.currentUser.uid;

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

  @override
  Future<AssistantThread> createThread({String? title}) async {
    final AssistantThread localThread = AssistantThread(
      id: IdGenerator.next('assistant-thread'),
      userId: _userId,
      title: title ?? '新建对话',
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
        _currentThreadId = _stringOf(data['id'], localThread.id);
        notifyListeners();
        return currentThread ?? localThread;
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
      title: title ?? '新的睡前陪伴对话',
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
  }) async {
    final AssistantMessage message = AssistantMessage(
      id: IdGenerator.next('assistant-msg'),
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
    AssistantMessageStatus status = AssistantMessageStatus.complete,
  }) async {
    final AssistantMessage message = AssistantMessage(
      id: IdGenerator.next('assistant-msg'),
      threadId: threadId,
      role: AssistantMessageRole.assistant,
      content: content,
      createdAt: DateTime.now(),
      status: status,
    );
    final List<AssistantMessage> next = List<AssistantMessage>.from(
      _messagesByThread[threadId] ?? const <AssistantMessage>[],
    )..add(message);
    _messagesByThread[threadId] = next;
    _touchThread(threadId);
    notifyListeners();
  }

  @override
  Future<void> setCurrentThread(String threadId) async {
    _currentThreadId = threadId;
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
    final _SnapshotData snapshot = _SnapshotData.fromPayload(
      _snapshotStore.payload,
      _userId,
    );
    _threads = snapshot.threads;
    _messagesByThread
      ..clear()
      ..addAll(snapshot.messagesByThread);
    final String latestThreadId = _stringOf(snapshot.userState['latestThreadId']);
    if (latestThreadId.isNotEmpty &&
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
