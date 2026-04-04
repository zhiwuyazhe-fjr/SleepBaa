import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/app/theme/app_text_styles.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class SleepDormApp extends StatelessWidget {
  const SleepDormApp({
    super.key,
    this.initialLocation = AppRoutes.home,
    this.homeMode = HomeMode.preSleep,
    this.clock,
    this.initialSettings,
    this.showNightWelcomeOutsideNightInDebug,
  });

  final String initialLocation;
  final HomeMode homeMode;
  final DateTime Function()? clock;
  final UserSettings? initialSettings;
  final bool? showNightWelcomeOutsideNightInDebug;

  @override
  Widget build(BuildContext context) {
    final GoRouter router = createRouter(
      homeMode: homeMode,
      initialLocation: initialLocation,
    );

    return AppScope(
      clock: clock,
      initialSettings: initialSettings,
      showNightWelcomeOutsideNightInDebug: showNightWelcomeOutsideNightInDebug,
      child: Builder(
        builder: (BuildContext context) {
          final AppServices services = context.appServices;
          return ListenableBuilder(
            listenable: services.settingsRepository,
            builder: (BuildContext context, Widget? child) {
              final UserSettings settings =
                  services.settingsRepository.currentSettings;
              return MaterialApp.router(
                title: 'DormSleep',
                debugShowCheckedModeBanner: false,
                theme: _buildTheme(settings.selectedNightMood),
                routerConfig: router,
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
      fontFamily: GoogleFonts.inter().fontFamily,
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
