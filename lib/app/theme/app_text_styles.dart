import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';

abstract final class AppTextStyles {
  static const List<String> cjkFallbackFonts = <String>[
    'PingFang SC',
    'Hiragino Sans GB',
    'Microsoft YaHei',
    'Noto Sans SC',
    'Noto Sans CJK SC',
    'Source Han Sans SC',
    'WenQuanYi Zen Hei',
    'sans-serif',
  ];

  static TextStyle _inter({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontFamilyFallback: cjkFallbackFonts,
    );
  }

  static TextStyle _manrope({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontFamilyFallback: cjkFallbackFonts,
    );
  }

  static TextTheme buildTextTheme({
    Color textPrimary = AppColors.textPrimary,
    Color textSecondary = AppColors.textSecondary,
  }) {
    final TextTheme bodyTheme = const TextTheme().copyWith(
      bodyLarge: _inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textPrimary,
        height: 1.45,
      ),
      bodyMedium: _inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textPrimary,
        height: 1.5,
      ),
      bodySmall: _inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textSecondary,
        height: 1.4,
      ),
      labelLarge: _inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      labelMedium: _inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: textSecondary,
      ),
      labelSmall: _inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: textSecondary,
        letterSpacing: 0.4,
      ),
    );

    return bodyTheme.copyWith(
      displayLarge: _manrope(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        height: 1.05,
      ),
      displayMedium: _manrope(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        height: 1.1,
      ),
      headlineLarge: _manrope(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        height: 1.12,
      ),
      headlineMedium: _manrope(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        height: 1.15,
      ),
      headlineSmall: _manrope(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: 1.2,
      ),
      titleLarge: _manrope(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: 1.2,
      ),
      titleMedium: _manrope(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      titleSmall: _manrope(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
    );
  }
}
