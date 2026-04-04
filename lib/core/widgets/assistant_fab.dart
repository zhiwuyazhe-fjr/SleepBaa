import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';

class AssistantFab extends StatefulWidget {
  const AssistantFab({super.key});

  @override
  State<AssistantFab> createState() => _AssistantFabState();
}

class _AssistantFabState extends State<AssistantFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 2500),
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    // Do not repeat in test logic, pumpAndSettle will timeout
    if (WidgetsBinding.instance.lifecycleState != null) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              final double pulse = _controller.value;
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: <Widget>[
                  // Glow ring
                  Container(
                    width: 58 + (pulse * 8),
                    height: 58 + (pulse * 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF8AF4FF).withOpacity(0.1 + (pulse * 0.1)),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: const Color(0xFF8AF4FF).withOpacity(0.2),
                          blurRadius: 16 + (pulse * 8),
                          spreadRadius: pulse * 4,
                        ),
                      ],
                    ),
                  ),
                  // Core
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[Color(0xFF2B3240), Color(0xFF121417)],
                      ),
                      border: Border.all(
                        color: const Color(0xFF8AF4FF).withOpacity(0.4),
                        width: 1.5,
                      ),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Transform.rotate(
                        angle: pulse * math.pi * 0.05,
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: const Color(0xFFE0FFFF),
                          size: 28,
                          shadows: <BoxShadow>[
                            BoxShadow(
                              color: const Color(0xFF8AF4FF),
                              blurRadius: 8 + (pulse * 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
