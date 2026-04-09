import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/mood_avatar.dart';

enum AssistantCaptureTab { dream, memo }

class AssistantPage extends StatefulWidget {
  const AssistantPage({
    super.key,
    this.captureModeEnabled = false,
    this.initialCaptureTab = AssistantCaptureTab.dream,
  });

  final bool captureModeEnabled;
  final AssistantCaptureTab initialCaptureTab;

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final List<_ConversationEntry> _entries = <_ConversationEntry>[];
  late AssistantCaptureTab _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialCaptureTab;
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submitPrompt() async {
    final String draft = _inputController.text.trim();
    if (draft.isEmpty) {
      _inputFocusNode.requestFocus();
      return;
    }

    final AppServices services = context.appServices;
    final List<_ConversationEntry> nextEntries = <_ConversationEntry>[
      ..._entries,
      _ConversationEntry(text: draft, isUser: true),
    ];

    if (widget.captureModeEnabled) {
      final SleepSession? session = services.sleepSessionRepository.activeSession;
      if (session == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('只有在睡眠模式中，才能使用梦记和事记收纳。')),
          );
        }
        return;
      }

      final SleepCaptureType type = _selectedTab == AssistantCaptureTab.dream
          ? SleepCaptureType.dream
          : SleepCaptureType.memo;
      final SleepCaptureRecord record = await services.sleepCaptureRepository
          .addRecord(type: type, sessionId: session.id, content: draft);
      nextEntries.add(
        _ConversationEntry(
          text: _selectedTab == AssistantCaptureTab.dream
              ? '我轻轻帮你收好了这段梦境。稍后可以去“我的 / 梦境记录”里继续回看，刚整理出的提要是：${record.outline}'
              : '这段事记已经替你收进“我的 / 事记仓库”。结束睡眠模式后，首页也会短暂提醒你回看：${record.outline}',
        ),
      );
    } else {
      nextEntries.add(
        const _ConversationEntry(
          text: '我收到啦。你可以继续告诉我现在的感受，或者让我帮你把它拆成更容易执行的小步骤。',
        ),
      );
    }

    setState(() {
      _entries
        ..clear()
        ..addAll(nextEntries);
      _inputController.clear();
    });
    _inputFocusNode.unfocus();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets mediaPadding = MediaQuery.paddingOf(context);
    final TextTheme textTheme = Theme.of(context).textTheme;
    final _CaptureCopy copy = _copyForCurrentMode();

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: <Widget>[
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
          Column(
            children: <Widget>[
              Container(
                padding: EdgeInsets.only(top: mediaPadding.top + 16),
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          _TopCircleButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                          _TopCircleButton(
                            icon: widget.captureModeEnabled
                                ? Icons.nightlight_round
                                : Icons.history_rounded,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const _FloatingAIAvatar(),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      copy.title,
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium?.copyWith(
                        color: AppColors.onDark,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      copy.subtitle,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppColors.onDark.withValues(alpha: 0.62),
                      ),
                    ),
                    if (widget.captureModeEnabled) ...<Widget>[
                      const SizedBox(height: AppSpacing.lg),
                      _CaptureTabSwitcher(
                        selected: _selectedTab,
                        onChanged: (AssistantCaptureTab value) {
                          setState(() {
                            _selectedTab = value;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xxl,
                  ),
                  children: <Widget>[
                    _AssistantMessageBubble(text: copy.prompt),
                    if (widget.captureModeEnabled) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      _CaptureFootnote(text: copy.footnote),
                    ],
                    if (_entries.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xl),
                      ..._entries.expand<Widget>((_ConversationEntry entry) {
                        return <Widget>[
                          entry.isUser
                              ? _UserMessageBubble(text: entry.text)
                              : _AssistantMessageBubble(text: entry.text),
                          const SizedBox(height: AppSpacing.lg),
                        ];
                      }),
                    ],
                  ],
                ),
              ),
              _FloatInputPanel(
                controller: _inputController,
                focusNode: _inputFocusNode,
                onSubmit: _submitPrompt,
                bottomPadding: mediaPadding.bottom > 0
                    ? mediaPadding.bottom + 12
                    : AppSpacing.xl,
                hintText: copy.inputHint,
              ),
            ],
          ),
        ],
      ),
    );
  }

  _CaptureCopy _copyForCurrentMode() {
    if (!widget.captureModeEnabled) {
      return const _CaptureCopy(
        title: '现在想聊些什么？',
        subtitle: '我会陪你慢慢放松，也可以帮你把脑海里的念头整理清楚。',
        prompt: '如果你愿意，可以先告诉我今晚最在意的一件事，我会顺着你的节奏陪你说下去。',
        inputHint: '轻轻写下你现在的感受...',
        footnote: '',
      );
    }

    return switch (_selectedTab) {
      AssistantCaptureTab.dream => const _CaptureCopy(
        title: '把梦先轻轻记下来',
        subtitle: '不用一次写完整，先把还记得的画面、人物、颜色或一句话留住就好。',
        prompt: '如果刚醒来还模糊，可以先从“我看到什么”“我当时什么感觉”“有没有一句特别清楚的话”开始写，我会帮你把梦记轻轻收好。',
        inputHint: '例如：我梦见自己站在很高的桥上，风很冷，但并不害怕...',
        footnote: '会保存到“我的 / 梦境记录”。',
      ),
      AssistantCaptureTab.memo => const _CaptureCopy(
        title: '把事也先安放下来',
        subtitle: '怕睡前突然想到的事明早忘掉，就先在这里交给我保管。',
        prompt: '你可以写下明天要做的事、突然想到的人名任务，或者一句不想忘记的话。我会先帮你整理成简短提要，让你今晚不用一直惦记着它。',
        inputHint: '例如：明早要给导师发材料，还要记得问室友借充电器...',
        footnote:
            '会保存到“我的 / 事记仓库”；结束睡眠模式后，首页会短暂提醒你回看。',
      ),
    };
  }
}

class _ConversationEntry {
  const _ConversationEntry({required this.text, this.isUser = false});

  final String text;
  final bool isUser;
}

class _CaptureCopy {
  const _CaptureCopy({
    required this.title,
    required this.subtitle,
    required this.prompt,
    required this.inputHint,
    required this.footnote,
  });

  final String title;
  final String subtitle;
  final String prompt;
  final String inputHint;
  final String footnote;
}

class _CaptureTabSwitcher extends StatelessWidget {
  const _CaptureTabSwitcher({
    required this.selected,
    required this.onChanged,
  });

  final AssistantCaptureTab selected;
  final ValueChanged<AssistantCaptureTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.darkSurface.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _TabChip(
            label: '梦记',
            selected: selected == AssistantCaptureTab.dream,
            onTap: () => onChanged(AssistantCaptureTab.dream),
          ),
          _TabChip(
            label: '事记',
            selected: selected == AssistantCaptureTab.memo,
            onTap: () => onChanged(AssistantCaptureTab.memo),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        gradient: selected
            ? const LinearGradient(
                colors: <Color>[AppColors.calmBlue, AppColors.primaryDeep],
              )
            : null,
        color: selected ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected
                    ? Colors.white
                    : AppColors.onDark.withValues(alpha: 0.72),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptureFootnote extends StatelessWidget {
  const _CaptureFootnote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.onDark.withValues(alpha: 0.56),
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
    final NightMoodPalette palette = context.nightMoodPalette;
    final double size = math
        .min(MediaQuery.sizeOf(context).width * 0.42, 220.0)
        .clamp(160.0, 220.0);

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double bobbingOffset =
              math.sin(_controller.value * math.pi * 2) * 6.0;
          final double pulse = _controller.value;
          final double innerPulse = math.sin(pulse * math.pi);

          return Transform.translate(
            offset: Offset(0, -bobbingOffset),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Container(
                  width: size * (0.75 + pulse * 0.25),
                  height: size * (0.75 + pulse * 0.25),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: palette.primarySoft.withValues(
                          alpha: 0.08 + pulse * 0.06,
                        ),
                        blurRadius: size * 0.4 + (pulse * 25),
                        spreadRadius: pulse * 12,
                      ),
                    ],
                  ),
                ),
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
                          palette.primarySoft.withValues(alpha: 0.15),
                          palette.calmBlue.withValues(alpha: 0.05),
                        ],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: palette.primarySoft.withValues(alpha: 0.1),
                          blurRadius: size * 0.2,
                        ),
                      ],
                    ),
                  ),
                ),
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
                      color: palette.primarySoft.withValues(
                        alpha: 0.2 + pulse * 0.15,
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
                              shadows: <Shadow>[
                                Shadow(
                                  color: palette.primarySoft,
                                  blurRadius: 15 + (pulse * 10),
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
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.onDark.withValues(alpha: 0.9),
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
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white,
            height: 1.4,
            fontWeight: FontWeight.w500,
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
    required this.hintText,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Future<void> Function() onSubmit;
  final double bottomPadding;
  final String hintText;

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
            color: Color(0x33000000),
            border: Border(top: BorderSide(color: AppColors.darkBorder)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.darkSurface.withValues(alpha: 0.5),
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
                      hintText: hintText,
                      hintStyle: textTheme.bodyLarge?.copyWith(
                        color: AppColors.onDark.withValues(alpha: 0.3),
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
        color: AppColors.darkSurface.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Icon(
            icon,
            color: AppColors.onDark.withValues(alpha: 0.8),
            size: 20,
          ),
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
