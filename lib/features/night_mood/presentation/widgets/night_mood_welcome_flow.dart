import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/mood_avatar.dart';

class NightMoodWelcomeFlow extends StatefulWidget {
  const NightMoodWelcomeFlow({
    super.key,
    this.initialMood,
    required this.onSkip,
    required this.onComplete,
  });

  final NightMood? initialMood;
  final AsyncVoidCallback onSkip;
  final AsyncValueCallback<NightMood> onComplete;

  @override
  State<NightMoodWelcomeFlow> createState() => _NightMoodWelcomeFlowState();
}

class _NightMoodWelcomeFlowState extends State<NightMoodWelcomeFlow> {
  NightMoodFlowStep _step = NightMoodFlowStep.select;
  late NightMood _selectedMood;
  late Set<String> _selectedReasons;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedMood = widget.initialMood ?? NightMood.calm;
    _selectedReasons = <String>{_selectedMood.reasons.first};
  }

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = NightMoodPalette.fromMood(_selectedMood);

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: switch (_step) {
          NightMoodFlowStep.select => _SelectionStep(
            key: const ValueKey<String>('night-mood-select-step'),
            selectedMood: _selectedMood,
            palette: palette,
            isSubmitting: _isSubmitting,
            onMoodChanged: _handleMoodChanged,
            onNext: () => setState(() => _step = NightMoodFlowStep.reasons),
            onSkip: _handleSkip,
          ),
          NightMoodFlowStep.reasons => _ReasonsStep(
            key: const ValueKey<String>('night-mood-reasons-step'),
            selectedMood: _selectedMood,
            palette: palette,
            selectedReasons: _selectedReasons,
            isSubmitting: _isSubmitting,
            onBack: () => setState(() => _step = NightMoodFlowStep.select),
            onToggleReason: _toggleReason,
            onNext: () => setState(() => _step = NightMoodFlowStep.welcome),
          ),
          NightMoodFlowStep.welcome => _WelcomeStep(
            key: const ValueKey<String>('night-mood-welcome-step'),
            selectedMood: _selectedMood,
            palette: palette,
            selectedReasons: _selectedReasons.toList(growable: false),
            isSubmitting: _isSubmitting,
            onBack: () => setState(() => _step = NightMoodFlowStep.reasons),
            onEnter: _handleComplete,
          ),
        },
      ),
    );
  }

  Future<void> _handleMoodChanged(NightMood mood) async {
    if (mood == _selectedMood || _isSubmitting) {
      return;
    }
    _triggerHaptic(HapticFeedback.selectionClick);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedMood = mood;
      _selectedReasons = <String>{mood.reasons.first};
    });
  }

  Future<void> _handleSkip() async {
    if (_isSubmitting) {
      return;
    }
    await _runGuarded(widget.onSkip);
  }

  void _toggleReason(String reason) {
    if (_isSubmitting) {
      return;
    }
    setState(() {
      if (_selectedReasons.contains(reason) && _selectedReasons.length > 1) {
        _selectedReasons.remove(reason);
      } else {
        _selectedReasons.add(reason);
      }
    });
  }

  Future<void> _handleComplete() async {
    if (_isSubmitting) {
      return;
    }
    await _runGuarded(() => widget.onComplete(_selectedMood));
  }

  Future<void> _runGuarded(AsyncVoidCallback action) async {
    setState(() => _isSubmitting = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

enum NightMoodFlowStep { select, reasons, welcome }

extension on NightMood {
  String get label {
    return switch (this) {
      NightMood.happy => '开心',
      NightMood.sad => '低落',
      NightMood.calm => '平静',
    };
  }

  String get moodTitle {
    return switch (this) {
      NightMood.happy => '想把这份轻盈带进今晚',
      NightMood.sad => '今晚想被温柔接住',
      NightMood.calm => '已经慢下来，适合进入睡前模式',
    };
  }

  String get reasonPrompt {
    return switch (this) {
      NightMood.happy => '是什么让你今晚感觉不错？',
      NightMood.sad => '什么让你今晚有点累或低落？',
      NightMood.calm => '什么在支撑你此刻的平静？',
    };
  }

  String get welcomeCopy {
    return switch (this) {
      NightMood.happy => '今晚延续这份好状态，帮你更轻松地进入休息节奏。',
      NightMood.sad => '今晚会给你更安静、更柔和的陪伴，让你慢慢缓下来。',
      NightMood.calm => '今晚就顺着这份稳定，慢慢进入睡眠。',
    };
  }

  List<String> get reasons {
    return switch (this) {
      NightMood.happy => const <String>[
        '睡得还不错',
        '今天有小进展',
        '和室友相处舒服',
        '完成了任务',
        '心情轻松',
        '想保持状态',
      ],
      NightMood.sad => const <String>[
        '今天压力有点大',
        '想念某个人',
        '睡眠不足',
        '需要一点安静',
        '事情卡住了',
        '身体有点疲惫',
      ],
      NightMood.calm => const <String>[
        '呼吸很顺',
        '脑子清楚了',
        '宿舍比较安静',
        '想早点休息',
        '节奏放慢了',
        '想稳稳睡一觉',
      ],
    };
  }
}

class _SelectionStep extends StatelessWidget {
  const _SelectionStep({
    super.key,
    required this.selectedMood,
    required this.palette,
    required this.isSubmitting,
    required this.onMoodChanged,
    required this.onNext,
    required this.onSkip,
  });

  final NightMood selectedMood;
  final NightMoodPalette palette;
  final bool isSubmitting;
  final AsyncValueCallback<NightMood> onMoodChanged;
  final VoidCallback onNext;
  final AsyncVoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double mediaTop = MediaQuery.paddingOf(context).top;
        final bool compact = constraints.maxHeight < 720;
        final double topCardHeight = math.min(
          compact ? 430 : 460,
          constraints.maxHeight * (compact ? 0.43 : 0.46),
        );

        return SafeArea(
          top: false,
          child: Column(
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
                width: double.infinity,
                height: topCardHeight,
                padding: EdgeInsets.fromLTRB(24, mediaTop + 18, 24, 20),
                decoration: BoxDecoration(
                  color: palette.welcomeCardColor,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(40),
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    const _FlowProgressIndicator(activeStep: 1),
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 420),
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            return ScaleTransition(
                              scale: Tween<double>(
                                begin: 0.86,
                                end: 1,
                              ).animate(animation),
                              child: child,
                            );
                          },
                      child: MoodAvatar(
                        key: ValueKey<NightMood>(selectedMood),
                        mood: selectedMood,
                        size: compact ? 190 : 280,
                        fillColor: palette.welcomeFaceColor,
                      ),
                    ),
                    SizedBox(height: compact ? 18 : 24),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                  child: Column(
                    children: <Widget>[
                      _MoodSelector(
                        selected: selectedMood,
                        onChanged: onMoodChanged,
                      ),
                      SizedBox(height: compact ? 24 : 32),
                      Text(
                        '今晚你更接近哪一种心情？',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: compact ? 28 : 30,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: compact ? 8 : 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        child: Text(
                          selectedMood.moodTitle,
                          key: ValueKey<NightMood>(selectedMood),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFFB8B8BD),
                          ),
                        ),
                      ),
                      const Spacer(),
                      _BottomActionBar(
                        primaryLabel: '下一步',
                        primaryBackgroundColor: Colors.white,
                        primaryTextColor: Colors.black,
                        onPrimaryPressed: isSubmitting ? null : () => onNext(),
                        padding: EdgeInsets.fromLTRB(
                          24,
                          compact ? 16 : 24,
                          24,
                          compact ? 22 : 30,
                        ),
                        secondaryLabel: 'Skip',
                        onSecondaryPressed: isSubmitting ? null : onSkip,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReasonsStep extends StatelessWidget {
  const _ReasonsStep({
    super.key,
    required this.selectedMood,
    required this.palette,
    required this.selectedReasons,
    required this.isSubmitting,
    required this.onBack,
    required this.onToggleReason,
    required this.onNext,
  });

  final NightMood selectedMood;
  final NightMoodPalette palette;
  final Set<String> selectedReasons;
  final bool isSubmitting;
  final VoidCallback onBack;
  final ValueChanged<String> onToggleReason;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final List<String> reasons = selectedMood.reasons;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const _FlowProgressIndicator(activeStep: 2),
            const SizedBox(height: 70),
            Text(
              selectedMood.reasonPrompt,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 32,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: reasons
                    .map((String reason) {
                      final bool isSelected = selectedReasons.contains(reason);
                      return SizedBox(
                        width: (MediaQuery.sizeOf(context).width - 64) / 2,
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 220),
                          scale: isSelected ? 1 : 0.985,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: isSubmitting
                                  ? null
                                  : () async {
                                      _triggerHaptic(
                                        HapticFeedback.selectionClick,
                                      );
                                      onToggleReason(reason);
                                    },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 260),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 18,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? palette.welcomeAccentColor
                                      : palette.welcomeSurfaceColor,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      reason,
                                      maxLines: 1,
                                      softWrap: false,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isSelected
                                            ? palette.welcomeTextOnAccent
                                            : Colors.white,
                                        fontSize: 16,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: 20),
            _BottomActionBar(
              primaryLabel: '继续',
              primaryBackgroundColor: palette.welcomeAccentColor,
              primaryTextColor: palette.welcomeTextOnAccent,
              onPrimaryPressed: isSubmitting ? null : () => onNext(),
              secondaryLabel: '返回',
              onSecondaryPressed: isSubmitting ? null : () => onBack(),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({
    super.key,
    required this.selectedMood,
    required this.palette,
    required this.selectedReasons,
    required this.isSubmitting,
    required this.onBack,
    required this.onEnter,
  });

  final NightMood selectedMood;
  final NightMoodPalette palette;
  final List<String> selectedReasons;
  final bool isSubmitting;
  final VoidCallback onBack;
  final AsyncVoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final String reasonSummary = '已选择 ${selectedReasons.length} 个今晚感受来源';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
        child: Column(
          children: <Widget>[
            const _FlowProgressIndicator(activeStep: 3),
            const Spacer(),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (BuildContext context, double value, Widget? child) {
                return Transform.translate(
                  offset: Offset(0, 24 * (1 - value)),
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: palette.welcomeCardColor,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Column(
                  children: <Widget>[
                    MoodAvatar(
                      mood: selectedMood,
                      size: 190,
                      fillColor: palette.welcomeFaceColor,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '今晚模式已准备好',
                      style: TextStyle(
                        color: palette.welcomeTextOnAccent,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      selectedMood.welcomeCopy,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.welcomeTextOnAccent.withAlpha(184),
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      reasonSummary,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.welcomeTextOnAccent.withAlpha(235),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            _BottomActionBar(
              primaryLabel: '进入今晚首页',
              primaryBackgroundColor: Colors.white,
              primaryTextColor: Colors.black,
              onPrimaryPressed: isSubmitting ? null : () => onEnter(),
              secondaryLabel: '返回',
              onSecondaryPressed: isSubmitting ? null : () => onBack(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowProgressIndicator extends StatelessWidget {
  const _FlowProgressIndicator({required this.activeStep});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(3, (int index) {
        final bool isActive = index < activeStep;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: index == 2 ? 0 : 8),
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.white.withAlpha(46),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

class _MoodSelector extends StatelessWidget {
  const _MoodSelector({required this.selected, required this.onChanged});

  final NightMood selected;
  final AsyncValueCallback<NightMood> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double gap = constraints.maxWidth < 360 ? 10 : 12;

          return Row(
            children: <Widget>[
              for (
                int index = 0;
                index < NightMood.values.length;
                index++
              ) ...<Widget>[
                Expanded(
                  child: Builder(
                    builder: (BuildContext context) {
                      final NightMood mood = NightMood.values[index];
                      final NightMoodPalette palette =
                          NightMoodPalette.fromMood(mood);
                      final bool isSelected = mood == selected;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => onChanged(mood),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? palette.welcomeAccentColor
                                  : const Color(0xFF2C2C2E),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              mood.label,
                              style: TextStyle(
                                color: isSelected
                                    ? palette.welcomeTextOnAccent
                                    : Colors.white70,
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (index != NightMood.values.length - 1) SizedBox(width: gap),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.primaryLabel,
    required this.primaryBackgroundColor,
    required this.primaryTextColor,
    required this.onPrimaryPressed,
    this.padding = const EdgeInsets.fromLTRB(24, 24, 24, 30),
    this.secondaryLabel,
    this.onSecondaryPressed,
  });

  final String primaryLabel;
  final Color primaryBackgroundColor;
  final Color primaryTextColor;
  final AsyncVoidCallback? onPrimaryPressed;
  final EdgeInsetsGeometry padding;
  final String? secondaryLabel;
  final AsyncVoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 72,
            child: secondaryLabel == null
                ? null
                : TextButton(
                    onPressed: onSecondaryPressed == null
                        ? null
                        : () async {
                            _triggerHaptic(HapticFeedback.lightImpact);
                            await onSecondaryPressed?.call();
                          },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: Text(secondaryLabel!),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 64,
              child: FilledButton(
                onPressed: onPrimaryPressed == null
                    ? null
                    : () async {
                        _triggerHaptic(HapticFeedback.lightImpact);
                        await onPrimaryPressed?.call();
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: primaryBackgroundColor,
                  foregroundColor: primaryTextColor,
                  disabledBackgroundColor: primaryBackgroundColor.withAlpha(
                    140,
                  ),
                  disabledForegroundColor: primaryTextColor.withAlpha(153),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(primaryLabel),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

typedef AsyncVoidCallback = FutureOr<void> Function();
typedef AsyncValueCallback<T> = FutureOr<void> Function(T value);

void _triggerHaptic(Future<void> Function() action) {
  unawaited(action().catchError((Object _) {}));
}
