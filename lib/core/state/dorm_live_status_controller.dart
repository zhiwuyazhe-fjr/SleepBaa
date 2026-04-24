import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';

typedef DormLiveStatusClock = DateTime Function();
typedef DormLiveStatusPeriodicTimerFactory =
    Timer Function(Duration duration, void Function(Timer timer) callback);

class DormLiveStatusController extends ChangeNotifier {
  DormLiveStatusController({
    required DormRepository dormRepository,
    Duration refreshInterval = const Duration(seconds: 15),
    DormLiveStatusClock? clock,
    DormLiveStatusPeriodicTimerFactory? periodicTimerFactory,
  }) : _dormRepository = dormRepository,
       _refreshInterval = refreshInterval,
       _clock = clock ?? DateTime.now,
       _periodicTimerFactory = periodicTimerFactory ?? Timer.periodic,
       _currentTime = (clock ?? DateTime.now)();

  final DormRepository _dormRepository;
  final Duration _refreshInterval;
  final DormLiveStatusClock _clock;
  final DormLiveStatusPeriodicTimerFactory _periodicTimerFactory;

  final Set<String> _activePageIds = <String>{};

  Timer? _timer;
  bool _isForeground = true;
  bool _isRefreshing = false;
  bool _refreshQueued = false;
  DateTime _currentTime;

  DateTime get currentTime => _currentTime;
  bool get isPolling => _timer != null;

  void setPageActive({required String pageId, required bool active}) {
    final String normalizedPageId = pageId.trim();
    if (normalizedPageId.isEmpty) {
      return;
    }
    final bool changed = active
        ? _activePageIds.add(normalizedPageId)
        : _activePageIds.remove(normalizedPageId);
    if (!changed) {
      return;
    }
    _syncPollingState();
  }

  void handleAppLifecycleState(AppLifecycleState state) {
    final bool nextForeground = state == AppLifecycleState.resumed;
    final bool changed = _isForeground != nextForeground;
    _isForeground = nextForeground;
    if (!changed && !nextForeground) {
      return;
    }
    _syncPollingState(
      forceRefresh: nextForeground && _activePageIds.isNotEmpty,
    );
  }

  void _syncPollingState({bool forceRefresh = false}) {
    final bool shouldPoll = _isForeground && _activePageIds.isNotEmpty;
    if (!shouldPoll) {
      _timer?.cancel();
      _timer = null;
      return;
    }

    final bool startedPolling = _timer == null;
    _timer ??= _periodicTimerFactory(_refreshInterval, (_) {
      unawaited(_refreshAndTick());
    });
    if (startedPolling || forceRefresh) {
      unawaited(_refreshAndTick());
    }
  }

  Future<void> _refreshAndTick() async {
    _currentTime = _clock();
    notifyListeners();

    if (_isRefreshing) {
      _refreshQueued = true;
      return;
    }

    _isRefreshing = true;
    try {
      do {
        _refreshQueued = false;
        await _dormRepository.refreshDormSnapshot();
      } while (_refreshQueued);
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _activePageIds.clear();
    super.dispose();
  }
}
