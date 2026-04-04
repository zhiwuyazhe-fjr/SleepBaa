import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color background = Color(0xFFF9F9FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF2F4F6);
  static const Color surfaceSoft = Color(0xFFECEEF1);
  static const Color surfaceBorder = Color(0xFFDFE3E7);
  static const Color divider = Color(0xFFEBEEF2);

  static const Color textPrimary = Color(0xFF2F3336);
  static const Color textSecondary = Color(0xFF5B6063);
  static const Color textMuted = Color(0xFF57606B);

  static const Color primary = Color(0xFF00697A);
  static const Color primarySoft = Color(0xFF8EDDF2);
  static const Color primaryHighlight = Color(0xFFB2EBF2);
  static const Color primaryDeep = Color(0xFF004F5D);
  static const Color calmBlue = Color(0xFF4EA8C2);

  static const Color darkBackground = Color(0xFF0C0E10);
  static const Color darkCard = Color(0xFF0B192E);
  static const Color darkSurface = Color(0xFF1A1C1E);
  static const Color darkGlass = Color(0x0AFFFFFF);
  static const Color darkBorder = Color(0x14FFFFFF);
  static const Color onDark = Color(0xFFF9F9FB);

  static const Color success = Color(0xFF4F8B6F);
  static const Color warning = Color(0xFFAD7A36);

  static const List<BoxShadow> cardShadow = <BoxShadow>[
    BoxShadow(color: Color(0x12000000), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0C000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> floatingShadow = <BoxShadow>[
    BoxShadow(color: Color(0x14000000), blurRadius: 32, offset: Offset(0, 16)),
    BoxShadow(color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 6)),
  ];
}
