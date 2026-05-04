import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class NightMoodPalette extends ThemeExtension<NightMoodPalette> {
  const NightMoodPalette({
    required this.mood,
    required this.primary,
    required this.primarySoft,
    required this.primaryHighlight,
    required this.primaryDeep,
    required this.calmBlue,
    required this.welcomeCardColor,
    required this.welcomeFaceColor,
    required this.welcomeAccentColor,
    required this.welcomeTextOnAccent,
    required this.welcomeSurfaceColor,
    required this.heroGradientStart,
    required this.heroGradientMid,
    required this.heroGradientEnd,
    required this.moonGradientStart,
    required this.moonGradientMid,
    required this.moonGradientEnd,
  });

  final NightMood? mood;
  final Color primary;
  final Color primarySoft;
  final Color primaryHighlight;
  final Color primaryDeep;
  final Color calmBlue;
  final Color welcomeCardColor;
  final Color welcomeFaceColor;
  final Color welcomeAccentColor;
  final Color welcomeTextOnAccent;
  final Color welcomeSurfaceColor;
  final Color heroGradientStart;
  final Color heroGradientMid;
  final Color heroGradientEnd;
  final Color moonGradientStart;
  final Color moonGradientMid;
  final Color moonGradientEnd;

  static NightMoodPalette fromMood(NightMood? mood) {
    return switch (mood) {
      NightMood.happy => const NightMoodPalette(
        mood: NightMood.happy,
        primary: Color(0xFFB94C7E),
        primarySoft: Color(0xFFF7B6D1),
        primaryHighlight: Color(0xFFFFE3EF),
        primaryDeep: Color(0xFF7F3358),
        calmBlue: Color(0xFFD97BA8),
        welcomeCardColor: Color(0xFFFFEEF6),
        welcomeFaceColor: Color(0xFFFFA6C9),
        welcomeAccentColor: Color(0xFFFFA6C9),
        welcomeTextOnAccent: AppColors.textStrong,
        welcomeSurfaceColor: AppColors.darkSurface,
        heroGradientStart: Color(0xFFFFA6C9),
        heroGradientMid: Color(0xFFF7B6D1),
        heroGradientEnd: Color(0xFFB94C7E),
        moonGradientStart: Color(0xFFFFD5E5),
        moonGradientMid: Color(0xFFFF9FC2),
        moonGradientEnd: Color(0xFFB94C7E),
      ),
      NightMood.sad => const NightMoodPalette(
        mood: NightMood.sad,
        primary: Color(0xFFBE6B4A),
        primarySoft: Color(0xFFF6B59A),
        primaryHighlight: Color(0xFFFFE7DD),
        primaryDeep: Color(0xFF7E4631),
        calmBlue: Color(0xFFD78764),
        welcomeCardColor: Color(0xFFFFE7DD),
        welcomeFaceColor: Color(0xFFFF9A72),
        welcomeAccentColor: Color(0xFFFF9A72),
        welcomeTextOnAccent: AppColors.textStrong,
        welcomeSurfaceColor: AppColors.darkSurface,
        heroGradientStart: Color(0xFFFF9A72),
        heroGradientMid: Color(0xFFF6B59A),
        heroGradientEnd: Color(0xFFBE6B4A),
        moonGradientStart: Color(0xFFFFD8C7),
        moonGradientMid: Color(0xFFF4A47F),
        moonGradientEnd: Color(0xFFBE6B4A),
      ),
      NightMood.calm => const NightMoodPalette(
        mood: NightMood.calm,
        primary: Color(0xFF2C8E78),
        primarySoft: Color(0xFFA8E5D1),
        primaryHighlight: Color(0xFFDDF7EE),
        primaryDeep: Color(0xFF1F6655),
        calmBlue: Color(0xFF5ABEA4),
        welcomeCardColor: Color(0xFFDDF7EE),
        welcomeFaceColor: Color(0xFF8DE0C2),
        welcomeAccentColor: Color(0xFF8DE0C2),
        welcomeTextOnAccent: AppColors.textStrong,
        welcomeSurfaceColor: AppColors.darkSurface,
        heroGradientStart: Color(0xFF8DE0C2),
        heroGradientMid: Color(0xFFA8E5D1),
        heroGradientEnd: Color(0xFF2C8E78),
        moonGradientStart: Color(0xFFD7F7EC),
        moonGradientMid: Color(0xFF8DE0C2),
        moonGradientEnd: Color(0xFF2C8E78),
      ),
      null => const NightMoodPalette(
        mood: null,
        primary: AppColors.primary,
        primarySoft: AppColors.primarySoft,
        primaryHighlight: AppColors.primaryHighlight,
        primaryDeep: AppColors.primaryDeep,
        calmBlue: AppColors.calmBlue,
        welcomeCardColor: Color(0xFFE8F7FB),
        welcomeFaceColor: AppColors.primarySoft,
        welcomeAccentColor: AppColors.primarySoft,
        welcomeTextOnAccent: AppColors.textStrong,
        welcomeSurfaceColor: AppColors.darkSurface,
        heroGradientStart: AppColors.primarySoft,
        heroGradientMid: AppColors.primarySoft,
        heroGradientEnd: AppColors.primary,
        moonGradientStart: AppColors.primarySoft,
        moonGradientMid: AppColors.calmBlue,
        moonGradientEnd: AppColors.primary,
      ),
    };
  }

  @override
  NightMoodPalette copyWith({
    NightMood? mood,
    Color? primary,
    Color? primarySoft,
    Color? primaryHighlight,
    Color? primaryDeep,
    Color? calmBlue,
    Color? welcomeCardColor,
    Color? welcomeFaceColor,
    Color? welcomeAccentColor,
    Color? welcomeTextOnAccent,
    Color? welcomeSurfaceColor,
    Color? heroGradientStart,
    Color? heroGradientMid,
    Color? heroGradientEnd,
    Color? moonGradientStart,
    Color? moonGradientMid,
    Color? moonGradientEnd,
  }) {
    return NightMoodPalette(
      mood: mood ?? this.mood,
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      primaryHighlight: primaryHighlight ?? this.primaryHighlight,
      primaryDeep: primaryDeep ?? this.primaryDeep,
      calmBlue: calmBlue ?? this.calmBlue,
      welcomeCardColor: welcomeCardColor ?? this.welcomeCardColor,
      welcomeFaceColor: welcomeFaceColor ?? this.welcomeFaceColor,
      welcomeAccentColor: welcomeAccentColor ?? this.welcomeAccentColor,
      welcomeTextOnAccent: welcomeTextOnAccent ?? this.welcomeTextOnAccent,
      welcomeSurfaceColor: welcomeSurfaceColor ?? this.welcomeSurfaceColor,
      heroGradientStart: heroGradientStart ?? this.heroGradientStart,
      heroGradientMid: heroGradientMid ?? this.heroGradientMid,
      heroGradientEnd: heroGradientEnd ?? this.heroGradientEnd,
      moonGradientStart: moonGradientStart ?? this.moonGradientStart,
      moonGradientMid: moonGradientMid ?? this.moonGradientMid,
      moonGradientEnd: moonGradientEnd ?? this.moonGradientEnd,
    );
  }

  @override
  NightMoodPalette lerp(ThemeExtension<NightMoodPalette>? other, double t) {
    if (other is! NightMoodPalette) {
      return this;
    }
    return NightMoodPalette(
      mood: t < 0.5 ? mood : other.mood,
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      primaryHighlight: Color.lerp(
        primaryHighlight,
        other.primaryHighlight,
        t,
      )!,
      primaryDeep: Color.lerp(primaryDeep, other.primaryDeep, t)!,
      calmBlue: Color.lerp(calmBlue, other.calmBlue, t)!,
      welcomeCardColor: Color.lerp(
        welcomeCardColor,
        other.welcomeCardColor,
        t,
      )!,
      welcomeFaceColor: Color.lerp(
        welcomeFaceColor,
        other.welcomeFaceColor,
        t,
      )!,
      welcomeAccentColor: Color.lerp(
        welcomeAccentColor,
        other.welcomeAccentColor,
        t,
      )!,
      welcomeTextOnAccent: Color.lerp(
        welcomeTextOnAccent,
        other.welcomeTextOnAccent,
        t,
      )!,
      welcomeSurfaceColor: Color.lerp(
        welcomeSurfaceColor,
        other.welcomeSurfaceColor,
        t,
      )!,
      heroGradientStart: Color.lerp(
        heroGradientStart,
        other.heroGradientStart,
        t,
      )!,
      heroGradientMid: Color.lerp(heroGradientMid, other.heroGradientMid, t)!,
      heroGradientEnd: Color.lerp(heroGradientEnd, other.heroGradientEnd, t)!,
      moonGradientStart: Color.lerp(
        moonGradientStart,
        other.moonGradientStart,
        t,
      )!,
      moonGradientMid: Color.lerp(moonGradientMid, other.moonGradientMid, t)!,
      moonGradientEnd: Color.lerp(moonGradientEnd, other.moonGradientEnd, t)!,
    );
  }
}

extension NightMoodThemeContext on BuildContext {
  NightMoodPalette get nightMoodPalette =>
      Theme.of(this).extension<NightMoodPalette>() ??
      NightMoodPalette.fromMood(null);
}
