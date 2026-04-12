import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
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
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isSending = false;
  int _lastRenderedMessageCount = 0;
  late AssistantCaptureTab _selectedTab;

  bool get _hasDraft => _inputController.text.trim().isNotEmpty;
  bool get _isCaptureMode => widget.captureModeEnabled;

  SleepCaptureType get _activeCaptureType =>
      _selectedTab == AssistantCaptureTab.memo
      ? SleepCaptureType.memo
      : SleepCaptureType.dream;

  _CaptureCopy get _copy {
    if (!_isCaptureMode) {
      return const _CaptureCopy(
        title: '现在想聊些什么？',
        subtitle: '我会陪你慢慢放松，也可以帮你把脑海里的念头整理清楚。',
        prompt: '如果你愿意，可以先告诉我今晚最在意的一件事，我会顺着你的节奏陪你说下去。',
        inputHint: '说一说吧',
        footnote: '',
        suggestions: <String>[
          '我现在有点睡不着',
          '宿舍有点吵',
          '帮我看看今晚该怎么放松',
        ],
      );
    }
    if (_selectedTab == AssistantCaptureTab.memo) {
      return const _CaptureCopy(
        title: '把事也先安放下来',
        subtitle: '怕睡前突然想到的事明早忘掉，就先在这里交给我保管。',
        prompt:
            '你可以写下明天要做的事、突然想到的人名任务，或者一句不想忘记的话。我会先帮你整理成简短提要，让你今晚不用一直惦记着它。',
        inputHint: '例如：明早要给导师发材料，还要记得问室友借充电器...',
        footnote: '会保存到“我的 / 事记仓库”；结束睡眠模式后，首页会短暂提醒你回看。',
        suggestions: <String>[
          '明早要给导师发材料，还要记得问室友借充电器',
          '记得把实验数据发给组会同学',
          '明天起床后先回老师消息',
        ],
      );
    }
    return const _CaptureCopy(
      title: '把梦先轻轻记下来',
      subtitle: '不用一次写完整，先把还记得的画面、人物、颜色或一句话留住就好。',
      prompt:
          '如果刚醒来还模糊，可以先从“我看到什么”“我当时什么感觉”“有没有一句特别清楚的话”开始写，我会帮你把梦记轻轻收好。',
      inputHint: '例如：我梦见自己站在很高的桥上，风很冷，但并不害怕...',
      footnote: '会保存到“我的 / 梦境记录”。',
      suggestions: <String>[
        '我梦见自己站在很高的桥上，风很冷，但并不害怕',
        '梦里一直在找教室，可怎么也走不到',
        '我只记得一片很亮的蓝色，还有一句重复的话',
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialCaptureTab;
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

    final String? activeSessionId =
        services.sleepSessionRepository.activeSession?.id;
    if (_isCaptureMode && (activeSessionId == null || activeSessionId.isEmpty)) {
      await notifyPassiveToast(context, message: '只有在睡眠模式中，才能使用梦记和事记收纳。');
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
      if (_isCaptureMode) {
        await services.assistantFacade.sendCapturePrompt(
          prompt: normalizedPrompt,
          captureType: _activeCaptureType,
          sessionId: activeSessionId!,
        );
      } else {
        await services.assistantFacade.sendPrompt(normalizedPrompt);
      }
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
            decoration: const InputDecoration(
              hintText: '例如：小眠、阿眠、今晚陪伴官',
            ),
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
    if (!context.mounted) {
      return;
    }
    await notifyPassiveToast(context, message: '助手名字已更新');
  }

  void _showVoiceHint() {
    notifyPassiveToast(context, message: '语音输入即将上线');
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
    await services.assistantFacade.createThread(
      title: _isCaptureMode
          ? (_activeCaptureType == SleepCaptureType.dream ? '梦记收纳' : '事记收纳')
          : '新对话',
    );
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
    final _CaptureCopy copy = _copy;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0A111D).withAlpha(242),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isFocused ? const Color(0xFF3E5E86) : const Color(0xFF1A2740),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
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
                          hintText: copy.inputHint,
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
    final _CaptureCopy copy = _copy;

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
                                _isCaptureMode ? copy.title : profile.assistantName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: AppColors.onDark,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              Text(
                                _isCaptureMode ? copy.subtitle : '线程记忆已开启',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppColors.onDark.withAlpha(170),
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
                  if (_isCaptureMode)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.md,
                      ),
                      child: _CaptureTabSwitcher(
                        selected: _selectedTab,
                        onChanged: (AssistantCaptureTab value) {
                          setState(() => _selectedTab = value);
                        },
                      ),
                    ),
                  if (!keyboardVisible) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: _AssistantHero(
                        profile: profile,
                        copy: copy,
                        captureModeEnabled: _isCaptureMode,
                      ),
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
                            copy: copy,
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
                                onRetry: message.status ==
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

class _CaptureCopy {
  const _CaptureCopy({
    required this.title,
    required this.subtitle,
    required this.prompt,
    required this.inputHint,
    required this.footnote,
    required this.suggestions,
  });

  final String title;
  final String subtitle;
  final String prompt;
  final String inputHint;
  final String footnote;
  final List<String> suggestions;
}

class _AssistantHero extends StatelessWidget {
  const _AssistantHero({
    required this.profile,
    required this.copy,
    required this.captureModeEnabled,
  });

  final AssistantProfile profile;
  final _CaptureCopy copy;
  final bool captureModeEnabled;

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
                  captureModeEnabled
                      ? copy.title
                      : '${profile.assistantName}会记住你的节奏',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.onDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  captureModeEnabled
                      ? copy.subtitle
                      : '温和、低压、不评判。你可以直接说困意、心情、宿舍状态，或者只是想被陪一会儿。',
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF10192A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF24334E)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _CaptureTabChip(
              label: '梦记',
              selected: selected == AssistantCaptureTab.dream,
              onTap: () => onChanged(AssistantCaptureTab.dream),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _CaptureTabChip(
              label: '事记',
              selected: selected == AssistantCaptureTab.memo,
              onTap: () => onChanged(AssistantCaptureTab.memo),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureTabChip extends StatelessWidget {
  const _CaptureTabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4E8DF7) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? Colors.white : AppColors.onDark.withAlpha(190),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _AssistantEmptyState extends StatelessWidget {
  const _AssistantEmptyState({
    required this.assistantName,
    required this.copy,
    required this.onSuggestionTap,
  });

  final String assistantName;
  final _CaptureCopy copy;
  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: const Color(0xFF10192A),
      border: Border.all(color: const Color(0xFF24334E)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            copy.title.isEmpty ? '先跟 $assistantName 说一句吧' : copy.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.onDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            copy.prompt,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.onDark.withAlpha(180),
              height: 1.5,
            ),
          ),
          if (copy.footnote.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              copy.footnote,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.onDark.withAlpha(160),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: copy.suggestions
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
}

String _formatTime(DateTime time) {
  final String hour = time.hour.toString().padLeft(2, '0');
  final String minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
