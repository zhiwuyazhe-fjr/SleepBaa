import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/core/backend/assistant_reply_gateway.dart';
import 'package:sleep_dorm_app/core/backend/app_environment.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_app_api_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_auth_client.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_session_store.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_snapshot_store.dart';
import 'package:sleep_dorm_app/core/data/cloudbase_repositories.dart';
import 'package:sleep_dorm_app/core/data/in_memory_repositories.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/facades/app_facades.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/core/notifications/unified_notification.dart';
import 'package:sleep_dorm_app/core/state/audio_playback_controller.dart';
import 'package:sleep_dorm_app/core/state/dorm_presence_sync_controller.dart';
import 'package:sleep_dorm_app/core/state/interference_probe_controller.dart';
import 'package:sleep_dorm_app/core/state/night_welcome_controller.dart';
import 'package:sleep_dorm_app/core/state/sleep_experience_controller.dart';

class AppScope extends StatefulWidget {
  const AppScope({
    super.key,
    required this.child,
    required this.environment,
    this.clock,
    this.initialSettings,
    this.showNightWelcomeOutsideNightInDebug,
  });

  final Widget child;
  final AppEnvironment environment;
  final AppClock? clock;
  final UserSettings? initialSettings;
  final bool? showNightWelcomeOutsideNightInDebug;

  static AppServices of(BuildContext context) {
    final _AppScopeInherited? inherited = context
        .dependOnInheritedWidgetOfExactType<_AppScopeInherited>();
    assert(inherited != null, 'AppScope not found in widget tree.');
    return inherited!.services;
  }

  @override
  State<AppScope> createState() => _AppScopeState();
}

class _AppScopeState extends State<AppScope> with WidgetsBindingObserver {
  late final AuthRepository _authRepository;
  late final UserSettingsRepository _settingsRepository;
  late final RecommendationRepository _recommendationRepository;
  late final SleepSessionRepository _sleepSessionRepository;
  late final FeedbackRepository _feedbackRepository;
  late final SleepCaptureRepository _sleepCaptureRepository;
  late final NotificationRepository _notificationRepository;
  late final DormRepository _dormRepository;
  late final DreamRepository _dreamRepository;
  late final InsightsRepository _insightsRepository;
  late final AssistantRepository _assistantRepository;
  late final UnifiedNotificationDispatcher _unifiedNotificationDispatcher;
  late final PassiveToastNotificationChannel _passiveToastNotificationChannel;
  late final AudioPlaybackController _audioPlaybackController;
  late final DormPresenceSyncController _dormPresenceSyncController;
  late final InterferenceProbeController _interferenceProbeController;
  late final SleepExperienceController _sleepExperienceController;
  late final NightWelcomeController _nightWelcomeController;
  late final ProfileFacade _profileFacade;
  late final SleepFacade _sleepFacade;
  late final DormFacade _dormFacade;
  late final NotificationFacade _notificationFacade;
  late final DreamFacade _dreamFacade;
  late final InsightsFacade _insightsFacade;
  late final AssistantFacade _assistantFacade;
  late final AssistantReplyGateway _assistantReplyGateway;
  late final AppServices _services;
  CloudBaseSnapshotStore? _cloudBaseSnapshotStore;
  CloudBaseAppApiClient? _cloudBaseAppApiClient;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _buildRepositories();
    _passiveToastNotificationChannel = PassiveToastNotificationChannel();
    _unifiedNotificationDispatcher = UnifiedNotificationDispatcher();
    _unifiedNotificationDispatcher.register(_passiveToastNotificationChannel);
    _audioPlaybackController = AudioPlaybackController();
    _dormPresenceSyncController = DormPresenceSyncController(
      authRepository: _authRepository,
      dormRepository: _dormRepository,
    );
    _interferenceProbeController = InterferenceProbeController(
      authRepository: _authRepository,
      dormRepository: _dormRepository,
      environment: widget.environment,
      appApiClient: _cloudBaseAppApiClient,
      snapshotStore: _cloudBaseSnapshotStore,
    );
    _nightWelcomeController = NightWelcomeController(
      clock: widget.clock ?? DateTime.now,
      showInDebugOutsideNight:
          widget.showNightWelcomeOutsideNightInDebug ?? kDebugMode,
    );
    _sleepExperienceController = SleepExperienceController(
      authRepository: _authRepository,
      settingsRepository: _settingsRepository,
      recommendationRepository: _recommendationRepository,
      sleepSessionRepository: _sleepSessionRepository,
      feedbackRepository: _feedbackRepository,
      sleepCaptureRepository: _sleepCaptureRepository,
      notificationRepository: _notificationRepository,
      dormRepository: _dormRepository,
      audioPlaybackController: _audioPlaybackController,
      pushNotificationGateway: const NoOpPushNotificationGateway(),
    );
    _profileFacade = ProfileFacade(
      authRepository: _authRepository,
      settingsRepository: _settingsRepository,
      recommendationRepository: _recommendationRepository,
    );
    _sleepFacade = SleepFacade(
      experienceController: _sleepExperienceController,
      recommendationRepository: _recommendationRepository,
      sleepSessionRepository: _sleepSessionRepository,
      audioPlaybackController: _audioPlaybackController,
    );
    _dormFacade = DormFacade(
      authRepository: _authRepository,
      dormRepository: _dormRepository,
    );
    _notificationFacade = NotificationFacade(
      notificationRepository: _notificationRepository,
    );
    _dreamFacade = DreamFacade(
      authRepository: _authRepository,
      dreamRepository: _dreamRepository,
    );
    _insightsFacade = InsightsFacade(insightsRepository: _insightsRepository);
    _assistantFacade = AssistantFacade(
      authRepository: _authRepository,
      assistantRepository: _assistantRepository,
      sleepCaptureRepository: _sleepCaptureRepository,
      dormRepository: _dormRepository,
      assistantReplyGateway: _assistantReplyGateway,
    );
    _services = AppServices(
      environment: widget.environment,
      authRepository: _authRepository,
      settingsRepository: _settingsRepository,
      recommendationRepository: _recommendationRepository,
      sleepSessionRepository: _sleepSessionRepository,
      feedbackRepository: _feedbackRepository,
      sleepCaptureRepository: _sleepCaptureRepository,
      notificationRepository: _notificationRepository,
      dormRepository: _dormRepository,
      dreamRepository: _dreamRepository,
      insightsRepository: _insightsRepository,
      assistantRepository: _assistantRepository,
      notificationApi: _unifiedNotificationDispatcher,
      audioPlaybackController: _audioPlaybackController,
      dormPresenceSyncController: _dormPresenceSyncController,
      interferenceProbeController: _interferenceProbeController,
      sleepExperienceController: _sleepExperienceController,
      nightWelcomeController: _nightWelcomeController,
      profileFacade: _profileFacade,
      sleepFacade: _sleepFacade,
      dormFacade: _dormFacade,
      notificationFacade: _notificationFacade,
      dreamFacade: _dreamFacade,
      insightsFacade: _insightsFacade,
      assistantFacade: _assistantFacade,
    );
    _bootstrapExperience();
  }

  Future<void> _bootstrapExperience() async {
    try {
      await _sleepExperienceController.bootstrap();
      await _dormPresenceSyncController.syncPresenceFromCurrentLocation();
    } catch (_) {
      // Auth and callable failures are surfaced through repository state so
      // the app can keep rendering while settings diagnostics explain the
      // backend issue.
    }
  }

  void _buildRepositories() {
    if (widget.environment.usesCloudBase) {
      final CloudBaseSessionStore sessionStore = CloudBaseSessionStore();
      final CloudBaseAuthClient authClient = CloudBaseAuthClient(
        environment: widget.environment,
      );
      final CloudBaseAppApiClient appApiClient = CloudBaseAppApiClient(
        environment: widget.environment,
        sessionStore: sessionStore,
        authClient: authClient,
      );
      _cloudBaseAppApiClient = appApiClient;
      final CloudBaseSnapshotStore snapshotStore = CloudBaseSnapshotStore(
        appApiClient: appApiClient,
      );
      _cloudBaseSnapshotStore = snapshotStore;
      _authRepository = CloudBaseAuthRepository(
        environment: widget.environment,
        authClient: authClient,
        appApiClient: appApiClient,
        sessionStore: sessionStore,
        snapshotStore: snapshotStore,
      );
      _settingsRepository = CloudBaseUserSettingsRepository(
        authRepository: _authRepository,
        snapshotStore: snapshotStore,
        appApiClient: appApiClient,
      );
      _recommendationRepository = CloudBaseRecommendationRepository(
        authRepository: _authRepository,
        settingsRepository: _settingsRepository,
        snapshotStore: snapshotStore,
        appApiClient: appApiClient,
      );
      _sleepSessionRepository = CloudBaseSleepSessionRepository(
        authRepository: _authRepository,
        snapshotStore: snapshotStore,
        appApiClient: appApiClient,
      );
      _feedbackRepository = CloudBaseFeedbackRepository(
        sleepSessionRepository: _sleepSessionRepository,
        appApiClient: appApiClient,
        snapshotStore: snapshotStore,
      );
      _sleepCaptureRepository = CloudBaseSleepCaptureRepository(
        authRepository: _authRepository,
        snapshotStore: snapshotStore,
        appApiClient: appApiClient,
      );
      _notificationRepository = CloudBaseNotificationRepository(
        authRepository: _authRepository,
        snapshotStore: snapshotStore,
      );
      _dormRepository = CloudBaseDormRepository(
        authRepository: _authRepository,
        snapshotStore: snapshotStore,
        appApiClient: appApiClient,
      );
      _dreamRepository = CloudBaseDreamRepository(
        authRepository: _authRepository,
        snapshotStore: snapshotStore,
        appApiClient: appApiClient,
      );
      _assistantRepository = CloudBaseAssistantRepository(
        authRepository: _authRepository,
        snapshotStore: snapshotStore,
        appApiClient: appApiClient,
      );
      _assistantReplyGateway = CloudBaseAssistantReplyGateway(
        appApiClient: appApiClient,
        snapshotStore: snapshotStore,
      );
      _insightsRepository = CloudBaseInsightsRepository(
        authRepository: _authRepository,
        snapshotStore: snapshotStore,
        appApiClient: appApiClient,
        sleepSessionRepository: _sleepSessionRepository,
        dormRepository: _dormRepository,
        dreamRepository: _dreamRepository,
      );
      return;
    }

    _authRepository = InMemoryAuthRepository();
    _settingsRepository = InMemoryUserSettingsRepository(
      initialSettings: widget.initialSettings,
    );
    _recommendationRepository = InMemoryRecommendationRepository();
    _sleepSessionRepository = InMemorySleepSessionRepository(
      initialUid: _authRepository.currentUser.uid,
    );
    _feedbackRepository = InMemoryFeedbackRepository(
      sleepSessionRepository: _sleepSessionRepository,
    );
    _sleepCaptureRepository = InMemorySleepCaptureRepository();
    _notificationRepository = InMemoryNotificationRepository(
      ownerUid: _authRepository.currentUser.uid,
    );
    _dormRepository = InMemoryDormRepository(
      currentUserId: _authRepository.currentUser.uid,
    );
    _dreamRepository = InMemoryDreamRepository(
      userId: _authRepository.currentUser.uid,
    );
    _assistantRepository = InMemoryAssistantRepository(
      userId: _authRepository.currentUser.uid,
    );
    _assistantReplyGateway = const StubAssistantReplyGateway();
    _insightsRepository = InMemoryInsightsRepository(
      sleepSessionRepository: _sleepSessionRepository,
      dormRepository: _dormRepository,
      dreamRepository: _dreamRepository,
    );
    _cloudBaseAppApiClient = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_dormPresenceSyncController.syncPresenceFromCurrentLocation());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _passiveToastNotificationChannel.dispose();
    _assistantFacade.dispose();
    _insightsFacade.dispose();
    _dreamFacade.dispose();
    _notificationFacade.dispose();
    _dormFacade.dispose();
    _sleepFacade.dispose();
    _profileFacade.dispose();
    _interferenceProbeController.dispose();
    _sleepExperienceController.dispose();
    _nightWelcomeController.dispose();
    _audioPlaybackController.dispose();
    _disposeListenable(_assistantRepository);
    _disposeListenable(_insightsRepository);
    _disposeListenable(_dreamRepository);
    _disposeListenable(_dormRepository);
    _disposeListenable(_notificationRepository);
    _disposeListenable(_sleepCaptureRepository);
    _disposeListenable(_feedbackRepository);
    _disposeListenable(_sleepSessionRepository);
    _disposeListenable(_recommendationRepository);
    _disposeListenable(_settingsRepository);
    _disposeListenable(_authRepository);
    _disposeListenable(_cloudBaseSnapshotStore);
    super.dispose();
  }

  void _disposeListenable(Object? instance) {
    if (instance == null) {
      return;
    }
    if (instance case ChangeNotifier notifier) {
      notifier.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AppScopeInherited(services: _services, child: widget.child);
  }
}

class _AppScopeInherited extends InheritedWidget {
  const _AppScopeInherited({required this.services, required super.child});

  final AppServices services;

  @override
  bool updateShouldNotify(_AppScopeInherited oldWidget) => false;
}

class AppServices {
  const AppServices({
    required this.environment,
    required this.authRepository,
    required this.settingsRepository,
    required this.recommendationRepository,
    required this.sleepSessionRepository,
    required this.feedbackRepository,
    required this.sleepCaptureRepository,
    required this.notificationRepository,
    required this.dormRepository,
    required this.dreamRepository,
    required this.insightsRepository,
    required this.assistantRepository,
    required this.notificationApi,
    required this.audioPlaybackController,
    required this.dormPresenceSyncController,
    required this.interferenceProbeController,
    required this.sleepExperienceController,
    required this.nightWelcomeController,
    required this.profileFacade,
    required this.sleepFacade,
    required this.dormFacade,
    required this.notificationFacade,
    required this.dreamFacade,
    required this.insightsFacade,
    required this.assistantFacade,
  });

  final AppEnvironment environment;
  final AuthRepository authRepository;
  final UserSettingsRepository settingsRepository;
  final RecommendationRepository recommendationRepository;
  final SleepSessionRepository sleepSessionRepository;
  final FeedbackRepository feedbackRepository;
  final SleepCaptureRepository sleepCaptureRepository;
  final NotificationRepository notificationRepository;
  final DormRepository dormRepository;
  final DreamRepository dreamRepository;
  final InsightsRepository insightsRepository;
  final AssistantRepository assistantRepository;
  final UnifiedNotificationApi notificationApi;
  final AudioPlaybackController audioPlaybackController;
  final DormPresenceSyncController dormPresenceSyncController;
  final InterferenceProbeController interferenceProbeController;
  final SleepExperienceController sleepExperienceController;
  final NightWelcomeController nightWelcomeController;
  final ProfileFacade profileFacade;
  final SleepFacade sleepFacade;
  final DormFacade dormFacade;
  final NotificationFacade notificationFacade;
  final DreamFacade dreamFacade;
  final InsightsFacade insightsFacade;
  final AssistantFacade assistantFacade;
}

extension AppScopeContext on BuildContext {
  AppServices get appServices => AppScope.of(this);
}
