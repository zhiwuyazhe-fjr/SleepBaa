import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/widgets/mood_avatar.dart';

class AssistantFab extends StatefulWidget {
  const AssistantFab({super.key});

  static const Size bounds = Size(108, 118);

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
          width: AssistantFab.bounds.width,
          height: AssistantFab.bounds.height,
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
                      size: 34,
                      shadows: <Shadow>[
                        Shadow(
                          color: palette.primarySoft,
                          blurRadius: 12 + (pulse * 5),
                        ),
                      ],
                    )
                  : MoodAvatar(
                      key: const ValueKey<String>('assistant-fab-mood-avatar'),
                      mood: palette.mood!,
                      size: 60,
                      fillColor: palette.welcomeFaceColor,
                    );

              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: <Widget>[
                  // Glow ring
                  Container(
                    width: 66 + (pulse * 12),
                    height: 66 + (pulse * 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.primarySoft.withValues(
                        alpha: 0.18 + (pulse * 0.14),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: palette.primarySoft.withValues(alpha: 0.34),
                          blurRadius: 24 + (pulse * 10),
                          spreadRadius: 2 + (pulse * 5),
                        ),
                      ],
                    ),
                  ),
                  if (!hasMoodAvatar)
                    Container(
                      key: const ValueKey<String>(
                        'assistant-fab-default-shell',
                      ),
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            AppColors.assistantFabShellStart,
                            AppColors.assistantFabShellEnd,
                          ],
                        ),
                        border: Border.all(
                          color: palette.primarySoft.withValues(alpha: 0.4),
                          width: 1.6,
                        ),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: AppColors.assistantFabShadow,
                            blurRadius: 18,
                            offset: Offset(0, 8),
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
                      width: 84,
                      height: 84,
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
