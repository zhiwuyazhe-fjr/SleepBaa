import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/app/theme/app_text_styles.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/backend/app_environment.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class SleepDormApp extends StatelessWidget {
  const SleepDormApp({
    super.key,
    this.initialLocation = AppRoutes.home,
    this.homeMode = HomeMode.preSleep,
    this.environment,
    this.clock,
    this.initialSettings,
    this.showNightWelcomeOutsideNightInDebug,
  });

  final String initialLocation;
  final HomeMode homeMode;
  final AppEnvironment? environment;
  final DateTime Function()? clock;
  final UserSettings? initialSettings;
  final bool? showNightWelcomeOutsideNightInDebug;

  @override
  Widget build(BuildContext context) {
    final AppEnvironment resolvedEnvironment =
        environment ?? AppEnvironment.inMemory();

    return AppScope(
      environment: resolvedEnvironment,
      clock: clock,
      initialSettings: initialSettings,
      showNightWelcomeOutsideNightInDebug: showNightWelcomeOutsideNightInDebug,
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
                homeMode: homeMode,
                initialLocation: initialLocation,
                theme: _buildTheme(effectiveMood),
                title: 'DormSleep',
              );
            },
          );
        },
      ),
    );
  }

  ThemeData _buildTheme(NightMood? mood) {
    final NightMoodPalette palette = NightMoodPalette.fromMood(mood);
    final ColorScheme colorScheme = const ColorScheme.light().copyWith(
      primary: palette.primary,
      onPrimary: AppColors.onDark,
      secondary: palette.primarySoft,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      outline: AppColors.surfaceBorder,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: AppTextStyles.buildTextTheme(),
      fontFamilyFallback: AppTextStyles.cjkFallbackFonts,
      extensions: <ThemeExtension<dynamic>>[palette],
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: AppColors.divider,
      splashColor: palette.primarySoft.withAlpha(38),
      highlightColor: Colors.transparent,
    );
  }
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
        oldWidget.services.authRepository != widget.services.authRepository) {
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
          child: routedChild,
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
    if (shouldShowCloudBaseAuthBlockingScreen(
      usesCloudBase: usesCloudBase,
      hasCompletedInitialAuthBootstrap:
          authRepository.hasCompletedInitialAuthBootstrap,
    )) {
      return const _AuthLoadingPage();
    }
    return child;
  }
}

class _AuthLoadingPage extends StatelessWidget {
  const _AuthLoadingPage();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background.withAlpha(214),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
