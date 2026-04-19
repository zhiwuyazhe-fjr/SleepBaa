import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/widgets/assistant_fab.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
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
  String? _boundUid;
  bool _isSavingSettings = false;
  bool _isSavingDormAnchor = false;
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

  Future<String?> _promptDormName(String initialName) {
    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _DormNameDialog(initialName: initialName);
      },
    );
  }

  Future<void> _renameDorm(AppServices services, Dorm dorm) async {
    final String? nextName = await _promptDormName(dorm.name);
    if (nextName == null || nextName.isEmpty) {
      return;
    }
    await services.dormFacade.renameDorm(nextName);
    if (!mounted) {
      return;
    }
    await notifyPassiveToast(context, message: '宿舍名称已更新。');
  }

  Future<void> _refreshDormLocation(AppServices services) async {
    setState(() => _isSavingDormAnchor = true);
    try {
      final DormLocationAnchor? anchor = await services
          .dormPresenceSyncController
          .captureCurrentLocationAnchor(requestPermission: true);
      if (anchor == null) {
        if (!mounted) {
          return;
        }
        await notifyPassiveToast(
          context,
          message: '未能获取定位，请检查定位权限和系统定位开关。',
        );
        return;
      }
      await services.dormPresenceSyncController.persistDormLocationAnchor(
        anchor,
      );
      if (!mounted) {
        return;
      }
      final bool usesCloudPersistence =
          services.environment.usesCloudBase &&
          services.environment.hasCloudBaseAppApi;
      await notifyPassiveToast(
        context,
        message: usesCloudPersistence
            ? '宿舍位置已重新记录，并会在下次打开 App 时继续沿用。'
            : '宿舍位置已记录到本机，但当前未写入云端。',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await notifyPassiveToast(context, message: '记录宿舍位置失败：$error');
    } finally {
      if (mounted) {
        setState(() => _isSavingDormAnchor = false);
      }
    }
  }

  Future<void> _leaveDorm(AppServices services) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('退出宿舍'),
          content: const Text('退出后将离开当前宿舍空间。若你是最后一位成员，宿舍会自动归档。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认退出'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await services.dormFacade.leaveDorm();
    if (!mounted) {
      return;
    }
    await notifyPassiveToast(context, message: '你已退出当前宿舍。');
  }

  Future<void> _signOut(AppServices services) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('退出登录'),
          content: const Text('退出后将清除当前登录状态，需要重新完成登录。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认退出'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await services.profileFacade.signOut();
    if (!mounted) {
      return;
    }
    context.go(AppRoutes.authPhone);
    await notifyPassiveToast(context, message: '已退出登录。');
  }

  String _locationSummary(
    Dorm dorm, {
    DormLocationAnchor? effectiveAnchor,
  }) {
    final DormLocationAnchor? anchor = effectiveAnchor ?? dorm.locationAnchor;
    if (dorm.id.isEmpty) {
      return '加入宿舍后可记录宿舍坐标，用于自动判断“已返 / 未返”。';
    }
    if (anchor == null) {
      return '暂未配置自动回宿判断。点击下方按钮记录当前宿舍位置。';
    }
    final DateTime recordedAt = anchor.recordedAt.toLocal();
    return '已记录宿舍坐标，判定半径 ${anchor.radiusMeters.toStringAsFixed(0)}m。'
        ' 上次记录于 ${recordedAt.month}/${recordedAt.day} '
        '${recordedAt.hour.toString().padLeft(2, '0')}:'
        '${recordedAt.minute.toString().padLeft(2, '0')}。';
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[
            services.authRepository,
            services.settingsRepository,
            services.dormRepository,
            services.nightWelcomeController,
          ]),
          builder: (BuildContext context, Widget? child) {
            final UserProfile profile = services.profileFacade.currentUser;
            final UserSettings settings = services.profileFacade.currentSettings;
            final Dorm dorm = services.dormFacade.currentDorm;
            final String displayedPhone = <String?>[
              profile.phoneNumber,
              services.authRepository.currentUser.phoneNumber,
            ].whereType<String>().map((String item) => item.trim()).firstWhere(
              (String item) => item.isNotEmpty,
              orElse: () => '',
            );
            _syncState(profile, settings);

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: <Widget>[
                AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      UserAvatar(
                        profile: profile,
                        size: 84,
                        editable: true,
                        onTap: () => pickAndSaveAvatar(context),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _ProfileLine(
                              label: '昵称',
                              value: profile.displayName.isEmpty
                                  ? '暂未设置'
                                  : profile.displayName,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _ProfileLine(
                              label: '个性签名',
                              value: profile.tagline.isEmpty
                                  ? '还没有填写个性签名'
                                  : profile.tagline,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _ProfileLine(
                              label: '角色',
                              value: profile.role.isEmpty ? '暂未设置' : profile.role,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      PrimaryButton(
                        label: '编辑',
                        expand: false,
                        variant: PrimaryButtonVariant.soft,
                        onPressed: () => context.push(AppRoutes.profileEdit),
                      ),
                    ],
                  ),
                ),
                if (services.authRepository.lastAuthError != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    color: AppColors.surfaceMuted,
                    child: Text(
                      services.authRepository.lastAuthError!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Text('切换心情', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '选择后整应用配色会立即切换。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.lg,
                    horizontal: AppSpacing.md,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: _MoodAssistantFabSlot(
                          label: '开心',
                          palette: NightMoodPalette.fromMood(NightMood.happy),
                          keySuffix: '-settings-happy',
                          selected:
                              settings.selectedNightMood == NightMood.happy,
                          enabled: !_isApplyingNightMood,
                          onTap: () => unawaited(
                            _applyNightMood(services, NightMood.happy),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: _MoodAssistantFabSlot(
                          label: '低落',
                          palette: NightMoodPalette.fromMood(NightMood.sad),
                          keySuffix: '-settings-sad',
                          selected: settings.selectedNightMood == NightMood.sad,
                          enabled: !_isApplyingNightMood,
                          onTap: () => unawaited(
                            _applyNightMood(services, NightMood.sad),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: _MoodAssistantFabSlot(
                          label: '平静',
                          palette: NightMoodPalette.fromMood(NightMood.calm),
                          keySuffix: '-settings-calm',
                          selected:
                              settings.selectedNightMood == NightMood.calm,
                          enabled: !_isApplyingNightMood,
                          onTap: () => unawaited(
                            _applyNightMood(services, NightMood.calm),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: _MoodAssistantFabSlot(
                          label: '未知',
                          palette: NightMoodPalette.fromMood(null),
                          keySuffix: '-settings-unknown',
                          selected: settings.selectedNightMood == null,
                          enabled: !_isApplyingNightMood,
                          onTap: () => unawaited(
                            _applyNightMood(services, null),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('睡眠偏好', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            '目标睡眠时长',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Text('${_sleepGoalHours.toStringAsFixed(1)} 小时'),
                        ],
                      ),
                      Slider(
                        value: _sleepGoalHours,
                        min: 6,
                        max: 9,
                        divisions: 12,
                        onChanged: (double value) {
                          setState(() => _sleepGoalHours = value);
                        },
                      ),
                      _ActionRow(
                        title: '睡前提醒时间',
                        subtitle: Formatters.formatClock(_bedtimeReminder),
                        onTap: _pickReminderTime,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('睡前提醒'),
                        value: _bedtimeReminderEnabled,
                        onChanged: (bool value) {
                          setState(() => _bedtimeReminderEnabled = value);
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('晨间反馈提醒'),
                        value: _morningReminderEnabled,
                        onChanged: (bool value) {
                          setState(() => _morningReminderEnabled = value);
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('宿舍动态提醒'),
                        value: _dormAlertsEnabled,
                        onChanged: (bool value) {
                          setState(() => _dormAlertsEnabled = value);
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('智能建议'),
                        value: _smartSuggestionsEnabled,
                        onChanged: (bool value) {
                          setState(() => _smartSuggestionsEnabled = value);
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PrimaryButton(
                        label: _isSavingSettings ? '保存中...' : '保存睡眠设置',
                        icon: Icons.save_rounded,
                        onPressed: _isSavingSettings
                            ? null
                            : () => _saveSleepSettings(services),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('账号与安全', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        displayedPhone.isEmpty
                            ? '当前未显示手机号'
                            : '当前手机号：$displayedPhone',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      PrimaryButton(
                        label: '退出登录',
                        expand: false,
                        variant: PrimaryButtonVariant.ghost,
                        icon: Icons.logout_rounded,
                        onPressed: () => _signOut(services),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('宿舍', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        dorm.id.isEmpty ? '你还没有加入宿舍' : dorm.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _locationSummary(dorm),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (dorm.id.isEmpty)
                        PrimaryButton(
                          label: '创建或加入宿舍',
                          icon: Icons.group_rounded,
                          onPressed: () => context.push(AppRoutes.dormInvite),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: PrimaryButton(
                                    label: '编辑宿舍名称',
                                    variant: PrimaryButtonVariant.soft,
                                    icon: Icons.edit_rounded,
                                    onPressed: () => _renameDorm(services, dorm),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: PrimaryButton(
                                    label: _isSavingDormAnchor ? '记录中...' : '重新记录位置',
                                    variant: PrimaryButtonVariant.soft,
                                    icon: Icons.my_location_rounded,
                                    onPressed: _isSavingDormAnchor
                                        ? null
                                        : () => _refreshDormLocation(services),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: <Widget>[
                                PrimaryButton(
                                  label: '邀请舍友',
                                  expand: false,
                                  variant: PrimaryButtonVariant.soft,
                                  icon: Icons.group_add_rounded,
                                  onPressed: () => context.push(AppRoutes.dormInvite),
                                ),
                                PrimaryButton(
                                  label: '退出宿舍',
                                  expand: false,
                                  variant: PrimaryButtonVariant.ghost,
                                  icon: Icons.logout_rounded,
                                  onPressed: () => _leaveDorm(services),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Uses [AssistantFabVisual] so each option matches the floating assistant glyph.
class _MoodAssistantFabSlot extends StatelessWidget {
  const _MoodAssistantFabSlot({
    required this.label,
    required this.palette,
    required this.keySuffix,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final NightMoodPalette palette;
  final String keySuffix;
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
          onTap: enabled ? onTap : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: EdgeInsets.all(selected ? 3 : 0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    width: selected ? 2.5 : 0,
                    color: selected ? palette.primary : Colors.transparent,
                  ),
                  boxShadow: selected
                      ? <BoxShadow>[
                          BoxShadow(
                            color: palette.primary.withAlpha(55),
                            blurRadius: 10,
                            spreadRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: AssistantFabVisual(
                    palette: palette,
                    keySuffix: keySuffix,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium?.copyWith(
                  color: palette.primaryDeep,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DormNameDialog extends StatefulWidget {
  const _DormNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_DormNameDialog> createState() => _DormNameDialogState();
}

class _DormNameDialogState extends State<_DormNameDialog> {
  late String _value = widget.initialName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑宿舍名称'),
      content: TextFormField(
        initialValue: widget.initialName,
        autofocus: true,
        decoration: const InputDecoration(hintText: '输入新的宿舍名称'),
        onChanged: (String value) => _value = value,
        onFieldSubmitted: (String value) {
          Navigator.of(context).pop(value.trim());
        },
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_value.trim()),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _ProfileLine extends StatelessWidget {
  const _ProfileLine({required this.label, required this.value});

  final String label;
  final String value;

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
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.35),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
