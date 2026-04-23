import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_page_insets.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/core/utils/formatters.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_menu_group_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_settings_group.dart';
import 'package:sleep_dorm_app/core/widgets/mood_avatar.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';
import 'package:sleep_dorm_app/features/profile/presentation/widgets/account_action_widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _boundUid;
  bool _isSavingSettings = false;
  bool _isApplyingNightMood = false;
  double _sleepGoalHours = 7.5;
  bool _bedtimeReminderEnabled = true;
  bool _morningReminderEnabled = true;
  bool _dormAlertsEnabled = true;
  bool _smartSuggestionsEnabled = true;
  TimeOfDay _bedtimeReminder = const TimeOfDay(hour: 23, minute: 10);

  void _syncState(UserProfile profile, UserSettings settings) {
    if (_boundUid == profile.uid) {
      return;
    }
    _boundUid = profile.uid;
    _sleepGoalHours = settings.sleepGoalHours;
    _bedtimeReminderEnabled = settings.bedtimeReminderEnabled;
    _morningReminderEnabled = settings.morningReminderEnabled;
    _dormAlertsEnabled = settings.dormAlertsEnabled;
    _smartSuggestionsEnabled = settings.smartSuggestionsEnabled;
    _bedtimeReminder = settings.bedtimeReminder;
  }

  Future<void> _saveSleepSettings(AppServices services) async {
    setState(() => _isSavingSettings = true);
    try {
      final UserSettings nextSettings = services.profileFacade.currentSettings
          .copyWith(
            sleepGoalHours: _sleepGoalHours,
            bedtimeReminderEnabled: _bedtimeReminderEnabled,
            morningReminderEnabled: _morningReminderEnabled,
            dormAlertsEnabled: _dormAlertsEnabled,
            smartSuggestionsEnabled: _smartSuggestionsEnabled,
            bedtimeReminder: _bedtimeReminder,
          );
      await services.settingsRepository.saveSettings(nextSettings);
      if (!mounted) {
        return;
      }
      await notifyPassiveToast(context, message: '睡眠设置已保存。');
    } catch (error) {
      if (!mounted) {
        return;
      }
      await notifyPassiveToast(context, message: '保存失败：$error');
    } finally {
      if (mounted) {
        setState(() => _isSavingSettings = false);
      }
    }
  }

  Future<void> _applyNightMood(AppServices services, NightMood? mood) async {
    if (_isApplyingNightMood) {
      return;
    }
    setState(() => _isApplyingNightMood = true);
    try {
      final UserSettings next = mood == null
          ? services.profileFacade.currentSettings.copyWith(
              clearSelectedNightMood: true,
            )
          : services.profileFacade.currentSettings.copyWith(
              selectedNightMood: mood,
            );
      services.settingsRepository.replaceLocalSettings(next);
      services.nightWelcomeController.releaseNightMoodThemeOverride();
      if (mounted) {
        setState(() => _isApplyingNightMood = false);
      }
      unawaited(notifyPassiveToast(context, message: '已切换心情主题。'));
      unawaited(_persistNightMoodInBackground(services, mood));
    } catch (error) {
      if (!mounted) {
        return;
      }
      await notifyPassiveToast(context, message: '保存失败：$error');
      if (mounted) {
        setState(() => _isApplyingNightMood = false);
      }
    }
  }

  Future<void> _persistNightMoodInBackground(
    AppServices services,
    NightMood? mood,
  ) async {
    try {
      await services.profileFacade.saveNightMood(mood);
    } catch (error) {
      if (!mounted) {
        return;
      }
      await notifyPassiveToast(context, message: '同步到云端失败：$error');
    }
  }

  Future<void> _pickReminderTime() async {
    final TimeOfDay? result = await showTimePicker(
      context: context,
      initialTime: _bedtimeReminder,
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() => _bedtimeReminder = result);
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[
            services.authRepository,
            services.settingsRepository,
            services.nightWelcomeController,
          ]),
          builder: (BuildContext context, Widget? child) {
            final UserProfile profile = services.profileFacade.currentUser;
            final UserSettings settings =
                services.profileFacade.currentSettings;
            _syncState(profile, settings);

            return ListView(
              padding: AppPageInsets.page(bottom: AppSpacing.lg),
              children: <Widget>[
                if (services.authRepository.lastAuthError != null) ...<Widget>[
                  AppCard(
                    color: AppColors.surfaceMuted,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    borderRadius: AppRadius.compactCard,
                    child: Text(
                      services.authRepository.lastAuthError!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                AppMenuGroupCard(
                  borderRadius: AppRadius.compactCard,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                  itemPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  items: <AppMenuGroupCardItem>[
                    AppMenuGroupCardItem(
                      title: '账号管理',
                      titleStyle: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      onTap: () => context.push(AppRoutes.profileAccountCenter),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AppSettingsGroup(
                  title: '切换心情主题',
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xxs,
                        AppSpacing.md,
                        AppSpacing.xs,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: _MoodAssistantFabSlot(
                              label: '开心',
                              palette: NightMoodPalette.fromMood(
                                NightMood.happy,
                              ),
                              selected:
                                  settings.selectedNightMood == NightMood.happy,
                              enabled: !_isApplyingNightMood,
                              onTap: () => unawaited(
                                _applyNightMood(services, NightMood.happy),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Expanded(
                            child: _MoodAssistantFabSlot(
                              label: '低落',
                              palette: NightMoodPalette.fromMood(NightMood.sad),
                              selected:
                                  settings.selectedNightMood == NightMood.sad,
                              enabled: !_isApplyingNightMood,
                              onTap: () => unawaited(
                                _applyNightMood(services, NightMood.sad),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Expanded(
                            child: _MoodAssistantFabSlot(
                              label: '平静',
                              palette: NightMoodPalette.fromMood(
                                NightMood.calm,
                              ),
                              selected:
                                  settings.selectedNightMood == NightMood.calm,
                              enabled: !_isApplyingNightMood,
                              onTap: () => unawaited(
                                _applyNightMood(services, NightMood.calm),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Expanded(
                            child: _MoodAssistantFabSlot(
                              label: '未知',
                              palette: NightMoodPalette.fromMood(null),
                              selected: settings.selectedNightMood == null,
                              enabled: !_isApplyingNightMood,
                              onTap: () =>
                                  unawaited(_applyNightMood(services, null)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AppSettingsGroup(
                  title: '睡眠偏好',
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        _SettingsSliderRow(
                          title: '目标睡眠时长',
                          valueLabel:
                              '${_sleepGoalHours.toStringAsFixed(1)} 小时',
                          onChanged: (double value) {
                            setState(() => _sleepGoalHours = value);
                          },
                          value: _sleepGoalHours,
                        ),
                        AppSettingsItem(
                          icon: Icons.schedule_rounded,
                          title: '睡前提醒时间',
                          iconColor: context.nightMoodPalette.primaryDeep,
                          trailing: _SettingsValueTrailing(
                            value: Formatters.formatClock(_bedtimeReminder),
                          ),
                          onTap: _pickReminderTime,
                        ),
                        _SettingsSwitchRow(
                          icon: Icons.bedtime_rounded,
                          title: '睡前提醒',
                          value: _bedtimeReminderEnabled,
                          onChanged: (bool value) {
                            setState(() => _bedtimeReminderEnabled = value);
                          },
                        ),
                        _SettingsSwitchRow(
                          icon: Icons.wb_twilight_outlined,
                          title: '晨间反馈提醒',
                          value: _morningReminderEnabled,
                          onChanged: (bool value) {
                            setState(() => _morningReminderEnabled = value);
                          },
                        ),
                        _SettingsSwitchRow(
                          icon: Icons.notifications_active_outlined,
                          title: '宿舍动态提醒',
                          value: _dormAlertsEnabled,
                          onChanged: (bool value) {
                            setState(() => _dormAlertsEnabled = value);
                          },
                        ),
                        _SettingsSwitchRow(
                          icon: Icons.auto_awesome_rounded,
                          title: '智能建议',
                          value: _smartSuggestionsEnabled,
                          onChanged: (bool value) {
                            setState(() => _smartSuggestionsEnabled = value);
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.xs,
                            AppSpacing.md,
                            AppSpacing.xs,
                          ),
                          child: PrimaryButton(
                            label: '保存睡眠设置',
                            icon: Icons.save_rounded,
                            isLoading: _isSavingSettings,
                            loadingLabel: '保存中...',
                            size: PrimaryButtonSize.compact,
                            variant: PrimaryButtonVariant.soft,
                            onPressed: () => _saveSleepSettings(services),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AccountSignOutButton(services: services, label: '退出登录'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SettingsSliderRow extends StatelessWidget {
  const _SettingsSliderRow({
    required this.title,
    required this.valueLabel,
    required this.onChanged,
    required this.value,
  });

  final String title;
  final String valueLabel;
  final ValueChanged<double> onChanged;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 28,
            child: Center(
              child: Icon(
                Icons.hotel_rounded,
                size: 20,
                color: context.nightMoodPalette.primaryDeep,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      valueLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    overlayShape: SliderComponentShape.noOverlay,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                  ),
                  child: Slider(
                    value: value,
                    min: 6,
                    max: 9,
                    divisions: 12,
                    onChanged: onChanged,
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

class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppSettingsItem(
      icon: icon,
      iconColor: context.nightMoodPalette.primaryDeep,
      title: title,
      trailing: SizedBox(
        width: 44,
        height: 24,
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.centerRight,
          child: Switch(
            value: value,
            onChanged: (bool next) {
              HapticFeedback.selectionClick();
              onChanged(next);
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeThumbColor: context.nightMoodPalette.primary,
            activeTrackColor: context.nightMoodPalette.primarySoft,
          ),
        ),
      ),
      onTap: () => onChanged(!value),
    );
  }
}

class _SettingsValueTrailing extends StatelessWidget {
  const _SettingsValueTrailing({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: AppSpacing.xxs),
        const Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: AppColors.textHint,
        ),
      ],
    );
  }
}

class _MoodAssistantFabSlot extends StatelessWidget {
  const _MoodAssistantFabSlot({
    required this.label,
    required this.palette,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final NightMoodPalette palette;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onTap();
                }
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                height: 64,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: selected ? 66 : 60,
                    height: selected ? 66 : 60,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: selected ? 2 : 0,
                        color: selected ? palette.primary : Colors.transparent,
                      ),
                    ),
                    child: _MoodSelectionVisual(palette: palette),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyLarge?.copyWith(
                  color: palette.primaryDeep,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodSelectionVisual extends StatelessWidget {
  const _MoodSelectionVisual({required this.palette});

  final NightMoodPalette palette;

  @override
  Widget build(BuildContext context) {
    if (palette.mood != null) {
      return MoodAvatar(
        mood: palette.mood!,
        size: 50,
        fillColor: palette.welcomeFaceColor,
      );
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.assistantFabShellStart,
            AppColors.assistantFabShellEnd,
          ],
        ),
        border: Border.all(
          color: palette.primarySoft.withValues(alpha: 0.32),
          width: 1.2,
        ),
      ),
      child: Icon(
        Icons.auto_awesome_rounded,
        color: palette.primaryHighlight,
        size: 24,
      ),
    );
  }
}
