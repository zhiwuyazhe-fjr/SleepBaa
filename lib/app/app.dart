import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_text_styles.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class SleepDormApp extends StatelessWidget {
  const SleepDormApp({
    super.key,
    this.initialLocation = AppRoutes.home,
    this.homeMode = HomeMode.preSleep,
  });

  final String initialLocation;
  final HomeMode homeMode;

  @override
  Widget build(BuildContext context) {
    final GoRouter router = createRouter(
      homeMode: homeMode,
      initialLocation: initialLocation,
    );

    return AppScope(
      child: MaterialApp.router(
        title: 'DormSleep',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        routerConfig: router,
      ),
    );
  }

  ThemeData _buildTheme() {
    final ColorScheme colorScheme = const ColorScheme.light().copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.onDark,
      secondary: AppColors.primarySoft,
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
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: AppColors.divider,
      splashColor: AppColors.primarySoft.withAlpha(38),
      highlightColor: Colors.transparent,
    );
  }
}
