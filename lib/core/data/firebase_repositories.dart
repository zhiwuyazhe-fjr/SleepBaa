import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/core/data/firebase_contract.dart';
import 'package:sleep_dorm_app/core/data/in_memory_repositories.dart';
import 'package:sleep_dorm_app/core/data/model_serializers.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/utils/id_generator.dart';

Map<String, dynamic> _dormMemberToMap(DormMember member) {
  return <String, dynamic>{
    'uid': member.uid,
    'name': member.name,
    'status': member.status.name,
    'sleepModeActive': member.sleepModeActive,
    'lastActiveAt': member.lastActiveAt,
    'note': member.note,
    'avatarUrl': member.avatarUrl,
  };
}

DormMember _dormMemberFromMap(Map<String, dynamic> map) {
  return DormMember(
    uid: map['uid'] as String? ?? '',
    name: map['name'] as String? ?? '',
    status: _firstWhereOrNull(
          DormMemberStatus.values,
          (DormMemberStatus item) => item.name == map['status'],
        ) ??
        DormMemberStatus.quiet,
    sleepModeActive: map['sleepModeActive'] as bool? ?? false,
    lastActiveAt: _dateValue(map['lastActiveAt']) ?? DateTime.now(),
    note: map['note'] as String? ?? '',
    avatarUrl: map['avatarUrl'] as String?,
  );
}

Map<String, dynamic> _dormRuleToMap(DormRule rule) {
  return <String, dynamic>{
    'id': rule.id,
    'title': rule.title,
    'detail': rule.detail,
  };
}

DormRule _dormRuleFromMap(Map<String, dynamic> map) {
  return DormRule(
    id: map['id'] as String? ?? '',
    title: map['title'] as String? ?? '',
    detail: map['detail'] as String? ?? '',
  );
}

Map<String, dynamic> _dormEventToMap(DormEvent event) {
  return <String, dynamic>{
    'id': event.id,
    'type': event.type.name,
    'title': event.title,
    'detail': event.detail,
    'createdAt': event.createdAt,
    'actorUid': event.actorUid,
  };
}

DormEvent _dormEventFromMap(Map<String, dynamic> map) {
  return DormEvent(
    id: map['id'] as String? ?? '',
    type: _firstWhereOrNull(
          DormEventType.values,
          (DormEventType item) => item.name == map['type'],
        ) ??
        DormEventType.system,
    title: map['title'] as String? ?? '',
    detail: map['detail'] as String? ?? '',
    createdAt: _dateValue(map['createdAt']) ?? DateTime.now(),
    actorUid: map['actorUid'] as String?,
  );
}

Map<String, dynamic> _dormInviteToMap(DormInvite invite) {
  return <String, dynamic>{
    'id': invite.id,
    'dormId': invite.dormId,
    'code': invite.code,
    'createdByUid': invite.createdByUid,
    'createdAt': invite.createdAt,
    'expiresAt': invite.expiresAt,
    'status': invite.status.name,
    'acceptedByUid': invite.acceptedByUid,
    'acceptedAt': invite.acceptedAt,
  };
}

DormInvite _dormInviteFromMap(Map<String, dynamic> map) {
  return DormInvite(
    id: map['id'] as String? ?? '',
    dormId: map['dormId'] as String? ?? '',
    code: map['code'] as String? ?? '',
    createdByUid: map['createdByUid'] as String? ?? '',
    createdAt: _dateValue(map['createdAt']) ?? DateTime.now(),
    expiresAt:
        _dateValue(map['expiresAt']) ??
        DateTime.now().add(const Duration(days: 3)),
    status: _firstWhereOrNull(
          DormInviteStatus.values,
          (DormInviteStatus item) => item.name == map['status'],
        ) ??
        DormInviteStatus.pending,
    acceptedByUid: map['acceptedByUid'] as String?,
    acceptedAt: _dateValue(map['acceptedAt']),
  );
}

DateTime? _dateValue(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T item) test) {
  for (final T item in items) {
    if (test(item)) {
      return item;
    }
  }
  return null;
}

class FirebaseAuthRepository extends ChangeNotifier implements AuthRepository {
  FirebaseAuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
  }) : _auth = auth,
       _firestore = firestore,
       _storage = storage {
    _authSubscription = _auth.authStateChanges().listen(_handleAuthStateChanged);
    final User? current = _auth.currentUser;
    if (current != null) {
      _handleAuthStateChanged(current);
    }
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  UserProfile _currentUser = buildDefaultUserProfile();
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSubscription;

  @override
  UserProfile get currentUser => _currentUser;

  @override
  Future<UserProfile> signInAnonymously() async {
    final User user = _auth.currentUser ?? (await _auth.signInAnonymously()).user!;
    final String uid = user.uid;
    await _ensureSeedData(uid);
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _userDoc(uid).get();
    _currentUser = ModelSerializers.userProfileFromMap(
      snapshot.data() ?? ModelSerializers.userProfileToMap(buildDefaultUserProfile().copyWith(uid: uid)),
    );
    notifyListeners();
    return _currentUser;
  }

  @override
  Future<void> updateProfile({
    required String displayName,
    required String tagline,
    required String role,
  }) async {
    final UserProfile next = _currentUser.copyWith(
      displayName: displayName,
      tagline: tagline,
      role: role,
      avatarFallbackSeed: displayName,
    );
    await _userDoc(_currentUser.uid).set(
      ModelSerializers.userProfileToMap(next),
      SetOptions(merge: true),
    );
    _currentUser = next;
    notifyListeners();
  }

  @override
  Future<void> updateAvatar({
    required String? avatarPath,
    required Uint8List? avatarBytes,
  }) async {
    String? avatarUrl = _currentUser.avatarUrl;
    if (avatarBytes != null && avatarBytes.isNotEmpty) {
      final Reference reference = _storage.ref().child(
        'avatars/${_currentUser.uid}/profile.jpg',
      );
      await reference.putData(
        avatarBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      avatarUrl = await reference.getDownloadURL();
    }
    final UserProfile next = _currentUser.copyWith(
      avatarPath: avatarPath,
      avatarBytes: avatarBytes,
      avatarUrl: avatarUrl,
    );
    await _userDoc(_currentUser.uid).set(
      ModelSerializers.userProfileToMap(next),
      SetOptions(merge: true),
    );
    _currentUser = next;
    notifyListeners();
  }

  void _handleAuthStateChanged(User? user) {
    _userSubscription?.cancel();
    if (user == null) {
      _currentUser = buildDefaultUserProfile();
      notifyListeners();
      return;
    }
    _userSubscription = _userDoc(user.uid).snapshots().listen((snapshot) {
      final Map<String, dynamic>? data = snapshot.data();
      if (data == null) {
        return;
      }
      _currentUser = ModelSerializers.userProfileFromMap(data);
      notifyListeners();
    });
  }

  Future<void> _ensureSeedData(String uid) async {
    final UserProfile defaultProfile = buildDefaultUserProfile().copyWith(uid: uid);
    await _userDoc(uid).set(
      ModelSerializers.userProfileToMap(defaultProfile),
      SetOptions(merge: true),
    );
    await _firestore
        .collection(FirebaseCollections.userSettings)
        .doc(uid)
        .set(
          ModelSerializers.userSettingsToMap(buildDefaultUserSettings()),
          SetOptions(merge: true),
        );
    final String dormId = defaultProfile.dormId ?? 'dorm-204';
    await _firestore.collection(FirebaseCollections.dorms).doc(dormId).set(
      <String, dynamic>{
        'id': dormId,
        'name': '梅苑 2 栋 204',
        'overview': '宿舍整体状态平稳，灯光已调暗，适合逐步进入睡眠模式。',
        'noiseDb': 32,
        'lightLabel': '偏暗',
        'quietLabel': '良好',
        'rulesSettings': ModelSerializers.dormRulesSettingsToMap(
          buildDefaultDormRulesSettings(),
        ),
      },
      SetOptions(merge: true),
    );
    await _firestore
        .collection(FirebaseCollections.dorms)
        .doc(dormId)
        .collection(FirebaseCollections.dormMembers)
        .doc(uid)
        .set(
          _dormMemberToMap(
            DormMember(
              uid: uid,
              name: defaultProfile.displayName,
              status: DormMemberStatus.quiet,
              sleepModeActive: false,
              lastActiveAt: DateTime.now(),
              note: '准备做睡前放松。',
            ),
          ),
          SetOptions(merge: true),
        );
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _firestore.collection(FirebaseCollections.users).doc(uid);
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}

class FirebaseUserSettingsRepository extends ChangeNotifier
    implements UserSettingsRepository {
  FirebaseUserSettingsRepository({
    required FirebaseFirestore firestore,
    required AuthRepository authRepository,
  }) : _firestore = firestore,
       _authRepository = authRepository {
    _authRepository.addListener(_restartSubscription);
    _restartSubscription();
  }

  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  UserSettings _settings = buildDefaultUserSettings();

  @override
  UserSettings get currentSettings => _settings;

  @override
  Future<void> saveSettings(UserSettings settings) async {
    final String uid = _authRepository.currentUser.uid;
    if (uid.isEmpty) {
      return;
    }
    await _firestore.collection(FirebaseCollections.userSettings).doc(uid).set(
      ModelSerializers.userSettingsToMap(settings),
      SetOptions(merge: true),
    );
    _settings = settings;
    notifyListeners();
  }

  void _restartSubscription() {
    _subscription?.cancel();
    final String uid = _authRepository.currentUser.uid;
    if (uid.isEmpty) {
      return;
    }
    _subscription = _firestore
        .collection(FirebaseCollections.userSettings)
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
          final Map<String, dynamic>? data = snapshot.data();
          if (data == null) {
            return;
          }
          _settings = ModelSerializers.userSettingsFromMap(data);
          notifyListeners();
        });
  }

  @override
  void dispose() {
    _authRepository.removeListener(_restartSubscription);
    _subscription?.cancel();
    super.dispose();
  }
}

class FirebaseSleepSessionRepository extends ChangeNotifier
    implements SleepSessionRepository {
  FirebaseSleepSessionRepository({
    required FirebaseFirestore firestore,
    required AuthRepository authRepository,
  }) : _firestore = firestore,
       _authRepository = authRepository {
    _authRepository.addListener(_restartSubscription);
    _restartSubscription();
  }

  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
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
    final List<SleepSession> pending = _sessions
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
    return _sessions.where((SleepSession session) {
      return session.startedAt.year == month.year &&
          session.startedAt.month == month.month;
    }).toList();
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

    final String uid = _authRepository.currentUser.uid;
    final DocumentReference<Map<String, dynamic>> ref = _firestore
        .collection(FirebaseCollections.sleepSessions)
        .doc();
    final DateTime now = DateTime.now();
    final SleepSession session = SleepSession(
      id: ref.id,
      uid: uid,
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
    await _writeSession(ref, session);
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
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> saveSession(SleepSession session) async {
    await _writeSession(
      _firestore.collection(FirebaseCollections.sleepSessions).doc(session.id),
      session,
    );
  }

  Future<void> _writeSession(
    DocumentReference<Map<String, dynamic>> ref,
    SleepSession session,
  ) async {
    await ref.set(ModelSerializers.sleepSessionToMap(session), SetOptions(merge: true));
    await _replaceSubcollection(
      ref: ref,
      collection: FirebaseCollections.awakenings,
      values: session.awakenings.map(ModelSerializers.awakeningToMap).toList(),
      idFor: (Map<String, dynamic> item) => item['id'] as String,
    );
    await _replaceSubcollection(
      ref: ref,
      collection: FirebaseCollections.recommendationFeedback,
      values: session.feedback
          .map(ModelSerializers.recommendationFeedbackToMap)
          .toList(),
      idFor: (Map<String, dynamic> item) =>
          item['recommendationId'] as String? ?? IdGenerator.next('feedback'),
    );
  }

  Future<void> _replaceSubcollection({
    required DocumentReference<Map<String, dynamic>> ref,
    required String collection,
    required List<Map<String, dynamic>> values,
    required String Function(Map<String, dynamic>) idFor,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> existing =
        await ref.collection(collection).get();
    final WriteBatch batch = _firestore.batch();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (final Map<String, dynamic> item in values) {
      batch.set(ref.collection(collection).doc(idFor(item)), item);
    }
    await batch.commit();
  }

  void _restartSubscription() {
    _subscription?.cancel();
    final String uid = _authRepository.currentUser.uid;
    if (uid.isEmpty) {
      _sessions = const <SleepSession>[];
      notifyListeners();
      return;
    }
    _subscription = _firestore
        .collection(FirebaseCollections.sleepSessions)
        .where('uid', isEqualTo: uid)
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snapshot) async {
          final List<SleepSession> hydrated = await Future.wait(
            snapshot.docs.map(_hydrateSession),
          );
          hydrated.sort(
            (SleepSession a, SleepSession b) =>
                a.startedAt.compareTo(b.startedAt),
          );
          _sessions = hydrated;
          notifyListeners();
        });
  }

  Future<SleepSession> _hydrateSession(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final Map<String, dynamic> data = doc.data();
    final QuerySnapshot<Map<String, dynamic>> awakeningsSnapshot =
        await doc.reference.collection(FirebaseCollections.awakenings).get();
    final QuerySnapshot<Map<String, dynamic>> feedbackSnapshot = await doc
        .reference
        .collection(FirebaseCollections.recommendationFeedback)
        .get();
    data['awakenings'] = awakeningsSnapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> item) => item.data())
        .toList(growable: false);
    data['feedback'] = feedbackSnapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> item) => item.data())
        .toList(growable: false);
    return ModelSerializers.sleepSessionFromMap(data);
  }

  @override
  void dispose() {
    _authRepository.removeListener(_restartSubscription);
    _subscription?.cancel();
    super.dispose();
  }
}

class FirebaseFeedbackRepository extends ChangeNotifier
    implements FeedbackRepository {
  FirebaseFeedbackRepository({
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
        updatedAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }
}

class FirebaseNotificationRepository extends ChangeNotifier
    implements NotificationRepository {
  FirebaseNotificationRepository({
    required FirebaseFirestore firestore,
    required AuthRepository authRepository,
  }) : _firestore = firestore,
       _authRepository = authRepository {
    _authRepository.addListener(_restartSubscription);
    _restartSubscription();
  }

  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  List<NotificationItem> _notifications = const <NotificationItem>[];

  @override
  List<NotificationItem> get notifications =>
      List<NotificationItem>.unmodifiable(_notifications);

  @override
  List<NotificationItem> unreadNotifications() {
    return _notifications
        .where((NotificationItem item) => !item.isRead)
        .toList(growable: false);
  }

  @override
  Future<void> markRead(String notificationId) async {
    final String uid = _authRepository.currentUser.uid;
    await _firestore
        .collection(FirebaseCollections.notifications)
        .doc(uid)
        .collection(FirebaseCollections.notificationItems)
        .doc(notificationId)
        .set(<String, dynamic>{'readAt': DateTime.now()}, SetOptions(merge: true));
  }

  @override
  Future<void> upsertNotification(NotificationItem notification) async {
    final String uid = _authRepository.currentUser.uid;
    await _firestore
        .collection(FirebaseCollections.notifications)
        .doc(uid)
        .collection(FirebaseCollections.notificationItems)
        .doc(notification.id)
        .set(
          <String, dynamic>{
            'id': notification.id,
            'category': notification.category.name,
            'title': notification.title,
            'body': notification.body,
            'createdAt': notification.createdAt,
            'route': notification.route,
            'readAt': notification.readAt,
            'ownerUid': uid,
          },
          SetOptions(merge: true),
        );
  }

  @override
  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    final String uid = _authRepository.currentUser.uid;
    await _firestore
        .collection(FirebaseCollections.users)
        .doc(uid)
        .collection(FirebaseCollections.notificationTokens)
        .doc(token)
        .set(<String, dynamic>{
          'token': token,
          'platform': platform,
          'updatedAt': DateTime.now(),
        }, SetOptions(merge: true));
  }

  void _restartSubscription() {
    _subscription?.cancel();
    final String uid = _authRepository.currentUser.uid;
    if (uid.isEmpty) {
      _notifications = const <NotificationItem>[];
      notifyListeners();
      return;
    }
    _subscription = _firestore
        .collection(FirebaseCollections.notifications)
        .doc(uid)
        .collection(FirebaseCollections.notificationItems)
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
          _notifications = snapshot.docs
              .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                final Map<String, dynamic> data = doc.data();
                return NotificationItem(
                  id: data['id'] as String? ?? doc.id,
                  category: _firstWhereOrNull(
                        NotificationCategory.values,
                        (NotificationCategory item) =>
                            item.name == data['category'],
                      ) ??
                      NotificationCategory.system,
                  title: data['title'] as String? ?? '',
                  body: data['body'] as String? ?? '',
                  createdAt: _dateValue(data['createdAt']) ?? DateTime.now(),
                  route: data['route'] as String? ?? AppRoutes.notifications,
                  readAt: _dateValue(data['readAt']),
                  ownerUid: data['ownerUid'] as String?,
                );
              })
              .toList(growable: false)
            ..sort(
              (NotificationItem a, NotificationItem b) =>
                  b.createdAt.compareTo(a.createdAt),
            );
          notifyListeners();
        });
  }

  @override
  void dispose() {
    _authRepository.removeListener(_restartSubscription);
    _subscription?.cancel();
    super.dispose();
  }
}

class FirebaseDormRepository extends ChangeNotifier implements DormRepository {
  FirebaseDormRepository({
    required FirebaseFirestore firestore,
    required AuthRepository authRepository,
  }) : _firestore = firestore,
       _authRepository = authRepository {
    _authRepository.addListener(_restartSubscriptions);
    _restartSubscriptions();
  }

  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository;

  final StreamController<Dorm> _dormController =
      StreamController<Dorm>.broadcast();
  final StreamController<List<DormMember>> _membersController =
      StreamController<List<DormMember>>.broadcast();
  final StreamController<List<DormRule>> _rulesController =
      StreamController<List<DormRule>>.broadcast();
  final StreamController<List<DormEvent>> _eventsController =
      StreamController<List<DormEvent>>.broadcast();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _dormSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _membersSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _rulesSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _eventsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _invitesSubscription;

  String? _activeDormId;
  Map<String, dynamic> _dormData = <String, dynamic>{};
  List<DormMember> _members = const <DormMember>[];
  List<DormRule> _rules = const <DormRule>[];
  List<DormEvent> _events = const <DormEvent>[];
  List<DormInvite> _invites = const <DormInvite>[];
  Dorm _currentDorm = buildDefaultDorm('anon-paul');

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
  Future<void> updateCurrentUserStatus({
    required String uid,
    required DormMemberStatus status,
    required bool sleepModeActive,
    required String note,
  }) async {
    final String dormId = _activeDormId ?? _authRepository.currentUser.dormId ?? 'dorm-204';
    await _firestore
        .collection(FirebaseCollections.dorms)
        .doc(dormId)
        .collection(FirebaseCollections.dormMembers)
        .doc(uid)
        .set(
          <String, dynamic>{
            'uid': uid,
            'name': _authRepository.currentUser.displayName,
            'status': status.name,
            'sleepModeActive': sleepModeActive,
            'lastActiveAt': DateTime.now(),
            'note': note,
            'avatarUrl': _authRepository.currentUser.avatarUrl,
          },
          SetOptions(merge: true),
        );
    await _addEvent(
      dormId: dormId,
      event: DormEvent(
        id: IdGenerator.next('dorm-event'),
        type: DormEventType.memberStatus,
        title: '成员状态已更新',
        detail: note,
        createdAt: DateTime.now(),
        actorUid: uid,
      ),
    );
  }

  @override
  Future<void> saveRules(DormRulesSettings settings) async {
    final String dormId = _activeDormId ?? _authRepository.currentUser.dormId ?? 'dorm-204';
    await _firestore.collection(FirebaseCollections.dorms).doc(dormId).set(
      <String, dynamic>{
        'rulesSettings': ModelSerializers.dormRulesSettingsToMap(settings),
      },
      SetOptions(merge: true),
    );
    final WriteBatch batch = _firestore.batch();
    for (final DormRule rule in buildDormSummaryRules(settings)) {
      batch.set(
        _firestore
            .collection(FirebaseCollections.dorms)
            .doc(dormId)
            .collection(FirebaseCollections.dormRules)
            .doc(rule.id),
        _dormRuleToMap(rule),
      );
    }
    await batch.commit();
    await _addEvent(
      dormId: dormId,
      event: DormEvent(
        id: IdGenerator.next('dorm-event'),
        type: DormEventType.ruleUpdate,
        title: '宿舍规则已更新',
        detail: '安静时段：${settings.quietHours}',
        createdAt: DateTime.now(),
        actorUid: _authRepository.currentUser.uid,
      ),
    );
  }

  @override
  Future<DormInvite> createInvite() async {
    final String dormId = _activeDormId ?? _authRepository.currentUser.dormId ?? 'dorm-204';
    final DormInvite invite = DormInvite(
      id: IdGenerator.next('invite'),
      dormId: dormId,
      code: 'DORM-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      createdByUid: _authRepository.currentUser.uid,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 3)),
      status: DormInviteStatus.pending,
    );
    await _firestore
        .collection(FirebaseCollections.dorms)
        .doc(dormId)
        .collection(FirebaseCollections.dormInvites)
        .doc(invite.id)
        .set(_dormInviteToMap(invite));
    await _addEvent(
      dormId: dormId,
      event: DormEvent(
        id: IdGenerator.next('dorm-event'),
        type: DormEventType.invite,
        title: '宿舍邀请码已创建',
        detail: '邀请码 ${invite.code} 已生成，可发送给室友。',
        createdAt: DateTime.now(),
        actorUid: _authRepository.currentUser.uid,
      ),
    );
    return invite;
  }

  @override
  Future<void> acceptInvite(String inviteCode) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collectionGroup(FirebaseCollections.dormInvites)
        .where('code', isEqualTo: inviteCode)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return;
    }
    final QueryDocumentSnapshot<Map<String, dynamic>> inviteDoc =
        snapshot.docs.first;
    final DormInvite invite = _dormInviteFromMap(<String, dynamic>{
      ...inviteDoc.data(),
      'id': inviteDoc.id,
    });
    final DateTime now = DateTime.now();
    if (invite.status != DormInviteStatus.pending ||
        invite.expiresAt.isBefore(now)) {
      return;
    }

    final String uid = _authRepository.currentUser.uid;
    final UserProfile profile = _authRepository.currentUser;
    final DocumentReference<Map<String, dynamic>> userDoc = _firestore
        .collection(FirebaseCollections.users)
        .doc(uid);
    final DocumentReference<Map<String, dynamic>> dormRef = _firestore
        .collection(FirebaseCollections.dorms)
        .doc(invite.dormId);
    final DocumentReference<Map<String, dynamic>> memberRef = dormRef
        .collection(FirebaseCollections.dormMembers)
        .doc(uid);
    final DocumentReference<Map<String, dynamic>> eventRef = dormRef
        .collection(FirebaseCollections.dormEvents)
        .doc(IdGenerator.next('dorm-event'));

    await _firestore.runTransaction((Transaction transaction) async {
      transaction.set(
        inviteDoc.reference,
        <String, dynamic>{
          'status': DormInviteStatus.accepted.name,
          'acceptedByUid': uid,
          'acceptedAt': now,
        },
        SetOptions(merge: true),
      );
      transaction.set(
        userDoc,
        <String, dynamic>{'dormId': invite.dormId},
        SetOptions(merge: true),
      );
      transaction.set(
        memberRef,
        _dormMemberToMap(
          DormMember(
            uid: uid,
            name: profile.displayName,
            status: DormMemberStatus.quiet,
            sleepModeActive: false,
            lastActiveAt: now,
            note: '通过邀请码加入宿舍。',
            avatarUrl: profile.avatarUrl,
          ),
        ),
        SetOptions(merge: true),
      );
      transaction.set(
        eventRef,
        _dormEventToMap(
          DormEvent(
            id: eventRef.id,
            type: DormEventType.invite,
            title: '宿舍邀请码已接受',
            detail: '邀请码 $inviteCode 已成功使用。',
            createdAt: now,
            actorUid: uid,
          ),
        ),
      );
    });
  }

  Future<void> _addEvent({
    required String dormId,
    required DormEvent event,
  }) {
    return _firestore
        .collection(FirebaseCollections.dorms)
        .doc(dormId)
        .collection(FirebaseCollections.dormEvents)
        .doc(event.id)
        .set(_dormEventToMap(event));
  }

  void _restartSubscriptions() {
    _cancelSubscriptions();
    final String? dormId = _authRepository.currentUser.dormId;
    if (dormId == null || dormId.isEmpty) {
      return;
    }
    _activeDormId = dormId;
    final DocumentReference<Map<String, dynamic>> dormRef =
        _firestore.collection(FirebaseCollections.dorms).doc(dormId);
    _dormSubscription = dormRef.snapshots().listen((snapshot) {
      _dormData = snapshot.data() ?? <String, dynamic>{};
      _rebuildDorm();
    });
    _membersSubscription = dormRef
        .collection(FirebaseCollections.dormMembers)
        .snapshots()
        .listen((snapshot) {
          _members = snapshot.docs
              .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                return _dormMemberFromMap(doc.data());
              })
              .toList(growable: false);
          _rebuildDorm();
        });
    _rulesSubscription = dormRef
        .collection(FirebaseCollections.dormRules)
        .snapshots()
        .listen((snapshot) {
          _rules = snapshot.docs
              .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                return _dormRuleFromMap(doc.data());
              })
              .toList(growable: false);
          _rebuildDorm();
        });
    _eventsSubscription = dormRef
        .collection(FirebaseCollections.dormEvents)
        .snapshots()
        .listen((snapshot) {
          _events = snapshot.docs
              .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                return _dormEventFromMap(doc.data());
              })
              .toList(growable: false)
            ..sort(
              (DormEvent a, DormEvent b) => b.createdAt.compareTo(a.createdAt),
            );
          _rebuildDorm();
        });
    _invitesSubscription = dormRef
        .collection(FirebaseCollections.dormInvites)
        .snapshots()
        .listen((snapshot) {
          _invites = snapshot.docs
              .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                return _dormInviteFromMap(doc.data());
              })
              .toList(growable: false);
          _rebuildDorm();
        });
  }

  void _rebuildDorm() {
    final DormRulesSettings settings = _dormData['rulesSettings'] == null
        ? buildDefaultDormRulesSettings()
        : ModelSerializers.dormRulesSettingsFromMap(
            Map<String, dynamic>.from(_dormData['rulesSettings'] as Map),
          );
    _currentDorm = Dorm(
      id: _dormData['id'] as String? ?? (_activeDormId ?? 'dorm-204'),
      name: _dormData['name'] as String? ?? '梅苑 2 栋 204',
      overview: _dormData['overview'] as String? ?? '宿舍整体状态平稳，灯光已调暗，适合逐步进入睡眠模式。',
      noiseDb: _dormData['noiseDb'] as int? ?? 32,
      lightLabel: _dormData['lightLabel'] as String? ?? '偏暗',
      quietLabel: _dormData['quietLabel'] as String? ?? '良好',
      rules: _rules.isEmpty ? buildDormSummaryRules(settings) : _rules,
      members: _members,
      rulesSettings: settings,
      events: _events,
      invites: _invites,
    );
    if (!_dormController.isClosed) {
      _dormController.add(_currentDorm);
      _membersController.add(_currentDorm.members);
      _rulesController.add(_currentDorm.rules);
      _eventsController.add(_currentDorm.events);
    }
    notifyListeners();
  }

  void _cancelSubscriptions() {
    _dormSubscription?.cancel();
    _membersSubscription?.cancel();
    _rulesSubscription?.cancel();
    _eventsSubscription?.cancel();
    _invitesSubscription?.cancel();
  }

  @override
  void dispose() {
    _authRepository.removeListener(_restartSubscriptions);
    _cancelSubscriptions();
    _dormController.close();
    _membersController.close();
    _rulesController.close();
    _eventsController.close();
    super.dispose();
  }
}

class FirebaseDreamRepository extends ChangeNotifier implements DreamRepository {
  FirebaseDreamRepository({
    required FirebaseFirestore firestore,
    required AuthRepository authRepository,
  }) : _firestore = firestore,
       _authRepository = authRepository {
    _authRepository.addListener(_restartSubscription);
    _restartSubscription();
  }

  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  List<DreamEntry> _entries = const <DreamEntry>[];

  @override
  List<DreamEntry> get entries => List<DreamEntry>.unmodifiable(_entries);

  @override
  DreamEntry? get latestEntry => _entries.isEmpty ? null : _entries.first;

  @override
  Future<void> saveDreamEntry(DreamEntry entry) async {
    await _firestore
        .collection(FirebaseCollections.dreamEntries)
        .doc(entry.id)
        .set(ModelSerializers.dreamEntryToMap(entry), SetOptions(merge: true));
  }

  @override
  Future<void> deleteDreamEntry(String entryId) async {
    await _firestore.collection(FirebaseCollections.dreamEntries).doc(entryId).delete();
  }

  void _restartSubscription() {
    _subscription?.cancel();
    final String uid = _authRepository.currentUser.uid;
    if (uid.isEmpty) {
      return;
    }
    _subscription = _firestore
        .collection(FirebaseCollections.dreamEntries)
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
          _entries = snapshot.docs
              .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                return ModelSerializers.dreamEntryFromMap(doc.data());
              })
              .toList(growable: false)
            ..sort(
              (DreamEntry a, DreamEntry b) => b.createdAt.compareTo(a.createdAt),
            );
          notifyListeners();
        });
  }

  @override
  void dispose() {
    _authRepository.removeListener(_restartSubscription);
    _subscription?.cancel();
    super.dispose();
  }
}

class FirebaseAssistantRepository extends ChangeNotifier
    implements AssistantRepository {
  FirebaseAssistantRepository({
    required FirebaseFirestore firestore,
    required AuthRepository authRepository,
  }) : _firestore = firestore,
       _authRepository = authRepository {
    _authRepository.addListener(_restartThreadsSubscription);
    _restartThreadsSubscription();
  }

  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _threadsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messagesSubscription;
  List<AssistantThread> _threads = const <AssistantThread>[];
  final Map<String, List<AssistantMessage>> _messagesByThread =
      <String, List<AssistantMessage>>{};
  String? _currentThreadId;

  @override
  List<AssistantThread> get threads => List<AssistantThread>.unmodifiable(_threads);

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
      _messagesByThread[threadId] ?? const <AssistantMessage>[],
    );
  }

  @override
  Future<AssistantThread> ensureThread({String? title}) async {
    if (currentThread != null) {
      return currentThread!;
    }
    final String uid = _authRepository.currentUser.uid;
    final DocumentReference<Map<String, dynamic>> ref = _firestore
        .collection(FirebaseCollections.assistantThreads)
        .doc();
    final AssistantThread thread = AssistantThread(
      id: ref.id,
      userId: uid,
      title: title ?? '今晚睡前聊聊',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await ref.set(ModelSerializers.assistantThreadToMap(thread));
    await setCurrentThread(thread.id);
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
    await _writeMessage(message);
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
    await _writeMessage(message);
  }

  Future<void> _writeMessage(AssistantMessage message) async {
    await _firestore
        .collection(FirebaseCollections.assistantThreads)
        .doc(message.threadId)
        .collection(FirebaseCollections.assistantMessages)
        .doc(message.id)
        .set(ModelSerializers.assistantMessageToMap(message));
    await _firestore
        .collection(FirebaseCollections.assistantThreads)
        .doc(message.threadId)
        .set(<String, dynamic>{'updatedAt': DateTime.now()}, SetOptions(merge: true));
  }

  @override
  Future<void> setCurrentThread(String threadId) async {
    _currentThreadId = threadId;
    _restartMessagesSubscription();
    notifyListeners();
  }

  void _restartThreadsSubscription() {
    _threadsSubscription?.cancel();
    final String uid = _authRepository.currentUser.uid;
    if (uid.isEmpty) {
      return;
    }
    _threadsSubscription = _firestore
        .collection(FirebaseCollections.assistantThreads)
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
          _threads = snapshot.docs
              .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                return ModelSerializers.assistantThreadFromMap(doc.data());
              })
              .toList(growable: false)
            ..sort(
              (AssistantThread a, AssistantThread b) =>
                  b.updatedAt.compareTo(a.updatedAt),
            );
          _currentThreadId ??= _threads.isEmpty ? null : _threads.first.id;
          _restartMessagesSubscription();
          notifyListeners();
        });
  }

  void _restartMessagesSubscription() {
    _messagesSubscription?.cancel();
    final String? threadId = _currentThreadId;
    if (threadId == null) {
      return;
    }
    _messagesSubscription = _firestore
        .collection(FirebaseCollections.assistantThreads)
        .doc(threadId)
        .collection(FirebaseCollections.assistantMessages)
        .snapshots()
        .listen((snapshot) {
          _messagesByThread[threadId] = snapshot.docs
              .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                return ModelSerializers.assistantMessageFromMap(doc.data());
              })
              .toList(growable: false)
            ..sort(
              (AssistantMessage a, AssistantMessage b) =>
                  a.createdAt.compareTo(b.createdAt),
            );
          notifyListeners();
        });
  }

  @override
  void dispose() {
    _authRepository.removeListener(_restartThreadsSubscription);
    _threadsSubscription?.cancel();
    _messagesSubscription?.cancel();
    super.dispose();
  }
}
