import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class PassiveToastController {
  _PassiveToastSession? _activeSession;
  int _requestVersion = 0;

  Future<void> show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 2),
    Key? toastKey,
  }) async {
    final OverlayState? overlay =
        Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.maybeOf(context);
    if (overlay == null || !overlay.mounted) {
      return;
    }

    _requestVersion += 1;
    final int currentVersion = _requestVersion;
    final _PassiveToastSession? previousSession = _activeSession;
    if (previousSession != null) {
      await previousSession.dismiss();
      if (identical(_activeSession, previousSession)) {
        _activeSession = null;
      }
    }
    if (currentVersion != _requestVersion) {
      return;
    }

    late final _PassiveToastSession session;
    session = _PassiveToastSession(
      overlay: overlay,
      message: message,
      duration: duration,
      toastKey: toastKey,
      onDismissed: () {
        if (identical(_activeSession, session)) {
          _activeSession = null;
        }
      },
    );
    _activeSession = session;
    session.show();
  }

  Future<void> dismiss() async {
    final _PassiveToastSession? activeSession = _activeSession;
    if (activeSession == null) {
      return;
    }
    await activeSession.dismiss();
    if (identical(_activeSession, activeSession)) {
      _activeSession = null;
    }
  }

  void dispose() {
    _requestVersion += 1;
    final _PassiveToastSession? activeSession = _activeSession;
    _activeSession = null;
    activeSession?.dismiss(immediate: true);
  }
}

class _PassiveToastSession {
  _PassiveToastSession({
    required this.overlay,
    required this.message,
    required this.duration,
    required this.toastKey,
    required this.onDismissed,
  });

  static const Duration _enterDuration = Duration(milliseconds: 360);
  static const Duration _exitDuration = Duration(milliseconds: 300);

  final OverlayState overlay;
  final String message;
  final Duration duration;
  final Key? toastKey;
  final VoidCallback onDismissed;

  final ValueNotifier<bool> _isVisible = ValueNotifier<bool>(false);
  final GlobalKey _toastLayoutKey = GlobalKey();
  OverlayEntry? _entry;
  Timer? _autoDismissTimer;
  Completer<void>? _dismissCompleter;
  bool _isDisposed = false;

  void show() {
    _entry = OverlayEntry(
      builder: (BuildContext context) {
        return Positioned(
          left: 16,
          right: 16,
          bottom: 12,
          child: SafeArea(
            top: false,
            child: ValueListenableBuilder<bool>(
              valueListenable: _isVisible,
              builder: (BuildContext context, bool visible, Widget? child) {
                final Duration transitionDuration = visible
                    ? _enterDuration
                    : _exitDuration;
                final Curve transitionCurve = visible
                    ? Curves.easeOutQuart
                    : Curves.easeInCubic;
                return AnimatedSlide(
                  duration: transitionDuration,
                  curve: transitionCurve,
                  offset: visible ? Offset.zero : const Offset(0, 0.24),
                  child: AnimatedOpacity(
                    duration: transitionDuration,
                    curve: transitionCurve,
                    opacity: visible ? 1 : 0,
                    child: AnimatedScale(
                      duration: transitionDuration,
                      curve: transitionCurve,
                      scale: visible ? 1 : 0.985,
                      child: child,
                    ),
                  ),
                );
              },
              child: IgnorePointer(
                child: KeyedSubtree(
                  key: toastKey,
                  child: Material(
                    key: _toastLayoutKey,
                    color: const Color(0xFF181B22),
                    borderRadius: BorderRadius.circular(14),
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_entry!);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handlePointerEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed) {
        return;
      }
      _isVisible.value = true;
    });
    _autoDismissTimer = Timer(duration, () {
      unawaited(dismiss());
    });
  }

  Future<void> dismiss({bool immediate = false}) {
    final Completer<void>? existingCompleter = _dismissCompleter;
    if (existingCompleter != null) {
      return existingCompleter.future;
    }

    final Completer<void> completer = Completer<void>();
    _dismissCompleter = completer;
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;

    Future<void> runDismiss() async {
      if (!_isDisposed) {
        if (immediate) {
          _isVisible.value = false;
        } else {
          _isVisible.value = false;
          await Future<void>.delayed(_exitDuration);
        }
      }
      _disposeEntry();
      onDismissed();
      completer.complete();
    }

    unawaited(runDismiss());
    return completer.future;
  }

  void _disposeEntry() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_handlePointerEvent);
    _entry?.remove();
    _entry = null;
    _isVisible.dispose();
  }

  void _handlePointerEvent(PointerEvent event) {
    if (event is! PointerDownEvent || _isDisposed) {
      return;
    }
    final Rect? toastRect = _getToastRect();
    if (toastRect == null) {
      return;
    }
    if (toastRect.contains(event.position)) {
      unawaited(dismiss());
    }
  }

  Rect? _getToastRect() {
    final BuildContext? context = _toastLayoutKey.currentContext;
    if (context == null) {
      return null;
    }
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) {
      return null;
    }
    final Offset topLeft = renderObject.localToGlobal(Offset.zero);
    return topLeft & renderObject.size;
  }
}
