import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/core/widgets/assistant_fab.dart';

class AssistantFabDock extends StatefulWidget {
  const AssistantFabDock({
    super.key,
    required this.child,
    this.minVerticalPercent = 0.18,
    this.maxVerticalPercent = 0.78,
    this.settleDuration = const Duration(milliseconds: 200),
  }) : assert(minVerticalPercent >= 0),
       assert(maxVerticalPercent <= 1),
       assert(minVerticalPercent < maxVerticalPercent);

  final Widget child;
  final double minVerticalPercent;
  final double maxVerticalPercent;
  final Duration settleDuration;

  @override
  State<AssistantFabDock> createState() => _AssistantFabDockState();
}

class _AssistantFabDockState extends State<AssistantFabDock>
    with SingleTickerProviderStateMixin {
  static const double _dragEdgeInset = 12;
  static const double _releaseScaleMin = 0.96;

  late final AnimationController _releaseController = AnimationController(
    vsync: this,
    duration: widget.settleDuration,
  );
  late final Animation<double> _releaseScale =
      Tween<double>(begin: _releaseScaleMin, end: 1).animate(
        CurvedAnimation(parent: _releaseController, curve: Curves.easeOutCubic),
      );

  bool _dockLeft = false;
  bool _dragging = false;
  double _verticalPercent = 0.58;

  @override
  void dispose() {
    _releaseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        final double fabWidth = AssistantFab.bounds.width;
        final double fabHeight = AssistantFab.bounds.height;
        final double centerY = (_verticalPercent * height).clamp(
          widget.minVerticalPercent * height,
          widget.maxVerticalPercent * height,
        );
        final double top = (centerY - (fabHeight / 2)).clamp(
          0,
          (height - fabHeight).clamp(0, double.infinity),
        );
        final double edgeInset = _dragging ? _dragEdgeInset : 0;
        final double left = _dockLeft
            ? edgeInset
            : width - fabWidth - edgeInset;

        return Stack(
          children: <Widget>[
            AnimatedPositioned(
              duration: _dragging ? Duration.zero : widget.settleDuration,
              curve: Curves.easeOutCubic,
              left: left,
              top: top,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (_) {
                  setState(() {
                    _dragging = true;
                  });
                },
                onPanUpdate: (DragUpdateDetails details) {
                  final RenderBox renderBox =
                      context.findRenderObject()! as RenderBox;
                  final Offset localPosition = renderBox.globalToLocal(
                    details.globalPosition,
                  );
                  final bool dockLeft = localPosition.dx < (width / 2);
                  final double updatedCenterY = (centerY + details.delta.dy)
                      .clamp(
                        widget.minVerticalPercent * height,
                        widget.maxVerticalPercent * height,
                      );
                  setState(() {
                    _dockLeft = dockLeft;
                    _verticalPercent = updatedCenterY / height;
                  });
                },
                onPanEnd: (_) {
                  setState(() {
                    _dragging = false;
                  });
                  _releaseController
                    ..reset()
                    ..forward();
                },
                onPanCancel: () {
                  setState(() {
                    _dragging = false;
                  });
                  _releaseController
                    ..reset()
                    ..forward();
                },
                child: ScaleTransition(
                  scale: _releaseScale,
                  child: widget.child,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
