import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/interaction/app_haptics.dart';
import 'package:sleep_dorm_app/core/widgets/mood_avatar.dart';

/// Same visual as the floating assistant FAB for a fixed [palette].
///
/// [keySuffix] is appended to inner [ValueKey] strings so multiple instances
/// (e.g. settings) do not duplicate keys. Use the default empty suffix for the
/// main [AssistantFab] so widget tests still find `assistant-fab-default-icon`.
class AssistantFabVisual extends StatefulWidget {
  const AssistantFabVisual({
    super.key,
    required this.palette,
    this.keySuffix = '',
  });

  final NightMoodPalette palette;
  final String keySuffix;

  static const Size bounds = Size(108, 118);

  @override
  State<AssistantFabVisual> createState() => _AssistantFabVisualState();
}

class _AssistantFabVisualState extends State<AssistantFabVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 2500),
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    if (WidgetsBinding.instance.lifecycleState != null) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _k(String base) => '$base${widget.keySuffix}';

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = widget.palette;
    final bool hasMoodAvatar = palette.mood != null;

    return SizedBox(
      width: AssistantFabVisual.bounds.width,
      height: AssistantFabVisual.bounds.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double pulse = _controller.value;
          final Widget fabGlyph = palette.mood == null
              ? Icon(
                  Icons.auto_awesome_rounded,
                  key: ValueKey<String>(_k('assistant-fab-default-icon')),
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
                  key: ValueKey<String>(_k('assistant-fab-mood-avatar')),
                  mood: palette.mood!,
                  size: 60,
                  fillColor: palette.welcomeFaceColor,
                );

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
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
                  key: ValueKey<String>(_k('assistant-fab-default-shell')),
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
                  key: ValueKey<String>(_k('assistant-fab-mood-shell')),
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
    );
  }
}

class AssistantFab extends StatefulWidget {
  const AssistantFab({super.key});

  static Size get bounds => AssistantFabVisual.bounds;

  @override
  State<AssistantFab> createState() => _AssistantFabState();
}

class _AssistantFabState extends State<AssistantFab> {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open assistant',
      child: GestureDetector(
        onTap: () {
          AppHaptics.navigation();
          context.push(AppRoutes.assistant);
        },
        child: AssistantFabVisual(palette: context.nightMoodPalette),
      ),
    );
  }
}
