import 'package:flutter/widgets.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';

abstract final class AppPageInsets {
  static const double horizontal = AppSpacing.xl;
  static const double top = AppSpacing.sm;

  static EdgeInsets page({
    double top = AppPageInsets.top,
    double bottom = AppSpacing.lg,
  }) {
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
  }

  static EdgeInsets floatingPage({
    double top = AppPageInsets.top,
    double bottom = 88,
  }) {
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
  }
}
