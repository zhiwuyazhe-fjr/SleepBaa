import 'package:flutter/material.dart';

class AmbientOrb extends StatefulWidget {
  const AmbientOrb({
    super.key,
    required this.size,
    required this.color,
    this.animate = false,
  });

  final double size;
  final Color color;
  final bool animate;

  @override
  State<AmbientOrb> createState() => _AmbientOrbState();
}

class _AmbientOrbState extends State<AmbientOrb>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 5),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate || _controller == null) {
      return _buildOrb(scale: 1, alpha: 0.18);
    }

    return AnimatedBuilder(
      animation: _controller!,
      builder: (BuildContext context, Widget? child) {
        final double progress = Curves.easeInOut.transform(_controller!.value);
        return _buildOrb(
          scale: 0.95 + (progress * 0.18),
          alpha: 0.14 + (progress * 0.12),
        );
      },
    );
  }

  Widget _buildOrb({required double scale, required double alpha}) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withAlpha((255 * alpha).round()),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: widget.color.withAlpha((255 * alpha).round()),
              blurRadius: widget.size * 0.28,
              spreadRadius: widget.size * 0.06,
            ),
          ],
        ),
      ),
    );
  }
}
