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
  int _lastRenderedMessageCount = 0;

  bool get _hasDraft => _inputController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleComposerStateChanged);
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
    _focusNode.removeListener(_handleComposerStateChanged);
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit(AppServices services, {String? prompt}) async {
    final String normalizedPrompt = (prompt ?? _inputController.text).trim();
    if (normalizedPrompt.isEmpty || _isSending) {
      _focusNode.requestFocus();
      return;
    }
    setState(() {
      _isSending = true;
      if (prompt == null) {
        _inputController.clear();
      }
    });
    _focusNode.unfocus();
    _scrollToBottom();
    try {
      await services.assistantFacade.sendPrompt(normalizedPrompt);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    AppServices services,
    AssistantProfile profile,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final TextEditingController controller = TextEditingController(
      text: profile.assistantName,
    );
    final String? nextName = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('修改助手名字'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 12,
            decoration: const InputDecoration(hintText: '例如：小眠、阿眠、今晚陪伴官'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (nextName == null || nextName.trim().isEmpty) {
      return;
    }
    await services.assistantFacade.updateAssistantProfileName(nextName.trim());
    if (!mounted) {
      return;
    }
    messenger.showSnackBar(const SnackBar(content: Text('助手名字已更新')));
  }

  void _showVoiceHint() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('语音输入即将上线')));
  }

  Future<void> _retryLatestPrompt(AppServices services) async {
    final AssistantThread? thread = services.assistantFacade.currentThread;
    if (thread == null) {
      return;
    }
    final List<AssistantMessage> messages =
        services.assistantFacade.currentMessages;
    final AssistantMessage latestUserMessage = messages.lastWhere(
      (AssistantMessage item) => item.role == AssistantMessageRole.user,
      orElse: () => AssistantMessage(
        id: '',
        threadId: '',
        role: AssistantMessageRole.system,
        content: '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    if (latestUserMessage.id.isEmpty ||
        latestUserMessage.content.trim().isEmpty) {
      return;
    }
    await _handleSubmit(services, prompt: latestUserMessage.content);
  }

  Future<void> _startNewConversation(AppServices services) async {
    await services.assistantFacade.createThread(title: '新对话');
    if (!mounted) {
      return;
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _handleComposerStateChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Widget _buildComposer(AppServices services) {
    final bool isFocused = _focusNode.hasFocus;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0A111D).withAlpha(242),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isFocused ? const Color(0xFF3E5E86) : const Color(0xFF1A2740),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            _InputActionButton(
              icon: Icons.add_rounded,
              onPressed: () => _startNewConversation(services),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF111A2B),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isFocused
                        ? const Color(0xFF5D7BA2)
                        : const Color(0xFF22314C),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        key: const ValueKey<String>('assistant-composer-field'),
                        controller: _inputController,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 4,
                        enabled: !_isSending,
                        textInputAction: TextInputAction.newline,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          color: AppColors.onDark,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: '说一说吧',
                          hintStyle: TextStyle(
                            color: AppColors.onDark.withAlpha(125),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    if (!_hasDraft && !_isSending) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        onPressed: _showVoiceHint,
                        icon: const Icon(
                          Icons.mic_none_rounded,
                          color: Color(0xFF8FA6C7),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(
              onPressed: (_isSending || !_hasDraft)
                  ? null
                  : () => _handleSubmit(services),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4E8DF7),
                disabledBackgroundColor: const Color(0xFF26364F),
                foregroundColor: Colors.white,
                minimumSize: const Size(74, 46),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
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
                  : const Text('发送'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    final double keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final bool keyboardVisible = keyboardInset > 0;
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF0B1220),
              Color(0xFF111B30),
              Color(0xFF090F18),
            ],
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: services.assistantFacade,
            builder: (BuildContext context, Widget? child) {
              final AssistantProfile profile =
                  services.assistantFacade.assistantProfile;
              final List<AssistantMessage> messages =
                  services.assistantFacade.currentMessages;
              if (_lastRenderedMessageCount != messages.length) {
                _lastRenderedMessageCount = messages.length;
                _scrollToBottom();
              }

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
                                profile.assistantName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: AppColors.onDark,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        _CircleActionButton(
                          icon: Icons.edit_outlined,
                          onPressed: () =>
                              _showRenameDialog(context, services, profile),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _CircleActionButton(
                          icon: Icons.add_rounded,
                          onPressed: () => _startNewConversation(services),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _CircleActionButton(
                          icon: Icons.history_rounded,
                          onPressed: () =>
                              context.push(AppRoutes.assistantHistory),
                        ),
                      ],
                    ),
                  ),
                  if (!keyboardVisible) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: _AssistantHero(profile: profile),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  Expanded(
                    child: ListView(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        keyboardVisible ? AppSpacing.sm : AppSpacing.lg,
                      ),
                      children: <Widget>[
                        if (messages.isEmpty)
                          _AssistantEmptyState(
                            assistantName: profile.assistantName,
                            onSuggestionTap: (String suggestion) {
                              setState(() {
                                _inputController.text = suggestion;
                                _inputController.selection =
                                    TextSelection.collapsed(
                                      offset: suggestion.length,
                                    );
                              });
                              _focusNode.requestFocus();
                            },
                          )
                        else
                          ...messages.map(
                            (AssistantMessage message) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              child: _MessageBubble(
                                message: message,
                                assistantName: profile.assistantName,
                                onRetry:
                                    message.status ==
                                        AssistantMessageStatus.error
                                    ? () => _retryLatestPrompt(services)
                                    : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  AnimatedPadding(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      keyboardVisible ? 0 : AppSpacing.sm,
                      AppSpacing.lg,
                      keyboardVisible ? AppSpacing.sm : AppSpacing.lg,
                    ),
                    child: _buildComposer(services),
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

class _AssistantHero extends StatelessWidget {
  const _AssistantHero({required this.profile});

  final AssistantProfile profile;

  @override
  Widget build(BuildContext context) {
    final NightMood? mood = context.nightMoodPalette.mood;
    return AppCard(
      color: const Color(0xFF10192A),
      border: Border.all(color: const Color(0xFF24334E)),
      child: Row(
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  const Color(0xFF7BC4FF),
                  context.nightMoodPalette.primarySoft,
                ],
              ),
            ),
            alignment: Alignment.center,
            child: mood == null
                ? const Icon(
                    key: ValueKey<String>('assistant-page-default-avatar'),
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF16334E),
                    size: 30,
                  )
                : MoodAvatar(
                    key: const ValueKey<String>('assistant-page-mood-avatar'),
                    mood: mood,
                    size: 48,
                    fillColor: context.nightMoodPalette.welcomeFaceColor,
                  ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${profile.assistantName}会记住你的节奏',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.onDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '温和、低压、不评判。你可以直接说困意、心情、宿舍状态，或者只是想被陪一会儿。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onDark.withAlpha(180),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({required this.icon, required this.onPressed});

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

class _InputActionButton extends StatelessWidget {
  const _InputActionButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFF141F31),
          border: Border.all(color: const Color(0xFF25344F)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: const Color(0xFFB5C8E6), size: 20),
      ),
    );
  }
}

class _AssistantEmptyState extends StatelessWidget {
  const _AssistantEmptyState({
    required this.assistantName,
    required this.onSuggestionTap,
  });

  final String assistantName;
  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    const List<String> suggestions = <String>[
      '我现在有点睡不着',
      '宿舍有点吵',
      '帮我看看今晚该怎么放松',
    ];
    return AppCard(
      color: const Color(0xFF10192A),
      border: Border.all(color: const Color(0xFF24334E)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '先跟 $assistantName 说一句吧',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.onDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '你可以直接说今天的心情、困意、梦境，或者宿舍里正在发生什么。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.onDark.withAlpha(180),
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: suggestions
                .map(
                  (String label) => InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => onSuggestionTap(label),
                    child: Container(
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
                          color: AppColors.onDark.withAlpha(220),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.assistantName,
    this.onRetry,
  });

  final AssistantMessage message;
  final String assistantName;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.role == AssistantMessageRole.user;
    final Color bubbleColor = isUser
        ? const Color(0xFF6AA8FF)
        : message.status == AssistantMessageStatus.error
        ? const Color(0xFF41212C)
        : message.status == AssistantMessageStatus.pending
        ? const Color(0xFF162234)
        : const Color(0xFF10192A);
    final Color textColor = isUser ? Colors.white : AppColors.onDark;
    final String? statusLabel = _statusLabel(message);
    final String? statusDescription = _statusDescription(message);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 328),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(22),
              topRight: const Radius.circular(22),
              bottomLeft: Radius.circular(isUser ? 22 : 8),
              bottomRight: Radius.circular(isUser ? 8 : 22),
            ),
            border: isUser ? null : Border.all(color: const Color(0xFF24334E)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (!isUser)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      assistantName,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: textColor.withAlpha(170),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Text(
                  message.content,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Text(
                      _formatTime(message.createdAt),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: textColor.withAlpha(150),
                      ),
                    ),
                    if (statusLabel != null) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        statusLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: textColor.withAlpha(180),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                if (statusDescription != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    statusDescription,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: textColor.withAlpha(150),
                      height: 1.45,
                    ),
                  ),
                ],
                if (message.status == AssistantMessageStatus.error &&
                    onRetry != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFFC7D1),
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('重试'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _statusLabel(AssistantMessage message) {
    if (message.status == AssistantMessageStatus.pending) {
      return '生成中';
    }
    return switch (message.sourceMode) {
      AssistantReplySourceMode.remoteSuccess => '联网回复',
      AssistantReplySourceMode.fallbackSuccess => '回退回复',
      AssistantReplySourceMode.error => '回复失败',
      _ => null,
    };
  }

  String? _statusDescription(AssistantMessage message) {
    return switch (message.sourceMode) {
      AssistantReplySourceMode.fallbackSuccess =>
        message.errorMessage?.trim().isNotEmpty == true
            ? '远端模型未成功返回：${message.errorMessage}'
            : '远端模型未成功返回，本次使用了稳定回退回复。',
      AssistantReplySourceMode.error =>
        message.errorMessage?.trim().isNotEmpty == true
            ? '这次没有拿到有效回复：${message.errorMessage}'
            : '这次没有拿到有效回复，可以直接重试上一条消息。',
      _ => null,
    };
  }

  /*
  String? _statusLabel(AssistantMessage message) {
    if (message.status == AssistantMessageStatus.pending) {
      return '整理中';
    }
    return switch (message.sourceMode) {
      AssistantReplySourceMode.fallbackSuccess => '本地陪伴',
      AssistantReplySourceMode.error => '回复失败',
      _ => null,
    };
  }
  */
}

String _formatTime(DateTime time) {
  final String hour = time.hour.toString().padLeft(2, '0');
  final String minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
