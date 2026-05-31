import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/core/widgets/app_detail_page_header.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';

class NightAwakeningLogPage extends StatefulWidget {
  const NightAwakeningLogPage({super.key});

  @override
  State<NightAwakeningLogPage> createState() => _NightAwakeningLogPageState();
}

class _NightAwakeningLogPageState extends State<NightAwakeningLogPage> {
  TimeOfDay _time = TimeOfDay.now();
  String _trigger = '环境噪声';
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: <Widget>[
          const Positioned(
            left: -80,
            top: 30,
            child: _DarkGlow(size: 280, color: Color(0x1037C7A4)),
          ),
          const Positioned(
            right: -70,
            bottom: 40,
            child: _DarkGlow(size: 260, color: Color(0x102A8E78)),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xxl,
              ),
              children: <Widget>[
                AppDetailPageHeader(
                  title: '记录夜醒',
                  foregroundColor: AppColors.onDark,
                  onBack: () => context.pop(),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '把这次醒来的时间、原因和重新入睡的过程轻轻记下来，明早会更容易看见规律。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onDark.withAlpha(170),
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _DarkPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '夜醒时间',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.onDark,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.onDark,
                          side: const BorderSide(color: AppColors.darkBorder),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                        ),
                        onPressed: () async {
                          final TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: _time,
                          );
                          if (picked != null) {
                            setState(() => _time = picked);
                          }
                        },
                        icon: const Icon(Icons.schedule_rounded),
                        label: Text(_time.format(context)),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        '可能诱因',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.onDark,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children:
                            <String>[
                              '环境噪声',
                              '光线干扰',
                              '温度不适',
                              '身体不适',
                              '梦中惊醒',
                            ].map((String trigger) {
                              final bool selected = _trigger == trigger;
                              return _TriggerChip(
                                label: trigger,
                                selected: selected,
                                palette: palette,
                                onTap: () => setState(() => _trigger = trigger),
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _DarkPanel(
                  tint: palette.primary.withAlpha(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '补充记录',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.onDark,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '先把这次醒来的感觉或你刚刚做过的事记下来就好，重新入睡用了多久可以留到晨间反馈再补。',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.onDark.withAlpha(170),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _noteController,
                        minLines: 4,
                        maxLines: 6,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.onDark,
                          height: 1.55,
                        ),
                        decoration: InputDecoration(
                          labelText: '补充记录',
                          labelStyle: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.onDark.withAlpha(170),
                              ),
                          hintText: '比如：是否翻身、是否喝水、当时的情绪感受',
                          hintStyle: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.onDark.withAlpha(120),
                              ),
                          filled: true,
                          fillColor: Colors.white.withAlpha(10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.darkBorder,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.darkBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(color: palette.primarySoft),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: '保存夜醒记录',
                  foregroundColor: Colors.white,
                  onPressed: () async {
                    final NavigatorState navigator = Navigator.of(context);
                    final DateTime now = DateTime.now();
                    final DateTime occurredAt = DateTime(
                      now.year,
                      now.month,
                      now.day,
                      _time.hour,
                      _time.minute,
                    );
                    await context.appServices.sleepExperienceController
                        .addNightAwakening(
                          occurredAt: occurredAt,
                          trigger: _trigger,
                          minutesToSleep: 0,
                          note: _noteController.text.trim(),
                        );
                    if (!context.mounted) {
                      return;
                    }
                    notifyPassiveToast(context, message: '夜醒记录已保存');
                    navigator.pop();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkPanel extends StatelessWidget {
  const _DarkPanel({required this.child, this.tint});

  final Widget child;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: tint ?? AppColors.darkCard,
        borderRadius: AppRadius.cardLarge,
        border: Border.all(color: AppColors.darkBorder),
        boxShadow: AppColors.floatingShadow,
      ),
      child: child,
    );
  }
}

class _DarkGlow extends StatelessWidget {
  const _DarkGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color,
            blurRadius: size * 0.4,
            spreadRadius: size * 0.1,
          ),
        ],
      ),
    );
  }
}

class _TriggerChip extends StatelessWidget {
  const _TriggerChip({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final NightMoodPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? palette.primary.withAlpha(210)
                : AppColors.darkSurface.withAlpha(190),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? palette.primarySoft.withAlpha(160)
                  : AppColors.darkBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (selected) ...<Widget>[
                Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: Colors.white.withAlpha(235),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected
                      ? Colors.white
                      : AppColors.onDark.withAlpha(220),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
