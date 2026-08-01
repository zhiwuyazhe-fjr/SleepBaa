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

  static Future<void> trigger(AppHapticRole role) async {
    if (kIsWeb) {
      return;
    }
    try {
      await _perform(role);
    } catch (_) {
      try {
        await HapticFeedback.vibrate();
      } catch (_) {}
    }
  }

  static Future<void> _perform(AppHapticRole role) {
    return switch (role) {
      AppHapticRole.tap => _impact('light', HapticFeedback.lightImpact),
      AppHapticRole.navigation => _runPattern(<_HapticPulse>[
        const _HapticPulse.selection(),
        const _HapticPulse.light(after: Duration(milliseconds: 28)),
      ]),
      AppHapticRole.flowStart => _runPattern(<_HapticPulse>[
        const _HapticPulse.medium(),
        const _HapticPulse.selection(after: Duration(milliseconds: 64)),
      ]),
      AppHapticRole.confirm => _runPattern(<_HapticPulse>[
        const _HapticPulse.light(),
        const _HapticPulse.medium(after: Duration(milliseconds: 44)),
      ]),
      AppHapticRole.selection => _impact(
        'selection',
        HapticFeedback.selectionClick,
      ),
      AppHapticRole.messageSend => _runPattern(<_HapticPulse>[
        const _HapticPulse.light(),
        const _HapticPulse.selection(after: Duration(milliseconds: 30)),
        const _HapticPulse.medium(after: Duration(milliseconds: 42)),
        const _HapticPulse.selection(after: Duration(milliseconds: 56)),
      ]),
      AppHapticRole.destructive => _runPattern(<_HapticPulse>[
        const _HapticPulse.medium(),
        const _HapticPulse.heavy(after: Duration(milliseconds: 72)),
      ]),
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

  static Future<void> _runPattern(List<_HapticPulse> pulses) async {
    for (final _HapticPulse pulse in pulses) {
      if (pulse.after > Duration.zero) {
        await Future<void>.delayed(pulse.after);
      }
      await pulse.trigger();
    }
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

class _HapticPulse {
  const _HapticPulse._(this.type, {this.after = Duration.zero});

  const _HapticPulse.light({Duration after = Duration.zero})
    : this._(_HapticPulseType.light, after: after);

  const _HapticPulse.medium({Duration after = Duration.zero})
    : this._(_HapticPulseType.medium, after: after);

  const _HapticPulse.heavy({Duration after = Duration.zero})
    : this._(_HapticPulseType.heavy, after: after);

  const _HapticPulse.selection({Duration after = Duration.zero})
    : this._(_HapticPulseType.selection, after: after);

  final _HapticPulseType type;
  final Duration after;

  Future<void> trigger() {
    return switch (type) {
      _HapticPulseType.light => AppHaptics._impact(
        'light',
        HapticFeedback.lightImpact,
      ),
      _HapticPulseType.medium => AppHaptics._impact(
        'medium',
        HapticFeedback.mediumImpact,
      ),
      _HapticPulseType.heavy => AppHaptics._impact(
        'heavy',
        HapticFeedback.heavyImpact,
      ),
      _HapticPulseType.selection => AppHaptics._impact(
        'selection',
        HapticFeedback.selectionClick,
      ),
    };
  }
}

enum _HapticPulseType { light, medium, heavy, selection }
