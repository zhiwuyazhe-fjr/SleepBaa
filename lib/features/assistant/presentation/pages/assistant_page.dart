import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';

class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  String? _latestPrompt;

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
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
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets mediaPadding = MediaQuery.paddingOf(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          const double initialSheetSize = 0.58;
          final double frameWidth = constraints.maxWidth > 440
              ? 390
              : constraints.maxWidth;
          final double panelTop =
              constraints.maxHeight * (1 - initialSheetSize);
          final double foxSize = math
              .min(frameWidth * 0.46, constraints.maxHeight * 0.28)
              .clamp(160.0, 220.0)
              .toDouble();
          final double foxTop = panelTop - (foxSize * 0.40);
          final double safeTop = mediaPadding.top + 14;

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0xFFFFA23A),
                  Color(0xFF8CC77E),
                  Color(0xFF0A9A95),
                ],
              ),
            ),
            child: Stack(
              children: <Widget>[
                const Positioned(
                  left: -110,
                  top: 120,
                  child: _GlowOrb(size: 280, color: Color(0x40FFD54F)),
                ),
                const Positioned(
                  right: -130,
                  top: 250,
                  child: _GlowOrb(size: 320, color: Color(0x33E8F5E9)),
                ),
                const Positioned(
                  right: -90,
                  bottom: 120,
                  child: _GlowOrb(size: 260, color: Color(0x3326C6DA)),
                ),
                Center(
                  child: SizedBox(
                    width: frameWidth,
                    height: constraints.maxHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Positioned(
                          top: safeTop,
                          left: AppSpacing.lg,
                          child: _TopCircleButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: () => Navigator.of(context).maybePop(),
                            dark: false,
                          ),
                        ),
                        Positioned(
                          top: safeTop,
                          right: AppSpacing.lg,
                          child: const _TopCircleButton(
                            icon: Icons.auto_awesome_rounded,
                            onTap: _noop,
                            dark: true,
                          ),
                        ),
                        Positioned(
                          top: foxTop + 8,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: _FoxLikeCompanion(size: foxSize),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: panelTop - 8,
                          child: const _FoxPaws(),
                        ),
                        Positioned(
                          top: foxTop - 18,
                          right: 22,
                          child: const _SpeechBubble(),
                        ),
                        Positioned(
                          top: foxTop + 64,
                          right: 108,
                          child: const _ThoughtBubble(size: 12, alpha: 220),
                        ),
                        Positioned(
                          top: foxTop + 84,
                          right: 126,
                          child: const _ThoughtBubble(size: 8, alpha: 170),
                        ),
                      ],
                    ),
                  ),
                ),
                DraggableScrollableSheet(
                  initialChildSize: initialSheetSize,
                  minChildSize: 0.52,
                  maxChildSize: 0.9,
                  snap: true,
                  snapSizes: const <double>[0.58, 0.78, 0.9],
                  builder:
                      (
                        BuildContext context,
                        ScrollController scrollController,
                      ) {
                        return _GlassPanel(
                          scrollController: scrollController,
                          inputController: _inputController,
                          inputFocusNode: _inputFocusNode,
                          latestPrompt: _latestPrompt,
                          onSubmit: _submitPrompt,
                          bottomPadding: mediaPadding.bottom > 0
                              ? mediaPadding.bottom + 8
                              : AppSpacing.lg,
                        );
                      },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

void _noop() {}

class _TopCircleButton extends StatelessWidget {
  const _TopCircleButton({
    required this.icon,
    required this.onTap,
    required this.dark,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dark ? const Color(0xFF1E2024) : const Color(0x29FFFFFF),
            border: Border.all(
              color: dark ? const Color(0x1AFFFFFF) : const Color(0x55FFFFFF),
            ),
            boxShadow: dark
                ? const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ]
                : const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 14,
                      offset: Offset(0, 8),
                    ),
                  ],
          ),
          child: Icon(icon, color: Colors.white, size: dark ? 24 : 20),
        ),
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 178),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: const Color(0xF4F6FAE7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x66FFFFFF)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Text(
          'Tell me what kept\nyou awake tonight.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFF2B3240),
            height: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ThoughtBubble extends StatelessWidget {
  const _ThoughtBubble({required this.size, required this.alpha});

  final double size;
  final int alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.fromARGB(alpha, 246, 250, 231),
      ),
    );
  }
}

class _FoxLikeCompanion extends StatelessWidget {
  const _FoxLikeCompanion({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.94,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            top: 0,
            left: size * 0.18,
            child: const _FoxEar(left: true),
          ),
          Positioned(
            top: 0,
            right: size * 0.18,
            child: const _FoxEar(left: false),
          ),
          Positioned.fill(
            top: size * 0.12,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-0.18, -0.35),
                  radius: 0.92,
                  colors: <Color>[
                    Color(0xFFFFC15D),
                    Color(0xFFFD8A2B),
                    Color(0xFFE26515),
                  ],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 24,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    top: size * 0.16,
                    left: size * 0.18,
                    child: Container(
                      width: size * 0.20,
                      height: size * 0.14,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0x1AFFFFFF),
                      ),
                    ),
                  ),
                  Positioned(
                    left: size * 0.18,
                    right: size * 0.18,
                    bottom: size * 0.12,
                    child: Container(
                      height: size * 0.36,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFDF4E8),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(90),
                          bottom: Radius.circular(64),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: size * 0.22,
                    bottom: size * 0.16,
                    child: Container(
                      width: size * 0.18,
                      height: size * 0.18,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                  ),
                  Positioned(
                    right: size * 0.22,
                    bottom: size * 0.16,
                    child: Container(
                      width: size * 0.18,
                      height: size * 0.18,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                  ),
                  Positioned(
                    top: size * 0.42,
                    left: size * 0.31,
                    child: const _FoxEye(),
                  ),
                  Positioned(
                    top: size * 0.42,
                    right: size * 0.31,
                    child: const _FoxEye(),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: size * 0.22,
                    child: Center(
                      child: Container(
                        width: size * 0.08,
                        height: size * 0.08,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A211A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoxEar extends StatelessWidget {
  const _FoxEar({required this.left});

  final bool left;

  @override
  Widget build(BuildContext context) {
    final BorderRadius outerRadius = BorderRadius.only(
      topLeft: Radius.circular(left ? 42 : 10),
      topRight: Radius.circular(left ? 10 : 42),
      bottomLeft: const Radius.circular(10),
      bottomRight: const Radius.circular(10),
    );

    final BorderRadius innerRadius = BorderRadius.only(
      topLeft: Radius.circular(left ? 26 : 8),
      topRight: Radius.circular(left ? 8 : 26),
      bottomLeft: const Radius.circular(8),
      bottomRight: const Radius.circular(8),
    );

    return Transform.rotate(
      angle: left ? -0.38 : 0.38,
      child: SizedBox(
        width: 58,
        height: 72,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xFFFFB347), Color(0xFFE16B18)],
                ),
                borderRadius: outerRadius,
              ),
            ),
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              bottom: 14,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD0A7),
                  borderRadius: innerRadius,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoxEye extends StatelessWidget {
  const _FoxEye();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 22,
      child: Stack(
        children: <Widget>[
          const Positioned(left: 5, top: 3, child: _EyePupil()),
          Positioned(
            left: 14,
            top: 0,
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EyePupil extends StatelessWidget {
  const _EyePupil();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 13,
      height: 13,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF261A11),
      ),
    );
  }
}

class _FoxPaws extends StatelessWidget {
  const _FoxPaws();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const <Widget>[_FoxPaw(), SizedBox(width: 24), _FoxPaw()],
      ),
    );
  }
}

class _FoxPaw extends StatelessWidget {
  const _FoxPaw();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 40,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          Container(
            width: 54,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF4902D),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              width: 34,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFFF9F0E5),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.scrollController,
    required this.inputController,
    required this.inputFocusNode,
    required this.latestPrompt,
    required this.onSubmit,
    required this.bottomPadding,
  });

  final ScrollController scrollController;
  final TextEditingController inputController;
  final FocusNode inputFocusNode;
  final String? latestPrompt;
  final VoidCallback onSubmit;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(48)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x33FFFFFF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(48)),
            border: const Border(top: BorderSide(color: Color(0x66FFFFFF))),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x19000000),
                blurRadius: 36,
                offset: Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 88,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0x66FFFFFF),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl,
                    AppSpacing.sm,
                    AppSpacing.xxl,
                    AppSpacing.xl,
                  ),
                  children: <Widget>[
                    Text(
                      'Tonight felt a bit noisy,\nlet’s sort it out slowly.',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontSize: 24,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        shadows: const <Shadow>[
                          Shadow(
                            color: Color(0x22000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: const Color(0x1AFFFFFF),
                        borderRadius: AppRadius.card,
                        border: Border.all(color: const Color(0x3DFFFFFF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Recent suggestion',
                            style: textTheme.labelMedium?.copyWith(
                              color: Colors.white.withAlpha(210),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Try 15 minutes of breathing before switching on sleep mode.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (latestPrompt != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: const Color(0xF2FFFFFF),
                          borderRadius: AppRadius.card,
                          border: Border.all(color: const Color(0x4DFFFFFF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '已记录你的输入',
                              style: textTheme.labelMedium?.copyWith(
                                color: const Color(0xFF475266),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              latestPrompt!,
                              style: textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF2B3240),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _InputComposer(
                controller: inputController,
                focusNode: inputFocusNode,
                onSubmit: onSubmit,
                bottomPadding: bottomPadding,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputComposer extends StatelessWidget {
  const _InputComposer({
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
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        bottomPadding,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(22),
        border: const Border(top: BorderSide(color: Color(0x33FFFFFF))),
      ),
      child: Column(
        children: <Widget>[
          TextField(
            controller: controller,
            focusNode: focusNode,
            minLines: 1,
            maxLines: 3,
            style: textTheme.bodyMedium?.copyWith(color: Colors.white),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              hintText: '输入今晚最打扰你的事…',
              hintStyle: textTheme.bodyMedium?.copyWith(
                color: Colors.white.withAlpha(170),
              ),
              filled: true,
              fillColor: const Color(0x1FFFFFFF),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              border: OutlineInputBorder(
                borderRadius: AppRadius.card,
                borderSide: const BorderSide(color: Color(0x45FFFFFF)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.card,
                borderSide: const BorderSide(color: Color(0x45FFFFFF)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.card,
                borderSide: const BorderSide(color: Color(0x88FFFFFF)),
              ),
            ),
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              const _KeyboardGlassButton(),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[Color(0xFFFF700A), Color(0xFFFFAD4A)],
                    ),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x38FF700A),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: onSubmit,
                      child: Center(
                        child: Text(
                          '说完了',
                          style: textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeyboardGlassButton extends StatelessWidget {
  const _KeyboardGlassButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0x22FFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x44FFFFFF)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(Icons.keyboard_rounded, color: Colors.white, size: 24),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(color: color, blurRadius: 120, spreadRadius: 20),
          ],
        ),
      ),
    );
  }
}
