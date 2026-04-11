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
import 'package:sleep_dorm_app/features/auth/presentation/pages/phone_auth_page.dart';

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
    final GoRouter router = createRouter(
      homeMode: homeMode,
      initialLocation: initialLocation,
    );

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
              return MaterialApp.router(
                title: 'DormSleep',
                debugShowCheckedModeBanner: false,
                theme: _buildTheme(effectiveMood),
                routerConfig: router,
                builder: (BuildContext context, Widget? child) {
                  final Widget routedChild = child ?? const SizedBox.shrink();
                  return _CloudBaseAuthGate(
                    environment: resolvedEnvironment,
                    authRepository: services.authRepository,
                    child: routedChild,
                  );
                },
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

class _CloudBaseAuthGate extends StatelessWidget {
  const _CloudBaseAuthGate({
    required this.environment,
    required this.authRepository,
    required this.child,
  });

  final AppEnvironment environment;
  final AuthRepository authRepository;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!environment.usesCloudBase) {
      return child;
    }
    if (authRepository.hasVerifiedPhoneIdentity == true) {
      return child;
    }
    return Stack(
      children: <Widget>[
        const PhoneAuthPage(),
        if (authRepository.isAuthenticating == true) const _AuthLoadingPage(),
      ],
    );
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
