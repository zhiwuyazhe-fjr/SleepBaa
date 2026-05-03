import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_settings_group.dart';
import 'package:sleep_dorm_app/core/widgets/modals/app_modal.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';

class DormRulesPage extends StatefulWidget {
  const DormRulesPage({super.key, this.showReviewOverlayOnOpen = false});

  final bool showReviewOverlayOnOpen;

  @override
  State<DormRulesPage> createState() => _DormRulesPageState();
}

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
    setState(() => _isEditing = false);
  }

  Future<void> _showLightsOffEditor() async {
    final TextEditingController controller = TextEditingController(
      text: _lightsOffController.text,
    );
    await showAppModal<void>(
      context,
      spec: AppEditorSheetSpec<void>(
        useSafeArea: true,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (BuildContext sheetContext) {
          return AppBottomSheetScaffold(
            key: const ValueKey<String>('dorm-rules-lights-sheet'),
            title: '熄灯提醒',
            description: '填写室友确认后的熄灯约定。',
            includeBottomViewInsets: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: '例如 23:30后关闭主灯'),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
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
                            _lightsOffController.text = controller.text.trim();
                          });
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    controller.dispose();
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
                          bottom: showEditView ? 132 : AppSpacing.sm,
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: FractionallySizedBox(
                            widthFactor: widthFactor,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                showEditView
                                    ? _DormRulesEditHeader(
                                        onBack: () =>
                                            _cancelEditing(dorm.rulesSettings),
                                      )
                                    : _DormRulesDisplayHeader(
                                        palette: palette,
                                        canReviewProposal: canReviewProposal,
                                        hasPendingProposal: hasPendingProposal,
                                        onBack: () =>
                                            Navigator.of(context).maybePop(),
                                        onEdit: _enterEditMode,
                                        onReview: () {
                                          setState(
                                            () => _showReviewOverlay = true,
                                          );
                                        },
                                      ),
                                if (showEditView) ...<Widget>[
                                  _DormRulesEditBody(
                                    palette: palette,
                                    quietStartController: _quietStartController,
                                    quietEndController: _quietEndController,
                                    lightsOffController: _lightsOffController,
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
                                    ventilationMinutes: _ventilationMinutes,
                                    selectedVentilationWindow:
                                        _selectedVentilationWindow,
                                    routineTags: _routineTags,
                                    onEditLightsOff: _showLightsOffEditor,
                                    onExamWeekModeChanged: (bool value) =>
                                        setState(() => _examWeekMode = value),
                                    onBlackoutCurtainChanged: (bool value) =>
                                        setState(
                                          () => _blackoutCurtain = value,
                                        ),
                                    onVibrationFirstChanged: (bool value) =>
                                        setState(() => _vibrationFirst = value),
                                    onSummerTempChanged: (double value) =>
                                        setState(() => _summerTemp = value),
                                    onWinterTempChanged: (double value) =>
                                        setState(() => _winterTemp = value),
                                    onVentilationMinutesChanged:
                                        (double value) => setState(
                                          () => _ventilationMinutes = value,
                                        ),
                                    onVentilationWindowChanged:
                                        (String value) => setState(
                                          () => _selectedVentilationWindow =
                                              value,
                                        ),
                                    onRoutineTagToggled: (String value) {
                                      setState(() {
                                        if (_routineTags.contains(value)) {
                                          _routineTags = _routineTags
                                              .where(
                                                (String item) => item != value,
                                              )
                                              .toList(growable: false);
                                        } else {
                                          _routineTags = <String>[
                                            ..._routineTags,
                                            value,
                                          ];
                                        }
                                      });
                                    },
                                  ),
                                ] else ...<Widget>[
                                  _DormRulesDisplayBody(
                                    dorm: dorm,
                                    palette: palette,
                                  ),
                                  _DormRulesDisplayBottomBar(
                                    palette: palette,
                                    onPressed: hasPendingProposal
                                        ? () {
                                            if (canReviewProposal) {
                                              setState(
                                                () => _showReviewOverlay = true,
                                              );
                                            }
                                          }
                                        : () {
                                            notifyPassiveToast(
                                              context,
                                              message: '已记录你的确认，一起把约定执行下去吧。',
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
                                                () => _showReviewOverlay = true,
                                              );
                                            }
                                          : null,
                                    ),
                                ],
                              ],
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
                              padding: const EdgeInsets.only(top: 78),
                              child: Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    right: AppSpacing.lg,
                                  ),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 280,
                                    ),
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
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 760),
                              child: _DormRulesEditBottomBar(
                                palette: palette,
                                onCancel: () =>
                                    _cancelEditing(dorm.rulesSettings),
                                onConfirm: _handleSave,
                              ),
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
      child: Row(
        children: <Widget>[
          _DormRulesBackButton(onPressed: onBack),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '宿舍公约',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (canReviewProposal)
            _DormRulesHeaderPill(
              label: '待确认',
              icon: Icons.mark_chat_unread_rounded,
              palette: palette,
              onPressed: onReview,
            )
          else if (!hasPendingProposal)
            _DormRulesHeaderPill(
              key: const ValueKey<String>('dorm-rules-edit-entry'),
              label: '编辑',
              icon: Icons.edit_outlined,
              palette: palette,
              onPressed: onEdit,
            ),
        ],
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
      child: Row(
        children: <Widget>[
          _DormRulesBackButton(onPressed: onBack),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '编辑宿舍公约',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DormRulesBackButton extends StatelessWidget {
  const _DormRulesBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.button,
        onTap: onPressed,
        child: const SizedBox.square(
          dimension: 40,
          child: Icon(
            Icons.chevron_left_rounded,
            size: 22,
            color: AppColors.textPrimary,
          ),
        ),
      ),
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
    return Material(
      color: Colors.transparent,
      child: Ink(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: palette.welcomeAccentColor,
          borderRadius: AppRadius.button,
        ),
        child: InkWell(
          borderRadius: AppRadius.button,
          onTap: onPressed,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 16, color: palette.primaryDeep),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: palette.primaryDeep,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DormRulesDisplayBody extends StatelessWidget {
  const _DormRulesDisplayBody({required this.dorm, required this.palette});

  final Dorm dorm;
  final NightMoodPalette palette;

  @override
  Widget build(BuildContext context) {
    final List<_DormRuleRowData> rules = _buildDisplayRules(dorm.rulesSettings);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _DormRulesIntroCard(palette: palette),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '基本规则',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _DormRulesGroupCard(rules: rules, palette: palette),
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
    return AppCard(
      borderRadius: AppRadius.card,
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: _rulesIntroFill(palette),
      boxShadow: const <BoxShadow>[],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.md),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.shield_outlined,
              size: 24,
              color: palette.primaryDeep,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '共同维护良好宿舍环境',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: palette.primaryDeep,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '以下是大家共同制定的宿舍公约，请每位成员认真遵守。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: palette.primaryDeep,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DormRulesGroupCard extends StatelessWidget {
  const _DormRulesGroupCard({required this.rules, required this.palette});

  final List<_DormRuleRowData> rules;
  final NightMoodPalette palette;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const ValueKey<String>('dorm-rules-basic-group'),
      borderRadius: AppRadius.card,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      color: Colors.white,
      boxShadow: const <BoxShadow>[],
      child: Column(
        children: <Widget>[
          for (int index = 0; index < rules.length; index++) ...<Widget>[
            _DormRulesGroupRow(
              data: rules[index],
              palette: palette,
              iconFill: index.isEven
                  ? _rulesMutedIconFill(palette)
                  : _rulesAccentIconFill(palette),
            ),
            if (index != rules.length - 1) const SizedBox(height: 2),
          ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconFill,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(data.icon, size: 18, color: palette.primaryDeep),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  data.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  data.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.check_rounded,
              size: 14,
              color: Colors.white,
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
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            borderRadius: BorderRadius.circular(20),
            padding: const EdgeInsets.all(14),
            color: Colors.white,
            boxShadow: const <BoxShadow>[],
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _rulesMutedIconFill(palette),
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.timer_outlined,
                    size: 20,
                    color: palette.primaryDeep,
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        _pendingRuleSummary(proposal, currentSettings),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
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
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: palette.welcomeAccentColor,
                            borderRadius: BorderRadius.circular(AppSpacing.sm),
                          ),
                          child: Text(
                            '确认',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: palette.primaryDeep,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: _DormRulesActionButton(
        label: '我同意遵守以上公约',
        icon: Icons.check_circle_outline_rounded,
        fillColor: palette.welcomeAccentColor,
        textColor: palette.primaryDeep,
        onPressed: enabled ? onPressed : null,
        buttonHeight: 50,
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
    required this.onEditLightsOff,
    required this.onExamWeekModeChanged,
    required this.onBlackoutCurtainChanged,
    required this.onVibrationFirstChanged,
    required this.onSummerTempChanged,
    required this.onWinterTempChanged,
    required this.onVentilationMinutesChanged,
    required this.onVentilationWindowChanged,
    required this.onRoutineTagToggled,
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
  final VoidCallback onEditLightsOff;
  final ValueChanged<bool> onExamWeekModeChanged;
  final ValueChanged<bool> onBlackoutCurtainChanged;
  final ValueChanged<bool> onVibrationFirstChanged;
  final ValueChanged<double> onSummerTempChanged;
  final ValueChanged<double> onWinterTempChanged;
  final ValueChanged<double> onVentilationMinutesChanged;
  final ValueChanged<String> onVentilationWindowChanged;
  final ValueChanged<String> onRoutineTagToggled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppCard(
            key: const ValueKey<String>('dorm-rules-edit-intro'),
            borderRadius: AppRadius.card,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            color: palette.primaryHighlight,
            boxShadow: const <BoxShadow>[],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '修改后需要室友确认',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: palette.primaryDeep,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '本页保存的是调整草案，不会立即覆盖当前正式公约。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.primaryDeep,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppSettingsGroup(
            key: const ValueKey<String>('dorm-rules-basic-group'),
            title: '基础规则',
            children: <Widget>[
              _DormRulesEditableQuietHoursCard(
                palette: palette,
                quietStartController: quietStartController,
                quietEndController: quietEndController,
              ),
              _DormRulesEditableLightsCard(
                palette: palette,
                lightsOffCopy: lightsOffController.text.trim(),
                onTap: onEditLightsOff,
              ),
              _DormRulesEditableNoteCard(
                palette: palette,
                noteController: noteController,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSettingsGroup(
            title: '灯光与安静',
            children: <Widget>[
              _DormRulesToggleCard(
                palette: palette,
                icon: Icons.menu_book_rounded,
                title: '考试周模式',
                description: '提前进入静音协作',
                value: examWeekMode,
                onChanged: onExamWeekModeChanged,
              ),
              _DormRulesTextFieldCard(
                palette: palette,
                icon: Icons.light_mode_outlined,
                title: '个人照明要求',
                controller: personalLightingController,
                minLines: 1,
                maxLines: 2,
                hintText: '例如：仅使用个人台灯，避免直射室友。',
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
            children: <Widget>[
              _DormRulesToggleCard(
                palette: palette,
                icon: Icons.vibration_rounded,
                title: '优先震动提醒',
                description: '先震动，降低打扰',
                value: vibrationFirst,
                onChanged: onVibrationFirstChanged,
              ),
              _DormRulesTextFieldCard(
                palette: palette,
                icon: Icons.alarm_on_rounded,
                title: '闹钟响应时限',
                controller: alarmResponseController,
                keyboardType: TextInputType.number,
                suffixText: '秒',
                hintText: '60',
              ),
              _DormRulesTextFieldCard(
                palette: palette,
                icon: Icons.bedtime_rounded,
                title: '作息习惯备注',
                controller: routineNoteController,
                minLines: 1,
                maxLines: 2,
                hintText: '例如：平时起床时间约为 08:30。',
              ),
              _DormRulesChoiceCard(
                palette: palette,
                icon: Icons.sell_outlined,
                title: '作息标签',
                options: const <String>['考试周', '夜猫子', '早起党'],
                selectedOptions: routineTags,
                multiSelect: true,
                onSelected: onRoutineTagToggled,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSettingsGroup(
            title: '温度与通风',
            children: <Widget>[
              _DormRulesSliderCard(
                palette: palette,
                icon: Icons.ac_unit_rounded,
                title: '夏季空调',
                value: summerTemp,
                min: 20,
                max: 30,
                unit: '°C',
                onChanged: onSummerTempChanged,
              ),
              _DormRulesSliderCard(
                palette: palette,
                icon: Icons.thermostat_rounded,
                title: '冬季采暖',
                value: winterTemp,
                min: 16,
                max: 28,
                unit: '°C',
                onChanged: onWinterTempChanged,
              ),
              _DormRulesChoiceCard(
                palette: palette,
                icon: Icons.air_rounded,
                title: '通风时段',
                options: const <String>['早晨', '中午', '睡前'],
                selectedOptions: <String>[selectedVentilationWindow],
                onSelected: onVentilationWindowChanged,
              ),
              _DormRulesSliderCard(
                palette: palette,
                icon: Icons.timer_outlined,
                title: '通风时长',
                value: ventilationMinutes,
                min: 10,
                max: 60,
                unit: '分钟',
                onChanged: onVentilationMinutesChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DormRulesEditableQuietHoursCard extends StatelessWidget {
  const _DormRulesEditableQuietHoursCard({
    required this.palette,
    required this.quietStartController,
    required this.quietEndController,
  });

  final NightMoodPalette palette;
  final TextEditingController quietStartController;
  final TextEditingController quietEndController;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _DormRulesEditIcon(
                iconKey: const ValueKey<String>(
                  'dorm-rules-edit-icon-quiet-hours',
                ),
                palette: palette,
                icon: Icons.volume_off_rounded,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '安静时段',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool stackFields =
                  constraints.maxWidth < AppSpacing.xxxl * 7;
              final List<Widget> fields = <Widget>[
                _DormRulesTimeField(
                  label: '开始',
                  controller: quietStartController,
                ),
                _DormRulesTimeField(
                  label: '结束',
                  controller: quietEndController,
                ),
              ];
              if (stackFields) {
                return Column(
                  children: <Widget>[
                    fields.first,
                    const SizedBox(height: AppSpacing.xs),
                    fields.last,
                  ],
                );
              }
              return Row(
                children: <Widget>[
                  Expanded(child: fields.first),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: fields.last),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DormRulesTimeField extends StatelessWidget {
  const _DormRulesTimeField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

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
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          TextField(
            controller: controller,
            keyboardType: TextInputType.datetime,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            decoration: const InputDecoration(
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
    return AppSettingsItem(
      title: '熄灯提醒',
      icon: Icons.lightbulb_outline_rounded,
      iconColor: palette.primaryDeep,
      iconBackgroundColor: AppColors.surfaceMuted,
      iconContainerKey: const ValueKey<String>(
        'dorm-rules-edit-icon-lights-off',
      ),
      leadingWidth: AppSpacing.xxxl,
      onTap: onTap,
      trailing: _DormRulesValueTrailing(
        value: lightsOffCopy,
        color: palette.primaryDeep,
        showChevron: true,
      ),
    );
  }
}

class _DormRulesEditableNoteCard extends StatelessWidget {
  const _DormRulesEditableNoteCard({
    required this.palette,
    required this.noteController,
  });

  final NightMoodPalette palette;
  final TextEditingController noteController;

  @override
  Widget build(BuildContext context) {
    return _DormRulesTextFieldCard(
      palette: palette,
      icon: Icons.notes_rounded,
      title: '补充说明',
      controller: noteController,
      minLines: 2,
      maxLines: 3,
      hintText: '例如：考试周自动提前静音时间...',
    );
  }
}

class _DormRulesTextFieldCard extends StatelessWidget {
  const _DormRulesTextFieldCard({
    required this.palette,
    required this.icon,
    required this.title,
    required this.controller,
    this.keyboardType,
    this.minLines = 1,
    this.maxLines = 1,
    this.hintText,
    this.suffixText,
  });

  final NightMoodPalette palette;
  final IconData icon;
  final String title;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int minLines;
  final int maxLines;
  final String? hintText;
  final String? suffixText;

  @override
  Widget build(BuildContext context) {
    return _DormRulesSettingsControlRow(
      palette: palette,
      icon: icon,
      title: title,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: AppRadius.control,
        ),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          minLines: minLines,
          maxLines: maxLines,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
            height: 1.35,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            suffixText: suffixText,
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
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
    return _DormRulesSettingsControlRow(
      palette: palette,
      icon: icon,
      iconKey: ValueKey<String>('dorm-rules-edit-icon-$title'),
      title: title,
      description: description,
      trailing: _DormRulesThemeSwitch(
        switchKey: title == '考试周模式'
            ? const ValueKey<String>('dorm-rules-switch-exam-week')
            : null,
        palette: palette,
        value: value,
        onChanged: onChanged,
      ),
      onTap: () => onChanged(!value),
    );
  }
}

class _DormRulesChoiceCard extends StatelessWidget {
  const _DormRulesChoiceCard({
    required this.palette,
    required this.icon,
    required this.title,
    required this.options,
    required this.selectedOptions,
    required this.onSelected,
    this.multiSelect = false,
  });

  final NightMoodPalette palette;
  final IconData icon;
  final String title;
  final List<String> options;
  final List<String> selectedOptions;
  final ValueChanged<String> onSelected;
  final bool multiSelect;

  @override
  Widget build(BuildContext context) {
    return _DormRulesSettingsControlRow(
      palette: palette,
      icon: icon,
      title: title,
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: options
            .map((String option) {
              final bool selected = selectedOptions.contains(option);
              return FilterChip(
                selected: selected,
                showCheckmark: multiSelect,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                label: Text(option),
                onSelected: (_) => onSelected(option),
                selectedColor: palette.welcomeAccentColor,
                backgroundColor: AppColors.surfaceMuted,
                side: BorderSide(
                  color: selected
                      ? palette.primaryDeep.withAlpha(80)
                      : Colors.transparent,
                ),
                labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? palette.primaryDeep : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _DormRulesSliderCard extends StatelessWidget {
  const _DormRulesSliderCard({
    required this.palette,
    required this.icon,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
  });

  final NightMoodPalette palette;
  final IconData icon;
  final String title;
  final double value;
  final double min;
  final double max;
  final String unit;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final String roundedValue = value.round().toString();
    return _DormRulesSettingsControlRow(
      palette: palette,
      icon: icon,
      title: title,
      trailing: _DormRulesValueTrailing(
        value: '$roundedValue$unit',
        color: palette.primaryDeep,
      ),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: AppSpacing.xxs,
          overlayShape: const RoundSliderOverlayShape(
            overlayRadius: AppSpacing.md,
          ),
        ),
        child: Slider(
          min: min,
          max: max,
          divisions: (max - min).round(),
          value: value.clamp(min, max),
          activeColor: palette.primaryDeep,
          inactiveColor: palette.primarySoft.withAlpha(72),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _DormRulesSettingsControlRow extends StatelessWidget {
  const _DormRulesSettingsControlRow({
    required this.palette,
    required this.icon,
    required this.title,
    this.iconKey,
    this.description,
    this.trailing,
    this.child,
    this.onTap,
  });

  final NightMoodPalette palette;
  final IconData icon;
  final String title;
  final Key? iconKey;
  final String? description;
  final Widget? trailing;
  final Widget? child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: child == null
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: <Widget>[
          _DormRulesEditIcon(iconKey: iconKey, palette: palette, icon: icon),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (description != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    description!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.25,
                    ),
                  ),
                ],
                if (child != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  child!,
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.control,
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _DormRulesValueTrailing extends StatelessWidget {
  const _DormRulesValueTrailing({
    required this.value,
    required this.color,
    this.showChevron = false,
  });

  final String value;
  final Color color;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (showChevron) ...<Widget>[
          const SizedBox(width: AppSpacing.xxs),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.textHint,
          ),
        ],
      ],
    );
  }
}

class _DormRulesEditIcon extends StatelessWidget {
  const _DormRulesEditIcon({
    this.iconKey,
    required this.palette,
    required this.icon,
  });

  final Key? iconKey;
  final NightMoodPalette palette;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSpacing.xl,
      child: Center(
        child: Container(
          key: iconKey,
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: AppRadius.iconContainer,
          ),
          child: Center(
            child: Icon(icon, size: 20, color: palette.primaryDeep),
          ),
        ),
      ),
    );
  }
}

class _DormRulesThemeSwitch extends StatelessWidget {
  const _DormRulesThemeSwitch({
    this.switchKey,
    required this.palette,
    required this.value,
    required this.onChanged,
  });

  final Key? switchKey;
  final NightMoodPalette palette;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Switch(
      key: switchKey,
      value: value,
      onChanged: onChanged,
      thumbColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> states,
      ) {
        return states.contains(WidgetState.selected)
            ? palette.primary
            : AppColors.surface;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> states,
      ) {
        return states.contains(WidgetState.selected)
            ? palette.primaryHighlight
            : AppColors.surfaceMuted;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> states,
      ) {
        return states.contains(WidgetState.selected)
            ? palette.primarySoft
            : AppColors.surfaceBorder;
      }),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _DormRulesEditBottomBar extends StatelessWidget {
  const _DormRulesEditBottomBar({
    required this.palette,
    required this.onCancel,
    required this.onConfirm,
  });

  final NightMoodPalette palette;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        10,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.primaryHighlight,
              borderRadius: BorderRadius.circular(AppSpacing.md),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.groups_rounded,
                  size: 18,
                  color: palette.primaryDeep,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '保存后发送给 3 位室友确认',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.primaryDeep,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _DormRulesActionButton(
                  label: '取消',
                  fillColor: Colors.white,
                  textColor: AppColors.textPrimary,
                  onPressed: onCancel,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DormRulesActionButton(
                  buttonKey: const ValueKey<String>('dorm-rules-submit-button'),
                  label: '发起确认',
                  icon: Icons.send_rounded,
                  fillColor: palette.welcomeAccentColor,
                  textColor: palette.primaryDeep,
                  onPressed: onConfirm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DormRulesActionButton extends StatelessWidget {
  const _DormRulesActionButton({
    this.buttonKey,
    required this.label,
    required this.fillColor,
    required this.textColor,
    required this.onPressed,
    this.icon,
    this.buttonHeight = 48,
  });

  final Key? buttonKey;
  final String label;
  final Color fillColor;
  final Color textColor;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double buttonHeight;

  @override
  Widget build(BuildContext context) {
    final Color resolvedFill = onPressed == null
        ? fillColor.withAlpha(132)
        : fillColor;
    final Widget content = SizedBox(
      key: buttonKey,
      height: buttonHeight,
      child: Center(
        child: AnimatedScale(
          scale: onPressed == null ? 1 : 1,
          duration: const Duration(milliseconds: 120),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 18, color: textColor),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (onPressed == null) {
      return Ink(
        decoration: BoxDecoration(
          color: resolvedFill,
          borderRadius: AppRadius.button,
        ),
        child: content,
      );
    }
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: resolvedFill,
          borderRadius: AppRadius.button,
        ),
        child: InkWell(
          borderRadius: AppRadius.button,
          onTap: onPressed,
          child: content,
        ),
      ),
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
    return Material(
      color: Colors.transparent,
      child: AppCard(
        borderRadius: AppRadius.card,
        boxShadow: AppColors.floatingShadow,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _DormRulesActionButton(
              label: '同意',
              fillColor: palette.welcomeAccentColor,
              textColor: palette.primaryDeep,
              onPressed: onApprove,
            ),
            const SizedBox(height: AppSpacing.sm),
            _DormRulesActionButton(
              label: '不同意',
              fillColor: AppColors.surfaceMuted,
              textColor: AppColors.textPrimary,
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

List<_DormRuleRowData> _buildDisplayRules(DormRulesSettings settings) {
  return <_DormRuleRowData>[
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
      icon: Icons.air_rounded,
      title: '保持通风换气',
      description: '每天至少开窗通风${settings.ventilationMinutes.round()}分钟',
    ),
    const _DormRuleRowData(
      icon: Icons.delete_outline_rounded,
      title: '及时清理垃圾',
      description: '垃圾不过夜，保持宿舍整洁',
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

Color _rulesIntroFill(NightMoodPalette palette) {
  return Color.lerp(palette.welcomeAccentColor, Colors.white, 0.28)!;
}

Color _rulesAccentIconFill(NightMoodPalette palette) {
  return Color.lerp(palette.welcomeAccentColor, Colors.white, 0.12)!;
}

Color _rulesMutedIconFill(NightMoodPalette palette) {
  return Color.lerp(_rulesAccentIconFill(palette), Colors.white, 0.62)!;
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
