import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_page_insets.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/interaction/app_haptics.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/core/utils/formatters.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_detail_page_header.dart';
import 'package:sleep_dorm_app/core/widgets/app_settings_group.dart';
import 'package:sleep_dorm_app/core/widgets/modals/app_modal.dart';
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
  String? _boundSettingsSignature;
  bool _isSavingSettings = false;
  bool _isApplyingNightMood = false;
  bool _isSleepGoalExpanded = false;
  double _sleepGoalHours = 7.5;
  bool _bedtimeReminderEnabled = true;
  bool _morningReminderEnabled = true;
  bool _dormAlertsEnabled = true;
  bool _smartSuggestionsEnabled = true;
  bool _showHomeQuickActions = false;
  AppThemeMode _themeMode = AppThemeMode.system;
  AssistantReplyMotionLevel _assistantReplyMotionLevel =
      AssistantReplyMotionLevel.medium;
  TimeOfDay _bedtimeReminder = const TimeOfDay(hour: 23, minute: 10);

  void _syncState(UserProfile profile, UserSettings settings) {
    final String settingsSignature = _settingsSignature(settings);
    if (_boundUid == profile.uid &&
        _boundSettingsSignature == settingsSignature) {
      return;
    }
    _boundUid = profile.uid;
    _boundSettingsSignature = settingsSignature;
    _sleepGoalHours = settings.sleepGoalHours;
    _bedtimeReminderEnabled = settings.bedtimeReminderEnabled;
    _morningReminderEnabled = settings.morningReminderEnabled;
    _dormAlertsEnabled = settings.dormAlertsEnabled;
    _smartSuggestionsEnabled = settings.smartSuggestionsEnabled;
    _showHomeQuickActions = settings.showHomeQuickActions;
    _themeMode = settings.themeMode;
    _assistantReplyMotionLevel = settings.assistantReplyMotionLevel;
    _bedtimeReminder = settings.bedtimeReminder;
  }

  Future<void> _changeAssistantMotionLevel(
    AppServices services,
    AssistantReplyMotionLevel level,
  ) async {
    if (level == _assistantReplyMotionLevel) {
      return;
    }
    final UserSettings nextSettings = services.profileFacade.currentSettings
        .copyWith(assistantReplyMotionLevel: level);
    setState(() {
      _assistantReplyMotionLevel = level;
    });
    services.settingsRepository.replaceLocalSettings(nextSettings);
    unawaited(_saveSettingsInBackground(services, nextSettings));
    unawaited(notifyPassiveToast(context, message: '回复动效已更新。'));
  }

  Future<void> _showAssistantMotionSheet(AppServices services) async {
    final AssistantReplyMotionLevel? selected =
        await showAppModal<AssistantReplyMotionLevel>(
          context,
          spec: AppSelectionSheetSpec<AssistantReplyMotionLevel>(
            title: '回复动效强度',
            description: '调整主舞台上 AI 回复文字的漂浮感。',
            selectedValue: _assistantReplyMotionLevel,
            useSafeArea: true,
            showDragHandle: true,
            options: AssistantReplyMotionLevel.values
                .map(
                  (AssistantReplyMotionLevel level) =>
                      AppSelectionOption<AssistantReplyMotionLevel>(
                        value: level,
                        label: _assistantReplyMotionTitle(level),
                      ),
                )
                .toList(),
          ),
        );
    if (selected == null || !mounted) {
      return;
    }
    await _changeAssistantMotionLevel(services, selected);
  }

  Future<void> _saveSleepSettings(AppServices services) async {
    if (_isSavingSettings) {
      return;
    }
    final UserSettings nextSettings = services.profileFacade.currentSettings
        .copyWith(
          sleepGoalHours: _sleepGoalHours,
          bedtimeReminderEnabled: _bedtimeReminderEnabled,
          morningReminderEnabled: _morningReminderEnabled,
          dormAlertsEnabled: _dormAlertsEnabled,
          smartSuggestionsEnabled: _smartSuggestionsEnabled,
          bedtimeReminder: _bedtimeReminder,
        );
    setState(() => _isSavingSettings = true);
    services.settingsRepository.replaceLocalSettings(nextSettings);
    unawaited(_saveSettingsInBackground(services, nextSettings));
    if (!mounted) {
      return;
    }
    setState(() => _isSavingSettings = false);
    await notifyPassiveToast(context, message: '睡眠设置已更新。');
  }

  void _changeHomeQuickActionsVisibility(AppServices services, bool visible) {
    if (visible == _showHomeQuickActions) {
      return;
    }
    final UserSettings nextSettings = services.profileFacade.currentSettings
        .copyWith(showHomeQuickActions: visible);
    setState(() => _showHomeQuickActions = visible);
    services.settingsRepository.replaceLocalSettings(nextSettings);
    unawaited(_saveSettingsInBackground(services, nextSettings));
  }

  Future<void> _changeThemeMode(
    AppServices services,
    AppThemeMode themeMode,
  ) async {
    if (themeMode == _themeMode) {
      return;
    }
    final UserSettings nextSettings = services.profileFacade.currentSettings
        .copyWith(themeMode: themeMode);
    setState(() => _themeMode = themeMode);
    services.settingsRepository.replaceLocalSettings(nextSettings);
    unawaited(_saveSettingsInBackground(services, nextSettings));
    unawaited(notifyPassiveToast(context, message: '外观模式已更新。'));
  }

  Future<void> _showThemeModeSheet(AppServices services) async {
    final AppThemeMode? selected = await showAppModal<AppThemeMode>(
      context,
      spec: AppSelectionSheetSpec<AppThemeMode>(
        title: '外观模式',
        description: '控制全局浅色、深色或跟随系统显示。',
        selectedValue: _themeMode,
        useSafeArea: true,
        showDragHandle: true,
        options: AppThemeMode.values
            .map(
              (AppThemeMode mode) => AppSelectionOption<AppThemeMode>(
                value: mode,
                label: _themeModeTitle(mode),
              ),
            )
            .toList(growable: false),
      ),
    );
    if (selected == null || !mounted) {
      return;
    }
    await _changeThemeMode(services, selected);
  }

  Future<void> _saveSettingsInBackground(
    AppServices services,
    UserSettings settings,
  ) async {
    try {
      await services.settingsRepository.saveSettings(settings);
    } catch (error) {
      if (!mounted) {
        return;
      }
      await notifyPassiveToast(context, message: '保存失败：$error');
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
    final AppSemanticColors appColors = context.appColors;
    return Scaffold(
      appBar: AppDetailPageAppBar(
        title: '设置',
        onBack: () => Navigator.of(context).maybePop(),
      ),
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
                    color: appColors.surfaceMuted,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    borderRadius: AppRadius.compactCard,
                    child: Text(
                      services.authRepository.lastAuthError!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: appColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                AppSettingsGroup(
                  title: '账号',
                  children: <Widget>[
                    AppSettingsItem(
                      icon: Icons.person_outline_rounded,
                      iconColor: appColors.accentDeep,
                      iconBackgroundColor: appColors.surfaceMuted,
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
                  title: '小眠Agent',
                  children: <Widget>[
                    AppSettingsItem(
                      icon: Icons.auto_awesome_rounded,
                      title: '回复文字浮动',
                      iconColor: appColors.accentDeep,
                      iconBackgroundColor: appColors.surfaceMuted,
                      trailing: _SettingsValueTrailing(
                        value: _assistantReplyMotionTitle(
                          _assistantReplyMotionLevel,
                        ),
                      ),
                      hapticRole: AppHapticRole.selection,
                      onTap: () => _showAssistantMotionSheet(services),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AppSettingsGroup(
                  title: '显示与首页',
                  children: <Widget>[
                    AppSettingsItem(
                      icon: Icons.nightlight_round,
                      iconColor: appColors.accentDeep,
                      iconBackgroundColor: appColors.surfaceMuted,
                      title: '重新选择心情',
                      titleStyle: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      hapticRole: null,
                      onTap: () => context.push(AppRoutes.manualNightMood),
                    ),
                    AppSettingsItem(
                      icon: Icons.contrast_rounded,
                      iconColor: appColors.accentDeep,
                      iconBackgroundColor: appColors.surfaceMuted,
                      title: '外观模式',
                      trailing: AppSettingsValueTrailing(
                        value: _themeModeTitle(_themeMode),
                      ),
                      hapticRole: AppHapticRole.selection,
                      onTap: () => _showThemeModeSheet(services),
                    ),
                    _SettingsSwitchRow(
                      icon: Icons.grid_view_rounded,
                      title: '快捷功能',
                      value: _showHomeQuickActions,
                      onChanged: (bool value) =>
                          _changeHomeQuickActionsVisibility(services, value),
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
                          expanded: _isSleepGoalExpanded,
                          onToggle: () {
                            setState(
                              () =>
                                  _isSleepGoalExpanded = !_isSleepGoalExpanded,
                            );
                          },
                          onChanged: (double value) {
                            setState(() => _sleepGoalHours = value);
                          },
                          value: _sleepGoalHours,
                        ),
                        AppSettingsItem(
                          icon: Icons.schedule_rounded,
                          title: '睡前提醒时间',
                          iconColor: appColors.accentDeep,
                          iconBackgroundColor: appColors.surfaceMuted,
                          trailing: _SettingsValueTrailing(
                            value: Formatters.formatClock(_bedtimeReminder),
                          ),
                          hapticRole: AppHapticRole.selection,
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
                          title: '寝室动态提醒',
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
    required this.expanded,
    required this.onToggle,
    required this.onChanged,
    required this.value,
  });

  final String title;
  final String valueLabel;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<double> onChanged;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        AppSettingsItem(
          icon: Icons.hotel_rounded,
          iconColor: context.appColors.accentDeep,
          iconBackgroundColor: context.appColors.surfaceMuted,
          title: title,
          trailing: _SettingsValueTrailing(
            value: valueLabel,
            icon: expanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
          ),
          hapticRole: AppHapticRole.selection,
          onTap: onToggle,
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: _SleepGoalSliderPanel(
            value: value,
            onChanged: onChanged,
          ),
          crossFadeState: expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
          firstCurve: Curves.easeOutCubic,
          secondCurve: Curves.easeOutCubic,
          sizeCurve: Curves.easeOutCubic,
        ),
      ],
    );
  }
}

class _SleepGoalSliderPanel extends StatelessWidget {
  const _SleepGoalSliderPanel({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                '6 小时',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.appColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '9 小时',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.appColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
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
      iconColor: context.appColors.accentDeep,
      iconBackgroundColor: context.appColors.surfaceMuted,
      title: title,
      trailing: AppSettingsToggle(
        key: ValueKey<String>('settings-toggle-$title'),
        value: value,
      ),
      hapticRole: AppHapticRole.selection,
      onTap: () => onChanged(!value),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    );
  }
}

class _SettingsValueTrailing extends StatelessWidget {
  const _SettingsValueTrailing({
    required this.value,
    this.icon = Icons.chevron_right_rounded,
  });

  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.appColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Icon(icon, size: 18, color: context.appColors.textSecondary),
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
          onTap: enabled ? AppHaptics.selectionHandler(onTap) : null,
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
                  color: context.appColors.textPrimary,
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

String _settingsSignature(UserSettings settings) {
  final TimeOfDay bedtimeReminder = settings.bedtimeReminder;
  return <Object?>[
    settings.sleepGoalHours,
    settings.bedtimeReminderEnabled,
    settings.morningReminderEnabled,
    settings.dormAlertsEnabled,
    settings.smartSuggestionsEnabled,
    settings.showHomeQuickActions,
    settings.themeMode.name,
    bedtimeReminder.hour,
    bedtimeReminder.minute,
    settings.assistantReplyMotionLevel.name,
    settings.selectedNightMood?.name,
  ].join('|');
}

String _themeModeTitle(AppThemeMode mode) {
  return switch (mode) {
    AppThemeMode.system => '跟随系统',
    AppThemeMode.light => '浅色',
    AppThemeMode.dark => '深色',
  };
}

String _assistantReplyMotionTitle(AssistantReplyMotionLevel level) {
  return switch (level) {
    AssistantReplyMotionLevel.low => '低',
    AssistantReplyMotionLevel.medium => '中',
    AssistantReplyMotionLevel.high => '高',
  };
}
