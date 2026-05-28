import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/app_typography.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_detail_page_header.dart';
import 'package:sleep_dorm_app/core/widgets/app_settings_group.dart';
import 'package:sleep_dorm_app/core/widgets/modals/app_modal.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';

class DormRulesPage extends StatefulWidget {
  const DormRulesPage({super.key, this.showReviewOverlayOnOpen = false});

  final bool showReviewOverlayOnOpen;

  @override
  State<DormRulesPage> createState() => _DormRulesPageState();
}

enum _DormRulesInlineEditor { summer, winter, ventilationDuration }

enum _DormRulesDisplayGroup { basic, lightQuiet, routine, temperature }

class _DormRulesPageState extends State<DormRulesPage> {
  final TextEditingController _quietStartController = TextEditingController();
  final TextEditingController _quietEndController = TextEditingController();
  final TextEditingController _lightsOffController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _personalLightingController =
      TextEditingController();
  final TextEditingController _alarmResponseController =
      TextEditingController();
  final TextEditingController _routineNoteController = TextEditingController();
  final TextEditingController _objectionReasonController =
      TextEditingController();

  bool _initialized = false;
  bool _showReviewOverlay = false;
  bool _isEditing = false;
  bool _examWeekMode = true;
  bool _blackoutCurtain = true;
  bool _vibrationFirst = true;
  double _summerTemp = 26;
  double _winterTemp = 22;
  double _ventilationMinutes = 30;
  String _selectedVentilationWindow = '早晨';
  List<String> _routineTags = const <String>['考试周', '夜猫子', '早起党'];
  _DormRulesInlineEditor? _expandedInlineEditor;
  _DormRulesDisplayGroup? _expandedDisplayGroup;
  String _loadedProposalId = '';
  String _loadedSettingsSignature = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Dorm dorm = context.appServices.dormRepository.currentDorm;
    _syncDraftFromDorm(dorm);
    if (widget.showReviewOverlayOnOpen &&
        _canCurrentUserReviewProposal(dorm) &&
        !_showReviewOverlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _showReviewOverlay = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _quietStartController.dispose();
    _quietEndController.dispose();
    _lightsOffController.dispose();
    _noteController.dispose();
    _personalLightingController.dispose();
    _alarmResponseController.dispose();
    _routineNoteController.dispose();
    _objectionReasonController.dispose();
    super.dispose();
  }

  void _syncDraftFromDorm(Dorm dorm) {
    final String proposalId = dorm.pendingRuleProposal?.id ?? '';
    final String settingsSignature = _settingsSignature(dorm.rulesSettings);
    final bool shouldRefreshDraft =
        !_initialized ||
        (!_isEditing &&
            (proposalId != _loadedProposalId ||
                settingsSignature != _loadedSettingsSignature));
    if (shouldRefreshDraft) {
      _populateFromSettings(dorm.rulesSettings);
      _loadedProposalId = proposalId;
      _loadedSettingsSignature = settingsSignature;
    }
    _initialized = true;
  }

  void _populateFromSettings(DormRulesSettings settings) {
    final ({String start, String end}) parsed = _splitQuietHours(
      settings.quietHours,
    );
    _quietStartController.text = parsed.start;
    _quietEndController.text = parsed.end;
    _lightsOffController.text = _compactRuleCopy(settings.lightsOffTime);
    _noteController.text = settings.specialCase;
    _personalLightingController.text = settings.personalLighting;
    _alarmResponseController.text = settings.alarmResponseSeconds.toString();
    _routineNoteController.text = settings.routineNote;
    _examWeekMode = settings.examWeekMode;
    _blackoutCurtain = settings.blackoutCurtain;
    _vibrationFirst = settings.vibrationFirst;
    _summerTemp = settings.summerTempC;
    _winterTemp = settings.winterTempC;
    _ventilationMinutes = settings.ventilationMinutes;
    _selectedVentilationWindow = settings.ventilationWindow;
    _routineTags = settings.routineTags.isEmpty
        ? DormRulesSettings.defaults().routineTags
        : settings.routineTags;
  }

  bool _canCurrentUserReviewProposal(Dorm dorm) {
    final DormPendingRuleProposal? proposal = dorm.pendingRuleProposal;
    final String currentUserId =
        context.appServices.authRepository.currentUser.uid;
    return proposal != null &&
        proposal.proposerUid != currentUserId &&
        proposal.needsReviewFrom(currentUserId);
  }

  void _enterEditMode() {
    setState(() {
      _isEditing = true;
      _showReviewOverlay = false;
    });
  }

  void _cancelEditing(DormRulesSettings settings) {
    FocusScope.of(context).unfocus();
    _populateFromSettings(settings);
    setState(() {
      _isEditing = false;
      _expandedInlineEditor = null;
    });
  }

  Future<void> _showTextEditor({
    required String title,
    required TextEditingController targetController,
    String? description,
    String? hintText,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? suffixText,
    Key? sheetKey,
  }) async {
    final TextEditingController controller = TextEditingController(
      text: targetController.text,
    );
    await showAppModal<void>(
      context,
      spec: AppRichActionSheetSpec<void>(
        builder: (BuildContext sheetContext) {
          return AppRichActionSheetScaffold(
            surfaceKey:
                sheetKey ?? const ValueKey<String>('dorm-rules-editor-sheet'),
            title: title,
            description: description,
            footer: Row(
              children: <Widget>[
                Expanded(
                  child: PrimaryButton(
                    label: '取消',
                    variant: PrimaryButtonVariant.ghost,
                    size: PrimaryButtonSize.compact,
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: PrimaryButton(
                    label: '确定',
                    size: PrimaryButtonSize.compact,
                    onPressed: () {
                      setState(() {
                        targetController.text = controller.text.trim();
                      });
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: keyboardType,
              maxLines: maxLines,
              decoration: InputDecoration(
                hintText: hintText,
                suffixText: suffixText,
              ),
            ),
          );
        },
      ),
    );
    controller.dispose();
  }

  Future<void> _showQuietHoursEditor() async {
    final TextEditingController startController = TextEditingController(
      text: _quietStartController.text,
    );
    final TextEditingController endController = TextEditingController(
      text: _quietEndController.text,
    );
    await showAppModal<void>(
      context,
      spec: AppRichActionSheetSpec<void>(
        builder: (BuildContext sheetContext) {
          return AppRichActionSheetScaffold(
            title: '安静时段',
            description: '设置需要保持安静的开始和结束时间。',
            footer: Row(
              children: <Widget>[
                Expanded(
                  child: PrimaryButton(
                    label: '取消',
                    variant: PrimaryButtonVariant.ghost,
                    size: PrimaryButtonSize.compact,
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: PrimaryButton(
                    label: '确定',
                    size: PrimaryButtonSize.compact,
                    onPressed: () {
                      setState(() {
                        _quietStartController.text = startController.text
                            .trim();
                        _quietEndController.text = endController.text.trim();
                      });
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _DormRulesSheetTextField(
                  label: '开始',
                  controller: startController,
                  hintText: '23:00',
                  keyboardType: TextInputType.datetime,
                ),
                const SizedBox(height: AppSpacing.sm),
                _DormRulesSheetTextField(
                  label: '结束',
                  controller: endController,
                  hintText: '07:00',
                  keyboardType: TextInputType.datetime,
                ),
              ],
            ),
          );
        },
      ),
    );
    startController.dispose();
    endController.dispose();
  }

  Future<void> _showLightsOffEditor() {
    return _showTextEditor(
      title: '熄灯提醒',
      description: '填写室友确认后的熄灯约定。',
      hintText: '例如 23:30 后关闭主灯',
      targetController: _lightsOffController,
      sheetKey: const ValueKey<String>('dorm-rules-lights-sheet'),
    );
  }

  Future<void> _showSingleChoiceEditor({
    required String title,
    required List<String> options,
    required String selectedValue,
    required ValueChanged<String> onSelected,
  }) async {
    final String? selected = await showAppModal<String>(
      context,
      spec: AppSelectionSheetSpec<String>(
        title: title,
        selectedValue: selectedValue,
        options: options
            .map(
              (String option) =>
                  AppSelectionOption<String>(value: option, label: option),
            )
            .toList(growable: false),
      ),
    );
    if (selected != null) {
      setState(() => onSelected(selected));
    }
  }

  Future<void> _showRoutineTagsEditor() async {
    List<String> draftTags = _routineTags;
    await showAppModal<void>(
      context,
      spec: AppRichActionSheetSpec<void>(
        builder: (BuildContext sheetContext) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setSheetState) {
              return AppRichActionSheetScaffold(
                title: '作息标签',
                footer: Row(
                  children: <Widget>[
                    Expanded(
                      child: PrimaryButton(
                        label: '取消',
                        variant: PrimaryButtonVariant.ghost,
                        size: PrimaryButtonSize.compact,
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: PrimaryButton(
                        label: '确定',
                        size: PrimaryButtonSize.compact,
                        onPressed: () {
                          setState(() => _routineTags = draftTags);
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: const <String>['考试周', '夜猫子', '早起党']
                          .map((String option) {
                            final bool selected = draftTags.contains(option);
                            final AppSemanticColors appColors =
                                context.appColors;
                            return FilterChip(
                              selected: selected,
                              label: Text(option),
                              selectedColor: appColors.accent,
                              backgroundColor: AppColors.surfaceMuted,
                              side: BorderSide(
                                color: selected
                                    ? appColors.accentDeep.withAlpha(80)
                                    : AppColors.surfaceBorder,
                              ),
                              onSelected: (_) {
                                setSheetState(() {
                                  draftTags = selected
                                      ? draftTags
                                            .where(
                                              (String tag) => tag != option,
                                            )
                                            .toList(growable: false)
                                      : <String>[...draftTags, option];
                                });
                              },
                            );
                          })
                          .toList(growable: false),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();
    final AppServices services = context.appServices;
    final Dorm dorm = services.dormRepository.currentDorm;
    if (dorm.pendingRuleProposal != null) {
      return;
    }

    final String quietStart = _quietStartController.text.trim();
    final String quietEnd = _quietEndController.text.trim();
    final String lightsOff = _lightsOffController.text.trim();
    if (quietStart.isEmpty || quietEnd.isEmpty || lightsOff.isEmpty) {
      await notifyPassiveToast(context, message: '请先补全安静时段和熄灯提醒。');
      return;
    }

    final DormRulesSettings next = dorm.rulesSettings.copyWith(
      quietHours: '$quietStart - $quietEnd',
      lightsOffTime: lightsOff,
      specialCase: _noteController.text.trim(),
      personalLighting: _personalLightingController.text.trim(),
      examWeekMode: _examWeekMode,
      blackoutCurtain: _blackoutCurtain,
      vibrationFirst: _vibrationFirst,
      alarmResponseSeconds:
          int.tryParse(_alarmResponseController.text.trim()) ??
          dorm.rulesSettings.alarmResponseSeconds,
      routineNote: _routineNoteController.text.trim(),
      routineTags: _routineTags,
      summerTempC: _summerTemp,
      winterTempC: _winterTemp,
      ventilationWindow: _selectedVentilationWindow,
      ventilationMinutes: _ventilationMinutes,
    );
    await services.dormFacade.saveRules(next);
    if (!mounted) {
      return;
    }
    setState(() {
      _isEditing = false;
      _showReviewOverlay = false;
      _expandedInlineEditor = null;
    });
    await notifyPassiveToast(context, message: '已提交待确认规则，等待室友确认。');
  }

  Future<void> _handleApprove() async {
    await context.appServices.dormFacade.approvePendingRules();
    if (!mounted) {
      return;
    }
    setState(() => _showReviewOverlay = false);
    await notifyPassiveToast(context, message: '你已同意这次规则调整。');
  }

  Future<void> _handleReject() async {
    final String reason = _objectionReasonController.text.trim();
    if (reason.isEmpty) {
      await notifyPassiveToast(context, message: '请先填写不同意原因。');
      return;
    }
    await context.appServices.dormFacade.rejectPendingRules(reason: reason);
    if (!mounted) {
      return;
    }
    setState(() => _showReviewOverlay = false);
    _objectionReasonController.clear();
    await notifyPassiveToast(context, message: '已保留旧规则，并记录你的异议。');
  }

  @override
  Widget build(BuildContext context) {
    final Listenable dormRepository = context.appServices.dormRepository;
    return ListenableBuilder(
      listenable: dormRepository,
      builder: (BuildContext context, Widget? child) {
        final Dorm dorm = context.appServices.dormRepository.currentDorm;
        _syncDraftFromDorm(dorm);

        final NightMoodPalette palette = context.nightMoodPalette;
        final bool hasPendingProposal = dorm.pendingRuleProposal != null;
        final bool canReviewProposal = _canCurrentUserReviewProposal(dorm);
        final bool showEditView = _isEditing && !hasPendingProposal;

        if (_showReviewOverlay && !canReviewProposal) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _showReviewOverlay = false);
            }
          });
        }
        if (_isEditing && hasPendingProposal) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _cancelEditing(dorm.rulesSettings);
            }
          });
        }

        return PopScope<void>(
          canPop: !showEditView,
          onPopInvokedWithResult: (bool didPop, void result) {
            if (!didPop && showEditView) {
              _cancelEditing(dorm.rulesSettings);
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double widthFactor = _rulesPageWidthFactor(
                    constraints.maxWidth,
                  );
                  return Stack(
                    children: <Widget>[
                      SingleChildScrollView(
                        padding: EdgeInsets.only(
                          bottom: showEditView
                              ? AppSpacing.xxxl +
                                    AppSpacing.xxxl +
                                    AppSpacing.sm
                              : AppSpacing.sm,
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: FractionallySizedBox(
                            widthFactor: widthFactor,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              layoutBuilder:
                                  (
                                    Widget? currentChild,
                                    List<Widget> previousChildren,
                                  ) {
                                    return Stack(
                                      alignment: Alignment.topCenter,
                                      children: <Widget>[
                                        ...previousChildren,
                                        ?currentChild,
                                      ],
                                    );
                                  },
                              transitionBuilder:
                                  (Widget child, Animation<double> animation) {
                                    final bool isEditPage =
                                        child.key ==
                                        const ValueKey<String>(
                                          'dorm-rules-edit-view',
                                        );
                                    final Offset beginOffset = isEditPage
                                        ? const Offset(1, 0)
                                        : const Offset(-1, 0);
                                    final Animation<double> curvedAnimation =
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeOutCubic,
                                          reverseCurve: Curves.easeInCubic,
                                        );
                                    return FadeTransition(
                                      opacity: curvedAnimation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: beginOffset,
                                          end: Offset.zero,
                                        ).animate(curvedAnimation),
                                        child: child,
                                      ),
                                    );
                                  },
                              child: showEditView
                                  ? Column(
                                      key: const ValueKey<String>(
                                        'dorm-rules-edit-view',
                                      ),
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        _DormRulesEditHeader(
                                          onBack: () => _cancelEditing(
                                            dorm.rulesSettings,
                                          ),
                                        ),
                                        _DormRulesEditBody(
                                          palette: palette,
                                          quietStartController:
                                              _quietStartController,
                                          quietEndController:
                                              _quietEndController,
                                          lightsOffController:
                                              _lightsOffController,
                                          noteController: _noteController,
                                          personalLightingController:
                                              _personalLightingController,
                                          alarmResponseController:
                                              _alarmResponseController,
                                          routineNoteController:
                                              _routineNoteController,
                                          examWeekMode: _examWeekMode,
                                          blackoutCurtain: _blackoutCurtain,
                                          vibrationFirst: _vibrationFirst,
                                          summerTemp: _summerTemp,
                                          winterTemp: _winterTemp,
                                          ventilationMinutes:
                                              _ventilationMinutes,
                                          selectedVentilationWindow:
                                              _selectedVentilationWindow,
                                          routineTags: _routineTags,
                                          expandedInlineEditor:
                                              _expandedInlineEditor,
                                          onEditQuietHours:
                                              _showQuietHoursEditor,
                                          onEditLightsOff: _showLightsOffEditor,
                                          onEditNote: () => _showTextEditor(
                                            title: '补充说明',
                                            targetController: _noteController,
                                            maxLines: 3,
                                          ),
                                          onEditPersonalLighting: () =>
                                              _showTextEditor(
                                                title: '个人照明要求',
                                                targetController:
                                                    _personalLightingController,
                                                maxLines: 2,
                                              ),
                                          onEditAlarmResponse: () =>
                                              _showTextEditor(
                                                title: '闹钟响应时限',
                                                targetController:
                                                    _alarmResponseController,
                                                keyboardType:
                                                    TextInputType.number,
                                                suffixText: '秒',
                                              ),
                                          onEditRoutineNote: () =>
                                              _showTextEditor(
                                                title: '作息习惯备注',
                                                targetController:
                                                    _routineNoteController,
                                                maxLines: 2,
                                              ),
                                          onEditRoutineTags:
                                              _showRoutineTagsEditor,
                                          onToggleSummerTemp: () =>
                                              setState(() {
                                                _expandedInlineEditor =
                                                    _expandedInlineEditor ==
                                                        _DormRulesInlineEditor
                                                            .summer
                                                    ? null
                                                    : _DormRulesInlineEditor
                                                          .summer;
                                              }),
                                          onToggleWinterTemp: () =>
                                              setState(() {
                                                _expandedInlineEditor =
                                                    _expandedInlineEditor ==
                                                        _DormRulesInlineEditor
                                                            .winter
                                                    ? null
                                                    : _DormRulesInlineEditor
                                                          .winter;
                                              }),
                                          onToggleVentilationDuration: () =>
                                              setState(() {
                                                _expandedInlineEditor =
                                                    _expandedInlineEditor ==
                                                        _DormRulesInlineEditor
                                                            .ventilationDuration
                                                    ? null
                                                    : _DormRulesInlineEditor
                                                          .ventilationDuration;
                                              }),
                                          onSummerTempChanged: (double value) =>
                                              setState(
                                                () => _summerTemp = value,
                                              ),
                                          onWinterTempChanged: (double value) =>
                                              setState(
                                                () => _winterTemp = value,
                                              ),
                                          onVentilationMinutesChanged:
                                              (double value) => setState(
                                                () =>
                                                    _ventilationMinutes = value,
                                              ),
                                          onEditVentilationWindow: () =>
                                              _showSingleChoiceEditor(
                                                title: '通风时段',
                                                options: const <String>[
                                                  '早晨',
                                                  '中午',
                                                  '睡前',
                                                ],
                                                selectedValue:
                                                    _selectedVentilationWindow,
                                                onSelected: (String value) =>
                                                    _selectedVentilationWindow =
                                                        value,
                                              ),
                                          onExamWeekModeChanged: (bool value) =>
                                              setState(
                                                () => _examWeekMode = value,
                                              ),
                                          onBlackoutCurtainChanged:
                                              (bool value) => setState(
                                                () => _blackoutCurtain = value,
                                              ),
                                          onVibrationFirstChanged:
                                              (bool value) => setState(
                                                () => _vibrationFirst = value,
                                              ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      key: const ValueKey<String>(
                                        'dorm-rules-display-view',
                                      ),
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        _DormRulesDisplayHeader(
                                          palette: palette,
                                          canReviewProposal: canReviewProposal,
                                          hasPendingProposal:
                                              hasPendingProposal,
                                          onBack: () =>
                                              Navigator.of(context).maybePop(),
                                          onEdit: _enterEditMode,
                                          onReview: () {
                                            setState(
                                              () => _showReviewOverlay = true,
                                            );
                                          },
                                        ),
                                        _DormRulesDisplayBody(
                                          dorm: dorm,
                                          palette: palette,
                                          expandedGroup: _expandedDisplayGroup,
                                          onToggleGroup:
                                              (_DormRulesDisplayGroup group) {
                                                setState(() {
                                                  _expandedDisplayGroup =
                                                      _expandedDisplayGroup ==
                                                          group
                                                      ? null
                                                      : group;
                                                });
                                              },
                                        ),
                                        _DormRulesDisplayBottomBar(
                                          palette: palette,
                                          onPressed: hasPendingProposal
                                              ? () {
                                                  if (canReviewProposal) {
                                                    setState(
                                                      () => _showReviewOverlay =
                                                          true,
                                                    );
                                                  }
                                                }
                                              : () {
                                                  notifyPassiveToast(
                                                    context,
                                                    message:
                                                        '已记录你的确认，一起把约定执行下去吧。',
                                                  );
                                                },
                                          enabled:
                                              !hasPendingProposal ||
                                              canReviewProposal,
                                        ),
                                        if (hasPendingProposal)
                                          _DormRulesPendingSection(
                                            proposal: dorm.pendingRuleProposal!,
                                            currentSettings: dorm.rulesSettings,
                                            palette: palette,
                                            onReviewPending: canReviewProposal
                                                ? () {
                                                    setState(
                                                      () => _showReviewOverlay =
                                                          true,
                                                    );
                                                  }
                                                : null,
                                          ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                      if (_showReviewOverlay && canReviewProposal)
                        Align(
                          alignment: Alignment.topCenter,
                          child: FractionallySizedBox(
                            widthFactor: widthFactor,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top:
                                    AppSpacing.xxxl +
                                    AppSpacing.xl +
                                    AppSpacing.sm,
                              ),
                              child: Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    right: AppSpacing.lg,
                                  ),
                                  child: FractionallySizedBox(
                                    widthFactor: 0.72,
                                    alignment: Alignment.topRight,
                                    child: _DormRulesReviewOverlay(
                                      palette: palette,
                                      objectionReasonController:
                                          _objectionReasonController,
                                      onApprove: _handleApprove,
                                      onReject: _handleReject,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (showEditView)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            widthFactor: widthFactor,
                            child: _DormRulesEditBottomBar(
                              onCancel: () =>
                                  _cancelEditing(dorm.rulesSettings),
                              onConfirm: _handleSave,
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
      },
    );
  }
}

class _DormRulesDisplayHeader extends StatelessWidget {
  const _DormRulesDisplayHeader({
    required this.palette,
    required this.canReviewProposal,
    required this.hasPendingProposal,
    required this.onBack,
    required this.onEdit,
    required this.onReview,
  });

  final NightMoodPalette palette;
  final bool canReviewProposal;
  final bool hasPendingProposal;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: AppDetailPageHeader(
        title: '宿舍公约',
        onBack: onBack,
        trailing: canReviewProposal
            ? _DormRulesHeaderPill(
                label: '待确认',
                icon: Icons.mark_chat_unread_rounded,
                palette: palette,
                onPressed: onReview,
              )
            : !hasPendingProposal
            ? _DormRulesHeaderPill(
                key: const ValueKey<String>('dorm-rules-edit-entry'),
                label: '编辑',
                icon: Icons.edit_outlined,
                palette: palette,
                onPressed: onEdit,
              )
            : null,
      ),
    );
  }
}

class _DormRulesEditHeader extends StatelessWidget {
  const _DormRulesEditHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: AppDetailPageHeader(title: '编辑宿舍公约', onBack: onBack),
    );
  }
}

class _DormRulesHeaderPill extends StatelessWidget {
  const _DormRulesHeaderPill({
    super.key,
    required this.label,
    required this.icon,
    required this.palette,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final NightMoodPalette palette;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      label: label,
      icon: icon,
      expand: false,
      size: PrimaryButtonSize.compact,
      variant: PrimaryButtonVariant.soft,
      onPressed: onPressed,
    );
  }
}

class _DormRulesDisplayBody extends StatelessWidget {
  const _DormRulesDisplayBody({
    required this.dorm,
    required this.palette,
    required this.expandedGroup,
    required this.onToggleGroup,
  });

  final Dorm dorm;
  final NightMoodPalette palette;
  final _DormRulesDisplayGroup? expandedGroup;
  final ValueChanged<_DormRulesDisplayGroup> onToggleGroup;

  @override
  Widget build(BuildContext context) {
    final List<_DormRuleGroupData> groups = _buildDisplayRuleGroups(
      dorm.rulesSettings,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _DormRulesIntroCard(palette: palette),
          const SizedBox(height: AppSpacing.sm),
          for (int index = 0; index < groups.length; index++) ...<Widget>[
            _DormRulesDisplayGroupCard(
              data: groups[index],
              palette: palette,
              expanded: expandedGroup == groups[index].group,
              onTap: () => onToggleGroup(groups[index].group),
            ),
            if (index != groups.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _DormRulesIntroCard extends StatelessWidget {
  const _DormRulesIntroCard({required this.palette});

  final NightMoodPalette palette;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return AppCard(
      borderRadius: AppRadius.card,
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: _rulesIntroFill(appColors),
      boxShadow: const <BoxShadow>[],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            constraints: const BoxConstraints.tightFor(
              width: AppSpacing.xxxl,
              height: AppSpacing.xxxl,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.iconContainer,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.shield_outlined,
              size: AppSpacing.lg,
              color: appColors.accentDeep,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '共同维护良好宿舍环境',
            style: AppTypography.sectionTitle(
              textTheme,
            ).copyWith(color: appColors.accentDeep),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '以下是大家共同制定的宿舍公约，请每位成员认真遵守。',
            style: AppTypography.body(
              textTheme,
            ).copyWith(color: appColors.accentDeep),
          ),
        ],
      ),
    );
  }
}

class _DormRulesDisplayGroupCard extends StatelessWidget {
  const _DormRulesDisplayGroupCard({
    required this.data,
    required this.palette,
    required this.expanded,
    required this.onTap,
  });

  final _DormRuleGroupData data;
  final NightMoodPalette palette;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return AppCard(
      borderRadius: AppRadius.compactCard,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      color: Colors.white,
      boxShadow: const <BoxShadow>[],
      child: Column(
        children: <Widget>[
          AppSettingsItem(
            key: ValueKey<String>('dorm-rules-display-group-${data.keySuffix}'),
            title: data.title,
            icon: data.icon,
            iconColor: appColors.accentDeep,
            iconBackgroundColor: AppColors.surfaceMuted,
            iconContainerSize: AppSpacing.xxxl,
            iconSize: AppSpacing.lg,
            leadingWidth: AppSpacing.xxxl,
            titleStyle: AppTypography.body(textTheme).copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  data.summary,
                  style: AppTypography.bodyMuted(textTheme).copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                AnimatedRotation(
                  turns: expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
            onTap: onTap,
          ),
          KeyedSubtree(
            key: ValueKey<String>(
              'dorm-rules-display-group-${data.keySuffix}-body',
            ),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: expanded
                    ? Padding(
                        key: ValueKey<String>(
                          'dorm-rules-display-group-${data.keySuffix}-rows',
                        ),
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Column(
                          children: <Widget>[
                            for (
                              int index = 0;
                              index < data.rows.length;
                              index++
                            ) ...<Widget>[
                              _DormRulesGroupRow(
                                data: data.rows[index],
                                palette: palette,
                                iconFill: index.isEven
                                    ? _rulesMutedIconFill(appColors)
                                    : _rulesAccentIconFill(appColors),
                              ),
                              if (index != data.rows.length - 1)
                                const SizedBox(height: AppSpacing.xxs),
                            ],
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DormRulesGroupRow extends StatelessWidget {
  const _DormRulesGroupRow({
    required this.data,
    required this.palette,
    required this.iconFill,
  });

  final _DormRuleRowData data;
  final NightMoodPalette palette;
  final Color iconFill;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            constraints: const BoxConstraints.tightFor(
              width: AppSpacing.xxxl,
              height: AppSpacing.xxxl,
            ),
            decoration: BoxDecoration(
              color: iconFill,
              borderRadius: AppRadius.iconContainer,
            ),
            alignment: Alignment.center,
            child: Icon(
              data.icon,
              size: AppSpacing.lg,
              color: appColors.accentDeep,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  data.title,
                  style: AppTypography.cardTitle(textTheme).copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  data.description,
                  style: AppTypography.bodyMuted(
                    textTheme,
                  ).copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            constraints: const BoxConstraints.tightFor(
              width: AppSpacing.xl,
              height: AppSpacing.xl,
            ),
            decoration: BoxDecoration(
              color: appColors.accent,
              borderRadius: AppRadius.pill,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.check_rounded,
              size: AppSpacing.md,
              color: appColors.textOnAccent,
            ),
          ),
        ],
      ),
    );
  }
}

class _DormRulesPendingSection extends StatelessWidget {
  const _DormRulesPendingSection({
    required this.proposal,
    required this.currentSettings,
    required this.palette,
    this.onReviewPending,
  });

  final DormPendingRuleProposal proposal;
  final DormRulesSettings currentSettings;
  final NightMoodPalette palette;
  final VoidCallback? onReviewPending;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '待确认规则',
            style: AppTypography.meta(textTheme).copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppCard(
            borderRadius: AppRadius.compactCard,
            padding: const EdgeInsets.all(AppSpacing.sm),
            color: Colors.white,
            boxShadow: const <BoxShadow>[],
            child: Row(
              children: <Widget>[
                Container(
                  constraints: const BoxConstraints.tightFor(
                    width: AppSpacing.xxxl,
                    height: AppSpacing.xxxl,
                  ),
                  decoration: BoxDecoration(
                    color: _rulesMutedIconFill(appColors),
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.timer_outlined,
                    size: 20,
                    color: appColors.accentDeep,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _pendingRuleTitle(
                          currentSettings,
                          proposal.proposedSettings,
                        ),
                        style: AppTypography.cardTitle(textTheme).copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        _pendingRuleSummary(proposal, currentSettings),
                        style: AppTypography.bodyMuted(
                          textTheme,
                        ).copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IgnorePointer(
                  ignoring: onReviewPending == null,
                  child: Opacity(
                    opacity: onReviewPending == null ? 0.56 : 1,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                        onTap: onReviewPending,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: appColors.accent,
                            borderRadius: BorderRadius.circular(AppSpacing.sm),
                          ),
                          child: Text(
                            '确认',
                            style: AppTypography.chip(textTheme).copyWith(
                              color: appColors.textOnAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
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

class _DormRulesDisplayBottomBar extends StatelessWidget {
  const _DormRulesDisplayBottomBar({
    required this.palette,
    required this.onPressed,
    required this.enabled,
  });

  final NightMoodPalette palette;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: PrimaryButton(
        label: '我同意遵守以上公约',
        icon: Icons.check_circle_outline_rounded,
        size: PrimaryButtonSize.compact,
        backgroundColor: appColors.accent,
        foregroundColor: appColors.textOnAccent,
        onPressed: enabled ? onPressed : null,
      ),
    );
  }
}

class _DormRulesEditBody extends StatelessWidget {
  const _DormRulesEditBody({
    required this.palette,
    required this.quietStartController,
    required this.quietEndController,
    required this.lightsOffController,
    required this.noteController,
    required this.personalLightingController,
    required this.alarmResponseController,
    required this.routineNoteController,
    required this.examWeekMode,
    required this.blackoutCurtain,
    required this.vibrationFirst,
    required this.summerTemp,
    required this.winterTemp,
    required this.ventilationMinutes,
    required this.selectedVentilationWindow,
    required this.routineTags,
    required this.expandedInlineEditor,
    required this.onEditQuietHours,
    required this.onEditLightsOff,
    required this.onEditNote,
    required this.onEditPersonalLighting,
    required this.onEditAlarmResponse,
    required this.onEditRoutineNote,
    required this.onEditRoutineTags,
    required this.onToggleSummerTemp,
    required this.onToggleWinterTemp,
    required this.onToggleVentilationDuration,
    required this.onSummerTempChanged,
    required this.onWinterTempChanged,
    required this.onVentilationMinutesChanged,
    required this.onEditVentilationWindow,
    required this.onExamWeekModeChanged,
    required this.onBlackoutCurtainChanged,
    required this.onVibrationFirstChanged,
  });

  final NightMoodPalette palette;
  final TextEditingController quietStartController;
  final TextEditingController quietEndController;
  final TextEditingController lightsOffController;
  final TextEditingController noteController;
  final TextEditingController personalLightingController;
  final TextEditingController alarmResponseController;
  final TextEditingController routineNoteController;
  final bool examWeekMode;
  final bool blackoutCurtain;
  final bool vibrationFirst;
  final double summerTemp;
  final double winterTemp;
  final double ventilationMinutes;
  final String selectedVentilationWindow;
  final List<String> routineTags;
  final _DormRulesInlineEditor? expandedInlineEditor;
  final VoidCallback onEditQuietHours;
  final VoidCallback onEditLightsOff;
  final VoidCallback onEditNote;
  final VoidCallback onEditPersonalLighting;
  final VoidCallback onEditAlarmResponse;
  final VoidCallback onEditRoutineNote;
  final VoidCallback onEditRoutineTags;
  final VoidCallback onToggleSummerTemp;
  final VoidCallback onToggleWinterTemp;
  final VoidCallback onToggleVentilationDuration;
  final ValueChanged<double> onSummerTempChanged;
  final ValueChanged<double> onWinterTempChanged;
  final ValueChanged<double> onVentilationMinutesChanged;
  final VoidCallback onEditVentilationWindow;
  final ValueChanged<bool> onExamWeekModeChanged;
  final ValueChanged<bool> onBlackoutCurtainChanged;
  final ValueChanged<bool> onVibrationFirstChanged;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final TextStyle groupTitleStyle = AppTypography.meta(
      textTheme,
    ).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double horizontalInset = (constraints.maxWidth * 0.06)
            .clamp(AppSpacing.lg, AppSpacing.xl)
            .toDouble();
        const EdgeInsetsGeometry groupPadding = EdgeInsets.symmetric(
          vertical: AppSpacing.xs,
        );
        const EdgeInsetsGeometry groupHeaderPadding = EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxs,
        );

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppCard(
                key: const ValueKey<String>('dorm-rules-edit-intro'),
                borderRadius: AppRadius.surfaceSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                color: appColors.accentSoft,
                boxShadow: const <BoxShadow>[],
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      key: const ValueKey<String>('dorm-rules-edit-intro-icon'),
                      constraints: const BoxConstraints.tightFor(
                        width: AppSpacing.xxxl,
                        height: AppSpacing.xxxl,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: AppRadius.iconContainer,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.verified_user_outlined,
                        size: AppSpacing.lg,
                        color: appColors.accentDeep,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '修改后需要室友确认',
                            style: AppTypography.cardTitle(
                              textTheme,
                            ).copyWith(color: appColors.accentDeep),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            '本页保存的是调整草案，不会立即覆盖当前正式公约。',
                            style: AppTypography.bodyMuted(
                              textTheme,
                            ).copyWith(color: appColors.accentDeep),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppSettingsGroup(
                key: const ValueKey<String>('dorm-rules-basic-group'),
                title: '基础规则',
                borderRadius: AppRadius.surfaceSecondary,
                padding: groupPadding,
                headerPadding: groupHeaderPadding,
                titleStyle: groupTitleStyle,
                children: <Widget>[
                  _DormRulesEditableQuietHoursCard(
                    palette: palette,
                    quietStartController: quietStartController,
                    quietEndController: quietEndController,
                    onTap: onEditQuietHours,
                  ),
                  _DormRulesEditableLightsCard(
                    palette: palette,
                    lightsOffCopy: _dormRulesFirstTimeOrPreview(
                      lightsOffController.text,
                    ),
                    onTap: onEditLightsOff,
                  ),
                  _DormRulesEditableNoteCard(
                    palette: palette,
                    noteController: noteController,
                    onTap: onEditNote,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppSettingsGroup(
                title: '灯光与安静',
                borderRadius: AppRadius.surfaceSecondary,
                padding: groupPadding,
                headerPadding: groupHeaderPadding,
                titleStyle: groupTitleStyle,
                children: <Widget>[
                  _DormRulesToggleCard(
                    palette: palette,
                    icon: Icons.menu_book_rounded,
                    title: '考试周模式',
                    description: '提前进入静音协作',
                    value: examWeekMode,
                    onChanged: onExamWeekModeChanged,
                  ),
                  _DormRulesCompactValueCard(
                    palette: palette,
                    icon: Icons.light_mode_outlined,
                    title: '个人照明要求',
                    value: _dormRulesPreviewText(
                      personalLightingController.text,
                    ),
                    onTap: onEditPersonalLighting,
                  ),
                  _DormRulesToggleCard(
                    palette: palette,
                    icon: Icons.blinds_closed_outlined,
                    title: '遮光帘建议',
                    description: '减少走廊和窗边杂光',
                    value: blackoutCurtain,
                    onChanged: onBlackoutCurtainChanged,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppSettingsGroup(
                title: '闹钟与作息',
                borderRadius: AppRadius.surfaceSecondary,
                padding: groupPadding,
                headerPadding: groupHeaderPadding,
                titleStyle: groupTitleStyle,
                children: <Widget>[
                  _DormRulesToggleCard(
                    palette: palette,
                    icon: Icons.vibration_rounded,
                    title: '优先震动提醒',
                    description: '先震动，降低打扰',
                    value: vibrationFirst,
                    onChanged: onVibrationFirstChanged,
                  ),
                  _DormRulesCompactValueCard(
                    palette: palette,
                    icon: Icons.alarm_on_rounded,
                    title: '闹钟响应时限',
                    value: '${alarmResponseController.text.trim()} 秒',
                    onTap: onEditAlarmResponse,
                  ),
                  _DormRulesCompactValueCard(
                    palette: palette,
                    icon: Icons.bedtime_rounded,
                    title: '作息习惯备注',
                    value: _dormRulesPreviewText(routineNoteController.text),
                    onTap: onEditRoutineNote,
                  ),
                  _DormRulesCompactValueCard(
                    palette: palette,
                    icon: Icons.sell_outlined,
                    title: '作息标签',
                    value: _dormRulesTagsSummary(routineTags),
                    onTap: onEditRoutineTags,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppSettingsGroup(
                title: '温度与通风',
                borderRadius: AppRadius.surfaceSecondary,
                padding: groupPadding,
                headerPadding: groupHeaderPadding,
                titleStyle: groupTitleStyle,
                children: <Widget>[
                  _DormRulesCompactValueCard(
                    palette: palette,
                    icon: Icons.ac_unit_rounded,
                    title: '夏季空调',
                    value: '${summerTemp.round()}°C',
                    onTap: onToggleSummerTemp,
                  ),
                  _DormRulesInlineSlider(
                    sliderKey: const ValueKey<String>(
                      'dorm-rules-summer-temp-slider',
                    ),
                    expanderKey: const ValueKey<String>(
                      'dorm-rules-summer-temp-expander',
                    ),
                    visible:
                        expandedInlineEditor == _DormRulesInlineEditor.summer,
                    valueLabel: '${summerTemp.round()}°C',
                    value: summerTemp,
                    min: 20,
                    max: 30,
                    divisions: 10,
                    onChanged: onSummerTempChanged,
                  ),
                  _DormRulesCompactValueCard(
                    palette: palette,
                    icon: Icons.thermostat_rounded,
                    title: '冬季采暖',
                    value: '${winterTemp.round()}°C',
                    onTap: onToggleWinterTemp,
                  ),
                  _DormRulesInlineSlider(
                    sliderKey: const ValueKey<String>(
                      'dorm-rules-winter-temp-slider',
                    ),
                    expanderKey: const ValueKey<String>(
                      'dorm-rules-winter-temp-expander',
                    ),
                    visible:
                        expandedInlineEditor == _DormRulesInlineEditor.winter,
                    valueLabel: '${winterTemp.round()}°C',
                    value: winterTemp,
                    min: 16,
                    max: 28,
                    divisions: 12,
                    onChanged: onWinterTempChanged,
                  ),
                  _DormRulesCompactValueCard(
                    palette: palette,
                    icon: Icons.air_rounded,
                    title: '通风时段',
                    value: selectedVentilationWindow,
                    onTap: onEditVentilationWindow,
                  ),
                  _DormRulesCompactValueCard(
                    palette: palette,
                    icon: Icons.timer_outlined,
                    title: '通风时长',
                    value: '${ventilationMinutes.round()}分钟',
                    onTap: onToggleVentilationDuration,
                  ),
                  _DormRulesInlineSlider(
                    sliderKey: const ValueKey<String>(
                      'dorm-rules-ventilation-duration-slider',
                    ),
                    expanderKey: const ValueKey<String>(
                      'dorm-rules-ventilation-duration-expander',
                    ),
                    visible:
                        expandedInlineEditor ==
                        _DormRulesInlineEditor.ventilationDuration,
                    valueLabel: '${ventilationMinutes.round()}分钟',
                    value: ventilationMinutes,
                    min: 10,
                    max: 60,
                    divisions: 50,
                    onChanged: onVentilationMinutesChanged,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

const EdgeInsetsGeometry _dormRulesEditItemPadding = EdgeInsets.symmetric(
  horizontal: AppSpacing.md,
  vertical: AppSpacing.xs,
);

TextStyle? _dormRulesEditItemTitleStyle(BuildContext context) {
  return AppTypography.body(
    Theme.of(context).textTheme,
  ).copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600);
}

class _DormRulesEditableQuietHoursCard extends StatelessWidget {
  const _DormRulesEditableQuietHoursCard({
    required this.palette,
    required this.quietStartController,
    required this.quietEndController,
    required this.onTap,
  });

  final NightMoodPalette palette;
  final TextEditingController quietStartController;
  final TextEditingController quietEndController;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return AppSettingsItem(
      title: '安静时段',
      icon: Icons.volume_off_rounded,
      iconColor: appColors.accentDeep,
      iconBackgroundColor: AppColors.surfaceMuted,
      iconContainerSize: AppSpacing.xxxl,
      iconSize: AppSpacing.lg,
      iconContainerKey: const ValueKey<String>(
        'dorm-rules-edit-icon-quiet-hours',
      ),
      leadingWidth: AppSpacing.xxxl,
      titleStyle: _dormRulesEditItemTitleStyle(context),
      padding: _dormRulesEditItemPadding,
      onTap: onTap,
      trailing: AppSettingsValueTrailing(
        key: const ValueKey<String>('dorm-rules-trailing-quiet-hours'),
        value:
            '${quietStartController.text.trim()} - ${quietEndController.text.trim()}',
        showChevron: true,
      ),
    );
  }
}

class _DormRulesSheetTextField extends StatelessWidget {
  const _DormRulesSheetTextField({
    required this.label,
    required this.controller,
    this.hintText,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.control,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: AppTypography.chip(Theme.of(context).textTheme).copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: AppTypography.body(Theme.of(context).textTheme).copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _DormRulesEditableLightsCard extends StatelessWidget {
  const _DormRulesEditableLightsCard({
    required this.palette,
    required this.lightsOffCopy,
    required this.onTap,
  });

  final NightMoodPalette palette;
  final String lightsOffCopy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return AppSettingsItem(
      title: '熄灯提醒',
      icon: Icons.lightbulb_outline_rounded,
      iconColor: appColors.accentDeep,
      iconBackgroundColor: AppColors.surfaceMuted,
      iconContainerSize: AppSpacing.xxxl,
      iconSize: AppSpacing.lg,
      iconContainerKey: const ValueKey<String>(
        'dorm-rules-edit-icon-lights-off',
      ),
      leadingWidth: AppSpacing.xxxl,
      titleStyle: _dormRulesEditItemTitleStyle(context),
      padding: _dormRulesEditItemPadding,
      onTap: onTap,
      trailing: AppSettingsValueTrailing(
        key: const ValueKey<String>('dorm-rules-trailing-lights-off'),
        value: lightsOffCopy,
        showChevron: true,
      ),
    );
  }
}

class _DormRulesEditableNoteCard extends StatelessWidget {
  const _DormRulesEditableNoteCard({
    required this.palette,
    required this.noteController,
    required this.onTap,
  });

  final NightMoodPalette palette;
  final TextEditingController noteController;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _DormRulesCompactValueCard(
      palette: palette,
      icon: Icons.notes_rounded,
      title: '补充说明',
      value: _dormRulesPreviewText(noteController.text),
      onTap: onTap,
    );
  }
}

class _DormRulesCompactValueCard extends StatelessWidget {
  const _DormRulesCompactValueCard({
    required this.palette,
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final NightMoodPalette palette;
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return AppSettingsItem(
      title: title,
      icon: icon,
      iconColor: appColors.accentDeep,
      iconBackgroundColor: AppColors.surfaceMuted,
      iconContainerSize: AppSpacing.xxxl,
      iconSize: AppSpacing.lg,
      leadingWidth: AppSpacing.xxxl,
      titleStyle: _dormRulesEditItemTitleStyle(context),
      padding: _dormRulesEditItemPadding,
      onTap: onTap,
      trailing: AppSettingsValueTrailing(
        key: ValueKey<String>('dorm-rules-trailing-$title'),
        value: value,
        showChevron: true,
      ),
    );
  }
}

class _DormRulesInlineSlider extends StatelessWidget {
  const _DormRulesInlineSlider({
    required this.sliderKey,
    this.expanderKey,
    required this.visible,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final Key sliderKey;
  final Key? expanderKey;
  final bool visible;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return KeyedSubtree(
      key: expanderKey,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: visible
              ? Padding(
                  key: ValueKey<Key>(sliderKey),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.xs,
                  ),
                  child: SizedBox(
                    height: AppSpacing.xxxl,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: AppSpacing.xxs,
                            activeTrackColor: appColors.accent,
                            inactiveTrackColor: AppColors.surfaceSoft,
                            thumbColor: appColors.accentDeep,
                            overlayShape: SliderComponentShape.noOverlay,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: AppSpacing.xs,
                            ),
                          ),
                          child: Slider(
                            key: sliderKey,
                            value: value.clamp(min, max),
                            min: min,
                            max: max,
                            divisions: divisions,
                            onChanged: onChanged,
                          ),
                        ),
                        IgnorePointer(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              valueLabel,
                              style:
                                  AppTypography.bodyMuted(
                                    Theme.of(context).textTheme,
                                  ).copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _DormRulesToggleCard extends StatelessWidget {
  const _DormRulesToggleCard({
    required this.palette,
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final NightMoodPalette palette;
  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return AppSettingsItem(
      title: title,
      icon: icon,
      iconColor: appColors.accentDeep,
      iconBackgroundColor: AppColors.surfaceMuted,
      iconContainerSize: AppSpacing.xxxl,
      iconSize: AppSpacing.lg,
      iconContainerKey: ValueKey<String>('dorm-rules-edit-icon-$title'),
      leadingWidth: AppSpacing.xxxl,
      titleStyle: _dormRulesEditItemTitleStyle(context),
      padding: _dormRulesEditItemPadding,
      trailing: AppSettingsToggle(
        key: title == '考试周模式'
            ? const ValueKey<String>('dorm-rules-switch-exam-week')
            : null,
        value: value,
      ),
      onTap: () => onChanged(!value),
    );
  }
}

class _DormRulesEditBottomBar extends StatelessWidget {
  const _DormRulesEditBottomBar({
    required this.onCancel,
    required this.onConfirm,
  });

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double horizontalInset = (constraints.maxWidth * 0.06)
            .clamp(AppSpacing.lg, AppSpacing.xl)
            .toDouble();

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalInset,
            AppSpacing.sm,
            horizontalInset,
            AppSpacing.lg,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: PrimaryButton(
                  key: const ValueKey<String>('dorm-rules-cancel-button'),
                  label: '取消',
                  variant: PrimaryButtonVariant.ghost,
                  size: PrimaryButtonSize.compact,
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                  borderColor: AppColors.surfaceBorder,
                  onPressed: onCancel,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: PrimaryButton(
                  key: const ValueKey<String>('dorm-rules-submit-button'),
                  label: '发起确认',
                  icon: Icons.send_rounded,
                  size: PrimaryButtonSize.compact,
                  variant: PrimaryButtonVariant.soft,
                  onPressed: onConfirm,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DormRulesReviewOverlay extends StatelessWidget {
  const _DormRulesReviewOverlay({
    required this.palette,
    required this.objectionReasonController,
    required this.onApprove,
    required this.onReject,
  });

  final NightMoodPalette palette;
  final TextEditingController objectionReasonController;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return Material(
      color: Colors.transparent,
      child: AppCard(
        borderRadius: AppRadius.card,
        boxShadow: AppColors.floatingShadow,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            PrimaryButton(
              label: '同意',
              size: PrimaryButtonSize.compact,
              backgroundColor: appColors.accent,
              foregroundColor: appColors.textOnAccent,
              onPressed: onApprove,
            ),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: '不同意',
              variant: PrimaryButtonVariant.ghost,
              size: PrimaryButtonSize.compact,
              borderColor: AppColors.surfaceBorder,
              onPressed: onReject,
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: AppRadius.control,
              ),
              child: TextField(
                controller: objectionReasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: '输入你有异议的地方',
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DormRuleRowData {
  const _DormRuleRowData({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _DormRuleGroupData {
  const _DormRuleGroupData({
    required this.group,
    required this.keySuffix,
    required this.icon,
    required this.title,
    required this.summary,
    required this.rows,
  });

  final _DormRulesDisplayGroup group;
  final String keySuffix;
  final IconData icon;
  final String title;
  final String summary;
  final List<_DormRuleRowData> rows;
}

List<_DormRuleGroupData> _buildDisplayRuleGroups(DormRulesSettings settings) {
  return <_DormRuleGroupData>[
    _DormRuleGroupData(
      group: _DormRulesDisplayGroup.basic,
      keySuffix: 'basic',
      icon: Icons.rule_folder_outlined,
      title: '基础规则',
      summary: '3 项',
      rows: <_DormRuleRowData>[
        _DormRuleRowData(
          icon: Icons.volume_off_rounded,
          title: _quietHoursSummary(settings.quietHours),
          description: '请使用耳机，避免外放声音',
        ),
        _DormRuleRowData(
          icon: Icons.lightbulb_outline_rounded,
          title: _compactRuleCopy(settings.lightsOffTime),
          description: '请使用台灯或小夜灯',
        ),
        _DormRuleRowData(
          icon: Icons.notes_rounded,
          title: '补充说明',
          description: _dormRulesPreviewLongText(settings.specialCase),
        ),
      ],
    ),
    _DormRuleGroupData(
      group: _DormRulesDisplayGroup.lightQuiet,
      keySuffix: 'light-quiet',
      icon: Icons.light_mode_outlined,
      title: '灯光与安静',
      summary: '3 项',
      rows: <_DormRuleRowData>[
        _DormRuleRowData(
          icon: Icons.menu_book_rounded,
          title: '考试周模式',
          description: settings.examWeekMode ? '提前进入静音协作' : '按日常公约执行',
        ),
        _DormRuleRowData(
          icon: Icons.light_mode_outlined,
          title: '个人照明要求',
          description: _dormRulesPreviewLongText(settings.personalLighting),
        ),
        _DormRuleRowData(
          icon: Icons.blinds_closed_outlined,
          title: '遮光帘建议',
          description: settings.blackoutCurtain ? '减少走廊和窗边杂光' : '暂不特别要求',
        ),
      ],
    ),
    _DormRuleGroupData(
      group: _DormRulesDisplayGroup.routine,
      keySuffix: 'routine',
      icon: Icons.bedtime_rounded,
      title: '闹钟与作息',
      summary: '4 项',
      rows: <_DormRuleRowData>[
        _DormRuleRowData(
          icon: Icons.vibration_rounded,
          title: '优先震动提醒',
          description: settings.vibrationFirst ? '先震动，降低打扰' : '可直接响铃提醒',
        ),
        _DormRuleRowData(
          icon: Icons.alarm_on_rounded,
          title: '闹钟响应时限',
          description: '${settings.alarmResponseSeconds} 秒内处理响铃',
        ),
        _DormRuleRowData(
          icon: Icons.bedtime_rounded,
          title: '作息习惯备注',
          description: _dormRulesPreviewLongText(settings.routineNote),
        ),
        _DormRuleRowData(
          icon: Icons.sell_outlined,
          title: '作息标签',
          description: _dormRulesTagsSummary(settings.routineTags),
        ),
      ],
    ),
    _DormRuleGroupData(
      group: _DormRulesDisplayGroup.temperature,
      keySuffix: 'temperature',
      icon: Icons.thermostat_rounded,
      title: '温度与通风',
      summary: '4 项',
      rows: <_DormRuleRowData>[
        _DormRuleRowData(
          icon: Icons.ac_unit_rounded,
          title: '夏季空调',
          description: '${settings.summerTempC.round()}°C',
        ),
        _DormRuleRowData(
          icon: Icons.thermostat_rounded,
          title: '冬季采暖',
          description: '${settings.winterTempC.round()}°C',
        ),
        _DormRuleRowData(
          icon: Icons.air_rounded,
          title: '通风时段',
          description: settings.ventilationWindow,
        ),
        _DormRuleRowData(
          icon: Icons.timer_outlined,
          title: '保持通风换气',
          description: '每天至少开窗通风${settings.ventilationMinutes.round()}分钟',
        ),
      ],
    ),
  ];
}

({String start, String end}) _splitQuietHours(String quietHours) {
  final RegExp regex = RegExp(r'(\d{1,2}:\d{2})');
  final List<String> matches = regex
      .allMatches(quietHours)
      .map((RegExpMatch match) => match.group(1) ?? '')
      .where((String value) => value.isNotEmpty)
      .toList(growable: false);
  return (
    start: matches.isNotEmpty ? matches.first : '23:00',
    end: matches.length > 1 ? matches[1] : '07:00',
  );
}

String _settingsSignature(DormRulesSettings settings) {
  return <String>[
    settings.quietHours,
    settings.lightsOffTime,
    settings.specialCase,
    settings.personalLighting,
    settings.examWeekMode.toString(),
    settings.blackoutCurtain.toString(),
    settings.vibrationFirst.toString(),
    settings.alarmResponseSeconds.toString(),
    settings.routineNote,
    settings.routineTags.join(','),
    settings.summerTempC.toStringAsFixed(1),
    settings.winterTempC.toStringAsFixed(1),
    settings.ventilationWindow,
    settings.ventilationMinutes.toStringAsFixed(1),
  ].join('|');
}

String _quietHoursSummary(String quietHours) {
  final ({String start, String end}) parsed = _splitQuietHours(quietHours);
  return '${parsed.start}后保持安静';
}

String _compactRuleCopy(String value) {
  return value.replaceAll(' ', '');
}

String _dormRulesFirstTimeOrPreview(String value) {
  final RegExpMatch? match = RegExp(r'\d{1,2}:\d{2}').firstMatch(value);
  if (match != null) {
    return match.group(0) ?? _dormRulesPreviewText(value);
  }
  return _dormRulesPreviewText(value);
}

String _dormRulesPreviewText(String value) {
  final String compact = value.trim().replaceAll(RegExp(r'\s+'), '');
  if (compact.isEmpty) {
    return '未设置';
  }
  const int maxPreviewLength = 8;
  if (compact.length <= maxPreviewLength) {
    return compact;
  }
  return '${compact.substring(0, maxPreviewLength)}...';
}

String _dormRulesPreviewLongText(String value) {
  final String compact = value.trim().replaceAll(RegExp(r'\s+'), '');
  if (compact.isEmpty) {
    return '未设置';
  }
  const int maxPreviewLength = 22;
  if (compact.length <= maxPreviewLength) {
    return compact;
  }
  return '${compact.substring(0, maxPreviewLength)}...';
}

String _dormRulesTagsSummary(List<String> tags) {
  if (tags.isEmpty) {
    return '未设置';
  }
  return tags.join(' · ');
}

double _rulesPageWidthFactor(double maxWidth) {
  if (maxWidth >= 1200) {
    return 0.38;
  }
  if (maxWidth >= 900) {
    return 0.46;
  }
  if (maxWidth >= 700) {
    return 0.58;
  }
  if (maxWidth >= 520) {
    return 0.74;
  }
  return 1;
}

Color _rulesIntroFill(AppSemanticColors appColors) {
  return Color.lerp(appColors.accent, Colors.white, 0.28)!;
}

Color _rulesAccentIconFill(AppSemanticColors appColors) {
  return Color.lerp(appColors.accent, Colors.white, 0.12)!;
}

Color _rulesMutedIconFill(AppSemanticColors appColors) {
  return Color.lerp(_rulesAccentIconFill(appColors), Colors.white, 0.62)!;
}

String _pendingRuleTitle(
  DormRulesSettings currentSettings,
  DormRulesSettings next,
) {
  if (next.quietHours != currentSettings.quietHours) {
    return '安静时段调整';
  }
  if (_compactRuleCopy(next.lightsOffTime) !=
      _compactRuleCopy(currentSettings.lightsOffTime)) {
    return '熄灯提醒调整';
  }
  if (next.specialCase.trim().isNotEmpty &&
      next.specialCase.trim() != currentSettings.specialCase.trim()) {
    return '补充说明更新';
  }
  return '宿舍公约调整';
}

String _pendingRuleSummary(
  DormPendingRuleProposal proposal,
  DormRulesSettings currentSettings,
) {
  final DormRulesSettings next = proposal.proposedSettings;
  String detail = '请查看新的宿舍公约草案';
  if (next.quietHours != currentSettings.quietHours) {
    detail = '安静时段调整为 ${next.quietHours.replaceAll(' ', '')}';
  } else if (_compactRuleCopy(next.lightsOffTime) !=
      _compactRuleCopy(currentSettings.lightsOffTime)) {
    detail = '熄灯提醒改为 ${_compactRuleCopy(next.lightsOffTime)}';
  } else if (next.specialCase.trim().isNotEmpty &&
      next.specialCase.trim() != currentSettings.specialCase.trim()) {
    detail = next.specialCase.trim();
  }
  return '${proposal.proposerName}提议：$detail';
}
