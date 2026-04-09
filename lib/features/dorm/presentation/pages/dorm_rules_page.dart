import 'package:flutter/material.dart';
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
  const DormRulesPage({super.key});

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
  bool _examWeekMode = true;
  bool _blackoutCurtain = true;
  bool _vibrationFirst = true;
  double _summerTemp = 26;
  double _winterTemp = 22;
  double _ventilationMinutes = 30;
  String _selectedVentilationWindow = '早晨';
  List<String> _routineTags = const <String>['考试周', '夜猫子', '早起党'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    final DormRulesSettings settings =
        context.appServices.dormRepository.currentDorm.rulesSettings;
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
    _initialized = true;
  }

  @override
  void dispose() {
    _quietHoursController.dispose();
    _specialCaseController.dispose();
    _lightsOffController.dispose();
    _personalLightingController.dispose();
    _alarmResponseController.dispose();
    _routineNoteController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();
    final DormRulesSettings current =
        context.appServices.dormRepository.currentDorm.rulesSettings;
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
    await notifyPassiveToast(context, message: '宿舍规则已保存到当前会话。');
  }

  @override
  Widget build(BuildContext context) {
    final Dorm dorm = context.appServices.dormRepository.currentDorm;
    final NightMoodPalette palette = context.nightMoodPalette;
    return Scaffold(
      appBar: AppBar(title: const Text('宿舍公约')),
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
          child: PrimaryButton(label: '保存规则', onPressed: _handleSave),
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
                  _SectionCard(
                    title: '声音公约',
                    subtitle: 'Quiet hours & noise limits',
                    trailing: Switch(
                      value: _examWeekMode,
                      onChanged: (bool value) {
                        setState(() => _examWeekMode = value);
                      },
                    ),
                    child: Column(
                      children: <Widget>[
                        _RuleField(
                          label: '静音时段',
                          controller: _quietHoursController,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _RuleField(
                          label: '特殊情况说明',
                          controller: _specialCaseController,
                          maxLines: 3,
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
                        _RuleField(
                          label: '主灯关闭时间',
                          controller: _lightsOffController,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _RuleField(
                          label: '个人照明要求',
                          controller: _personalLightingController,
                          maxLines: 3,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        CheckboxListTile(
                          value: _blackoutCurtain,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('建议统一使用遮光帘'),
                          subtitle: const Text('减少走廊和窗边杂光的影响'),
                          onChanged: (bool? value) {
                            setState(() => _blackoutCurtain = value ?? false);
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
                      onChanged: (bool value) {
                        setState(() => _vibrationFirst = value);
                      },
                    ),
                    child: Column(
                      children: <Widget>[
                        _RuleField(
                          label: '闹钟响应时限（秒）',
                          controller: _alarmResponseController,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _RuleField(
                          label: '作息习惯备注',
                          controller: _routineNoteController,
                          maxLines: 3,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: const <String>['考试周', '夜猫子', '早起党']
                              .map(
                                (String label) => _TagChip(
                                  label: label,
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
                        _LabeledSlider(
                          label: '夏季空调 ${_summerTemp.toStringAsFixed(0)}°C',
                          min: 20,
                          max: 30,
                          value: _summerTemp,
                          onChanged: (double value) {
                            setState(() => _summerTemp = value);
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _LabeledSlider(
                          label: '冬季采暖 ${_winterTemp.toStringAsFixed(0)}°C',
                          min: 16,
                          max: 28,
                          value: _winterTemp,
                          onChanged: (double value) {
                            setState(() => _winterTemp = value);
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          '通风时段',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: const <String>['早晨', '中午', '睡前']
                              .map(
                                (String label) => _TagChip(
                                  label: label,
                                  active: _selectedVentilationWindow == label,
                                  onTap: () {
                                    setState(() {
                                      _selectedVentilationWindow = label;
                                    });
                                  },
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _LabeledSlider(
                          label: '通风时长 ${_ventilationMinutes.round()} 分钟',
                          min: 10,
                          max: 60,
                          value: _ventilationMinutes,
                          onChanged: (double value) {
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
        ],
      ),
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
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
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
  final ValueChanged<double> onChanged;

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
    this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryHighlight : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: active ? AppColors.primaryDeep : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
