import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';

class AssistantFab extends StatelessWidget {
  const AssistantFab({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open assistant',
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.assistant),
        child: SizedBox(
          width: 86,
          height: 94,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: <Widget>[
              const Positioned(top: 2, left: 14, child: _FoxEar(left: true)),
              const Positioned(top: 2, right: 14, child: _FoxEar(left: false)),
              Container(
                width: 74,
                height: 74,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment(-0.15, -0.25),
                    radius: 0.92,
                    colors: <Color>[
                      Color(0xFF31353B),
                      Color(0xFF1E2024),
                      Color(0xFF121417),
                    ],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 24,
                      offset: Offset(0, 14),
                    ),
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Positioned(
                      top: 18,
                      left: 18,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withAlpha(28),
                        ),
                      ),
                    ),
                    const Positioned(top: 27, left: 24, child: _FaceDot()),
                    const Positioned(top: 27, right: 24, child: _FaceDot()),
                    const Positioned(
                      bottom: 17,
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF8AF4FF),
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoxEar extends StatelessWidget {
  const _FoxEar({required this.left});

  final bool left;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: left ? -0.38 : 0.38,
      child: SizedBox(
        width: 24,
        height: 32,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFA23A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(left ? 18 : 8),
                  topRight: Radius.circular(left ? 8 : 18),
                  bottomLeft: const Radius.circular(8),
                  bottomRight: const Radius.circular(8),
                ),
              ),
            ),
            Positioned(
              top: 6,
              left: 5,
              right: 5,
              bottom: 6,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD5B6),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(left ? 12 : 6),
                    topRight: Radius.circular(left ? 6 : 12),
                    bottomLeft: const Radius.circular(6),
                    bottomRight: const Radius.circular(6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaceDot extends StatelessWidget {
  const _FaceDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF7FBFF),
      ),
    );
  }
}
