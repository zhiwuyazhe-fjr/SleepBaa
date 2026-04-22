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
import 'package:sleep_dorm_app/core/notifications/app_notification_service.dart';
import 'package:sleep_dorm_app/core/notifications/bedtime_reminder_sync_controller.dart';
import 'package:sleep_dorm_app/core/notifications/cloudbase_notification_sync_controller.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/core/notifications/sleep_mode_notification_controller.dart';
import 'package:sleep_dorm_app/core/notifications/unified_notification.dart';
import 'package:sleep_dorm_app/core/state/audio_playback_controller.dart';
import 'package:sleep_dorm_app/core/state/dorm_noise_sample_ledger.dart';
import 'package:sleep_dorm_app/core/state/dorm_presence_sync_controller.dart';
import 'package:sleep_dorm_app/core/state/interference_probe_controller.dart';
import 'package:sleep_dorm_app/core/state/night_welcome_controller.dart';
import 'package:sleep_dorm_app/core/state/sleep_experience_controller.dart';
import 'package:sleep_dorm_app/features/assistant/presentation/controllers/assistant_conversation_controller.dart';

class AppScope extends StatefulWidget {
  const AppScope({
    super.key,
    required this.child,
    required this.environment,
    this.clock,
    this.initialSettings,
    this.showNightWelcomeOutsideNightInDebug,
    this.appNotificationService,
  });

  final Widget child;
  final AppEnvironment environment;
  final AppClock? clock;
  final UserSettings? initialSettings;
  final bool? showNightWelcomeOutsideNightInDebug;
  final AppNotificationService? appNotificationService;

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
  late final AppNotificationService _appNotificationService;
  late final BedtimeReminderSyncController _bedtimeReminderSyncController;
  late final CloudBaseNotificationSyncController
  _cloudBaseNotificationSyncController;
  late final AudioPlaybackController _audioPlaybackController;
  late final DormPresenceSyncController _dormPresenceSyncController;
  late final DormNoiseSampleLedger _dormNoiseSampleLedger;
  late final InterferenceProbeController _interferenceProbeController;
  late final SleepExperienceController _sleepExperienceController;
  late final SleepModeNotificationController _sleepModeNotificationController;
  late final NightWelcomeController _nightWelcomeController;
  late final ProfileFacade _profileFacade;
  late final SleepFacade _sleepFacade;
  late final DormFacade _dormFacade;
  late final NotificationFacade _notificationFacade;
  late final DreamFacade _dreamFacade;
  late final InsightsFacade _insightsFacade;
  late final AssistantFacade _assistantFacade;
  late final AssistantConversationController _assistantConversationController;
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
    _appNotificationService =
        widget.appNotificationService ?? AppNotificationService();
    _bedtimeReminderSyncController = BedtimeReminderSyncController(
      authRepository: _authRepository,
      settingsRepository: _settingsRepository,
      notificationService: _appNotificationService,
    );
    _cloudBaseNotificationSyncController = CloudBaseNotificationSyncController(
      authRepository: _authRepository,
      notificationRepository: _notificationRepository,
      notificationService: _appNotificationService,
      snapshotStore: _cloudBaseSnapshotStore,
    );
    _audioPlaybackController = AudioPlaybackController();
    _dormPresenceSyncController = DormPresenceSyncController(
      authRepository: _authRepository,
      dormRepository: _dormRepository,
    );
    _dormNoiseSampleLedger = DormNoiseSampleLedger();
    _interferenceProbeController = InterferenceProbeController(
      authRepository: _authRepository,
      dormRepository: _dormRepository,
      environment: widget.environment,
      appApiClient: _cloudBaseAppApiClient,
      snapshotStore: _cloudBaseSnapshotStore,
      noiseSampleLedger: _dormNoiseSampleLedger,
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
      appNotificationService: _appNotificationService,
      audioPlaybackController: _audioPlaybackController,
      pushNotificationGateway: const NoOpPushNotificationGateway(),
      clock: widget.clock,
    );
    _sleepModeNotificationController = SleepModeNotificationController(
      sleepSessionRepository: _sleepSessionRepository,
      notificationService: _appNotificationService,
    );
    _profileFacade = ProfileFacade(
      authRepository: _authRepository,
      settingsRepository: _settingsRepository,
      recommendationRepository: _recommendationRepository,
      dormRepository: _dormRepository,
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
      assistantRepository: _assistantRepository,
      sleepCaptureRepository: _sleepCaptureRepository,
      dormRepository: _dormRepository,
      assistantReplyGateway: _assistantReplyGateway,
    );
    _assistantConversationController = AssistantConversationController(
      assistantRepository: _assistantRepository,
      sleepCaptureRepository: _sleepCaptureRepository,
      sleepSessionRepository: _sleepSessionRepository,
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
      assistantReplyGateway: _assistantReplyGateway,
      notificationApi: _unifiedNotificationDispatcher,
      appNotificationService: _appNotificationService,
      audioPlaybackController: _audioPlaybackController,
      dormPresenceSyncController: _dormPresenceSyncController,
      dormNoiseSampleLedger: _dormNoiseSampleLedger,
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
      assistantConversationController: _assistantConversationController,
    );
    _bootstrapExperience();
  }

  Future<void> _bootstrapExperience() async {
    try {
      await _sleepExperienceController.bootstrap();
      await _appNotificationService.initialize();
      await _appNotificationService.cancelSleepModeNotification();
      _bedtimeReminderSyncController.start();
      _cloudBaseNotificationSyncController.start();
      await _dormPresenceSyncController.restoreCachedLocationAnchor();
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
        appApiClient: appApiClient,
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
    _bedtimeReminderSyncController.handleAppLifecycleState(state);
    _cloudBaseNotificationSyncController.handleAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Always poke ensureAuthenticated so that a returning user gets their
      // session restored.  The call is a fast no-op when the cached auth
      // state is still valid.
      unawaited(_authRepository.ensureAuthenticated());
      // Heavy background syncs (presence, sleep) only run when there is an
      // authenticated user — otherwise resuming from the SMS app to check a
      // verification code would trigger network calls that cycle the auth
      // gate and destroy PhoneAuthPage state.
      if (_authRepository.hasVerifiedPhoneIdentity) {
        unawaited(_sleepExperienceController.handleAppResumed());
        unawaited(
          _dormPresenceSyncController.syncPresenceFromCurrentLocation(),
        );
      }
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
    _dormPresenceSyncController.dispose();
    _sleepModeNotificationController.dispose();
    _sleepFacade.dispose();
    _profileFacade.dispose();
    _assistantConversationController.dispose();
    _interferenceProbeController.dispose();
    _sleepExperienceController.dispose();
    _nightWelcomeController.dispose();
    _audioPlaybackController.dispose();
    unawaited(_bedtimeReminderSyncController.dispose());
    unawaited(_cloudBaseNotificationSyncController.dispose());
    unawaited(_appNotificationService.dispose());
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
    required this.assistantReplyGateway,
    required this.notificationApi,
    required this.appNotificationService,
    required this.audioPlaybackController,
    required this.dormPresenceSyncController,
    required this.dormNoiseSampleLedger,
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
    required this.assistantConversationController,
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
  final AssistantReplyGateway assistantReplyGateway;
  final UnifiedNotificationApi notificationApi;
  final AppNotificationService appNotificationService;
  final AudioPlaybackController audioPlaybackController;
  final DormPresenceSyncController dormPresenceSyncController;
  final DormNoiseSampleLedger dormNoiseSampleLedger;
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
  final AssistantConversationController assistantConversationController;
}

extension AppScopeContext on BuildContext {
  AppServices get appServices => AppScope.of(this);
}
