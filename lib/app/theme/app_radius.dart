import 'package:flutter/material.dart';

abstract final class AppRadius {
  static const double xs = 8;
  static const double sm = 16;
  static const double md = 24;
  static const double lg = 32;
  static const double xl = 48;

  static BorderRadius get surfacePrimary => BorderRadius.circular(md);
  static BorderRadius get stripCard => BorderRadius.circular(md);
  static BorderRadius get surfaceSecondary => BorderRadius.circular(sm);
  static BorderRadius get iconContainer => BorderRadius.circular(sm);

  static BorderRadius get card => BorderRadius.circular(md);
  static BorderRadius get cardLarge => BorderRadius.circular(lg);
  static BorderRadius get pill => BorderRadius.circular(xl);
  static BorderRadius get sheetTop =>
      const BorderRadius.vertical(top: Radius.circular(xl));
}
