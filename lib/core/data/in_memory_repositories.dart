import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class InMemoryAuthRepository extends ChangeNotifier implements AuthRepository {
  UserProfile _currentUser = const UserProfile(
    uid: 'anon-paul',
    displayName: 'Paul',
    tagline: 'Dorm Sleep Explorer',
    role: '宿舍睡眠优化实验成员',
    dormId: 'dorm-204',
    avatarFallbackSeed: 'Paul',
  );

  @override
  UserProfile get currentUser => _currentUser;

  @override
  Future<UserProfile> signInAnonymously() async => _currentUser;

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
  Future<void> updateAvatar({
    required String? avatarPath,
    required Uint8List? avatarBytes,
  }) async {
    _currentUser = _currentUser.copyWith(
      avatarPath: avatarPath,
      avatarBytes: avatarBytes,
    );
    notifyListeners();
  }
}

class InMemoryUserSettingsRepository extends ChangeNotifier
    implements UserSettingsRepository {
  InMemoryUserSettingsRepository({UserSettings? initialSettings})
    : _settings = initialSettings ?? _defaultSettings;

  static const UserSettings _defaultSettings = UserSettings(
    sleepGoalHours: 7.5,
    bedtimeReminderEnabled: true,
    morningReminderEnabled: true,
    dormAlertsEnabled: true,
    bedtimeReminder: TimeOfDay(hour: 23, minute: 10),
    preferredTrackTitle: '深海海浪',
    smartSuggestionsEnabled: true,
  );

  UserSettings _settings;

  @override
  UserSettings get currentSettings => _settings;

  @override
  Future<void> saveSettings(UserSettings settings) async {
    _settings = settings;
    notifyListeners();
  }
}

class InMemoryRecommendationRepository extends ChangeNotifier
    implements RecommendationRepository {
  InMemoryRecommendationRepository()
    : _tonightRecommendations = <NightRecommendation>[
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
  Future<void> setRecommendationState(
    String recommendationId,
    RecommendationExecutionState state,
  ) async {
    _tonightRecommendations = _tonightRecommendations.map((
      NightRecommendation item,
    ) {
      if (item.id != recommendationId) {
        if (item.type == RecommendationType.audio &&
            item.executionState == RecommendationExecutionState.playing &&
            state != RecommendationExecutionState.playing) {
          return item.copyWith(
            executionState: RecommendationExecutionState.selected,
          );
        }
        return item;
      }
      return item.copyWith(executionState: state);
    }).toList();
    notifyListeners();
  }
}

class InMemorySleepSessionRepository extends ChangeNotifier
    implements SleepSessionRepository {
  InMemorySleepSessionRepository() : _sessions = _seedSessions();

  List<SleepSession> _sessions;

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
  List<SleepSession> get sessions => List<SleepSession>.unmodifiable(_sessions);

  @override
  Future<SleepSession> startSleepSession({
    required List<NightRecommendation> recommendationSnapshot,
    required String? dormId,
  }) async {
    final SleepSession? existing = activeSession;
    if (existing != null) {
      return existing;
    }

    final DateTime now = DateTime.now();
    final SleepSession session = SleepSession(
      id: 'session-${now.millisecondsSinceEpoch}',
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
          .toList(),
      awakenings: const <NightAwakeningEntry>[],
      feedback: const <RecommendationFeedback>[],
      summary: null,
    );
    _sessions = <SleepSession>[..._sessions, session];
    notifyListeners();
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
    await saveSession(
      existing.copyWith(
        sleepModeActive: sleepModeActive,
        status: status,
        endedAt: endedAt,
        selectedRecommendationIds:
            selectedRecommendationIds ?? existing.selectedRecommendationIds,
      ),
    );
  }

  @override
  Future<void> saveSession(SleepSession session) async {
    _sessions = _sessions.map((SleepSession current) {
      return current.id == session.id ? session : current;
    }).toList();
    notifyListeners();
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
    return _sessions.where((SleepSession session) {
      return session.startedAt.year == month.year &&
          session.startedAt.month == month.month;
    }).toList();
  }

  static List<SleepSession> _seedSessions() {
    final DateTime now = DateTime.now();
    final List<SleepSession> seeded = <SleepSession>[];

    for (int offset = 18; offset >= 2; offset--) {
      final DateTime day = now.subtract(Duration(days: offset));
      final double durationHours = 6.1 + ((offset % 5) * 0.35);
      seeded.add(
        SleepSession(
          id: 'history-$offset',
          startedAt: DateTime(day.year, day.month, day.day, 23, 20),
          endedAt: DateTime(day.year, day.month, day.day + 1, 7, 0),
          status: SleepSessionStatus.completed,
          sleepModeActive: false,
          dormId: 'dorm-204',
          recommendations: _historicalRecommendations,
          selectedRecommendationIds: const <String>['audio-ocean'],
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
        ),
      );
    }

    final DateTime yesterday = now.subtract(const Duration(days: 1));
    seeded.add(
      SleepSession(
        id: 'pending-yesterday',
        startedAt: DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          23,
          12,
        ),
        endedAt: DateTime(now.year, now.month, now.day, 6, 58),
        status: SleepSessionStatus.awaitingFeedback,
        sleepModeActive: false,
        dormId: 'dorm-204',
        recommendations: _historicalRecommendations,
        selectedRecommendationIds: const <String>['audio-ocean', 'earplug'],
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
      ),
    );

    return seeded;
  }

  static const List<NightRecommendation> _historicalRecommendations =
      <NightRecommendation>[
        NightRecommendation(
          id: 'audio-ocean',
          title: '睡前放松音频',
          subtitle: '深海海浪白噪音',
          type: RecommendationType.audio,
          icon: Icons.dark_mode_rounded,
          tags: <String>['15 分钟', '深度放松'],
          executionState: RecommendationExecutionState.completed,
          track: AudioTrack(
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
          tags: <String>['1 分钟'],
          executionState: RecommendationExecutionState.completed,
        ),
      ];
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
        summary: summary,
        feedback: recommendationFeedback,
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
  }) async {
    final DateTime now = DateTime.now();
    final SleepCaptureRecord record = SleepCaptureRecord(
      id: 'capture-${now.microsecondsSinceEpoch}',
      type: type,
      sessionId: sessionId,
      createdAt: now,
      title: _buildTitle(type: type, now: now, content: content),
      outline: _buildOutline(type: type, content: content),
      content: content.trim(),
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
      return type == SleepCaptureType.dream ? '记录了一段尚待补充的梦境片段。' : '记录了一段待整理的夜间事记。';
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
  InMemoryNotificationRepository()
    : _notifications = <NotificationItem>[
        NotificationItem(
          id: 'feedback-pending',
          category: NotificationCategory.reminder,
          title: '晨间反馈待完成',
          body: '昨晚的行动建议还没记录效果，花 1 分钟帮我继续优化今晚方案。',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          route: AppRoutes.feedbackMorning,
          readAt: null,
        ),
        NotificationItem(
          id: 'dorm-quiet',
          category: NotificationCategory.dorm,
          title: '宿舍环境保持安静',
          body: '室友已经关闭公共灯光，现在更适合进入睡眠模式。',
          createdAt: DateTime.now().subtract(const Duration(hours: 8)),
          route: AppRoutes.dorm,
          readAt: null,
        ),
        NotificationItem(
          id: 'session-ended',
          category: NotificationCategory.session,
          title: '昨晚睡眠模式已结束',
          body: '夜间记录已经保留，醒来后可以补充主观感受。',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          route: AppRoutes.feedbackMorning,
          readAt: DateTime.now().subtract(const Duration(hours: 3)),
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
  Dorm _currentDorm = Dorm(
    id: 'dorm-204',
    name: '梅苑 2 栋 204',
    overview: '宿舍整体状态平稳，灯光已调暗，适合逐步进入睡眠模式。',
    noiseDb: 32,
    lightLabel: '偏暗',
    quietLabel: '良好',
    rules: const <DormRule>[
      DormRule(title: '23:30 后关闭主灯', detail: '为准备休息的室友保留低刺激环境。'),
      DormRule(title: '夜间媒体内容统一佩戴耳机', detail: '避免随机外放声音造成二次唤醒。'),
    ],
    members: <DormMember>[
      DormMember(
        uid: 'anon-paul',
        name: 'Paul',
        status: DormMemberStatus.quiet,
        sleepModeActive: false,
        lastActiveAt: DateTime(2026, 4, 4, 22, 10),
        note: '准备做睡前放松',
      ),
      DormMember(
        uid: 'roommate-a',
        name: '林淯',
        status: DormMemberStatus.sleeping,
        sleepModeActive: true,
        lastActiveAt: DateTime(2026, 4, 4, 22, 20),
        note: '已开启睡眠模式',
      ),
      DormMember(
        uid: 'roommate-b',
        name: '阿哲',
        status: DormMemberStatus.active,
        sleepModeActive: false,
        lastActiveAt: DateTime(2026, 4, 4, 22, 34),
        note: '正在收拾桌面，预计 10 分钟后安静下来。',
      ),
    ],
  );

  @override
  Dorm get currentDorm => _currentDorm;

  @override
  Future<void> updateCurrentUserStatus({
    required String uid,
    required DormMemberStatus status,
    required bool sleepModeActive,
    required String note,
  }) async {
    _currentDorm = _currentDorm.copyWith(
      members: _currentDorm.members.map((DormMember member) {
        if (member.uid != uid) {
          return member;
        }
        return member.copyWith(
          status: status,
          sleepModeActive: sleepModeActive,
          lastActiveAt: DateTime.now(),
          note: note,
        );
      }).toList(),
    );
    notifyListeners();
  }
}

class NoOpPushNotificationGateway implements PushNotificationGateway {
  const NoOpPushNotificationGateway();

  @override
  Future<void> scheduleFeedbackReminder({
    required String sessionId,
    required DateTime when,
  }) async {}
}
