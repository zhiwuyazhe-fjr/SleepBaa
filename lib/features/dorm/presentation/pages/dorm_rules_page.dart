import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
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
  String _selectedVentilationWindow = 'Morning';
  List<String> _routineTags = <String>[];

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
    _routineTags = List<String>.from(settings.routineTags);
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
        color: AppColors.surface.withAlpha(245),
        child: SafeArea(
          top: false,
          child: PrimaryButton(label: '保存规则', onPressed: _handleSave),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: <Widget>[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  dorm.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '把每个人的作息边界写清楚，宿舍就能更安静地运转。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _RulesSection(
            title: '声音公约',
            child: Column(
              children: <Widget>[
                _RuleField(
                  label: '安静时段',
                  controller: _quietHoursController,
                ),
                const SizedBox(height: AppSpacing.md),
                _RuleField(
                  label: '特殊情况说明',
                  controller: _specialCaseController,
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.md),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('考试周模式'),
                  subtitle: const Text('考试周时默认更严格地控制声音'),
                  value: _examWeekMode,
                  activeThumbColor: palette.primary,
                  onChanged: (bool value) {
                    setState(() => _examWeekMode = value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _RulesSection(
            title: '灯光与睡前习惯',
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
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('统一使用遮光帘'),
                  subtitle: const Text('减少走廊和窗边杂光'),
                  value: _blackoutCurtain,
                  activeThumbColor: palette.primary,
                  onChanged: (bool value) {
                    setState(() => _blackoutCurtain = value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _RulesSection(
            title: '作息约定',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _RuleField(
                        label: '闹钟响应时限（秒）',
                        controller: _alarmResponseController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('振动优先'),
                        subtitle: const Text('先振动，再外放'),
                        value: _vibrationFirst,
                        activeThumbColor: palette.primary,
                        onChanged: (bool value) {
                          setState(() => _vibrationFirst = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _RuleField(
                  label: '作息习惯备注',
                  controller: _routineNoteController,
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '宿舍作息标签',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: <String>['考研党', '夜猫子', '早起党']
                      .map(
                        (String label) => _TagChip(
                          label: label,
                          active: _routineTags.contains(label),
                          onTap: () {
                            setState(() {
                              if (_routineTags.contains(label)) {
                                _routineTags.remove(label);
                              } else {
                                _routineTags.add(label);
                              }
                            });
                          },
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _RulesSection(
            title: '温度与通风',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SliderTile(
                  label: '夏季空调',
                  value: _summerTemp,
                  min: 18,
                  max: 30,
                  suffix: '°C',
                  onChanged: (double value) {
                    setState(() => _summerTemp = value);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _SliderTile(
                  label: '冬季采暖',
                  value: _winterTemp,
                  min: 18,
                  max: 30,
                  suffix: '°C',
                  onChanged: (double value) {
                    setState(() => _winterTemp = value);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '通风时段',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: <String>['Morning', 'Noon', 'Bedtime']
                      .map(
                        (String label) => _TagChip(
                          label: label,
                          active: _selectedVentilationWindow == label,
                          onTap: () {
                            setState(() => _selectedVentilationWindow = label);
                          },
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: AppSpacing.md),
                _SliderTile(
                  label: '通风时长',
                  value: _ventilationMinutes,
                  min: 10,
                  max: 60,
                  suffix: '分钟',
                  onChanged: (double value) {
                    setState(() => _ventilationMinutes = value);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();
    final AppServices services = context.appServices;
    final DormRulesSettings current = services.dormRepository.currentDorm.rulesSettings;
    final DormRulesSettings next = current.copyWith(
      quietHours: _quietHoursController.text.trim().isEmpty
          ? current.quietHours
          : _quietHoursController.text.trim(),
      specialCase: _specialCaseController.text.trim().isEmpty
          ? current.specialCase
          : _specialCaseController.text.trim(),
      lightsOffTime: _lightsOffController.text.trim().isEmpty
          ? current.lightsOffTime
          : _lightsOffController.text.trim(),
      personalLighting: _personalLightingController.text.trim().isEmpty
          ? current.personalLighting
          : _personalLightingController.text.trim(),
      examWeekMode: _examWeekMode,
      blackoutCurtain: _blackoutCurtain,
      vibrationFirst: _vibrationFirst,
      alarmResponseSeconds:
          int.tryParse(_alarmResponseController.text.trim()) ??
          current.alarmResponseSeconds,
      routineNote: _routineNoteController.text.trim().isEmpty
          ? current.routineNote
          : _routineNoteController.text.trim(),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('宿舍规则已保存。')));
  }
}

class _RulesSection extends StatelessWidget {
  const _RulesSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
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
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String suffix;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$label ${value.round()}$suffix',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
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
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: active
              ? context.nightMoodPalette.primarySoft.withAlpha(72)
              : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? context.nightMoodPalette.primarySoft.withAlpha(140)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
