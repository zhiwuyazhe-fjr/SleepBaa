import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/app_brand.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_text_styles.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/backend/app_environment.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/state/evening_welcome_local_store.dart';
import 'package:sleep_dorm_app/core/notifications/app_notification_service.dart';
import 'package:sleep_dorm_app/core/notifications/notification_navigation_coordinator.dart';

class SleepDormApp extends StatefulWidget {
  const SleepDormApp({
    super.key,
    this.initialLocation = AppRoutes.home,
    this.homeMode = HomeMode.preSleep,
    this.environment,
    this.clock,
    this.initialSettings,
    this.showNightWelcomeOutsideNightInDebug,
    this.appNotificationService,
    this.initialLocalEveningWelcome,
  });

  final String initialLocation;
  final HomeMode homeMode;
  final AppEnvironment? environment;
  final DateTime Function()? clock;
  final UserSettings? initialSettings;
  final bool? showNightWelcomeOutsideNightInDebug;
  final AppNotificationService? appNotificationService;

  /// Local welcome + encouragement for current period after [main] pruning.
  final LocalEveningWelcomeBootState? initialLocalEveningWelcome;

  @override
  State<SleepDormApp> createState() => _SleepDormAppState();
}

class _SleepDormAppState extends State<SleepDormApp> {
  @override
  Widget build(BuildContext context) {
    final AppEnvironment resolvedEnvironment =
        widget.environment ?? AppEnvironment.inMemory();

    return AppScope(
      environment: resolvedEnvironment,
      clock: widget.clock,
      initialSettings: widget.initialSettings,
      showNightWelcomeOutsideNightInDebug:
          widget.showNightWelcomeOutsideNightInDebug,
      appNotificationService: widget.appNotificationService,
      initialLocalEveningWelcome: widget.initialLocalEveningWelcome,
      child: Builder(
        builder: (BuildContext context) {
          final AppServices services = context.appServices;
          return ListenableBuilder(
            listenable: Listenable.merge(<Listenable>[
              services.authRepository,
              services.settingsRepository,
              services.nightWelcomeController,
            ]),
            builder: (BuildContext context, Widget? child) {
              final UserSettings settings =
                  services.settingsRepository.currentSettings;
              final NightMood? effectiveMood = services.nightWelcomeController
                  .effectiveMood(settings.selectedNightMood);
              return _RoutedSleepDormApp(
                services: services,
                usesCloudBase: resolvedEnvironment.usesCloudBase,
                homeMode: widget.homeMode,
                initialLocation: widget.initialLocation,
                theme: _buildTheme(effectiveMood),
                title: AppBrand.displayName,
              );
            },
          );
        },
      ),
    );
  }

  ThemeData _buildTheme(NightMood? mood) {
    final NightMoodPalette palette = NightMoodPalette.fromMood(mood);
    final AppSemanticColors appColors = AppSemanticColors.light(palette);
    final ColorScheme colorScheme = const ColorScheme.light().copyWith(
      primary: appColors.accent,
      onPrimary: appColors.textOnAccent,
      secondary: appColors.accentSoft,
      surface: appColors.surface,
      onSurface: appColors.textPrimary,
      outline: appColors.borderSubtle,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: appColors.pageBackground,
      textTheme: AppTextStyles.buildTextTheme(),
      fontFamilyFallback: AppTextStyles.cjkFallbackFonts,
      extensions: <ThemeExtension<dynamic>>[palette, appColors],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: appColors.pageBackground,
        foregroundColor: appColors.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: appColors.borderSubtle,
      splashColor: appColors.accentSoft.withAlpha(38),
      highlightColor: Colors.transparent,
    );
  }
}

class _NotificationBridge extends StatefulWidget {
  const _NotificationBridge({required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  State<_NotificationBridge> createState() => _NotificationBridgeState();
}

class _NotificationBridgeState extends State<_NotificationBridge> {
  NotificationNavigationCoordinator? _coordinator;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _coordinator ??= _createCoordinator();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_coordinator?.start());
    });
  }

  @override
  void didUpdateWidget(covariant _NotificationBridge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router == widget.router) {
      return;
    }
    final NotificationNavigationCoordinator? previous = _coordinator;
    _coordinator = _createCoordinator();
    unawaited(previous?.dispose());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_coordinator?.start());
    });
  }

  @override
  void dispose() {
    unawaited(_coordinator?.dispose());
    super.dispose();
  }

  NotificationNavigationCoordinator _createCoordinator() {
    final AppServices services = context.appServices;
    return NotificationNavigationCoordinator(
      router: widget.router,
      notificationRepository: services.notificationRepository,
      notificationService: services.appNotificationService,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

bool shouldShowCloudBaseAuthBlockingScreen({
  required bool usesCloudBase,
  required bool hasCompletedInitialAuthBootstrap,
}) {
  return usesCloudBase && !hasCompletedInitialAuthBootstrap;
}

class _RoutedSleepDormApp extends StatefulWidget {
  const _RoutedSleepDormApp({
    required this.services,
    required this.usesCloudBase,
    required this.homeMode,
    required this.initialLocation,
    required this.theme,
    required this.title,
  });

  final AppServices services;
  final bool usesCloudBase;
  final HomeMode homeMode;
  final String initialLocation;
  final ThemeData theme;
  final String title;

  @override
  State<_RoutedSleepDormApp> createState() => _RoutedSleepDormAppState();
}

class _RoutedSleepDormAppState extends State<_RoutedSleepDormApp> {
  late GoRouter _router = _buildRouter();

  GoRouter _buildRouter() {
    return createRouter(
      usesCloudBase: widget.usesCloudBase,
      authRepository: widget.services.authRepository,
      sleepSessionRepository: widget.services.sleepSessionRepository,
      homeMode: widget.homeMode,
      initialLocation: widget.initialLocation,
    );
  }

  @override
  void didUpdateWidget(covariant _RoutedSleepDormApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.usesCloudBase != widget.usesCloudBase ||
        oldWidget.homeMode != widget.homeMode ||
        oldWidget.initialLocation != widget.initialLocation ||
        oldWidget.services.authRepository != widget.services.authRepository ||
        oldWidget.services.sleepSessionRepository !=
            widget.services.sleepSessionRepository) {
      _router.dispose();
      _router = _buildRouter();
    }
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: widget.title,
      debugShowCheckedModeBanner: false,
      theme: widget.theme,
      routerConfig: _router,
      builder: (BuildContext context, Widget? child) {
        final Widget routedChild = child ?? const SizedBox.shrink();
        return _CloudBaseAuthGate(
          usesCloudBase: widget.usesCloudBase,
          authRepository: widget.services.authRepository,
          child: _NotificationBridge(router: _router, child: routedChild),
        );
      },
    );
  }
}

class _CloudBaseAuthGate extends StatelessWidget {
  const _CloudBaseAuthGate({
    required this.usesCloudBase,
    required this.authRepository,
    required this.child,
  });

  final bool usesCloudBase;
  final AuthRepository authRepository;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!usesCloudBase) {
      return child;
    }

    if (authRepository.hasVerifiedPhoneIdentity == true) {
      return child;
    }

    final bool showLoadingOverlay =
        !authRepository.hasCompletedInitialAuthBootstrap ||
        authRepository.isAuthenticating;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        child,
        if (showLoadingOverlay) const _AuthLoadingOverlay(),
      ],
    );
  }
}

class _AuthLoadingOverlay extends StatelessWidget {
  const _AuthLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background.withAlpha(214),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
