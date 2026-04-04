import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/widgets/mood_avatar.dart';

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
              final palette = context.nightMoodPalette;
              final bool hasMoodAvatar = palette.mood != null;
              final double pulse = _controller.value;
              final Widget fabGlyph = palette.mood == null
                  ? Icon(
                      Icons.auto_awesome_rounded,
                      key: const ValueKey<String>('assistant-fab-default-icon'),
                      color: palette.primaryHighlight,
                      size: 28,
                      shadows: <Shadow>[
                        Shadow(
                          color: palette.primarySoft,
                          blurRadius: 8 + (pulse * 4),
                        ),
                      ],
                    )
                  : MoodAvatar(
                      key: const ValueKey<String>('assistant-fab-mood-avatar'),
                      mood: palette.mood!,
                      size: 44,
                      fillColor: palette.welcomeFaceColor,
                    );

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
                      color: palette.primarySoft.withValues(
                        alpha: 0.1 + (pulse * 0.1),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: palette.primarySoft.withValues(alpha: 0.2),
                          blurRadius: 16 + (pulse * 8),
                          spreadRadius: pulse * 4,
                        ),
                      ],
                    ),
                  ),
                  if (!hasMoodAvatar)
                    Container(
                      key: const ValueKey<String>(
                        'assistant-fab-default-shell',
                      ),
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
                          color: palette.primarySoft.withValues(alpha: 0.4),
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
                          child: fabGlyph,
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      key: const ValueKey<String>('assistant-fab-mood-shell'),
                      width: 62,
                      height: 62,
                      child: Center(
                        child: Transform.rotate(
                          angle: pulse * math.pi * 0.04,
                          child: fabGlyph,
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
