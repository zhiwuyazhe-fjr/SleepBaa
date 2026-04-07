import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/mood_avatar.dart';

class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      await context.appServices.assistantFacade.selectMostRecentThread();
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit(AppServices services) async {
    final String prompt = _inputController.text.trim();
    if (prompt.isEmpty || _isSending) {
      _focusNode.requestFocus();
      return;
    }
    setState(() {
      _isSending = true;
      _inputController.clear();
    });
    _focusNode.unfocus();
    _scrollToBottom();
    try {
      await services.assistantFacade.sendPrompt(prompt);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _startNewConversation(AppServices services) async {
    await services.assistantFacade.createThread(title: '新对话');
    if (mounted) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF0E1624), Color(0xFF080C14)],
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: services.assistantFacade,
            builder: (BuildContext context, Widget? child) {
              final AssistantThread? currentThread =
                  services.assistantFacade.currentThread;
              final List<AssistantMessage> messages =
                  services.assistantFacade.currentMessages;
              return Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    child: Row(
                      children: <Widget>[
                        _CircleActionButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                currentThread?.title ?? 'AI 助手',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: AppColors.onDark,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentThread == null
                                    ? '开始一段新的睡前对话'
                                    : '历史会话和新建对话都在右上角',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppColors.onDark.withValues(
                                        alpha: 0.66,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        _CircleActionButton(
                          icon: Icons.add_rounded,
                          onPressed: () => _startNewConversation(services),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _CircleActionButton(
                          icon: Icons.history_rounded,
                          onPressed: () => context.push(AppRoutes.assistantHistory),
                        ),
                      ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _AssistantHeroAvatar(
                      mood: context.nightMoodPalette.mood,
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      children: <Widget>[
                        if (messages.isEmpty)
                          const _AssistantEmptyState()
                        else
                          ...messages.map(
                            (AssistantMessage message) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              child: _MessageBubble(message: message),
                            ),
                          ),
                        if (_isSending)
                          const Padding(
                            padding: EdgeInsets.only(top: AppSpacing.sm),
                            child: _TypingBubble(),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: AppCard(
                      color: const Color(0xFF111927),
                      border: Border.all(
                        color: const Color(0xFF223047),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: _inputController,
                              focusNode: _focusNode,
                              minLines: 1,
                              maxLines: 5,
                              style: const TextStyle(color: AppColors.onDark),
                              onSubmitted: (_) => _handleSubmit(services),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: '输入你现在的状态、困意、宿舍情况或想聊的内容',
                                hintStyle: TextStyle(
                                  color: AppColors.onDark.withValues(alpha: 0.46),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          FilledButton(
                            onPressed: _isSending
                                ? null
                                : () => _handleSubmit(services),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF6AA8FF),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(54, 54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: _isSending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                          ),
                        ],
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

class _AssistantHeroAvatar extends StatelessWidget {
  const _AssistantHeroAvatar({required this.mood});

  final NightMood? mood;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF101827),
        border: Border.all(color: const Color(0xFF223047)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: mood == null
          ? const Icon(
              Icons.auto_awesome_rounded,
              key: ValueKey<String>('assistant-page-default-avatar'),
              color: Color(0xFFA9C5F8),
              size: 34,
            )
          : MoodAvatar(
              key: const ValueKey<String>('assistant-page-mood-avatar'),
              mood: mood!,
              size: 54,
              fillColor: context.nightMoodPalette.welcomeFaceColor,
            ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF121B2A),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.onDark),
      ),
    );
  }
}

class _AssistantEmptyState extends StatelessWidget {
  const _AssistantEmptyState();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: const Color(0xFF111927),
      border: Border.all(color: const Color(0xFF223047)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '今晚想先从哪件事开始聊？',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.onDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '你可以直接说睡不着、宿舍太吵、今天心情不好，或者让 AI 帮你总结今晚计划。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.onDark.withValues(alpha: 0.72),
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: const <Widget>[
              _SuggestionChip(label: '我现在有点睡不着'),
              _SuggestionChip(label: '宿舍有点吵'),
              _SuggestionChip(label: '帮我看看今晚计划'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF172235),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF26354F)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.onDark.withValues(alpha: 0.82),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final AssistantMessage message;

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.role == AssistantMessageRole.user;
    final Color bubbleColor = isUser
        ? const Color(0xFF6AA8FF)
        : message.status == AssistantMessageStatus.error
        ? const Color(0xFF4B2430)
        : const Color(0xFF111927);
    final Color textColor = isUser ? Colors.white : AppColors.onDark;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(22),
              topRight: const Radius.circular(22),
              bottomLeft: Radius.circular(isUser ? 22 : 8),
              bottomRight: Radius.circular(isUser ? 8 : 22),
            ),
            border: isUser
                ? null
                : Border.all(color: const Color(0xFF223047)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  message.content,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatTime(message.createdAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: textColor.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF111927),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF223047)),
        ),
        child: const SizedBox(
          width: 32,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _Dot(),
              _Dot(),
              _Dot(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: Color(0xFFA9C5F8),
        shape: BoxShape.circle,
      ),
    );
  }
}

String _formatTime(DateTime time) {
  final String hour = time.hour.toString().padLeft(2, '0');
  final String minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
