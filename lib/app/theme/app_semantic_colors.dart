import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.pageBackground,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceRaised,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textOnAccent,
    required this.accent,
    required this.accentSoft,
    required this.accentDeep,
    required this.heroStart,
    required this.heroMid,
    required this.heroEnd,
    required this.darkGlass,
    required this.primaryButtonShadow,
  });

  final Color pageBackground;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceRaised;
  final Color borderSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textOnAccent;
  final Color accent;
  final Color accentSoft;
  final Color accentDeep;
  final Color heroStart;
  final Color heroMid;
  final Color heroEnd;
  final Color darkGlass;
  final List<BoxShadow> primaryButtonShadow;

  static AppSemanticColors light(NightMoodPalette palette) {
    return AppSemanticColors(
      pageBackground: AppColors.background,
      surface: AppColors.surface,
      surfaceMuted: AppColors.surfaceMuted,
      surfaceRaised: AppColors.surface,
      borderSubtle: AppColors.surfaceBorder,
      textPrimary: AppColors.textPrimary,
      textSecondary: AppColors.textSecondary,
      textOnAccent: palette.welcomeTextOnAccent,
      accent: palette.welcomeAccentColor,
      accentSoft: palette.primaryHighlight,
      accentDeep: _deepForMood(palette.mood),
      heroStart: palette.heroGradientStart,
      heroMid: palette.heroGradientMid,
      heroEnd: palette.heroGradientEnd,
      darkGlass: AppColors.darkGlass,
      primaryButtonShadow: _primaryButtonShadow(palette.welcomeAccentColor),
    );
  }

  static AppSemanticColors dark(NightMoodPalette palette) {
    return AppSemanticColors(
      pageBackground: const Color(0xFF161A1E),
      surface: const Color(0xFF20262B),
      surfaceMuted: const Color(0xFF20262B),
      surfaceRaised: const Color(0xFF242A30),
      borderSubtle: const Color(0x16FFFFFF),
      textPrimary: AppColors.onDark,
      textSecondary: AppColors.onDark.withAlpha(180),
      textOnAccent: const Color(0xFF102B28),
      accent: const Color(0xFF7FB8AA),
      accentSoft: const Color(0xFF243531),
      accentDeep: const Color(0xFF516B64),
      heroStart: const Color(0xFF2B3A3A),
      heroMid: const Color(0xFF243033),
      heroEnd: const Color(0xFF1E2529),
      darkGlass: const Color(0x24FFFFFF),
      primaryButtonShadow: _primaryButtonShadow(const Color(0xFF7FB8AA)),
    );
  }

  static Color _deepForMood(NightMood? mood) {
    return switch (mood) {
      NightMood.happy => const Color(0xFF684A59),
      NightMood.sad => const Color(0xFF735847),
      NightMood.calm => const Color(0xFF516B64),
      null => const Color(0xFF3F5962),
    };
  }

  static List<BoxShadow> _primaryButtonShadow(Color accent) {
    return <BoxShadow>[
      BoxShadow(
        color: accent.withAlpha(54),
        blurRadius: 24,
        offset: const Offset(0, 12),
      ),
      const BoxShadow(
        color: Color(0x14000000),
        blurRadius: 12,
        offset: Offset(0, 4),
      ),
    ];
  }

  @override
  AppSemanticColors copyWith({
    Color? pageBackground,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceRaised,
    Color? borderSubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? textOnAccent,
    Color? accent,
    Color? accentSoft,
    Color? accentDeep,
    Color? heroStart,
    Color? heroMid,
    Color? heroEnd,
    Color? darkGlass,
    List<BoxShadow>? primaryButtonShadow,
  }) {
    return AppSemanticColors(
      pageBackground: pageBackground ?? this.pageBackground,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textOnAccent: textOnAccent ?? this.textOnAccent,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      accentDeep: accentDeep ?? this.accentDeep,
      heroStart: heroStart ?? this.heroStart,
      heroMid: heroMid ?? this.heroMid,
      heroEnd: heroEnd ?? this.heroEnd,
      darkGlass: darkGlass ?? this.darkGlass,
      primaryButtonShadow: primaryButtonShadow ?? this.primaryButtonShadow,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) {
      return this;
    }
    return AppSemanticColors(
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textOnAccent: Color.lerp(textOnAccent, other.textOnAccent, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentDeep: Color.lerp(accentDeep, other.accentDeep, t)!,
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroMid: Color.lerp(heroMid, other.heroMid, t)!,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t)!,
      darkGlass: Color.lerp(darkGlass, other.darkGlass, t)!,
      primaryButtonShadow: t < 0.5
          ? primaryButtonShadow
          : other.primaryButtonShadow,
    );
  }
}

extension AppSemanticColorsContext on BuildContext {
  AppSemanticColors get appColors {
    return Theme.of(this).extension<AppSemanticColors>() ??
        AppSemanticColors.light(nightMoodPalette);
  }
}
