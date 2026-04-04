import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
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
  String _selectedVentilationWindow = 'Morning';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }

    final Dorm dorm = context.appServices.dormRepository.currentDorm;
    _quietHoursController.text = '23:00 - 07:00';
    _specialCaseController.text = dorm.rules.length > 1
        ? dorm.rules[1].detail
        : '如有小组讨论或临时会议，请提前在宿舍群里同步。';
    _lightsOffController.text = 'After 23:30';
    _personalLightingController.text = '仅使用护眼台灯，避免直射到正在休息的室友。';
    _alarmResponseController.text = '60';
    _routineNoteController.text = '通常在 08:30 起床，考试周会提前到 07:20。';
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
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text('宿舍公约')),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface.withAlpha(242),
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
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double horizontalPadding = constraints.maxWidth >= 720
              ? AppSpacing.xxxl
              : AppSpacing.lg;

          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
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
                  color: AppColors.primarySoft,
                  animate: true,
                ),
              ),
              Positioned(
                top: 220,
                left: -48,
                child: AmbientOrb(
                  size: 140,
                  color: const Color(0xFFE5C187),
                  animate: true,
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      AppSpacing.sm,
                      horizontalPadding,
                      150,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _RulesHeroCard(dorm: dorm),
                        const SizedBox(height: AppSpacing.lg),
                        _RuleSectionCard(
                          icon: Icons.volume_off_rounded,
                          title: '声音公约',
                          subtitle: 'Quiet hours & noise limits',
                          iconGradient: const <Color>[
                            Color(0xFFFF8A3D),
                            Color(0xFFF45B49),
                          ],
                          trailing: _MiniSwitch(
                            value: _examWeekMode,
                            onChanged: (bool value) {
                              setState(() {
                                _examWeekMode = value;
                              });
                            },
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              _RuleField(
                                label: '静音时段',
                                icon: Icons.schedule_rounded,
                                controller: _quietHoursController,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _RuleField(
                                label: '特殊情况说明',
                                icon: Icons.message_outlined,
                                controller: _specialCaseController,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _RuleSectionCard(
                          icon: Icons.lightbulb_rounded,
                          title: '灯光管理',
                          subtitle: 'Light usage & sleep hygiene',
                          iconGradient: const <Color>[
                            Color(0xFFF8C748),
                            Color(0xFFF1A12D),
                          ],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              _RuleField(
                                label: '主灯关闭时间',
                                icon: Icons.dark_mode_rounded,
                                controller: _lightsOffController,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _RuleField(
                                label: '个人照明要求',
                                icon: Icons.bedtime_rounded,
                                controller: _personalLightingController,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setState(() {
                                    _blackoutCurtain = !_blackoutCurtain;
                                  });
                                },
                                child: Row(
                                  children: <Widget>[
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: _blackoutCurtain
                                            ? AppColors.primarySoft
                                            : AppColors.surfaceMuted,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                        color: _blackoutCurtain
                                            ? AppColors.primaryDeep
                                            : Colors.transparent,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        '建议统一使用遮光帘，减少走廊和窗边杂光。',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: AppColors.textPrimary,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _RuleSectionCard(
                          icon: Icons.alarm_rounded,
                          title: '闹钟与作息',
                          subtitle: 'Alarms and daily cycles',
                          iconGradient: const <Color>[
                            Color(0xFF4DB7F5),
                            Color(0xFF2B7DE1),
                          ],
                          trailing: _MiniSwitch(
                            value: _vibrationFirst,
                            onChanged: (bool value) {
                              setState(() {
                                _vibrationFirst = value;
                              });
                            },
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: _RuleField(
                                      label: '闹钟响应时限 (秒)',
                                      icon: Icons.timer_outlined,
                                      controller: _alarmResponseController,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(
                                        AppSpacing.md,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceMuted,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            '振动优先',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium
                                                ?.copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                          ),
                                          const SizedBox(height: AppSpacing.xs),
                                          Text(
                                            _vibrationFirst ? '已开启' : '未开启',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _RuleField(
                                label: '作息习惯备注',
                                icon: Icons.notes_rounded,
                                controller: _routineNoteController,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Wrap(
                                spacing: AppSpacing.xs,
                                runSpacing: AppSpacing.xs,
                                children: const <Widget>[
                                  _TagChip(label: '考研党', active: true),
                                  _TagChip(label: '夜猫子'),
                                  _TagChip(label: '早起鸟'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _RuleSectionCard(
                          icon: Icons.thermostat_rounded,
                          title: '温度调节',
                          subtitle: 'AC & ventilation preferences',
                          iconGradient: const <Color>[
                            Color(0xFF5CD7B4),
                            Color(0xFF1DAE8E),
                          ],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              _TemperatureSlider(
                                label: '夏季空调',
                                value: _summerTemp,
                                color: const Color(0xFFEE8A32),
                                onChanged: (double value) {
                                  setState(() {
                                    _summerTemp = value;
                                  });
                                },
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _TemperatureSlider(
                                label: '冬季采暖',
                                value: _winterTemp,
                                color: const Color(0xFFE55B4A),
                                onChanged: (double value) {
                                  setState(() {
                                    _winterTemp = value;
                                  });
                                },
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                '通风时段',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Wrap(
                                spacing: AppSpacing.xs,
                                runSpacing: AppSpacing.xs,
                                children: <String>['Morning', 'Noon', 'Bedtime']
                                    .map((String label) {
                                      return _TagChip(
                                        label: label,
                                        active:
                                            _selectedVentilationWindow == label,
                                        onTap: () {
                                          setState(() {
                                            _selectedVentilationWindow = label;
                                          });
                                        },
                                      );
                                    })
                                    .toList(),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                '通风时长 ${_ventilationMinutes.round()} 分钟',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: AppColors.primarySoft,
                                  inactiveTrackColor: AppColors.surfaceSoft,
                                  thumbColor: AppColors.primary,
                                  overlayColor: AppColors.primarySoft.withAlpha(
                                    48,
                                  ),
                                ),
                                child: Slider(
                                  min: 10,
                                  max: 60,
                                  value: _ventilationMinutes,
                                  onChanged: (double value) {
                                    setState(() {
                                      _ventilationMinutes = value;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleSave() {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('宿舍规则已保存到当前会话。')));
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

class _RuleSectionCard extends StatelessWidget {
  const _RuleSectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconGradient,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> iconGradient;
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(colors: iconGradient),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: iconGradient.last.withAlpha(56),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: AppColors.onDark),
              ),
              const SizedBox(width: AppSpacing.md),
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
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing case final Widget trailing) trailing,
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
    required this.icon,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceMuted,
            prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: AppColors.primary.withAlpha(120)),
            ),
          ),
        ),
      ],
    );
  }
}

class _TemperatureSlider extends StatelessWidget {
  const _TemperatureSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              '${value.round()}°C',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: AppColors.surfaceSoft,
            thumbColor: AppColors.surface,
            overlayColor: color.withAlpha(48),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(min: 18, max: 30, value: value, onChanged: onChanged),
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, this.active = false, this.onTap});

  final String label;
  final bool active;
  final VoidCallback? onTap;

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
              ? AppColors.primarySoft.withAlpha(72)
              : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? AppColors.primarySoft.withAlpha(120)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: active ? AppColors.primaryDeep : AppColors.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
          activeTrackColor: AppColors.primarySoft,
        ),
      ),
    );
  }
}
