import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
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
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  String? _boundUid;
  PhoneVerificationChallenge? _phoneChallenge;
  bool _isSavingSettings = false;
  bool _isSendingCode = false;
  bool _isRecoveringPhone = false;
  double _sleepGoalHours = 7.5;
  bool _bedtimeReminderEnabled = true;
  bool _morningReminderEnabled = true;
  bool _dormAlertsEnabled = true;
  bool _smartSuggestionsEnabled = true;
  TimeOfDay _bedtimeReminder = const TimeOfDay(hour: 23, minute: 10);

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

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
    _phoneController.text = profile.phoneNumber ?? '';
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('设置已保存')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingSettings = false);
      }
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

  Future<void> _sendPhoneCode(AppServices services) async {
    final String phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先输入手机号')));
      return;
    }
    setState(() => _isSendingCode = true);
    try {
      final PhoneVerificationChallenge challenge =
          await services.profileFacade.sendPhoneVerificationCode(phoneNumber);
      if (!mounted) {
        return;
      }
      setState(() => _phoneChallenge = challenge);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('验证码已发送')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败：$error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingCode = false);
      }
    }
  }

  Future<void> _recoverPhoneAccount(AppServices services) async {
    final String phoneNumber = _phoneController.text.trim();
    final String code = _codeController.text.trim();
    if (phoneNumber.isEmpty || code.isEmpty || _phoneChallenge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先输入手机号、发送验证码并填写验证码')),
      );
      return;
    }
    setState(() => _isRecoveringPhone = true);
    try {
      await services.profileFacade.recoverWithPhone(
        phoneNumber: phoneNumber,
        verificationId: _phoneChallenge!.verificationId,
        code: code,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _phoneChallenge = null;
        _codeController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('手机号主账号已恢复')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('恢复失败：$error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRecoveringPhone = false);
      }
    }
  }

  Future<void> _renameDorm(AppServices services, Dorm dorm) async {
    final TextEditingController controller = TextEditingController(text: dorm.name);
    final String? nextName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('编辑宿舍名称'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '输入新的宿舍名称'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    if (nextName == null || nextName.isEmpty) {
      return;
    }
    await services.dormFacade.renameDorm(nextName);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('宿舍名称已更新')));
    }
  }

  Future<void> _leaveDorm(AppServices services) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('退出宿舍'),
          content: const Text('退出后将离开当前宿舍空间，最后一位成员退出时宿舍会自动归档。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
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
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已退出当前宿舍')));
    }
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
          ]),
          builder: (BuildContext context, Widget? child) {
            final UserProfile profile = services.profileFacade.currentUser;
            final UserSettings settings = services.profileFacade.currentSettings;
            final Dorm dorm = services.dormFacade.currentDorm;
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
                                  ? '未设置'
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
                              value: profile.role.isEmpty ? '未设置' : profile.role,
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
                        profile.phoneNumber == null || profile.phoneNumber!.isEmpty
                            ? '绑定手机号并恢复原账号数据'
                            : '当前手机号：${profile.phoneNumber}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '验证码登录完成后，会把当前匿名账号数据迁移到手机号主账号。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: '手机号',
                          hintText: '请输入手机号',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '验证码',
                          hintText: '请输入验证码',
                        ),
                      ),
                      if (_phoneChallenge != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _phoneChallenge!.isExistingUser
                              ? '该手机号已有主账号，验证后会恢复原账号数据。'
                              : '该手机号还没有主账号，验证后会创建并迁移当前数据。',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: PrimaryButton(
                              label: _isSendingCode ? '发送中...' : '发送验证码',
                              expand: false,
                              variant: PrimaryButtonVariant.soft,
                              onPressed: _isSendingCode
                                  ? null
                                  : () => _sendPhoneCode(services),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: PrimaryButton(
                              label: _isRecoveringPhone ? '恢复中...' : '确认绑定',
                              expand: false,
                              onPressed: _isRecoveringPhone
                                  ? null
                                  : () => _recoverPhoneAccount(services),
                            ),
                          ),
                        ],
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
                        dorm.id.isEmpty
                            ? '先创建宿舍或输入邀请码加入宿舍。'
                            : '可以在这里编辑宿舍名称、邀请舍友，或者退出当前宿舍。',
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
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: <Widget>[
                            PrimaryButton(
                              label: '编辑宿舍名称',
                              expand: false,
                              variant: PrimaryButtonVariant.soft,
                              icon: Icons.edit_rounded,
                              onPressed: () => _renameDorm(services, dorm),
                            ),
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
                ),
              ],
            );
          },
        ),
      ),
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
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
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
