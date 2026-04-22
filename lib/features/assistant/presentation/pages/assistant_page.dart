import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/core/widgets/mood_avatar.dart';
import 'package:sleep_dorm_app/features/assistant/presentation/controllers/assistant_conversation_controller.dart';

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
  final FocusNode _focusNode = FocusNode();

  late AssistantCaptureTab _selectedTab;
  String? _stagedUserPrompt;
  String? _stagedThreadId;

  bool get _hasDraft => _inputController.text.trim().isNotEmpty;
  bool get _isCaptureMode => widget.captureModeEnabled;

  SleepCaptureType get _activeCaptureType =>
      _selectedTab == AssistantCaptureTab.memo
      ? SleepCaptureType.memo
      : SleepCaptureType.dream;

  Future<void> _showThreadBusyToast() {
    return notifyPassiveToast(context, message: '上一条还在处理中，请稍后再发');
  }

  _CaptureCopy get _copy {
    if (!_isCaptureMode) {
      return const _CaptureCopy(
        title: '安静疗愈空间',
        subtitle: '这里会只保留你此刻最需要看的那条回复。',
        prompt: '你可以先说今晚最在意的一件事。发出消息后，你的话会停在中央，小眠会把回应轻轻托上来。',
        inputHint: '把今晚最在意的一句话交给我',
        footnote: '',
        suggestions: <String>['我现在有点睡不着', '宿舍有点吵', '帮我把脑子里的事放下来'],
      );
    }
    if (_selectedTab == AssistantCaptureTab.memo) {
      return const _CaptureCopy(
        title: '事记收纳',
        subtitle: '先放下待办，今晚只留出一点安静。',
        prompt: '怕睡前想到的事明早忘掉，就先交给我保管。我会把它整理成一条轻量状态，等你需要时再回看。',
        inputHint: '写下你暂时不想一直惦记的事',
        footnote: '会保存到“我的 / 事记仓库”，结束睡眠模式后可以继续整理。',
        suggestions: <String>[
          '明早要给导师发材料，还要记得问室友借充电器',
          '记得把实验数据发给组会同学',
          '明天起床后先回老师消息',
        ],
      );
    }
    return const _CaptureCopy(
      title: '梦记收纳',
      subtitle: '趁画面还没有散掉，先留住最亮的一层。',
      prompt: '不必一次写完整，只要把还记得的人物、颜色、情绪或一句话留下来。我会先帮你温柔收好。',
      inputHint: '把还记得的梦境先轻轻写下来',
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
      await context.appServices.assistantConversationController.bootstrap();
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleComposerStateChanged);
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit(AppServices services, {String? prompt}) async {
    final String normalizedPrompt = (prompt ?? _inputController.text).trim();
    if (normalizedPrompt.isEmpty) {
      _focusNode.requestFocus();
      return;
    }

    final AssistantConversationController controller =
        services.assistantConversationController;
    final AssistantConversationSubmitResult result = _isCaptureMode
        ? await controller.submitCapturePrompt(
            prompt: normalizedPrompt,
            captureType: _activeCaptureType,
          )
        : await controller.submitPrompt(normalizedPrompt);

    switch (result) {
      case AssistantConversationSubmitResult.sent:
        if (mounted) {
          setState(() {
            _inputController.clear();
            _stagedUserPrompt = normalizedPrompt;
            _stagedThreadId = controller.currentThread?.id;
          });
        }
        _focusNode.unfocus();
        break;
      case AssistantConversationSubmitResult.busy:
        await _showThreadBusyToast();
        break;
      case AssistantConversationSubmitResult.missingActiveSession:
        if (!mounted) {
          return;
        }
        await notifyPassiveToast(context, message: '只有在睡眠模式中，才能使用梦记和事记收纳。');
        _focusNode.requestFocus();
        break;
      case AssistantConversationSubmitResult.empty:
        _focusNode.requestFocus();
        break;
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
    if (!context.mounted) {
      return;
    }
    await notifyPassiveToast(context, message: '助手名字已更新');
  }

  Future<void> _retryLatestPrompt(AppServices services) async {
    final AssistantConversationSubmitResult result = await services
        .assistantConversationController
        .retryLatestPrompt(
          captureModeEnabled: _isCaptureMode,
          captureType: _activeCaptureType,
        );
    if (result == AssistantConversationSubmitResult.busy) {
      await _showThreadBusyToast();
      return;
    }
    if (result == AssistantConversationSubmitResult.missingActiveSession) {
      if (!mounted) {
        return;
      }
      await notifyPassiveToast(context, message: '只有在睡眠模式中，才能使用梦记和事记收纳。');
    }
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
    setState(() {
      _inputController.clear();
      _stagedUserPrompt = null;
      _stagedThreadId = null;
    });
    _focusNode.unfocus();
  }

  void _handleComposerStateChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  String _busyComposerHint() {
    if (_isCaptureMode) {
      return _activeCaptureType == SleepCaptureType.dream
          ? '小眠正在轻轻整理这段梦境...'
          : '小眠正在替你安放这段事记...';
    }
    return '小眠正在整理回复...';
  }

  Widget _buildComposer({
    required AppServices services,
    required _AssistantSurfacePalette palette,
  }) {
    final bool isFocused = _focusNode.hasFocus;
    final AssistantThreadTurnState? turnState =
        services.assistantConversationController.turnState;
    final bool isThreadBusy =
        turnState != null && turnState.status != AssistantThreadTurnStatus.idle;
    final bool showSendingIndicator = isThreadBusy;
    final String hintText = isThreadBusy && !_hasDraft
        ? _busyComposerHint()
        : _copy.inputHint;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.chromeSurface,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: isFocused ? palette.focusBorder : palette.chromeBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            _ComposerActionButton(
              icon: Icons.add_rounded,
              palette: palette,
              onPressed: isThreadBusy
                  ? null
                  : () => _startNewConversation(services),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: palette.composerFieldSurface,
                  borderRadius: AppRadius.surfaceSecondary,
                  border: Border.all(
                    color: isFocused
                        ? palette.focusBorder
                        : palette.fieldBorder,
                  ),
                ),
                child: TextField(
                  key: const ValueKey<String>('assistant-composer-field'),
                  controller: _inputController,
                  focusNode: _focusNode,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  onChanged: (_) => setState(() {}),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onDark,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.placeholderText,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            FilledButton(
              onPressed: (isThreadBusy || !_hasDraft)
                  ? null
                  : () => _handleSubmit(services),
              style: FilledButton.styleFrom(
                backgroundColor: palette.sendSurface,
                disabledBackgroundColor: palette.disabledSurface,
                foregroundColor: palette.sendForeground,
                disabledForegroundColor: palette.placeholderText,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.surfaceSecondary,
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: showSendingIndicator
                    ? SizedBox(
                        key: const ValueKey<String>('assistant-composer-busy'),
                        width: AppSpacing.md,
                        height: AppSpacing.md,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.sendForeground,
                        ),
                      )
                    : Text(
                        '发送',
                        key: const ValueKey<String>('assistant-composer-send'),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: palette.sendForeground,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    final _CaptureCopy copy = _copy;
    final double keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final bool keyboardVisible = keyboardInset > 0;
    final double horizontalPadding = MediaQuery.of(context).size.width * 0.06;
    final _AssistantSurfacePalette palette = _AssistantSurfacePalette.from(
      context,
    );

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              palette.backgroundStart,
              palette.backgroundMid,
              palette.backgroundEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge(<Listenable>[
              services.assistantFacade,
              services.assistantConversationController,
            ]),
            builder: (BuildContext context, Widget? child) {
              final AssistantProfile profile =
                  services.assistantFacade.assistantProfile;
              final List<AssistantMessage> messages =
                  services.assistantConversationController.currentMessages;
              final AssistantThreadTurnState? turnState =
                  services.assistantConversationController.turnState;
              final _ConversationSnapshot snapshot =
                  _ConversationSnapshot.fromMessages(messages);
              final String? stagedUserPrompt =
                  services.assistantConversationController.currentThread?.id ==
                      _stagedThreadId
                  ? _stagedUserPrompt
                  : null;
              final bool hasConversation =
                  snapshot.hasConversation || stagedUserPrompt != null;

              return Column(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      AppSpacing.xs,
                      horizontalPadding,
                      AppSpacing.sm,
                    ),
                    child: _HistoryHint(
                      palette: palette,
                      onTap: () => context.push(AppRoutes.assistantHistory),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      AppSpacing.md,
                    ),
                    child: _AssistantHeader(
                      assistantName: profile.assistantName,
                      subtitle: _isCaptureMode
                          ? copy.subtitle
                          : '当前页只展示最新一条回复，历史记录已收起。',
                      captureCopy: copy,
                      captureModeEnabled: _isCaptureMode,
                      palette: palette,
                      onBack: () => Navigator.of(context).maybePop(),
                      onRename: () =>
                          _showRenameDialog(context, services, profile),
                      onNewConversation: () => _startNewConversation(services),
                    ),
                  ),
                  if (_isCaptureMode)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        0,
                        horizontalPadding,
                        AppSpacing.sm,
                      ),
                      child: _CaptureTabSwitcher(
                        selected: _selectedTab,
                        palette: palette,
                        onChanged: (AssistantCaptureTab value) {
                          setState(() => _selectedTab = value);
                        },
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        AppSpacing.sm,
                        horizontalPadding,
                        keyboardVisible ? AppSpacing.sm : AppSpacing.lg,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: hasConversation
                            ? _AssistantCurrentStage(
                                key: const ValueKey<String>(
                                  'assistant-page-current-stage',
                                ),
                                assistantName: profile.assistantName,
                                snapshot: snapshot,
                                stagedUserPrompt: stagedUserPrompt,
                                turnState: turnState,
                                captureModeEnabled: _isCaptureMode,
                                captureType: _activeCaptureType,
                                palette: palette,
                                onRetry:
                                    snapshot.latestAssistantMessage?.status ==
                                        AssistantMessageStatus.error
                                    ? () => _retryLatestPrompt(services)
                                    : null,
                              )
                            : _AssistantEmptyState(
                                key: const ValueKey<String>(
                                  'assistant-empty-stage',
                                ),
                                assistantName: profile.assistantName,
                                copy: copy,
                                palette: palette,
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
                              ),
                      ),
                    ),
                  ),
                  AnimatedPadding(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      keyboardVisible ? 0 : AppSpacing.sm,
                      horizontalPadding,
                      keyboardVisible ? AppSpacing.sm : AppSpacing.lg,
                    ),
                    child: _buildComposer(services: services, palette: palette),
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

class _AssistantHeader extends StatelessWidget {
  const _AssistantHeader({
    required this.assistantName,
    required this.subtitle,
    required this.captureCopy,
    required this.captureModeEnabled,
    required this.palette,
    required this.onBack,
    required this.onRename,
    required this.onNewConversation,
  });

  final String assistantName;
  final String subtitle;
  final _CaptureCopy captureCopy;
  final bool captureModeEnabled;
  final _AssistantSurfacePalette palette;
  final VoidCallback onBack;
  final VoidCallback onRename;
  final VoidCallback onNewConversation;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _ChromeIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          palette: palette,
          onPressed: onBack,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Row(
            children: <Widget>[
              _AssistantIdentityAvatar(
                captureModeEnabled: captureModeEnabled,
                palette: palette,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      captureModeEnabled ? captureCopy.title : assistantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppColors.onDark,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        _ChromeIconButton(
          icon: Icons.edit_outlined,
          palette: palette,
          onPressed: onRename,
        ),
        const SizedBox(width: AppSpacing.xs),
        _ChromeIconButton(
          icon: Icons.add_comment_rounded,
          palette: palette,
          onPressed: onNewConversation,
        ),
      ],
    );
  }
}

class _AssistantIdentityAvatar extends StatelessWidget {
  const _AssistantIdentityAvatar({
    required this.captureModeEnabled,
    required this.palette,
  });

  final bool captureModeEnabled;
  final _AssistantSurfacePalette palette;

  @override
  Widget build(BuildContext context) {
    final NightMood? mood = context.nightMoodPalette.mood;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            palette.avatarGradientStart,
            palette.avatarGradientEnd,
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.avatarGlow,
            blurRadius: AppSpacing.xxl,
            offset: const Offset(0, AppSpacing.xs),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: CircleAvatar(
          radius: AppSpacing.lg,
          backgroundColor: palette.avatarSurface,
          child: captureModeEnabled
              ? Icon(
                  Icons.auto_awesome_rounded,
                  color: palette.avatarForeground,
                )
              : mood == null
              ? Icon(
                  key: const ValueKey<String>('assistant-page-default-avatar'),
                  Icons.auto_awesome_rounded,
                  color: palette.avatarForeground,
                )
              : MoodAvatar(
                  key: const ValueKey<String>('assistant-page-mood-avatar'),
                  mood: mood,
                  size: AppSpacing.xxxl,
                  fillColor: context.nightMoodPalette.welcomeFaceColor,
                ),
        ),
      ),
    );
  }
}

class _HistoryHint extends StatelessWidget {
  const _HistoryHint({required this.palette, required this.onTap});

  final _AssistantSurfacePalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: InkWell(
        key: const ValueKey<String>('assistant-history-hint'),
        borderRadius: AppRadius.pill,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.keyboard_double_arrow_up_rounded,
                size: AppSpacing.md,
                color: palette.mutedText,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '再次上拉查看对话记录',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: palette.mutedText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantEmptyState extends StatelessWidget {
  const _AssistantEmptyState({
    super.key,
    required this.assistantName,
    required this.copy,
    required this.palette,
    required this.onSuggestionTap,
  });

  final String assistantName;
  final _CaptureCopy copy;
  final _AssistantSurfacePalette palette;
  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.94,
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: palette.stageSurface,
                  borderRadius: AppRadius.cardLarge,
                  border: Border.all(color: palette.chromeBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      copy.title.isEmpty
                          ? '先跟 $assistantName 说一句吧'
                          : copy.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppColors.onDark,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      copy.prompt,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: palette.secondaryText,
                        height: 1.6,
                      ),
                    ),
                    if (copy.footnote.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        copy.footnote,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: palette.mutedText),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: copy.suggestions
                    .map(
                      (String label) => _SuggestionChip(
                        label: label,
                        palette: palette,
                        onTap: () => onSuggestionTap(label),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantCurrentStage extends StatelessWidget {
  const _AssistantCurrentStage({
    super.key,
    required this.assistantName,
    required this.snapshot,
    required this.stagedUserPrompt,
    required this.turnState,
    required this.captureModeEnabled,
    required this.captureType,
    required this.palette,
    this.onRetry,
  });

  final String assistantName;
  final _ConversationSnapshot snapshot;
  final String? stagedUserPrompt;
  final AssistantThreadTurnState? turnState;
  final bool captureModeEnabled;
  final SleepCaptureType captureType;
  final _AssistantSurfacePalette palette;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final AssistantMessage? latestUser = snapshot.latestUserMessage;
    final AssistantMessage? latestAssistant = snapshot.latestAssistantMessage;
    final String? currentUserText = latestUser?.content ?? stagedUserPrompt;
    final List<_AssistantStatusItem> statusItems = _buildStatusItems(
      assistantMessage: latestAssistant,
      turnState: turnState,
      captureModeEnabled: captureModeEnabled,
      captureType: captureType,
    );

    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.94,
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (currentUserText != null)
                Container(
                  key: const ValueKey<String>('assistant-current-user-message'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: palette.userBubbleSurface,
                    borderRadius: AppRadius.surfacePrimary,
                    border: Border.all(color: palette.userBubbleBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '你刚刚说',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: palette.mutedText),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        currentUserText,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.onDark,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              if (currentUserText != null)
                const SizedBox(height: AppSpacing.xl),
              Container(
                key: const ValueKey<String>(
                  'assistant-current-assistant-message',
                ),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.card,
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: <Color>[palette.assistantGlow, Colors.transparent],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      assistantName,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: palette.mutedText,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      latestAssistant?.content.trim().isNotEmpty == true
                          ? latestAssistant!.content
                          : '小眠正在整理这一条回应...',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.onDark,
                        height: 1.7,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (statusItems.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  key: const ValueKey<String>('assistant-current-status-list'),
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  children: statusItems
                      .map(
                        (_AssistantStatusItem item) =>
                            _AssistantStatusLine(item: item, palette: palette),
                      )
                      .toList(growable: false),
                ),
              ],
              if (latestAssistant?.status == AssistantMessageStatus.error &&
                  latestAssistant?.errorMessage?.trim().isNotEmpty ==
                      true) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  latestAssistant!.errorMessage!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.mutedText,
                    height: 1.5,
                  ),
                ),
              ],
              if (latestAssistant?.status == AssistantMessageStatus.error &&
                  onRetry != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                TextButton.icon(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: palette.retryColor,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: AppSpacing.md),
                  label: const Text('重试这条回复'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantStatusLine extends StatelessWidget {
  const _AssistantStatusLine({required this.item, required this.palette});

  final _AssistantStatusItem item;
  final _AssistantSurfacePalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(item.icon, size: AppSpacing.md, color: palette.statusText),
        const SizedBox(width: AppSpacing.xs),
        Text(
          item.label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: palette.statusText),
        ),
      ],
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final _AssistantSurfacePalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.pill,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.suggestionSurface,
          borderRadius: AppRadius.pill,
          border: Border.all(color: palette.suggestionBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.onDark),
          ),
        ),
      ),
    );
  }
}

class _ChromeIconButton extends StatelessWidget {
  const _ChromeIconButton({
    required this.icon,
    required this.palette,
    required this.onPressed,
  });

  final IconData icon;
  final _AssistantSurfacePalette palette;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.actionSurface,
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.onDark),
      ),
    );
  }
}

class _ComposerActionButton extends StatelessWidget {
  const _ComposerActionButton({
    required this.icon,
    required this.palette,
    this.onPressed,
  });

  final IconData icon;
  final _AssistantSurfacePalette palette;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.surfaceSecondary,
      onTap: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.actionSurface,
          borderRadius: AppRadius.surfaceSecondary,
          border: Border.all(color: palette.fieldBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(icon, color: AppColors.onDark),
        ),
      ),
    );
  }
}

class _CaptureTabSwitcher extends StatelessWidget {
  const _CaptureTabSwitcher({
    required this.selected,
    required this.palette,
    required this.onChanged,
  });

  final AssistantCaptureTab selected;
  final _AssistantSurfacePalette palette;
  final ValueChanged<AssistantCaptureTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: palette.stageSurface,
        borderRadius: AppRadius.pill,
        border: Border.all(color: palette.chromeBorder),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _CaptureTabChip(
              label: '梦记',
              selected: selected == AssistantCaptureTab.dream,
              palette: palette,
              onTap: () => onChanged(AssistantCaptureTab.dream),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _CaptureTabChip(
              label: '事记',
              selected: selected == AssistantCaptureTab.memo,
              palette: palette,
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
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final _AssistantSurfacePalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.pill,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? palette.sendSurface : Colors.transparent,
          borderRadius: AppRadius.pill,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? palette.sendForeground : palette.secondaryText,
          ),
        ),
      ),
    );
  }
}

class _ConversationSnapshot {
  const _ConversationSnapshot({
    required this.latestUserMessage,
    required this.latestAssistantMessage,
    required this.messageCount,
  });

  final AssistantMessage? latestUserMessage;
  final AssistantMessage? latestAssistantMessage;
  final int messageCount;

  bool get hasConversation =>
      latestUserMessage != null || latestAssistantMessage != null;

  static _ConversationSnapshot fromMessages(List<AssistantMessage> messages) {
    AssistantMessage? latestUser;
    AssistantMessage? latestAssistant;
    for (final AssistantMessage message in messages.reversed) {
      if (latestUser == null && message.role == AssistantMessageRole.user) {
        latestUser = message;
      }
      if (latestAssistant == null &&
          message.role == AssistantMessageRole.assistant) {
        latestAssistant = message;
      }
      if (latestUser != null && latestAssistant != null) {
        break;
      }
    }
    return _ConversationSnapshot(
      latestUserMessage: latestUser,
      latestAssistantMessage: latestAssistant,
      messageCount: messages.length,
    );
  }
}

class _AssistantStatusItem {
  const _AssistantStatusItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

List<_AssistantStatusItem> _buildStatusItems({
  required AssistantMessage? assistantMessage,
  required AssistantThreadTurnState? turnState,
  required bool captureModeEnabled,
  required SleepCaptureType captureType,
}) {
  final List<_AssistantStatusItem> items = <_AssistantStatusItem>[];
  final bool isBusy =
      turnState != null && turnState.status != AssistantThreadTurnStatus.idle;

  if (captureModeEnabled &&
      assistantMessage != null &&
      assistantMessage.status != AssistantMessageStatus.error &&
      !isBusy) {
    items.add(
      _AssistantStatusItem(
        icon: captureType == SleepCaptureType.dream
            ? Icons.bedtime_rounded
            : Icons.bookmark_added_rounded,
        label: captureType == SleepCaptureType.dream ? '梦记已收纳' : '事记已收纳',
      ),
    );
  }

  if (isBusy || assistantMessage?.status == AssistantMessageStatus.pending) {
    items.add(
      _AssistantStatusItem(
        icon: Icons.hourglass_top_rounded,
        label: captureModeEnabled
            ? (captureType == SleepCaptureType.dream ? '正在整理梦记' : '正在整理事记')
            : '正在整理回复',
      ),
    );
    return items;
  }

  switch (assistantMessage?.sourceMode) {
    case AssistantReplySourceMode.remoteSuccess:
      items.add(
        const _AssistantStatusItem(
          icon: Icons.wifi_tethering_rounded,
          label: '联网回复已完成',
        ),
      );
    case AssistantReplySourceMode.fallbackSuccess:
      items.add(
        const _AssistantStatusItem(
          icon: Icons.auto_awesome_rounded,
          label: '备用回复已完成',
        ),
      );
    case AssistantReplySourceMode.error:
      items.add(
        const _AssistantStatusItem(
          icon: Icons.error_outline_rounded,
          label: '这次回复失败',
        ),
      );
    case null:
      if (assistantMessage != null) {
        items.add(
          const _AssistantStatusItem(
            icon: Icons.check_circle_outline_rounded,
            label: '陪伴回复已就绪',
          ),
        );
      }
  }

  return items;
}

class _AssistantSurfacePalette {
  const _AssistantSurfacePalette({
    required this.backgroundStart,
    required this.backgroundMid,
    required this.backgroundEnd,
    required this.chromeSurface,
    required this.chromeBorder,
    required this.fieldBorder,
    required this.focusBorder,
    required this.stageSurface,
    required this.userBubbleSurface,
    required this.userBubbleBorder,
    required this.assistantGlow,
    required this.actionSurface,
    required this.composerFieldSurface,
    required this.suggestionSurface,
    required this.suggestionBorder,
    required this.sendSurface,
    required this.sendForeground,
    required this.disabledSurface,
    required this.avatarGradientStart,
    required this.avatarGradientEnd,
    required this.avatarSurface,
    required this.avatarForeground,
    required this.avatarGlow,
    required this.secondaryText,
    required this.mutedText,
    required this.placeholderText,
    required this.statusText,
    required this.retryColor,
  });

  final Color backgroundStart;
  final Color backgroundMid;
  final Color backgroundEnd;
  final Color chromeSurface;
  final Color chromeBorder;
  final Color fieldBorder;
  final Color focusBorder;
  final Color stageSurface;
  final Color userBubbleSurface;
  final Color userBubbleBorder;
  final Color assistantGlow;
  final Color actionSurface;
  final Color composerFieldSurface;
  final Color suggestionSurface;
  final Color suggestionBorder;
  final Color sendSurface;
  final Color sendForeground;
  final Color disabledSurface;
  final Color avatarGradientStart;
  final Color avatarGradientEnd;
  final Color avatarSurface;
  final Color avatarForeground;
  final Color avatarGlow;
  final Color secondaryText;
  final Color mutedText;
  final Color placeholderText;
  final Color statusText;
  final Color retryColor;

  static _AssistantSurfacePalette from(BuildContext context) {
    final NightMoodPalette mood = context.nightMoodPalette;
    return _AssistantSurfacePalette(
      backgroundStart: Color.lerp(
        AppColors.darkBackground,
        mood.heroGradientStart,
        0.55,
      )!,
      backgroundMid: Color.lerp(
        AppColors.darkBackground,
        mood.heroGradientMid,
        0.38,
      )!,
      backgroundEnd: Color.lerp(
        AppColors.darkBackground,
        mood.heroGradientEnd,
        0.2,
      )!,
      chromeSurface: Color.lerp(
        AppColors.darkSurface,
        mood.welcomeSurfaceColor,
        0.5,
      )!,
      chromeBorder: mood.primarySoft.withAlpha(44),
      fieldBorder: mood.primarySoft.withAlpha(34),
      focusBorder: mood.primarySoft.withAlpha(88),
      stageSurface: Color.lerp(
        AppColors.darkSurface,
        mood.welcomeSurfaceColor,
        0.62,
      )!,
      userBubbleSurface: Color.lerp(
        mood.welcomeSurfaceColor,
        mood.heroGradientMid,
        0.32,
      )!,
      userBubbleBorder: mood.primarySoft.withAlpha(52),
      assistantGlow: mood.primarySoft.withAlpha(28),
      actionSurface: Color.lerp(
        AppColors.darkSurface,
        mood.welcomeSurfaceColor,
        0.46,
      )!,
      composerFieldSurface: Color.lerp(
        AppColors.darkSurface,
        mood.welcomeSurfaceColor,
        0.28,
      )!,
      suggestionSurface: Color.lerp(
        AppColors.darkSurface,
        mood.welcomeSurfaceColor,
        0.36,
      )!,
      suggestionBorder: mood.primarySoft.withAlpha(34),
      sendSurface: mood.welcomeAccentColor,
      sendForeground: mood.welcomeTextOnAccent,
      disabledSurface: mood.primaryDeep.withAlpha(120),
      avatarGradientStart: mood.moonGradientStart,
      avatarGradientEnd: mood.moonGradientEnd,
      avatarSurface: mood.welcomeCardColor.withAlpha(242),
      avatarForeground: mood.primaryDeep,
      avatarGlow: mood.primarySoft.withAlpha(24),
      secondaryText: AppColors.onDark.withAlpha(196),
      mutedText: AppColors.onDark.withAlpha(136),
      placeholderText: AppColors.onDark.withAlpha(112),
      statusText: AppColors.onDark.withAlpha(144),
      retryColor: mood.primarySoft,
    );
  }
}
