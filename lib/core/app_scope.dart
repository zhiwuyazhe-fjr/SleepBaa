import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/core/data/in_memory_repositories.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/state/audio_playback_controller.dart';
import 'package:sleep_dorm_app/core/state/sleep_experience_controller.dart';

class AppScope extends StatefulWidget {
  const AppScope({super.key, required this.child});

  final Widget child;

  static AppServices of(BuildContext context) {
    final _AppScopeInherited? inherited = context
        .dependOnInheritedWidgetOfExactType<_AppScopeInherited>();
    assert(inherited != null, 'AppScope not found in widget tree.');
    return inherited!.services;
  }

  @override
  State<AppScope> createState() => _AppScopeState();
}

class _AppScopeState extends State<AppScope> {
  late final InMemoryAuthRepository _authRepository;
  late final InMemoryUserSettingsRepository _settingsRepository;
  late final InMemoryRecommendationRepository _recommendationRepository;
  late final InMemorySleepSessionRepository _sleepSessionRepository;
  late final InMemoryFeedbackRepository _feedbackRepository;
  late final InMemoryNotificationRepository _notificationRepository;
  late final InMemoryDormRepository _dormRepository;
  late final AudioPlaybackController _audioPlaybackController;
  late final SleepExperienceController _sleepExperienceController;
  late final AppServices _services;

  @override
  void initState() {
    super.initState();
    _authRepository = InMemoryAuthRepository();
    _settingsRepository = InMemoryUserSettingsRepository();
    _recommendationRepository = InMemoryRecommendationRepository();
    _sleepSessionRepository = InMemorySleepSessionRepository();
    _feedbackRepository = InMemoryFeedbackRepository(
      sleepSessionRepository: _sleepSessionRepository,
    );
    _notificationRepository = InMemoryNotificationRepository();
    _dormRepository = InMemoryDormRepository();
    _audioPlaybackController = AudioPlaybackController();
    _sleepExperienceController = SleepExperienceController(
      authRepository: _authRepository,
      settingsRepository: _settingsRepository,
      recommendationRepository: _recommendationRepository,
      sleepSessionRepository: _sleepSessionRepository,
      feedbackRepository: _feedbackRepository,
      notificationRepository: _notificationRepository,
      dormRepository: _dormRepository,
      audioPlaybackController: _audioPlaybackController,
      pushNotificationGateway: const NoOpPushNotificationGateway(),
    );
    _services = AppServices(
      authRepository: _authRepository,
      settingsRepository: _settingsRepository,
      recommendationRepository: _recommendationRepository,
      sleepSessionRepository: _sleepSessionRepository,
      feedbackRepository: _feedbackRepository,
      notificationRepository: _notificationRepository,
      dormRepository: _dormRepository,
      audioPlaybackController: _audioPlaybackController,
      sleepExperienceController: _sleepExperienceController,
    );
    _sleepExperienceController.bootstrap();
  }

  @override
  void dispose() {
    _sleepExperienceController.dispose();
    _audioPlaybackController.dispose();
    _dormRepository.dispose();
    _notificationRepository.dispose();
    _feedbackRepository.dispose();
    _sleepSessionRepository.dispose();
    _recommendationRepository.dispose();
    _settingsRepository.dispose();
    _authRepository.dispose();
    super.dispose();
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
    required this.authRepository,
    required this.settingsRepository,
    required this.recommendationRepository,
    required this.sleepSessionRepository,
    required this.feedbackRepository,
    required this.notificationRepository,
    required this.dormRepository,
    required this.audioPlaybackController,
    required this.sleepExperienceController,
  });

  final AuthRepository authRepository;
  final UserSettingsRepository settingsRepository;
  final RecommendationRepository recommendationRepository;
  final SleepSessionRepository sleepSessionRepository;
  final FeedbackRepository feedbackRepository;
  final NotificationRepository notificationRepository;
  final DormRepository dormRepository;
  final AudioPlaybackController audioPlaybackController;
  final SleepExperienceController sleepExperienceController;
}

extension AppScopeContext on BuildContext {
  AppServices get appServices => AppScope.of(this);
}
