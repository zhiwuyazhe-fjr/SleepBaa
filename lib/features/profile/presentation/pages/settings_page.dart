import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/utils/avatar_picker.dart';
import 'package:sleep_dorm_app/core/utils/formatters.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';
import 'package:sleep_dorm_app/core/widgets/user_avatar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _initialized = false;
  late final TextEditingController _nameController;
  late final TextEditingController _taglineController;
  late final TextEditingController _roleController;
  late double _sleepGoalHours;
  late bool _bedtimeReminderEnabled;
  late bool _morningReminderEnabled;
  late bool _dormAlertsEnabled;
  late bool _smartSuggestionsEnabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    final AppServices services = context.appServices;
    final UserProfile profile = services.authRepository.currentUser;
    final UserSettings settings = services.settingsRepository.currentSettings;
    _nameController = TextEditingController(text: profile.displayName);
    _taglineController = TextEditingController(text: profile.tagline);
    _roleController = TextEditingController(text: profile.role);
    _sleepGoalHours = settings.sleepGoalHours;
    _bedtimeReminderEnabled = settings.bedtimeReminderEnabled;
    _morningReminderEnabled = settings.morningReminderEnabled;
    _dormAlertsEnabled = settings.dormAlertsEnabled;
    _smartSuggestionsEnabled = settings.smartSuggestionsEnabled;
    _initialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    final UserProfile profile = services.authRepository.currentUser;
    final UserSettings settings = services.settingsRepository.currentSettings;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: <Widget>[
            Text('个人信息', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      UserAvatar(
                        profile: profile,
                        size: 76,
                        editable: true,
                        onTap: () => pickAndSaveAvatar(context),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '当前头像',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '支持从相册中选择新的头像图片。',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => pickAndSaveAvatar(context),
                        child: const Text('更换头像'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _LabeledField(label: '昵称', controller: _nameController),
                  const SizedBox(height: AppSpacing.md),
                  _LabeledField(label: '身份标签', controller: _taglineController),
                  const SizedBox(height: AppSpacing.md),
                  _LabeledField(label: '宿舍角色', controller: _roleController),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('睡眠偏好', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        '目标睡眠时长',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      Text(
                        '${_sleepGoalHours.toStringAsFixed(1)} h',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _sleepGoalHours,
                    min: 6,
                    max: 9,
                    divisions: 12,
                    label: _sleepGoalHours.toStringAsFixed(1),
                    onChanged: (double value) {
                      setState(() => _sleepGoalHours = value);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('助眠偏好音频'),
                    subtitle: Text(settings.preferredTrackTitle),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('智能建议'),
                    subtitle: const Text('根据最近几晚反馈自动调整今晚的建议组合。'),
                    value: _smartSuggestionsEnabled,
                    onChanged: (bool value) {
                      setState(() => _smartSuggestionsEnabled = value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('通知与同步', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                children: <Widget>[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('睡前提醒'),
                    subtitle: Text(
                      '当前提醒时间 ${Formatters.formatClock(settings.bedtimeReminder)}',
                    ),
                    value: _bedtimeReminderEnabled,
                    onChanged: (bool value) {
                      setState(() => _bedtimeReminderEnabled = value);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('晨间反馈提醒'),
                    subtitle: const Text('醒来后提醒补全昨晚建议的真实效果。'),
                    value: _morningReminderEnabled,
                    onChanged: (bool value) {
                      setState(() => _morningReminderEnabled = value);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Dorm 协作提醒'),
                    subtitle: const Text('同步宿舍环境状态和室友动态变化。'),
                    value: _dormAlertsEnabled,
                    onChanged: (bool value) {
                      setState(() => _dormAlertsEnabled = value);
                    },
                  ),
                  const Divider(height: AppSpacing.xxl),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('后端同步'),
                    subtitle: Text('当前为 Firebase-ready 架构，后续可直接接入真实 Firestore。'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: '保存设置',
              onPressed: () async {
                final ScaffoldMessengerState messenger = ScaffoldMessenger.of(
                  context,
                );
                await services.authRepository.updateProfile(
                  displayName: _nameController.text.trim(),
                  tagline: _taglineController.text.trim(),
                  role: _roleController.text.trim(),
                );
                await services.settingsRepository.saveSettings(
                  settings.copyWith(
                    sleepGoalHours: _sleepGoalHours,
                    bedtimeReminderEnabled: _bedtimeReminderEnabled,
                    morningReminderEnabled: _morningReminderEnabled,
                    dormAlertsEnabled: _dormAlertsEnabled,
                    smartSuggestionsEnabled: _smartSuggestionsEnabled,
                  ),
                );
                if (!mounted) {
                  return;
                }
                messenger.showSnackBar(
                  const SnackBar(content: Text('设置已保存')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
