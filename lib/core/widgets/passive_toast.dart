import 'dart:async';
import 'dart:collection';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_page_insets.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';

class PassiveToastController {
  final Queue<_PassiveToastRequest> _pending = Queue<_PassiveToastRequest>();
  _PassiveToastSession? _activeSession;
  bool _isProcessingQueue = false;
  bool _isDisposed = false;

  Future<void> show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 2),
    Key? toastKey,
  }) async {
    if (_isDisposed) {
      return;
    }
    final Completer<void> completer = Completer<void>();
    _pending.add(
      _PassiveToastRequest(
        context: context,
        message: message,
        duration: duration,
        toastKey: toastKey,
        completer: completer,
      ),
    );
    _activeSession?.dismissForQueuedRequest();
    _startQueueConsumerIfNeeded();
    await completer.future;
  }

  void _startQueueConsumerIfNeeded() {
    if (_isDisposed || _isProcessingQueue) {
      return;
    }
    _isProcessingQueue = true;
    unawaited(_consumeQueue());
  }

  Future<void> _consumeQueue() async {
    while (!_isDisposed && _pending.isNotEmpty) {
      final _PassiveToastRequest request = _pending.removeFirst();
      if (!request.context.mounted) {
        request.complete();
        continue;
      }
      final OverlayState? overlay =
          Overlay.maybeOf(request.context, rootOverlay: true) ??
          Overlay.maybeOf(request.context);
      if (overlay == null || !overlay.mounted) {
        request.complete();
        continue;
      }
      late final _PassiveToastSession session;
      session = _PassiveToastSession(
        overlay: overlay,
        message: request.message,
        duration: request.duration,
        toastKey: request.toastKey,
        onDismissed: () {
          if (identical(_activeSession, session)) {
            _activeSession = null;
          }
        },
      );
      _activeSession = session;
      session.show();
      await session.entered;
      if (_pending.isNotEmpty) {
        await session.dismiss(immediate: true);
      }
      await session.closed;
      request.complete();
    }
    _isProcessingQueue = false;
    if (!_isDisposed && _pending.isNotEmpty) {
      _startQueueConsumerIfNeeded();
    }
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
    _isDisposed = true;
    while (_pending.isNotEmpty) {
      _pending.removeFirst().complete();
    }
    final _PassiveToastSession? activeSession = _activeSession;
    _activeSession = null;
    activeSession?.dismiss(immediate: true);
  }
}

class _PassiveToastRequest {
  _PassiveToastRequest({
    required this.context,
    required this.message,
    required this.duration,
    required this.toastKey,
    required this.completer,
  });

  final BuildContext context;
  final String message;
  final Duration duration;
  final Key? toastKey;
  final Completer<void> completer;

  void complete() {
    if (completer.isCompleted) {
      return;
    }
    completer.complete();
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
  final Completer<void> _closedCompleter = Completer<void>();
  final Completer<void> _enteredCompleter = Completer<void>();
  OverlayEntry? _entry;
  Timer? _enterTimer;
  Timer? _autoDismissTimer;
  Completer<void>? _dismissCompleter;
  bool _isDisposed = false;
  bool _canTapDismiss = false;

  Future<void> get closed => _closedCompleter.future;
  Future<void> get entered => _enteredCompleter.future;

  void show() {
    _entry = OverlayEntry(
      builder: (BuildContext context) {
        final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
        return Positioned(
          left: AppPageInsets.horizontal,
          right: AppPageInsets.horizontal,
          bottom: keyboardInset > 0 ? keyboardInset + 12 : 12,
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
                    borderRadius: AppRadius.toast,
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
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
      _enterTimer = Timer(_enterDuration, _onEnterCompleted);
    });
  }

  void _onEnterCompleted() {
    if (_isDisposed) {
      return;
    }
    _enterTimer = null;
    _canTapDismiss = true;
    if (!_enteredCompleter.isCompleted) {
      _enteredCompleter.complete();
    }
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
    _canTapDismiss = false;
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
      if (!_closedCompleter.isCompleted) {
        _closedCompleter.complete();
      }
      completer.complete();
    }

    unawaited(runDismiss());
    return completer.future;
  }

  void dismissForQueuedRequest() {
    if (_isDisposed || !_enteredCompleter.isCompleted) {
      return;
    }
    if (_dismissCompleter != null) {
      return;
    }
    unawaited(dismiss(immediate: true));
  }

  void _disposeEntry() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _enterTimer?.cancel();
    _enterTimer = null;
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(
      _handlePointerEvent,
    );
    _entry?.remove();
    _entry = null;
    _isVisible.dispose();
    if (!_enteredCompleter.isCompleted) {
      _enteredCompleter.complete();
    }
  }

  void _handlePointerEvent(PointerEvent event) {
    if (event is! PointerDownEvent || _isDisposed || !_canTapDismiss) {
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
