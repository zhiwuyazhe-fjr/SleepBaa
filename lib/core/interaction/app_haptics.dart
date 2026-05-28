import 'package:flutter/services.dart';

class AppHaptics {
  const AppHaptics._();

  static Future<void> tap() => HapticFeedback.lightImpact();

  static Future<void> navigation() => HapticFeedback.lightImpact();

  static Future<void> confirm() => HapticFeedback.lightImpact();

  static Future<void> selection() => HapticFeedback.selectionClick();

  static VoidCallback? tapHandler(VoidCallback? onTap) {
    if (onTap == null) {
      return null;
    }
    return () {
      tap();
      onTap();
    };
  }

  static VoidCallback? navigationHandler(VoidCallback? onTap) {
    if (onTap == null) {
      return null;
    }
    return () {
      navigation();
      onTap();
    };
  }

  static VoidCallback? confirmHandler(VoidCallback? onTap) {
    if (onTap == null) {
      return null;
    }
    return () {
      confirm();
      onTap();
    };
  }

  static VoidCallback? selectionHandler(VoidCallback? onTap) {
    if (onTap == null) {
      return null;
    }
    return () {
      selection();
      onTap();
    };
  }
}
