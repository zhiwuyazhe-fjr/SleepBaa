import 'package:flutter/material.dart';

abstract final class AppTypography {
  static TextStyle heroTitle(TextTheme textTheme) {
    return (textTheme.headlineMedium ?? const TextStyle()).copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      height: 1.16,
    );
  }

  static TextStyle sectionTitle(TextTheme textTheme) {
    return (textTheme.titleLarge ?? const TextStyle()).copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      height: 1.22,
    );
  }

  static TextStyle panelTitle(TextTheme textTheme) {
    return (textTheme.titleMedium ?? const TextStyle()).copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.25,
    );
  }

  static TextStyle cardTitle(TextTheme textTheme) {
    return (textTheme.titleSmall ?? const TextStyle()).copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      height: 1.30,
    );
  }

  static TextStyle body(TextTheme textTheme) {
    return (textTheme.bodyMedium ?? const TextStyle()).copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.50,
    );
  }

  static TextStyle bodyMuted(TextTheme textTheme) {
    return (textTheme.bodySmall ?? const TextStyle()).copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.45,
    );
  }

  static TextStyle meta(TextTheme textTheme) {
    return (textTheme.labelMedium ?? const TextStyle()).copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.30,
      letterSpacing: 0,
    );
  }

  static TextStyle chip(TextTheme textTheme) {
    return (textTheme.labelSmall ?? const TextStyle()).copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 1.25,
      letterSpacing: 0,
    );
  }
}
