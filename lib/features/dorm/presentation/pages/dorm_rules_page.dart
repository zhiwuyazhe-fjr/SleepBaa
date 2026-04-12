import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/core/widgets/ambient_orb.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';

class DormRulesPage extends StatefulWidget {
  const DormRulesPage({
    super.key,
    this.showReviewOverlayOnOpen = false,
  });

  final bool showReviewOverlayOnOpen;

  @override
  State<DormRulesPage> createState() => _DormRulesPageState();
}

class _DormRulesPageState extends State<DormRulesPage> {
  final TextEditingController _quietHoursController = TextEditingController();
  final TextEditingController _specialCaseController = TextEditingController();
  final TextEditingController _lightsOffController = TextEditingController();
  final TextEditingController _personalLightingController =
      TextEditingController();
  final TextEditingController _alarmResponseController =
      TextEditingController();
  final TextEditingController _routineNoteController = TextEditingController();

  bool _initialized = false;
  bool _showReviewOverlay = false;
  bool _examWeekMode = true;
  bool _blackoutCurtain = true;
  bool _vibrationFirst = true;
  double _summerTemp = 26;
  double _winterTemp = 22;
  double _ventilationMinutes = 30;
  String _selectedVentilationWindow = '早晨';
  List<String> _routineTags = const <String>['考试周', '夜猫子', '早起党'];
  String _loadedProposalId = '';
  final TextEditingController _objectionReasonController =
      TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Dorm dorm = context.appServices.dormRepository.currentDorm;
    final String proposalId = dorm.pendingRuleProposal?.id ?? '';
    if (!_initialized || proposalId != _loadedProposalId) {
      _populateFromDorm(dorm);
      _loadedProposalId = proposalId;
    }
    _initialized = true;
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
    _quietHoursController.dispose();
    _specialCaseController.dispose();
    _lightsOffController.dispose();
    _personalLightingController.dispose();
    _alarmResponseController.dispose();
    _routineNoteController.dispose();
    _objectionReasonController.dispose();
    super.dispose();
  }

  void _populateFromDorm(Dorm dorm) {
    final DormRulesSettings settings =
        dorm.pendingRuleProposal?.proposedSettings ?? dorm.rulesSettings;
    _quietHoursController.text = settings.quietHours;
    _specialCaseController.text = settings.specialCase;
    _lightsOffController.text = settings.lightsOffTime;
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
    final String currentUserId = context.appServices.authRepository.currentUser.uid;
    return proposal != null &&
        proposal.proposerUid != currentUserId &&
        proposal.needsReviewFrom(currentUserId);
  }

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();
    final Dorm dorm = context.appServices.dormRepository.currentDorm;
    if (dorm.pendingRuleProposal != null) {
      return;
    }
    final DormRulesSettings current =
        dorm.rulesSettings;
    final DormRulesSettings next = current.copyWith(
      quietHours: _quietHoursController.text.trim(),
      specialCase: _specialCaseController.text.trim(),
      lightsOffTime: _lightsOffController.text.trim(),
      personalLighting: _personalLightingController.text.trim(),
      examWeekMode: _examWeekMode,
      blackoutCurtain: _blackoutCurtain,
      vibrationFirst: _vibrationFirst,
      alarmResponseSeconds:
          int.tryParse(_alarmResponseController.text.trim()) ??
          current.alarmResponseSeconds,
      routineNote: _routineNoteController.text.trim(),
      routineTags: _routineTags,
      summerTempC: _summerTemp,
      winterTempC: _winterTemp,
      ventilationWindow: _selectedVentilationWindow,
      ventilationMinutes: _ventilationMinutes,
    );
    await context.appServices.dormFacade.saveRules(next);
    if (!mounted) {
      return;
    }
    await notifyPassiveToast(context, message: '已提交待确认规则，等待室友确认。');
    if (!mounted) {
      return;
    }
    context.go(AppRoutes.dorm);
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
        final String proposalId = dorm.pendingRuleProposal?.id ?? '';
        if (proposalId != _loadedProposalId) {
          _populateFromDorm(dorm);
          _loadedProposalId = proposalId;
          if (_showReviewOverlay && !_canCurrentUserReviewProposal(dorm)) {
            _showReviewOverlay = false;
          }
        }
        final NightMoodPalette palette = context.nightMoodPalette;
        final bool hasPendingProposal = dorm.pendingRuleProposal != null;
        final bool canReviewProposal = _canCurrentUserReviewProposal(dorm);
        final bool lockForm = hasPendingProposal;
        return Scaffold(
      appBar: AppBar(
        title: const Text('宿舍公约'),
        actions: <Widget>[
          if (canReviewProposal)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  IconButton(
                    onPressed: () {
                      setState(() => _showReviewOverlay = !_showReviewOverlay);
                    },
                    icon: const Icon(Icons.mark_chat_unread_rounded),
                    tooltip: '查看待确认规则',
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface.withAlpha(246),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 24,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: PrimaryButton(
            label: hasPendingProposal ? '规则等待确认中' : '保存规则',
            onPressed: lockForm ? null : _handleSave,
          ),
        ),
      ),
      body: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0xFFEAF7F9),
                    Color(0xFFF7F4EA),
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -60,
            right: -40,
            child: AmbientOrb(
              size: 180,
              color: palette.primarySoft,
              animate: true,
            ),
          ),
          const Positioned(
            top: 220,
            left: -48,
            child: AmbientOrb(
              size: 140,
              color: Color(0xFFE5C187),
              animate: true,
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                140,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _RulesHeroCard(dorm: dorm),
                  const SizedBox(height: AppSpacing.lg),
                  if (hasPendingProposal)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: AppCard(
                        color: canReviewProposal
                            ? palette.primaryHighlight
                            : AppColors.surfaceMuted,
                        child: Text(
                          canReviewProposal
                              ? '有室友提交了新规则，确认后才会正式覆盖当前宿舍公约。'
                              : '当前有一份待确认的新规则，正式公约会在全员同意后更新。',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  _SectionCard(
                    title: '声音公约',
                    subtitle: 'Quiet hours & noise limits',
                    trailing: Switch(
                      value: _examWeekMode,
                      onChanged: lockForm
                          ? null
                          : (bool value) {
                              setState(() => _examWeekMode = value);
                            },
                    ),
                    child: Column(
                      children: <Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        _RuleField(
                          label: '静音时段',
                          controller: _quietHoursController,
                          enabled: !lockForm,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _RuleField(
                          label: '特殊情况说明',
                          controller: _specialCaseController,
                          maxLines: 3,
                          enabled: !lockForm,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SectionCard(
                    title: '灯光管理',
                    subtitle: 'Light usage & sleep hygiene',
                    child: Column(
                      children: <Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        _RuleField(
                          label: '主灯关闭时间',
                          controller: _lightsOffController,
                          enabled: !lockForm,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _RuleField(
                          label: '个人照明要求',
                          controller: _personalLightingController,
                          maxLines: 3,
                          enabled: !lockForm,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        CheckboxListTile(
                          value: _blackoutCurtain,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('建议统一使用遮光帘'),
                          subtitle: const Text('减少走廊和窗边杂光的影响'),
                          onChanged: lockForm
                              ? null
                              : (bool? value) {
                                  setState(
                                    () => _blackoutCurtain = value ?? false,
                                  );
                                },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SectionCard(
                    title: '闹钟与作息',
                    subtitle: 'Alarms and daily cycles',
                    trailing: Switch(
                      value: _vibrationFirst,
                      onChanged: lockForm
                          ? null
                          : (bool value) {
                              setState(() => _vibrationFirst = value);
                            },
                    ),
                    child: Column(
                      children: <Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        _RuleField(
                          label: '闹钟响应时限（秒）',
                          controller: _alarmResponseController,
                          keyboardType: TextInputType.number,
                          enabled: !lockForm,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _RuleField(
                          label: '作息习惯备注',
                          controller: _routineNoteController,
                          maxLines: 3,
                          enabled: !lockForm,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: <String>['考试周', '夜猫子', '早起党']
                              .map(
                                (String label) => _TagChip(
                                  label: label,
                                  active: _routineTags.contains(label),
                                  enabled: !lockForm,
                                  onTap: () {
                                    setState(() {
                                      if (_routineTags.contains(label)) {
                                        _routineTags = _routineTags
                                            .where(
                                              (String item) => item != label,
                                            )
                                            .toList(growable: false);
                                      } else {
                                        _routineTags = <String>[
                                          ..._routineTags,
                                          label,
                                        ];
                                      }
                                    });
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SectionCard(
                    title: '温度与通风',
                    subtitle: 'AC & ventilation preferences',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        _LabeledSlider(
                          label: '夏季空调 ${_summerTemp.toStringAsFixed(0)}°C',
                          min: 20,
                          max: 30,
                          value: _summerTemp,
                          onChanged: lockForm
                              ? null
                              : (double value) {
                                  setState(() => _summerTemp = value);
                                },
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _LabeledSlider(
                          label: '冬季采暖 ${_winterTemp.toStringAsFixed(0)}°C',
                          min: 16,
                          max: 28,
                          value: _winterTemp,
                          onChanged: lockForm
                              ? null
                              : (double value) {
                                  setState(() => _winterTemp = value);
                                },
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          '通风时段',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: <String>['早晨', '中午', '睡前']
                              .map(
                                (String label) => _TagChip(
                                  label: label,
                                  active: _selectedVentilationWindow == label,
                                  enabled: !lockForm,
                                  onTap: () {
                                    setState(() {
                                      _selectedVentilationWindow = label;
                                    });
                                  },
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _LabeledSlider(
                          label: '通风时长 ${_ventilationMinutes.round()} 分钟',
                          min: 10,
                          max: 60,
                          value: _ventilationMinutes,
                          onChanged: lockForm
                              ? null
                              : (double value) {
                                  setState(() => _ventilationMinutes = value);
                                },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showReviewOverlay && canReviewProposal)
            Positioned(
              top: MediaQuery.paddingOf(context).top + kToolbarHeight - 4,
              right: AppSpacing.lg,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Material(
                  color: Colors.transparent,
                  child: AppCard(
                    boxShadow: AppColors.floatingShadow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        PrimaryButton(label: '同意', onPressed: _handleApprove),
                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton(
                          onPressed: _handleReject,
                          child: const Text('不同意'),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: _objectionReasonController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: '输入你有异议的地方',
                            filled: true,
                            fillColor: AppColors.surfaceMuted,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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

class _RulesHeroCard extends StatelessWidget {
  const _RulesHeroCard({required this.dorm});

  final Dorm dorm;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      boxShadow: AppColors.floatingShadow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            dorm.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '把每个人的作息边界写清楚，宿舍就能更安静地运转。',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing case final Widget trailingWidget) trailingWidget,
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _RuleField extends StatelessWidget {
  const _RuleField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: label,
            filled: true,
            fillColor: AppColors.surfaceMuted,
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: maxLines > 1 ? AppSpacing.lg : AppSpacing.md,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double min;
  final double max;
  final double value;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        Slider(
          min: min,
          max: max,
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    this.active = false,
    this.enabled = true,
    this.onTap,
  });

  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: !enabled
              ? AppColors.surfaceMuted.withAlpha(180)
              : (active ? AppColors.primaryHighlight : AppColors.surfaceMuted),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: !enabled
                ? AppColors.textSecondary
                : (active ? AppColors.primaryDeep : AppColors.textPrimary),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
