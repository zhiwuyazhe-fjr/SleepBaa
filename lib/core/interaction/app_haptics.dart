import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AppHapticRole {
  tap,
  navigation,
  flowStart,
  confirm,
  selection,
  messageSend,
  destructive,
}

class AppHaptics {
  const AppHaptics._();

  static const MethodChannel _nativeChannel = MethodChannel(
    'com.dormsleep.app/haptics',
  );

  static bool _enabled = true;

  static bool get enabled => _enabled;

  static void configure({required bool enabled}) {
    _enabled = enabled;
  }

  static Future<void> trigger(AppHapticRole role) async {
    if (kIsWeb || !_enabled) {
      return;
    }
    try {
      await _perform(role);
    } catch (_) {
      // Haptics are best-effort and must never block the user action. Each
      // role already owns its fallback, so do not issue a second pulse here.
    }
  }

  static Future<void> _perform(AppHapticRole role) {
    return switch (role) {
      AppHapticRole.tap => _impact('light', HapticFeedback.lightImpact),
      AppHapticRole.navigation => _impact(
        'selection',
        HapticFeedback.selectionClick,
      ),
      AppHapticRole.flowStart => _impact('medium', HapticFeedback.mediumImpact),
      AppHapticRole.confirm => _impact('medium', HapticFeedback.mediumImpact),
      AppHapticRole.selection => _impact(
        'selection',
        HapticFeedback.selectionClick,
      ),
      AppHapticRole.messageSend => _impact(
        'medium',
        HapticFeedback.mediumImpact,
      ),
      AppHapticRole.destructive => _impact('heavy', HapticFeedback.heavyImpact),
    };
  }

  static Future<void> _impact(
    String style,
    Future<void> Function() fallback,
  ) async {
    // Keep the Flutter path for tests and non-Android targets. Android uses
    // the native channel so devices that ignore lightImpact still receive a
    // real view haptic/vibrator pulse.
    if (!Platform.isAndroid) {
      await fallback();
      return;
    }
    try {
      final bool? performed = await _nativeChannel.invokeMethod<bool>(
        'impact',
        <String, dynamic>{'style': style},
      );
      if (performed == true) {
        return;
      }
    } on MissingPluginException {
      // Use Flutter's platform haptic implementation when the channel is not
      // available (for example, an older Android engine).
    } catch (_) {
      // Fall through to the Flutter implementation.
    }
    await fallback();
  }

  static Future<void> tap() => trigger(AppHapticRole.tap);

  static Future<void> navigation() => trigger(AppHapticRole.navigation);

  static Future<void> flowStart() => trigger(AppHapticRole.flowStart);

  static Future<void> confirm() => trigger(AppHapticRole.confirm);

  static Future<void> selection() => trigger(AppHapticRole.selection);

  static Future<void> messageSend() => trigger(AppHapticRole.messageSend);

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

  static VoidCallback? messageSendHandler(VoidCallback? onTap) {
    return handler(onTap, role: AppHapticRole.messageSend);
  }

  static VoidCallback? destructiveHandler(VoidCallback? onTap) {
    return handler(onTap, role: AppHapticRole.destructive);
  }
}
