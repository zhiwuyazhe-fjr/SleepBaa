import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_auth_client.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/utils/id_generator.dart';

UserProfile buildDefaultUserProfile() {
  return const UserProfile(
    uid: 'anon-paul',
    displayName: 'Paul',
    tagline: 'Dorm Sleep Explorer',
    role: '宿舍睡眠优化实验成员',
    earnedBadgeIds: <String>['first-week', 'early-sleeper', 'sleep-master'],
    dormId: 'dorm-204',
    showDormPulseBadge: true,
    phoneNumber: null,
    phoneLinkedAt: null,
    avatarFallbackSeed: 'Paul',
  );
}

UserSettings buildDefaultUserSettings() {
  return const UserSettings(
    sleepGoalHours: 7.5,
    bedtimeReminderEnabled: true,
    morningReminderEnabled: true,
    dormAlertsEnabled: true,
    bedtimeReminder: TimeOfDay(hour: 23, minute: 10),
    preferredTrackTitle: '深海海浪',
    smartSuggestionsEnabled: true,
  );
}

AssistantProfile buildDefaultAssistantProfile(String userId) {
  return AssistantProfile(
    userId: userId,
    assistantName: '小眠',
    identityPrompt: '你是小眠，一位温和、低压、不评判的情绪陪伴型睡前助手。',
    tone: '温柔、稳定、共情',
    relationshipRole: '情绪陪伴助手',
    updatedAt: DateTime.now(),
  );
}

DormRulesSettings buildDefaultDormRulesSettings() {
  return DormRulesSettings.defaults();
}

List<DormRule> buildDormSummaryRules(DormRulesSettings settings) {
  return <DormRule>[
    DormRule(
      id: 'quiet-hours',
      title: '安静时段 ${settings.quietHours}',
      detail: settings.specialCase,
    ),
    DormRule(
      id: 'lights-off',
      title: settings.lightsOffTime,
      detail: settings.personalLighting,
    ),
  ];
}

Dorm buildDefaultDorm(String currentUserId) {
  final DormRulesSettings settings = buildDefaultDormRulesSettings();
  return Dorm(
    id: 'dorm-204',
    name: '梅苑 2 栋 204',
    overview: '宿舍整体状态平稳，灯光已调暗，适合逐步进入睡眠模式。',
    noiseDb: 32,
    lightLabel: '偏暗',
    quietLabel: '良好',
    rules: buildDormSummaryRules(settings),
    status: DormStatus.active,
    rulesSettings: settings,
    members: <DormMember>[
      DormMember(
        uid: currentUserId,
        name: 'Paul',
        status: DormMemberStatus.quiet,
        presenceStatus: DormPresenceStatus.returned,
        sleepModeActive: false,
        lastActiveAt: DateTime.now().subtract(const Duration(minutes: 22)),
        note: '准备做睡前放松。',
        displayBadgeId: 'sleep-master',
      ),
      DormMember(
        uid: 'roommate-a',
        name: '林淯',
        status: DormMemberStatus.quiet,
        presenceStatus: DormPresenceStatus.returned,
        sleepModeActive: true,
        lastActiveAt: DateTime.now().subtract(const Duration(minutes: 12)),
        note: '已开启睡眠模式。',
        displayBadgeId: 'monthly-perfect',
      ),
      DormMember(
        uid: 'roommate-b',
        name: '阿哲',
        status: DormMemberStatus.active,
        presenceStatus: DormPresenceStatus.away,
        sleepModeActive: false,
        lastActiveAt: DateTime.now().subtract(const Duration(minutes: 6)),
        note: '正在收拾桌面，预计 10 分钟后安静下来。',
        displayBadgeId: 'quiet-guardian',
      ),
    ],
    events: <DormEvent>[
      DormEvent(
        id: 'seed-event-quiet',
        type: DormEventType.notification,
        title: '宿舍环境保持安静',
        detail: '公共灯已经关闭，环境噪声保持在 35 dB 以下。',
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
      DormEvent(
        id: 'seed-event-status',
        type: DormEventType.memberStatus,
        title: '林淯已切换到睡眠模式',
        detail: '睡眠模式已开启，并已戴上耳机。',
        createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
        actorUid: 'roommate-a',
      ),
    ],
    invites: const <DormInvite>[],
    locationAnchor: DormLocationAnchor(
      latitude: 31.2304,
      longitude: 121.4737,
      radiusMeters: 100,
      recordedAt: DateTime.now().subtract(const Duration(days: 2)),
      recordedByUid: currentUserId,
    ),
    earnedDormBadgeIds: <String>['no-trouble-room', 'no-wake-room'],
  );
}

List<NightRecommendation> buildDefaultRecommendations() {
  return <NightRecommendation>[
    NightRecommendation(
      id: 'audio-ocean',
      title: '睡前放松音频',
      subtitle: '先用 15 分钟让身体慢慢降速，再进入正式睡眠模式。',
      type: RecommendationType.audio,
      icon: Icons.dark_mode_rounded,
      tags: const <String>['15 分钟', '深度放松'],
      executionState: RecommendationExecutionState.idle,
      track: const AudioTrack(
        id: 'deep-ocean',
        title: '深海海浪',
        subtitle: '低刺激白噪音 · 45 分钟',
        duration: Duration(minutes: 45),
      ),
    ),
    NightRecommendation(
      id: 'audio-rain',
      title: '夜雨白噪音',
      subtitle: '用连续雨声盖掉零碎杂音，适合容易被环境声打断的夜晚。',
      type: RecommendationType.audio,
      icon: Icons.water_drop_rounded,
      tags: const <String>['20 分钟', '雨声'],
      executionState: RecommendationExecutionState.idle,
      track: const AudioTrack(
        id: 'rain-mist',
        title: '雨夜薄雾',
        subtitle: '细密雨声背景 · 30 分钟',
        duration: Duration(minutes: 30),
      ),
    ),
    NightRecommendation(
      id: 'audio-breeze',
      title: '午夜微风',
      subtitle: '轻柔风声与低频底噪混合，更适合需要长时间陪伴的入睡阶段。',
      type: RecommendationType.audio,
      icon: Icons.air_rounded,
      tags: const <String>['25 分钟', '轻风'],
      executionState: RecommendationExecutionState.idle,
      track: const AudioTrack(
        id: 'midnight-breeze',
        title: '午夜微风',
        subtitle: '轻风包裹感 · 25 分钟',
        duration: Duration(minutes: 25),
      ),
    ),
    NightRecommendation(
      id: 'earplug',
      title: '佩戴隔音耳塞',
      subtitle: '先把随机噪声压下去，减少半夜被打断的概率。',
      type: RecommendationType.quickAction,
      icon: Icons.hearing_rounded,
      tags: const <String>['1 分钟', '降噪'],
      executionState: RecommendationExecutionState.idle,
    ),
    NightRecommendation(
      id: 'phone-down',
      title: '把手机放到桌面充电',
      subtitle: '减少屏幕光和消息提醒，让入睡节奏更稳定。',
      type: RecommendationType.quickAction,
      icon: Icons.phone_android_rounded,
      tags: const <String>['立刻执行'],
      executionState: RecommendationExecutionState.idle,
    ),
    NightRecommendation(
      id: 'water',
      title: '准备一小杯温水',
      subtitle: '避免夜里口渴醒来后还要起身找水，打断困意。',
      type: RecommendationType.quickAction,
      icon: Icons.water_drop_rounded,
      tags: const <String>['30 秒'],
      executionState: RecommendationExecutionState.idle,
    ),
  ];
}

class InMemoryAuthRepository extends ChangeNotifier implements AuthRepository {
  InMemoryAuthRepository({UserProfile? initialProfile})
    : _currentUser = initialProfile ?? buildDefaultUserProfile() {
    final String? phoneNumber = _currentUser.phoneNumber;
    if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
      _registeredPhones.add(normalizeCloudBasePhoneNumber(phoneNumber));
    }
  }

  UserProfile _currentUser;
  final Set<String> _registeredPhones = <String>{};
  final Map<String, String> _passwordsByPhone = <String, String>{};

  @override
  UserProfile get currentUser => _currentUser;

  @override
  bool get isAuthenticated => _currentUser.uid.isNotEmpty;

  @override
  bool get hasVerifiedPhoneIdentity =>
      _currentUser.phoneNumber?.trim().isNotEmpty == true;

  @override
  bool get isAuthenticating => false;

  @override
  bool get hasCompletedInitialAuthBootstrap => true;

  @override
  String? get lastAuthError => null;

  @override
  Future<UserProfile> signInAnonymously() async => _currentUser;

  @override
  Future<UserProfile> ensureAuthenticated() async => _currentUser;

  @override
  Future<UserProfile> retryAuthentication() async => _currentUser;

  @override
  Future<void> signOut() async {
    _currentUser = buildDefaultUserProfile().copyWith(
      uid: '',
      clearDormId: true,
      clearPhoneNumber: true,
      clearPhoneLinkedAt: true,
      clearAvatar: true,
    );
    notifyListeners();
  }

  @override
  Future<void> updateProfile({
    required String displayName,
    required String tagline,
    required String role,
  }) async {
    _currentUser = _currentUser.copyWith(
      displayName: displayName,
      tagline: tagline,
      role: role,
      avatarFallbackSeed: displayName,
    );
    notifyListeners();
  }

  @override
  Future<void> updateBadgePreferences({
    required List<String> earnedBadgeIds,
    String? equippedBadgeId,
    bool clearEquippedBadge = false,
  }) async {
    _currentUser = _currentUser.copyWith(
      earnedBadgeIds: earnedBadgeIds,
      equippedBadgeId: equippedBadgeId,
      clearEquippedBadge: clearEquippedBadge,
    );
    notifyListeners();
  }

  @override
  Future<void> updateDormBadgeVisibility({
    required bool showDormPulseBadge,
  }) async {
    _currentUser = _currentUser.copyWith(
      showDormPulseBadge: showDormPulseBadge,
    );
    notifyListeners();
  }

  @override
  Future<void> updateDormBadgeSelection({
    String? selectedDormBadgeId,
    bool clearSelectedDormBadgeId = false,
  }) async {
    _currentUser = _currentUser.copyWith(
      selectedDormBadgeId: selectedDormBadgeId,
      clearSelectedDormBadgeId: clearSelectedDormBadgeId,
    );
    notifyListeners();
  }

  @override
  Future<void> updateAvatar({
    required String? avatarPath,
    required Uint8List? avatarBytes,
  }) async {
    _currentUser = _currentUser.copyWith(
      avatarPath: avatarPath,
      avatarBytes: avatarBytes,
      avatarUrl: avatarPath,
      avatarStoragePath: avatarPath,
    );
    notifyListeners();
  }

  @override
  Future<PhoneVerificationChallenge> sendPhoneVerificationCode(
    String phoneNumber, {
    PhoneVerificationTarget target = PhoneVerificationTarget.any,
    String? captchaToken,
  }) async {
    final String normalizedPhoneNumber = normalizeCloudBasePhoneNumber(
      phoneNumber,
    );
    final bool alreadyRegistered = _registeredPhones.contains(
      normalizedPhoneNumber,
    );
    final bool isExistingUser = switch (target) {
      PhoneVerificationTarget.any => alreadyRegistered,
      PhoneVerificationTarget.existingUser => alreadyRegistered,
      PhoneVerificationTarget.newUser => alreadyRegistered,
    };
    if (target == PhoneVerificationTarget.newUser && isExistingUser) {
      throw const AuthPhoneTargetMismatchException('该手机号已注册，请直接登录。');
    }
    if (target == PhoneVerificationTarget.existingUser && !isExistingUser) {
      throw const AuthPhoneTargetMismatchException('未找到该手机号，请先注册。');
    }
    return PhoneVerificationChallenge(
      verificationId: 'local-verification-id',
      expiresIn: 600,
      isExistingUser: isExistingUser,
    );
  }

  @override
  Future<PhoneVerificationProof> verifyPhoneCode({
    required String verificationId,
    required String code,
  }) async {
    if (verificationId != 'local-verification-id' || code.trim() != '123456') {
      throw const AuthFlowException('验证码不正确，请重新输入。');
    }
    return const PhoneVerificationProof(
      verificationToken: 'local-verification-token',
      expiresIn: 600,
    );
  }

  @override
  Future<AuthCaptchaChallenge> createCaptchaChallenge() async {
    return const AuthCaptchaChallenge(
      token: 'local-captcha-token',
      imageData: '',
      expiresIn: 300,
    );
  }

  @override
  Future<String> verifyCaptchaChallenge({
    required String token,
    required String code,
  }) async {
    return 'local-captcha-proof';
  }

  @override
  Future<void> signInWithPassword({
    required String phoneNumber,
    required String password,
    String? captchaToken,
  }) async {
    final String normalizedPhoneNumber = normalizeCloudBasePhoneNumber(
      phoneNumber,
    );
    final String? savedPassword = _passwordsByPhone[normalizedPhoneNumber];
    if (!_registeredPhones.contains(normalizedPhoneNumber) ||
        (savedPassword != null && savedPassword != password)) {
      throw const AuthFlowException('请检查手机号和密码。');
    }
    _currentUser = _currentUser.copyWith(
      phoneNumber: normalizedPhoneNumber,
      phoneLinkedAt: DateTime.now(),
    );
    notifyListeners();
  }

  @override
  Future<void> signInWithPhoneCode({
    required String phoneNumber,
    required String verificationId,
    required String code,
    String? captchaToken,
  }) async {
    await verifyPhoneCode(verificationId: verificationId, code: code);
    final String normalizedPhoneNumber = normalizeCloudBasePhoneNumber(
      phoneNumber,
    );
    if (!_registeredPhones.contains(normalizedPhoneNumber)) {
      throw const AuthFlowException('未找到该手机号，请先注册。');
    }
    _currentUser = _currentUser.copyWith(
      phoneNumber: normalizedPhoneNumber,
      phoneLinkedAt: DateTime.now(),
    );
    notifyListeners();
  }

  @override
  Future<void> registerWithPhone({
    required String phoneNumber,
    required String verificationId,
    required String code,
    required String password,
  }) async {
    await verifyPhoneCode(verificationId: verificationId, code: code);
    final String normalizedPhoneNumber = normalizeCloudBasePhoneNumber(
      phoneNumber,
    );
    if (_registeredPhones.contains(normalizedPhoneNumber)) {
      throw const AuthFlowException('该手机号已注册，请直接登录。');
    }
    _registeredPhones.add(normalizedPhoneNumber);
    _passwordsByPhone[normalizedPhoneNumber] = password;
    _currentUser = _currentUser.copyWith(
      phoneNumber: normalizedPhoneNumber,
      phoneLinkedAt: DateTime.now(),
    );
    notifyListeners();
  }

  @override
  Future<void> resetPasswordWithPhone({
    required String phoneNumber,
    required String verificationId,
    required String code,
    required String newPassword,
  }) async {
    await verifyPhoneCode(verificationId: verificationId, code: code);
    await resetPasswordWithVerificationToken(
      phoneNumber: phoneNumber,
      verificationToken: 'local-verification-token',
      newPassword: newPassword,
    );
  }

  @override
  Future<void> resetPasswordWithVerificationToken({
    required String phoneNumber,
    required String verificationToken,
    required String newPassword,
  }) async {
    if (verificationToken != 'local-verification-token') {
      throw const AuthFlowException('验证码已失效，请重新验证。');
    }
    final String normalizedPhoneNumber = normalizeCloudBasePhoneNumber(
      phoneNumber,
    );
    if (!_registeredPhones.contains(normalizedPhoneNumber)) {
      throw const AuthFlowException('未找到该手机号，请先注册。');
    }
    _passwordsByPhone[normalizedPhoneNumber] = newPassword;
    _currentUser = _currentUser.copyWith(
      phoneNumber: normalizedPhoneNumber,
      phoneLinkedAt: DateTime.now(),
    );
    notifyListeners();
  }

  @override
  Future<void> authenticateWithPhone({
    required String phoneNumber,
    required String verificationId,
    required String code,
    required bool isExistingUser,
  }) async {
    if (!isExistingUser) {
      throw const AuthFlowException('请使用注册入口完成新账号创建并设置密码。');
    }
    await signInWithPhoneCode(
      phoneNumber: phoneNumber,
      verificationId: verificationId,
      code: code,
    );
  }
}

class InMemoryUserSettingsRepository extends ChangeNotifier
    implements UserSettingsRepository {
  InMemoryUserSettingsRepository({UserSettings? initialSettings})
    : _settings = initialSettings ?? buildDefaultUserSettings();

  UserSettings _settings;

  @override
  UserSettings get currentSettings => _settings;

  @override
  void replaceLocalSettings(UserSettings settings) {
    _settings = settings;
    notifyListeners();
  }

  @override
  Future<void> saveSettings(UserSettings settings) async {
    replaceLocalSettings(settings);
  }
}

class InMemoryRecommendationRepository extends ChangeNotifier
    implements RecommendationRepository {
  InMemoryRecommendationRepository({
    List<NightRecommendation>? initialRecommendations,
  }) : _tonightRecommendations =
           initialRecommendations ?? buildDefaultRecommendations();

  List<NightRecommendation> _tonightRecommendations;

  @override
  List<NightRecommendation> get tonightRecommendations =>
      List<NightRecommendation>.unmodifiable(_tonightRecommendations);

  @override
  Future<void> resetForTonight() async {
    _tonightRecommendations = _tonightRecommendations
        .map(
          (NightRecommendation item) =>
              item.copyWith(executionState: RecommendationExecutionState.idle),
        )
        .toList();
    notifyListeners();
  }

  @override
  Future<void> refreshAudioCatalog() async {}

  @override
  Future<AudioTrack?> resolvePlayableTrack({
    NightRecommendation? recommendation,
    bool forceRefresh = false,
  }) async {
    final AudioTrack? directTrack = recommendation?.track;
    if (directTrack != null) {
      return directTrack;
    }
    try {
      return _tonightRecommendations
          .firstWhere((NightRecommendation item) => item.track != null)
          .track;
    } on StateError {
      return null;
    }
  }

  @override
  Future<void> setRecommendationState(
    String recommendationId,
    RecommendationExecutionState state,
  ) async {
    _tonightRecommendations = _tonightRecommendations.map((
      NightRecommendation item,
    ) {
      if (item.type == RecommendationType.audio &&
          item.id != recommendationId &&
          state == RecommendationExecutionState.playing) {
        return item.copyWith(executionState: RecommendationExecutionState.idle);
      }
      if (item.id != recommendationId) {
        return item;
      }
      return item.copyWith(executionState: state);
    }).toList();
    notifyListeners();
  }
}

class InMemorySleepSessionRepository extends ChangeNotifier
    implements SleepSessionRepository {
  InMemorySleepSessionRepository({
    String initialUid = 'anon-paul',
    List<SleepSession>? initialSessions,
  }) : _uid = initialUid,
       _sessions = initialSessions ?? _seedSessions(initialUid);

  final String _uid;
  List<SleepSession> _sessions;

  @override
  SleepSession? get activeSession {
    try {
      return _sessions.lastWhere(
        (SleepSession session) => session.sleepModeActive,
      );
    } on StateError {
      return null;
    }
  }

  @override
  List<SleepSession> get sessions => List<SleepSession>.unmodifiable(_sessions);

  @override
  bool get isReadyForSessionLookup => true;

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
      uid: _uid,
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
          .toList(),
      segments: <SleepSegment>[SleepSegment(startedAt: moment, endedAt: null)],
      trackedDurationMinutes: 0,
      awakenings: const <NightAwakeningEntry>[],
      feedback: const <RecommendationFeedback>[],
      summary: null,
      updatedAt: moment,
    );
    await saveSession(session);
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
    final SleepSession normalized = _normalizeStoredSleepSession(session);
    final int index = _sessions.indexWhere(
      (SleepSession current) => current.id == normalized.id,
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

  static SleepSession _normalizeStoredSleepSession(SleepSession session) {
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
      normalized = _repairInactiveSleepSession(normalized);
    }
    return normalized;
  }

  static SleepSession _repairInactiveSleepSession(SleepSession session) {
    final List<SleepSegment> segments = _normalizedSegments(session);
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
      segments[openIndex] = segments[openIndex].copyWith(
        endedAt: resolvedEndAt,
      );
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

  static DateTime? _resolvedInactiveSessionEndAt(
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

  static int _closedSegmentsDurationMinutes(List<SleepSegment> segments) {
    return segments.fold<int>(
      0,
      (int total, SleepSegment segment) =>
          total + sleepSegmentDurationMinutes(segment),
    );
  }

  static bool _isValidAwaitingFeedbackSession(SleepSession session) {
    return canSubmitMorningFeedbackForSession(session);
  }

  static List<SleepSession> _seedSessions(String uid) {
    final DateTime now = DateTime.now();
    final List<SleepSession> seeded = <SleepSession>[];
    final List<NightRecommendation> historyRecommendations =
        <NightRecommendation>[
          NightRecommendation(
            id: 'audio-ocean',
            title: '睡前放松音频',
            subtitle: '深海海浪白噪音',
            type: RecommendationType.audio,
            icon: Icons.dark_mode_rounded,
            tags: const <String>['15 分钟', '深度放松'],
            executionState: RecommendationExecutionState.completed,
            track: const AudioTrack(
              id: 'deep-ocean',
              title: '深海海浪',
              subtitle: '低刺激白噪音 · 45 分钟',
              duration: Duration(minutes: 45),
            ),
          ),
          NightRecommendation(
            id: 'earplug',
            title: '佩戴隔音耳塞',
            subtitle: '隔离随机噪声',
            type: RecommendationType.quickAction,
            icon: Icons.hearing_rounded,
            tags: const <String>['1 分钟'],
            executionState: RecommendationExecutionState.completed,
          ),
        ];

    for (int offset = 18; offset >= 2; offset--) {
      final DateTime day = now.subtract(Duration(days: offset));
      final double durationHours = 6.1 + ((offset % 5) * 0.35);
      final DateTime startedAt = DateTime(day.year, day.month, day.day, 23, 20);
      final DateTime endedAt = DateTime(day.year, day.month, day.day + 1, 7, 0);
      seeded.add(
        SleepSession(
          id: 'history-$offset',
          uid: uid,
          startedAt: startedAt,
          endedAt: endedAt,
          sleepDayKey: sleepDayKeyFromDate(startedAt),
          status: SleepSessionStatus.completed,
          sleepModeActive: false,
          dormId: 'dorm-204',
          recommendations: historyRecommendations,
          selectedRecommendationIds: const <String>['audio-ocean'],
          segments: <SleepSegment>[
            SleepSegment(startedAt: startedAt, endedAt: endedAt),
          ],
          trackedDurationMinutes: (durationHours * 60).round(),
          awakenings: <NightAwakeningEntry>[
            if (offset.isEven)
              NightAwakeningEntry(
                id: 'awakening-$offset',
                occurredAt: DateTime(day.year, day.month, day.day + 1, 3, 18),
                trigger: '室友走动',
                minutesToSleep: 8,
                note: '翻身后重新入睡，还算稳定。',
              ),
          ],
          feedback: const <RecommendationFeedback>[],
          summary: MorningSummary(
            sleepQuality: 3 + (offset % 3),
            restedLevel: 3 + (offset % 2),
            totalSleepHours: durationHours,
            awakeningsCount: offset.isEven ? 1 : 0,
            note: offset.isEven ? '睡前音频帮助明显。' : '整体比较平稳。',
          ),
          updatedAt: DateTime(day.year, day.month, day.day + 1, 7, 0),
        ),
      );
    }

    final DateTime yesterday = now.subtract(const Duration(days: 1));
    final DateTime pendingStartedAt = DateTime(
      yesterday.year,
      yesterday.month,
      yesterday.day,
      23,
      12,
    );
    final DateTime pendingEndedAt = DateTime(
      now.year,
      now.month,
      now.day,
      6,
      58,
    );
    seeded.add(
      SleepSession(
        id: 'pending-yesterday',
        uid: uid,
        startedAt: pendingStartedAt,
        endedAt: pendingEndedAt,
        sleepDayKey: sleepDayKeyFromDate(pendingStartedAt),
        status: SleepSessionStatus.awaitingFeedback,
        sleepModeActive: false,
        dormId: 'dorm-204',
        recommendations: historyRecommendations,
        selectedRecommendationIds: const <String>['audio-ocean', 'earplug'],
        segments: <SleepSegment>[
          SleepSegment(startedAt: pendingStartedAt, endedAt: pendingEndedAt),
        ],
        trackedDurationMinutes: pendingEndedAt
            .difference(pendingStartedAt)
            .inMinutes,
        awakenings: <NightAwakeningEntry>[
          NightAwakeningEntry(
            id: 'awakening-yesterday',
            occurredAt: DateTime(now.year, now.month, now.day - 1, 3, 20),
            trigger: '轻微噪声',
            minutesToSleep: 12,
            note: '戴上耳塞后重新入睡。',
          ),
        ],
        feedback: const <RecommendationFeedback>[],
        summary: null,
        updatedAt: DateTime(now.year, now.month, now.day, 6, 58),
      ),
    );

    return seeded;
  }
}

class InMemoryFeedbackRepository extends ChangeNotifier
    implements FeedbackRepository {
  InMemoryFeedbackRepository({
    required SleepSessionRepository sleepSessionRepository,
  }) : _sleepSessionRepository = sleepSessionRepository;

  final SleepSessionRepository _sleepSessionRepository;

  @override
  Future<void> submitFeedback({
    required SleepSession session,
    required MorningSummary summary,
    required List<RecommendationFeedback> recommendationFeedback,
  }) async {
    await _sleepSessionRepository.saveSession(
      session.copyWith(
        status: SleepSessionStatus.completed,
        sleepModeActive: false,
        summary: summary,
        feedback: recommendationFeedback,
        updatedAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }
}

class InMemorySleepCaptureRepository extends ChangeNotifier
    implements SleepCaptureRepository {
  List<SleepCaptureRecord> _records = const <SleepCaptureRecord>[];
  PendingSleepMemoBanner? _pendingSleepMemoBanner;
  Timer? _bannerTimer;

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
    final SleepCaptureRecord record = SleepCaptureRecord(
      id: recordId ?? 'capture-${now.microsecondsSinceEpoch}',
      type: type,
      sessionId: sessionId,
      createdAt: now,
      title:
          title ??
          _buildTitle(type: type, now: now, content: normalizedContent),
      outline: outline ?? _buildOutline(type: type, content: normalizedContent),
      content: normalizedContent,
    );
    _records = <SleepCaptureRecord>[record, ..._records];
    notifyListeners();
    return record;
  }

  @override
  Future<void> showPendingBannerForSession(String sessionId) async {
    final List<SleepCaptureRecord> memoRecords = recordsForSession(sessionId)
        .where((SleepCaptureRecord item) => item.type == SleepCaptureType.memo)
        .toList();
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
            .toList();

    final List<PendingSleepMemoGroup> nextGroups = <PendingSleepMemoGroup>[
      ...carryoverGroups,
      if (memoRecords.isNotEmpty)
        PendingSleepMemoGroup(
          sessionId: sessionId,
          label: carryoverGroups.isEmpty ? '本次睡眠模式' : '本次睡眠模式（新）',
          items: memoRecords.map(_buildBannerLine).toList(),
          isCarryover: false,
        ),
    ];

    if (nextGroups.isEmpty) {
      await clearPendingBanner();
      return;
    }
    _pendingSleepMemoBanner = PendingSleepMemoBanner(
      title: '事记内容查收',
      subtitle: '点击查看或30min后自动消除。',
      groups: nextGroups,
      createdAt: DateTime.now(),
    );
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(minutes: 30), () {
      _pendingSleepMemoBanner = null;
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  Future<void> clearPendingBanner() async {
    _bannerTimer?.cancel();
    _pendingSleepMemoBanner = null;
    notifyListeners();
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
        .toList();
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
        .toList();
    return fragments.isEmpty ? '' : _truncate(fragments.first, 10);
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    super.dispose();
  }
}

class InMemoryNotificationRepository extends ChangeNotifier
    implements NotificationRepository {
  InMemoryNotificationRepository({String ownerUid = 'anon-paul'})
    : _notifications = <NotificationItem>[
        NotificationItem(
          id: 'feedback-pending',
          category: NotificationCategory.reminder,
          title: '晨间反馈待完成',
          body: '昨晚的行动建议还没记录效果，花 1 分钟帮我继续优化今晚方案。',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          route: AppRoutes.feedbackMorning,
          readAt: null,
          ownerUid: ownerUid,
        ),
        NotificationItem(
          id: 'dorm-quiet',
          category: NotificationCategory.dorm,
          title: '宿舍环境保持安静',
          body: '室友已经关闭公共灯光，现在更适合进入睡眠模式。',
          createdAt: DateTime.now().subtract(const Duration(hours: 8)),
          route: AppRoutes.dorm,
          readAt: null,
          ownerUid: ownerUid,
        ),
        NotificationItem(
          id: 'session-ended',
          category: NotificationCategory.session,
          title: '昨晚睡眠模式已结束',
          body: '夜间记录已经保留，醒来后可以补充主观感受。',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          route: AppRoutes.feedbackMorning,
          readAt: DateTime.now().subtract(const Duration(hours: 3)),
          ownerUid: ownerUid,
        ),
      ];

  List<NotificationItem> _notifications;

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
  Future<void> markRead(String notificationId) async {
    _notifications = _notifications.map((NotificationItem item) {
      return item.id == notificationId
          ? item.copyWith(readAt: DateTime.now())
          : item;
    }).toList();
    notifyListeners();
  }

  @override
  List<NotificationItem> unreadNotifications() {
    return notifications
        .where((NotificationItem item) => !item.isRead)
        .toList(growable: false);
  }

  @override
  Future<void> upsertNotification(NotificationItem notification) async {
    final int existingIndex = _notifications.indexWhere(
      (NotificationItem item) => item.id == notification.id,
    );
    if (existingIndex == -1) {
      _notifications = <NotificationItem>[notification, ..._notifications];
    } else {
      final List<NotificationItem> next = List<NotificationItem>.from(
        _notifications,
      );
      next[existingIndex] = notification;
      _notifications = next;
    }
    notifyListeners();
  }
}

class InMemoryDormRepository extends ChangeNotifier implements DormRepository {
  InMemoryDormRepository({
    Dorm? initialDorm,
    String currentUserId = 'anon-paul',
  }) : _currentUserId = currentUserId,
       _currentDorm = initialDorm ?? buildDefaultDorm(currentUserId) {
    _emitCurrentState();
  }

  final String _currentUserId;
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
    DormLocationAnchor? locationAnchor,
  }) async {
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
      status: DormStatus.active,
      members: <DormMember>[
        DormMember(
          uid: _currentUserId,
          name: _currentUserId == 'anon-paul' ? 'Paul' : '我',
          status: DormMemberStatus.quiet,
          presenceStatus: DormPresenceStatus.returned,
          sleepModeActive: false,
          lastActiveAt: now,
          note: '已创建宿舍，等待邀请舍友加入。',
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
          actorUid: _currentUserId,
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
    final DormMember? existingMember = _currentDorm.members
        .cast<DormMember?>()
        .firstWhere(
          (DormMember? member) => member?.uid == uid,
          orElse: () => null,
        );
    if (existingMember == null) {
      return;
    }
    final String nextNote = note ?? existingMember.note;
    _currentDorm = _currentDorm.copyWith(
      members: _currentDorm.members.map((DormMember member) {
        if (member.uid != uid) {
          return member;
        }
        return member.copyWith(
          status: status ?? member.status,
          presenceStatus: presenceStatus ?? member.presenceStatus,
          sleepModeActive: sleepModeActive ?? member.sleepModeActive,
          lastActiveAt: DateTime.now(),
          note: nextNote,
        );
      }).toList(),
      events: <DormEvent>[
        DormEvent(
          id: IdGenerator.next('dorm-event'),
          type: DormEventType.memberStatus,
          title: uid == _currentUserId ? '你已更新状态' : '室友更新了状态',
          detail: nextNote,
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
  Future<void> updateCurrentUserOnlineStatus({
    required String uid,
    required bool online,
  }) async {
    final DateTime now = DateTime.now();
    _currentDorm = _currentDorm.copyWith(
      members: _currentDorm.members
          .map((DormMember member) {
            if (member.uid != uid) {
              return member;
            }
            return member.copyWith(appOnline: online, appLastSeenAt: now);
          })
          .toList(growable: false),
    );
    _emitCurrentState();
    notifyListeners();
  }

  @override
  void hydrateCurrentDormLocationAnchor(DormLocationAnchor anchor) {
    _currentDorm = _currentDorm.copyWith(locationAnchor: anchor);
    _emitCurrentState();
    notifyListeners();
  }

  @override
  Future<void> saveDormLocationAnchor(DormLocationAnchor anchor) async {
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
    _currentDorm = _currentDorm.copyWith(
      noiseDb: noiseDb,
      lightLabel: lightLabel,
      quietLabel: quietLabel,
    );
    _emitCurrentState();
    notifyListeners();
  }

  @override
  Future<void> saveRules(DormRulesSettings settings) async {
    if (_currentDorm.pendingRuleProposal != null) {
      return;
    }
    final DateTime now = DateTime.now();
    final List<DormRule> proposedRules = buildDormSummaryRules(settings);
    final List<String> reviewerUids = _currentDorm.members
        .map((DormMember member) => member.uid)
        .toList(growable: false);
    final DormPendingRuleProposal proposal = DormPendingRuleProposal(
      id: IdGenerator.next('rule-proposal'),
      proposedSettings: settings,
      proposedRules: proposedRules,
      proposerUid: _currentUserId,
      proposerName: _memberNameFor(_currentUserId),
      createdAt: now,
      reviewerUids: reviewerUids,
      approvedUids: <String>[_currentUserId],
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
            actorUid: _currentUserId,
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
            actorUid: _currentUserId,
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
    if (proposal == null || !proposal.needsReviewFrom(_currentUserId)) {
      return;
    }
    final DateTime now = DateTime.now();
    final DormPendingRuleProposal nextProposal = proposal.copyWith(
      approvedUids: <String>{
        ...proposal.approvedUids,
        _currentUserId,
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
            createdAt: now,
            actorUid: _currentUserId,
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
            detail: '${_memberNameFor(_currentUserId)} 已同意这次规则调整。',
            createdAt: now,
            actorUid: _currentUserId,
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
    if (proposal == null || !proposal.needsReviewFrom(_currentUserId)) {
      return;
    }
    final String trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      return;
    }
    _currentDorm = _currentDorm.copyWith(
      clearPendingRuleProposal: true,
      events: <DormEvent>[
        DormEvent(
          id: IdGenerator.next('dorm-event'),
          type: DormEventType.ruleUpdate,
          title: '新宿舍公约未通过',
          detail: '${_memberNameFor(_currentUserId)} 提出异议：$trimmedReason',
          createdAt: DateTime.now(),
          actorUid: _currentUserId,
        ),
        ..._currentDorm.events,
      ],
    );
    _emitCurrentState();
    notifyListeners();
  }

  @override
  Future<DormInvite> createInvite() async {
    final DormInvite invite = DormInvite(
      id: IdGenerator.next('invite'),
      dormId: _currentDorm.id,
      code:
          'DORM-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      createdByUid: _currentUserId,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 3)),
      status: DormInviteStatus.pending,
    );
    _currentDorm = _currentDorm.copyWith(
      invites: <DormInvite>[invite, ..._currentDorm.invites],
      events: <DormEvent>[
        DormEvent(
          id: IdGenerator.next('dorm-event'),
          type: DormEventType.invite,
          title: '宿舍邀请码已创建',
          detail: '邀请码 ${invite.code} 已生成，可发送给室友。',
          createdAt: DateTime.now(),
          actorUid: _currentUserId,
        ),
        ..._currentDorm.events,
      ],
    );
    _emitCurrentState();
    notifyListeners();
    return invite;
  }

  @override
  Future<void> acceptInvite(String inviteCode) async {
    final bool inviteExists = _currentDorm.invites.any(
      (DormInvite invite) => invite.code == inviteCode,
    );
    if (!inviteExists) {
      return;
    }
    final bool memberExists = _currentDorm.members.any(
      (DormMember member) => member.uid == _currentUserId,
    );
    _currentDorm = _currentDorm.copyWith(
      invites: _currentDorm.invites.map((DormInvite invite) {
        if (invite.code != inviteCode) {
          return invite;
        }
        return invite.copyWith(
          status: DormInviteStatus.accepted,
          acceptedByUid: _currentUserId,
          acceptedAt: DateTime.now(),
        );
      }).toList(),
      members: memberExists
          ? _currentDorm.members
          : <DormMember>[
              DormMember(
                uid: _currentUserId,
                name: _currentUserId == 'anon-paul' ? 'Paul' : '新室友',
                status: DormMemberStatus.quiet,
                presenceStatus: DormPresenceStatus.returned,
                sleepModeActive: false,
                lastActiveAt: DateTime.now(),
                note: '通过邀请码加入宿舍。',
              ),
              ..._currentDorm.members,
            ],
      events: <DormEvent>[
        DormEvent(
          id: IdGenerator.next('dorm-event'),
          type: DormEventType.invite,
          title: '宿舍邀请码已接受',
          detail: '邀请码 $inviteCode 已成功使用。',
          createdAt: DateTime.now(),
          actorUid: _currentUserId,
        ),
        ..._currentDorm.events,
      ],
    );
    _emitCurrentState();
    notifyListeners();
  }

  @override
  Future<void> renameDorm(String name) async {
    _currentDorm = _currentDorm.copyWith(name: name);
    _emitCurrentState();
    notifyListeners();
  }

  @override
  Future<void> leaveDorm() async {
    final List<DormMember> remainingMembers = _currentDorm.members
        .where((DormMember member) => member.uid != _currentUserId)
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
  Future<void> refreshDormSnapshot() async {}

  @override
  Future<void> sendGentleReminder({
    required String targetUid,
    bool anonymous = true,
    required String message,
  }) async {
    final String trimmedMessage = message.trim();
    final DormMember? target = _currentDorm.members
        .where((DormMember member) => member.uid == targetUid)
        .cast<DormMember?>()
        .firstWhere((DormMember? item) => item != null, orElse: () => null);
    if (target == null || trimmedMessage.isEmpty) {
      return;
    }
    final String senderName = anonymous ? '您的舍友' : _currentUserLabel();
    _currentDorm = _currentDorm.copyWith(
      events: <DormEvent>[
        DormEvent(
          id: IdGenerator.next('dorm-event'),
          type: DormEventType.notification,
          title: '已发送委婉提醒',
          detail: '已由 $senderName 向 ${target.name} 发送一条温和的休息提醒：$trimmedMessage',
          createdAt: DateTime.now(),
          actorUid: _currentUserId,
        ),
        ..._currentDorm.events,
      ],
    );
    _emitCurrentState();
    notifyListeners();
  }

  void syncCurrentUserProfile(UserProfile profile) {
    _currentDorm = _currentDorm.copyWith(
      members: _currentDorm.members
          .map(
            (DormMember member) => member.uid == profile.uid
                ? member.copyWith(
                    name: profile.displayName,
                    avatarUrl: profile.avatarUrl,
                    displayBadgeId: profile.displayBadgeId,
                  )
                : member,
          )
          .toList(growable: false),
    );
    _emitCurrentState();
    notifyListeners();
  }

  String _currentUserLabel() {
    final DormMember? currentMember = _currentDorm.members
        .where((DormMember member) => member.uid == _currentUserId)
        .cast<DormMember?>()
        .firstWhere((DormMember? item) => item != null, orElse: () => null);
    return currentMember?.name ?? '舍友';
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

  String _memberNameFor(String uid) {
    for (final DormMember member in _currentDorm.members) {
      if (member.uid == uid) {
        return member.name;
      }
    }
    return _currentUserId == uid ? '你' : '室友';
  }

  @override
  void dispose() {
    _dormController.close();
    _membersController.close();
    _rulesController.close();
    _eventsController.close();
    super.dispose();
  }
}

class InMemoryDreamRepository extends ChangeNotifier
    implements DreamRepository {
  InMemoryDreamRepository({String userId = 'anon-paul'})
    : _entries = <DreamEntry>[
        DreamEntry(
          id: 'dream-1',
          userId: userId,
          title: '下雨的走廊',
          body: '我走过一条安静的长走廊，每扇门后面都透着一点暖黄的灯光。',
          tags: const <String>['平静', '雨夜', '走廊'],
          createdAt: DateTime.now().subtract(const Duration(hours: 10)),
          emotionLabel: '回味',
        ),
      ];

  List<DreamEntry> _entries;

  @override
  List<DreamEntry> get entries {
    final List<DreamEntry> sorted = List<DreamEntry>.from(
      _entries,
    )..sort((DreamEntry a, DreamEntry b) => b.createdAt.compareTo(a.createdAt));
    return List<DreamEntry>.unmodifiable(sorted);
  }

  @override
  DreamEntry? get latestEntry => entries.isEmpty ? null : entries.first;

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
  }

  @override
  Future<void> deleteDreamEntry(String entryId) async {
    _entries = _entries.where((DreamEntry item) => item.id != entryId).toList();
    notifyListeners();
  }
}

class InMemoryInsightsRepository extends ChangeNotifier
    implements InsightsRepository {
  InMemoryInsightsRepository({
    required SleepSessionRepository sleepSessionRepository,
    required DormRepository dormRepository,
    required DreamRepository dreamRepository,
  }) : _sleepSessionRepository = sleepSessionRepository,
       _dormRepository = dormRepository,
       _dreamRepository = dreamRepository {
    _sleepSessionRepository.addListener(_recompute);
    _dormRepository.addListener(_recompute);
    _dreamRepository.addListener(_recompute);
    _recompute();
  }

  final SleepSessionRepository _sleepSessionRepository;
  final DormRepository _dormRepository;
  final DreamRepository _dreamRepository;

  List<SleepInsight> _interferenceInsights = const <SleepInsight>[];
  SleepReport _currentReport = SleepReport(
    title: '本周睡眠快照',
    averageSleepHours: 0,
    averageSleepQuality: 0,
    averageRestedLevel: 0,
    calmNights: 0,
    dreamEntriesCount: 0,
    highlights: const <String>[],
    generatedAt: DateTime.now(),
  );
  SleepTrendSeries _profileSleepDurationTrend = _buildEmptySleepTrendSeries(
    metricKey: 'sleep_duration',
    unit: 'hours',
  );
  SleepTrendSeries _profileSleepQualityTrend = _buildEmptySleepTrendSeries(
    metricKey: 'sleep_quality',
    unit: 'score',
  );

  @override
  List<SleepInsight> get interferenceInsights =>
      List<SleepInsight>.unmodifiable(_interferenceInsights);

  @override
  SleepReport get currentReport => _currentReport;

  @override
  SleepTrendSeries get profileSleepDurationTrend => _profileSleepDurationTrend;

  @override
  SleepTrendSeries get profileSleepQualityTrend => _profileSleepQualityTrend;

  @override
  Future<void> refresh() async => _recompute();

  void _recompute() {
    final List<SleepSession> recent = _sleepSessionRepository.recentSessions();
    final List<SleepSession> completed = recent
        .where((SleepSession session) => session.summary != null)
        .toList(growable: false);
    final List<SleepSession> trendSessions = recent
        .where((SleepSession session) => !session.id.startsWith('history-'))
        .toList(growable: false);

    final double averageSleepHours = completed.isEmpty
        ? 0
        : completed.fold<double>(
                0,
                (double sum, SleepSession item) =>
                    sum + item.summary!.totalSleepHours,
              ) /
              completed.length;
    final double averageQuality = completed.isEmpty
        ? 0
        : completed.fold<double>(
                0,
                (double sum, SleepSession item) =>
                    sum + item.summary!.sleepQuality,
              ) /
              completed.length;
    final double averageRested = completed.isEmpty
        ? 0
        : completed.fold<double>(
                0,
                (double sum, SleepSession item) =>
                    sum + item.summary!.restedLevel,
              ) /
              completed.length;
    final int calmNights = recent
        .where((SleepSession item) => item.awakenings.isEmpty)
        .length;

    _currentReport = SleepReport(
      title: '本周睡眠快照',
      averageSleepHours: averageSleepHours,
      averageSleepQuality: averageQuality,
      averageRestedLevel: averageRested,
      calmNights: calmNights,
      dreamEntriesCount: _dreamRepository.entries.length,
      highlights: <String>[
        '本周平均睡眠时长为 ${averageSleepHours.toStringAsFixed(1)} 小时。',
        '宿舍安静状态为 ${_dormRepository.currentDorm.quietLabel}。',
        '本周共记录了 ${_dreamRepository.entries.length} 条梦境笔记。',
      ],
      generatedAt: DateTime.now(),
    );

    _interferenceInsights = <SleepInsight>[
      SleepInsight(
        id: 'noise',
        category: InsightCategory.interference,
        title: '宿舍噪声影响',
        summary: '当前宿舍噪声约为 ${_dormRepository.currentDorm.noiseDb} dB，今晚整体干扰较低。',
        metricLabel: '${_dormRepository.currentDorm.noiseDb} dB',
        createdAt: DateTime.now(),
      ),
      SleepInsight(
        id: 'awakenings',
        category: InsightCategory.interference,
        title: '夜间醒来次数',
        summary:
            '最近几次睡眠记录中共出现 ${recent.fold<int>(0, (int total, SleepSession item) => total + item.awakenings.length)} 次夜间醒来。',
        metricLabel:
            '${recent.fold<int>(0, (int total, SleepSession item) => total + item.awakenings.length)} 次',
        createdAt: DateTime.now(),
      ),
      SleepInsight(
        id: 'dreams',
        category: InsightCategory.trend,
        title: '梦境记录趋势',
        summary: '持续记录梦境，有助于把夜间情绪和恢复状态联系起来观察。',
        metricLabel: '${_dreamRepository.entries.length} 条',
        createdAt: DateTime.now(),
      ),
    ];

    _profileSleepDurationTrend = _buildSleepTrendSeries(
      metricKey: 'sleep_duration',
      unit: 'hours',
      sessions: trendSessions,
      valueOf: (SleepSession session) => session.summary?.totalSleepHours,
    );
    _profileSleepQualityTrend = _buildSleepTrendSeries(
      metricKey: 'sleep_quality',
      unit: 'score',
      sessions: trendSessions,
      valueOf: (SleepSession session) {
        final MorningSummary? summary = session.summary;
        if (summary == null) {
          return null;
        }
        final double raw = summary.sleepQuality.toDouble();
        return raw <= 5 ? raw * 20 : raw;
      },
    );

    notifyListeners();
  }

  @override
  void dispose() {
    _sleepSessionRepository.removeListener(_recompute);
    _dormRepository.removeListener(_recompute);
    _dreamRepository.removeListener(_recompute);
    super.dispose();
  }
}

class InMemoryAssistantRepository extends ChangeNotifier
    implements AssistantRepository {
  InMemoryAssistantRepository({String userId = 'anon-paul'})
    : _userId = userId,
      _assistantProfile = buildDefaultAssistantProfile(userId) {
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
        content: '一个轻柔的 15 分钟呼吸练习，也许能帮你慢慢切换到入睡状态。要不要我现在带你开始？',
        createdAt: DateTime.now().subtract(const Duration(minutes: 9)),
      ),
    ];
  }

  final String _userId;
  AssistantProfile _assistantProfile;
  late List<AssistantThread> _threads;
  final Map<String, List<AssistantMessage>> _messagesByThread =
      <String, List<AssistantMessage>>{};
  final Map<String, AssistantThreadTurnState> _turnStatesByThread =
      <String, AssistantThreadTurnState>{};
  String? _currentThreadId;

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

  @override
  AssistantThreadTurnState? turnStateForThread(String threadId) {
    return _turnStatesByThread[threadId];
  }

  @override
  Future<AssistantThread> createThread({String? title}) async {
    final AssistantThread thread = AssistantThread(
      id: IdGenerator.next('assistant-thread'),
      userId: _userId,
      title: title ?? '鏂扮殑鍔╃湢瀵硅瘽',
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
  Future<void> renameThread({
    required String threadId,
    required String title,
  }) async {
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

    final AssistantThread thread = AssistantThread(
      id: IdGenerator.next('assistant-thread'),
      userId: _userId,
      title: title ?? '新的助眠对话',
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
    final List<AssistantMessage> current = List<AssistantMessage>.from(
      _messagesByThread[threadId] ?? const <AssistantMessage>[],
    );
    final int index = current.indexWhere(
      (AssistantMessage item) => item.id == messageId,
    );
    if (index == -1) {
      return;
    }
    current[index] = current[index].copyWith(
      content: content,
      status: status,
      sourceMode: sourceMode,
      provider: provider,
      model: model,
      errorMessage: errorMessage,
    );
    _messagesByThread[threadId] = current;
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
      assistantName: assistantName.trim(),
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  void _touchThread(String threadId) {
    _threads = _threads.map((AssistantThread item) {
      if (item.id != threadId) {
        return item;
      }
      return item.copyWith(updatedAt: DateTime.now());
    }).toList();
  }
}

SleepTrendSeries _buildEmptySleepTrendSeries({
  required String metricKey,
  required String unit,
}) {
  final DateTime today = _currentSleepDayDate();
  return SleepTrendSeries(
    metricKey: metricKey,
    unit: unit,
    points: List<SleepTrendPoint>.generate(7, (int index) {
      final DateTime day = today.subtract(Duration(days: 6 - index));
      return SleepTrendPoint(
        dateKey: _dateKeyOf(day),
        weekdayLabel: _weekdayLabelOf(day),
        value: null,
      );
    }, growable: false),
  );
}

SleepTrendSeries _buildSleepTrendSeries({
  required String metricKey,
  required String unit,
  required List<SleepSession> sessions,
  required double? Function(SleepSession session) valueOf,
}) {
  final SleepTrendSeries base = _buildEmptySleepTrendSeries(
    metricKey: metricKey,
    unit: unit,
  );
  final Map<String, SleepSession> sessionsByDateKey = <String, SleepSession>{};
  for (final SleepSession session in sessions) {
    final String dateKey = session.sleepDayKey;
    sessionsByDateKey[dateKey] = session;
  }
  return base.copyWith(
    points: base.points
        .map((SleepTrendPoint point) {
          final SleepSession? session = sessionsByDateKey[point.dateKey];
          return point.copyWith(
            value: session == null ? null : valueOf(session),
          );
        })
        .toList(growable: false),
  );
}

DateTime _currentSleepDayDate() {
  final DateTime? currentSleepDay = sleepDayDateFromKey(
    sleepDayKeyFromDate(DateTime.now()),
  );
  return DateUtils.dateOnly(currentSleepDay ?? DateTime.now());
}

String _dateKeyOf(DateTime date) {
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _weekdayLabelOf(DateTime date) {
  const List<String> labels = <String>['一', '二', '三', '四', '五', '六', '日'];
  return labels[date.weekday - 1];
}

class NoOpPushNotificationGateway implements PushNotificationGateway {
  const NoOpPushNotificationGateway();

  @override
  Future<void> scheduleFeedbackReminder({
    required String sessionId,
    required DateTime when,
  }) async {}

  @override
  Future<void> cancelFeedbackReminder({required String sessionId}) async {}
}
