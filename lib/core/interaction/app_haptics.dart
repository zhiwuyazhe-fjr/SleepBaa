import 'package:flutter/services.dart';

enum AppHapticRole {
  tap,
  navigation,
  flowStart,
  confirm,
  selection,
  destructive,
}

class AppHaptics {
  const AppHaptics._();

  static Future<void> trigger(AppHapticRole role) {
    return switch (role) {
      AppHapticRole.tap => HapticFeedback.lightImpact(),
      AppHapticRole.navigation => HapticFeedback.mediumImpact(),
      AppHapticRole.flowStart => HapticFeedback.mediumImpact(),
      AppHapticRole.confirm => HapticFeedback.mediumImpact(),
      AppHapticRole.selection => HapticFeedback.selectionClick(),
      AppHapticRole.destructive => HapticFeedback.heavyImpact(),
    };
  }

  static Future<void> tap() => trigger(AppHapticRole.tap);

  static Future<void> navigation() => trigger(AppHapticRole.navigation);

  static Future<void> flowStart() => trigger(AppHapticRole.flowStart);

  static Future<void> confirm() => trigger(AppHapticRole.confirm);

  static Future<void> selection() => trigger(AppHapticRole.selection);

  static Future<void> destructive() => trigger(AppHapticRole.destructive);

  static VoidCallback? handler(
    VoidCallback? onTap, {
    AppHapticRole role = AppHapticRole.tap,
  }) {
    if (onTap == null) {
      return null;
    }
    return () {
      trigger(role);
      onTap();
    };
  }

  static VoidCallback? tapHandler(VoidCallback? onTap) {
    return handler(onTap);
  }

  static VoidCallback? navigationHandler(VoidCallback? onTap) {
    return handler(onTap, role: AppHapticRole.navigation);
  }

  static VoidCallback? flowStartHandler(VoidCallback? onTap) {
    return handler(onTap, role: AppHapticRole.flowStart);
  }

  static VoidCallback? confirmHandler(VoidCallback? onTap) {
    return handler(onTap, role: AppHapticRole.confirm);
  }

  static VoidCallback? selectionHandler(VoidCallback? onTap) {
    return handler(onTap, role: AppHapticRole.selection);
  }

  static VoidCallback? destructiveHandler(VoidCallback? onTap) {
    return handler(onTap, role: AppHapticRole.destructive);
  }
}
