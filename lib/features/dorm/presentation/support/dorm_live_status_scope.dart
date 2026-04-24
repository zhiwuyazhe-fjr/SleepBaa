import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';

class DormLiveStatusScope extends StatefulWidget {
  const DormLiveStatusScope({
    super.key,
    required this.pageId,
    required this.builder,
  });

  final String pageId;
  final WidgetBuilder builder;

  @override
  State<DormLiveStatusScope> createState() => _DormLiveStatusScopeState();
}

class _DormLiveStatusScopeState extends State<DormLiveStatusScope> {
  AppServices? _services;
  bool _syncScheduled = false;
  bool? _lastActive;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppServices services = context.appServices;
    if (!identical(_services, services)) {
      _services?.dormLiveStatusController.setPageActive(
        pageId: widget.pageId,
        active: false,
      );
      _services = services;
    }
    _scheduleSync();
  }

  @override
  void didUpdateWidget(covariant DormLiveStatusScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageId == widget.pageId) {
      return;
    }
    _services?.dormLiveStatusController.setPageActive(
      pageId: oldWidget.pageId,
      active: false,
    );
    _lastActive = null;
    _scheduleSync();
  }

  void _scheduleSync() {
    if (!mounted || _syncScheduled) {
      return;
    }
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted) {
        return;
      }
      final AppServices services = context.appServices;
      final ModalRoute<dynamic>? route = ModalRoute.of(context);
      final bool shouldPoll =
          TickerMode.valuesOf(context).enabled &&
          (route == null || route.isCurrent);
      if (_lastActive == shouldPoll) {
        return;
      }
      _lastActive = shouldPoll;
      services.dormLiveStatusController.setPageActive(
        pageId: widget.pageId,
        active: shouldPoll,
      );
    });
  }

  @override
  void dispose() {
    _services?.dormLiveStatusController.setPageActive(
      pageId: widget.pageId,
      active: false,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleSync();
    return widget.builder(context);
  }
}
