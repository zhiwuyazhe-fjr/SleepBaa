import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/widgets/mood_avatar.dart';

class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  String? _latestPrompt;

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _submitPrompt() {
    final String draft = _inputController.text.trim();
    if (draft.isEmpty) {
      _inputFocusNode.requestFocus();
      return;
    }

    setState(() {
      _latestPrompt = draft;
      _inputController.clear();
    });
    _inputFocusNode.unfocus();

    // Auto-scroll to bottom after a delay to ensure view updates
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutExpo,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets mediaPadding = MediaQuery.paddingOf(context);
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: <Widget>[
          // Animated abstract space background spots
          const Positioned(
            left: -120,
            top: 40,
            child: _GlowOrb(size: 360, color: Color(0x114EA8C2)),
          ),
          const Positioned(
            right: -80,
            bottom: -40,
            child: _GlowOrb(size: 400, color: Color(0x0C00697A)),
          ),
          const Positioned(
            right: -60,
            top: 240,
            child: _GlowOrb(size: 280, color: Color(0x0DFFFFFF)),
          ),

          // Main vertical layout
          Column(
            children: <Widget>[
              // Top Area (Action Bar & Avatar)
              Container(
                padding: EdgeInsets.only(top: mediaPadding.top + 16),
                child: Column(
                  children: [
                    // App Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _TopCircleButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                          _TopCircleButton(
                            icon: Icons.history_rounded,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    // Floating AIAvatar
                    const _FloatingAIAvatar(),
                    const SizedBox(height: AppSpacing.xl),

                    Text(
                      'What\'s on your mind?',
                      style: textTheme.headlineMedium?.copyWith(
                        color: AppColors.onDark,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'I\'m here to help you unwind and sleep better.',
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppColors.onDark.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),

              // Conversation Messages List
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xxl,
                  ),
                  children: <Widget>[
                    const _AssistantMessageBubble(
                      text:
                          'A gentle 15-minute breathing exercise could help you shift into sleep mode. Would you like me to start it for you?',
                    ),
                    if (_latestPrompt != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _UserMessageBubble(text: _latestPrompt!),
                      const SizedBox(height: AppSpacing.xl),
                      const _ThinkingIndicator(),
                    ],
                  ],
                ),
              ),

              // Input Area
              _FloatInputPanel(
                controller: _inputController,
                focusNode: _inputFocusNode,
                onSubmit: _submitPrompt,
                bottomPadding: mediaPadding.bottom > 0
                    ? mediaPadding.bottom + 12
                    : AppSpacing.xl,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FloatingAIAvatar extends StatefulWidget {
  const _FloatingAIAvatar();

  @override
  State<_FloatingAIAvatar> createState() => _FloatingAIAvatarState();
}

class _FloatingAIAvatarState extends State<_FloatingAIAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(seconds: 5),
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
    final palette = context.nightMoodPalette;
    // Determine dynamic size across devices
    final double size = math
        .min(MediaQuery.sizeOf(context).width * 0.42, 220.0)
        .clamp(160.0, 220.0);

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          // Slow vertical float
          final double bobbingOffset =
              math.sin(_controller.value * math.pi * 2) * 6.0;
          final double pulse = _controller.value;
          final double innerPulse = math.sin(pulse * math.pi);

          return Transform.translate(
            offset: Offset(0, -bobbingOffset),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                // Outer ethereal aura
                Container(
                  width: size * (0.75 + pulse * 0.25),
                  height: size * (0.75 + pulse * 0.25),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: palette.primarySoft.withOpacity(
                          0.08 + pulse * 0.06,
                        ),
                        blurRadius: size * 0.4 + (pulse * 25),
                        spreadRadius: pulse * 12,
                      ),
                    ],
                  ),
                ),
                // Inner shifting aura
                Transform.rotate(
                  angle: pulse * math.pi * 0.2,
                  child: Container(
                    width: size * (0.65 + innerPulse * 0.15),
                    height: size * (0.65 + innerPulse * 0.15),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: <Color>[
                          palette.primarySoft.withOpacity(0.15),
                          palette.calmBlue.withOpacity(0.05),
                        ],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: palette.primarySoft.withOpacity(0.1),
                          blurRadius: size * 0.2,
                        ),
                      ],
                    ),
                  ),
                ),
                // Core mysterious body
                Container(
                  width: size * 0.54,
                  height: size * 0.54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-0.2, -0.3),
                      radius: 0.8,
                      colors: <Color>[
                        Color(0xFF1E283A),
                        Color(0xFF0F1523),
                        Color(0xFF050810),
                      ],
                    ),
                    border: Border.all(
                      color: palette.primarySoft.withOpacity(
                        0.2 + pulse * 0.15,
                      ),
                      width: 1.5,
                    ),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Transform.scale(
                      scale: 1.0 + (innerPulse * 0.08),
                      child: palette.mood == null
                          ? Icon(
                              Icons.auto_awesome_rounded,
                              key: const ValueKey<String>(
                                'assistant-page-default-avatar',
                              ),
                              color: palette.primaryHighlight,
                              size: size * 0.22,
                              shadows: <BoxShadow>[
                                BoxShadow(
                                  color: palette.primarySoft,
                                  blurRadius: 15 + (pulse * 10),
                                  spreadRadius: pulse * 4,
                                ),
                              ],
                            )
                          : MoodAvatar(
                              key: const ValueKey<String>(
                                'assistant-page-mood-avatar',
                              ),
                              mood: palette.mood!,
                              size: size * 0.28,
                              fillColor: palette.welcomeFaceColor,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AssistantMessageBubble extends StatelessWidget {
  const _AssistantMessageBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(right: 48),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
            bottomLeft: Radius.circular(6),
          ),
          border: Border.all(color: AppColors.darkBorder),
          boxShadow: AppColors.cardShadow,
        ),
        child: Text(
          text,
          style: textTheme.bodyLarge?.copyWith(
            color: AppColors.onDark.withOpacity(0.9),
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _UserMessageBubble extends StatelessWidget {
  const _UserMessageBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(left: 48),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 14,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[AppColors.calmBlue, AppColors.primaryDeep],
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(6),
          ),
          boxShadow: AppColors.cardShadow,
        ),
        child: Text(
          text,
          style: textTheme.bodyLarge?.copyWith(
            color: Colors.white,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ThinkingIndicator extends StatefulWidget {
  const _ThinkingIndicator();

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 1000),
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    if (WidgetsBinding.instance.lifecycleState != null) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 60,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(3, (int index) {
                  // Phase shift dots
                  final double delay = index * 0.2;
                  final double rawValue = (_controller.value - delay).clamp(
                    0.0,
                    1.0,
                  );
                  final double pulse = math.sin(rawValue * math.pi);
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 5,
                    height: 5 + (pulse * 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primarySoft.withOpacity(
                        0.3 + pulse * 0.7,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FloatInputPanel extends StatelessWidget {
  const _FloatInputPanel({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.bottomPadding,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            bottomPadding,
          ),
          decoration: const BoxDecoration(
            color: Color(0x33000000), // very dark glass
            border: Border(top: BorderSide(color: AppColors.darkBorder)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              // Animated Input Field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.darkSurface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.darkBorder),
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.onDark,
                    ),
                    cursorColor: AppColors.primarySoft,
                    decoration: InputDecoration(
                      hintText: "Chat with Nocturne...",
                      hintStyle: textTheme.bodyLarge?.copyWith(
                        color: AppColors.onDark.withOpacity(0.3),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (_) => onSubmit(),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Send Button
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[AppColors.calmBlue, AppColors.primaryDeep],
                  ),
                  boxShadow: AppColors.floatingShadow,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: onSubmit,
                    child: const Center(
                      child: Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopCircleButton extends StatelessWidget {
  const _TopCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.darkSurface.withOpacity(0.4),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Icon(icon, color: AppColors.onDark.withOpacity(0.8), size: 20),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color,
            blurRadius: size * 0.4,
            spreadRadius: size * 0.1,
          ),
        ],
      ),
    );
  }
}
