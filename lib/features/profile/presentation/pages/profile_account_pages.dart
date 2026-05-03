import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_page_insets.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/core/utils/avatar_picker.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_settings_group.dart';
import 'package:sleep_dorm_app/core/widgets/app_strip_card.dart';
import 'package:sleep_dorm_app/core/widgets/modals/app_modal.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';
import 'package:sleep_dorm_app/core/widgets/user_avatar.dart';
import 'package:sleep_dorm_app/features/profile/presentation/widgets/account_action_widgets.dart';

final EdgeInsets _accountPagePadding = AppPageInsets.page(
  bottom: AppSpacing.lg,
);

class AccountManagementPage extends StatelessWidget {
  const AccountManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    return Scaffold(
      appBar: AppBar(title: const Text('账号管理')),
      body: SafeArea(
        child: ListView(
          padding: _accountPagePadding,
          children: <Widget>[
            AppSettingsGroup(
              children: <Widget>[
                AppSettingsItem(
                  icon: Icons.badge_outlined,
                  iconColor: palette.primaryDeep,
                  title: '个人资料',
                  onTap: () => context.push(AppRoutes.profileAccountProfile),
                ),
                AppSettingsItem(
                  icon: Icons.password_rounded,
                  iconColor: palette.primaryDeep,
                  title: '重置密码',
                  onTap: () => context.push(AppRoutes.profileAccountPassword),
                ),
                AppSettingsItem(
                  icon: Icons.login_rounded,
                  iconColor: palette.primaryDeep,
                  title: '登录管理',
                  onTap: () => context.push(AppRoutes.profileAccountLogin),
                ),
                AppSettingsItem(
                  icon: Icons.night_shelter_rounded,
                  iconColor: palette.primaryDeep,
                  title: '寝室管理',
                  onTap: () => context.push(AppRoutes.profileAccountDorm),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AccountProfilePage extends StatelessWidget {
  const AccountProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return Scaffold(
      appBar: AppBar(title: const Text('个人资料')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[
            services.authRepository,
            services.dormRepository,
          ]),
          builder: (BuildContext context, Widget? child) {
            final UserProfile profile = services.profileFacade.currentUser;
            final Dorm dorm = services.dormFacade.currentDorm;
            final String displayedPhone = _displayedPhone(
              profile,
              services.authRepository,
            );

            return ListView(
              padding: _accountPagePadding,
              children: <Widget>[
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  borderRadius: AppRadius.compactCard,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          UserAvatar(
                            profile: profile,
                            size: 60,
                            editable: true,
                            onTap: () => pickAndSaveAvatar(context),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  _profileDisplayName(profile),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  displayedPhone.isEmpty
                                      ? '尚未绑定手机号'
                                      : displayedPhone,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          SizedBox(
                            width: 92,
                            child: PrimaryButton(
                              label: '编辑资料',
                              size: PrimaryButtonSize.compact,
                              variant: PrimaryButtonVariant.soft,
                              onPressed: () =>
                                  context.push(AppRoutes.profileEdit),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppSettingsGroup(
                  children: <Widget>[
                    AppSettingsDetailItem(
                      label: '个性签名',
                      value: profile.tagline.isEmpty
                          ? '还没有填写个性签名'
                          : profile.tagline,
                    ),
                    AppSettingsDetailItem(
                      label: '角色',
                      value: profile.role.isEmpty ? '暂未设置' : profile.role,
                    ),
                    AppSettingsDetailItem(
                      label: '寝室',
                      value: dorm.id.isEmpty ? '未加入宿舍' : dorm.name,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class LoginManagementPage extends StatelessWidget {
  const LoginManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return Scaffold(
      appBar: AppBar(title: const Text('登录管理')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: services.authRepository,
          builder: (BuildContext context, Widget? child) {
            final UserProfile profile = services.profileFacade.currentUser;
            final String displayedPhone = _displayedPhone(
              profile,
              services.authRepository,
            );
            final bool hasVerifiedPhoneIdentity =
                services.authRepository.hasVerifiedPhoneIdentity;

            return ListView(
              padding: _accountPagePadding,
              children: <Widget>[
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  borderRadius: AppRadius.compactCard,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          _LeadingIconBadge(
                            icon: hasVerifiedPhoneIdentity
                                ? Icons.verified_user_rounded
                                : Icons.info_outline_rounded,
                            color: context.nightMoodPalette.welcomeAccentColor,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  hasVerifiedPhoneIdentity
                                      ? '当前账号已验证'
                                      : '当前账号未绑定手机号',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  displayedPhone.isEmpty
                                      ? '如果需要密码登录或重置密码，请先确认账号手机号。'
                                      : '当前手机号：$displayedPhone',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                        height: 1.3,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppSettingsGroup(
                  children: <Widget>[
                    AppSettingsDetailItem(
                      label: '登录方式',
                      value: displayedPhone.isEmpty ? '游客 / 本地账号' : '手机号 + 密码',
                    ),
                    AppSettingsDetailItem(
                      label: '手机验证',
                      value: hasVerifiedPhoneIdentity ? '已完成' : '未完成',
                    ),
                    AppSettingsDetailItem(
                      label: '最近绑定',
                      value: _formatDateTime(profile.phoneLinkedAt),
                    ),
                  ],
                ),
                if (services.authRepository.lastAuthError != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(
                    color: AppColors.surfaceMuted,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    borderRadius: AppRadius.compactCard,
                    child: Text(
                      services.authRepository.lastAuthError!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                AccountSignOutButton(services: services),
              ],
            );
          },
        ),
      ),
    );
  }
}

class DormManagementPage extends StatefulWidget {
  const DormManagementPage({super.key});

  @override
  State<DormManagementPage> createState() => _DormManagementPageState();
}

class _DormManagementPageState extends State<DormManagementPage> {
  bool _isSavingDormAnchor = false;

  Future<String?> _promptDormName(String initialName) {
    return showAppModal<String>(
      context,
      spec: AppFormDialogSpec<String>(
        builder: (BuildContext dialogContext) {
          return _DormNameDialog(initialName: initialName);
        },
      ),
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
        await notifyPassiveToast(context, message: '未能获取定位，请检查定位权限和系统定位开关。');
        return;
      }
      await services.dormPresenceSyncController.persistDormLocationAnchor(
        anchor,
      );
      if (!mounted) {
        return;
      }
      await notifyPassiveToast(context, message: '宿舍位置已重新记录。');
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
    final bool? confirmed = await showAppModal<bool>(
      context,
      spec: const AppDestructiveDialogSpec(
        title: '退出宿舍',
        body: '退出后将离开当前宿舍空间。若你是最后一位成员，宿舍会自动归档。',
        icon: AppDialogIconSpec(icon: Icons.logout_rounded),
        cancelLabel: '取消',
        confirmLabel: '确认退出',
      ),
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

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return Scaffold(
      appBar: AppBar(title: const Text('寝室管理')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: services.dormRepository,
          builder: (BuildContext context, Widget? child) {
            final Dorm dorm = services.dormFacade.currentDorm;
            final NightMoodPalette palette = context.nightMoodPalette;
            final TextTheme textTheme = Theme.of(context).textTheme;

            if (dorm.id.isEmpty) {
              return ListView(
                padding: _accountPagePadding,
                children: <Widget>[
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    borderRadius: AppRadius.compactCard,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '你还没有加入寝室',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '账号页只保留轻量入口，完整互动仍建议在宿舍页里完成。',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        PrimaryButton(
                          label: '创建或加入宿舍',
                          icon: Icons.group_rounded,
                          size: PrimaryButtonSize.compact,
                          onPressed: () => context.push(AppRoutes.dormInvite),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView(
              padding: _accountPagePadding,
              children: <Widget>[
                AppStripCard(
                  leading: _LeadingIconBadge(
                    icon: Icons.night_shelter_rounded,
                    color: palette.welcomeAccentColor,
                  ),
                  title: dorm.name,
                  subtitle: '${dorm.members.length} 位成员 · ${dorm.overview}',
                  padding: const EdgeInsets.all(AppSpacing.md),
                  borderRadius: AppRadius.compactCard,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppSettingsGroup(
                  children: <Widget>[
                    AppSettingsItem(
                      icon: Icons.group_add_rounded,
                      iconColor: palette.primary,
                      title: '邀请舍友',
                      onTap: () => context.push(AppRoutes.dormInvite),
                    ),
                    AppSettingsItem(
                      icon: Icons.rule_folder_outlined,
                      iconColor: palette.primary,
                      title: '查看宿舍规则',
                      onTap: () => context.push(AppRoutes.dormRules),
                    ),
                    AppSettingsItem(
                      icon: Icons.edit_rounded,
                      iconColor: palette.primary,
                      title: '编辑宿舍名称',
                      onTap: () => _renameDorm(services, dorm),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  borderRadius: AppRadius.compactCard,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _DenseMetaTile(
                        label: '定位状态',
                        value: _locationSummary(dorm),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      PrimaryButton(
                        label: '重新记录位置',
                        icon: Icons.my_location_rounded,
                        size: PrimaryButtonSize.compact,
                        variant: PrimaryButtonVariant.soft,
                        isLoading: _isSavingDormAnchor,
                        loadingLabel: '记录中...',
                        onPressed: () => _refreshDormLocation(services),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  borderRadius: AppRadius.compactCard,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '当前成员',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      for (int i = 0; i < dorm.members.length; i++) ...<Widget>[
                        _MemberRow(member: dorm.members[i]),
                        if (i != dorm.members.length - 1)
                          const SizedBox(height: AppSpacing.xs),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                PrimaryButton(
                  label: '退出当前宿舍',
                  icon: Icons.logout_rounded,
                  variant: PrimaryButtonVariant.ghost,
                  size: PrimaryButtonSize.compact,
                  onPressed: () => _leaveDorm(services),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DenseMetaTile extends StatelessWidget {
  const _DenseMetaTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.compactCard,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeadingIconBadge extends StatelessWidget {
  const _LeadingIconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withAlpha(56),
        borderRadius: AppRadius.compactCard,
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});

  final DormMember member;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.compactCard,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(
              radius: 18,
              backgroundColor: context.nightMoodPalette.primarySoft.withAlpha(
                90,
              ),
              child: Text(
                member.name.isEmpty ? '?' : member.name.characters.first,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    member.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_presenceLabel(member.presenceStatus)} · ${_statusLabel(member.status)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    return AppFormDialogScaffold(
      title: '编辑宿舍名称',
      body: '修改后会同步显示在当前宿舍空间。',
      icon: const AppDialogIconSpec(icon: Icons.edit_outlined),
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
        AppModalAction(
          label: '取消',
          variant: PrimaryButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppModalAction(
          label: '保存',
          onPressed: () => Navigator.of(context).pop(_value.trim()),
        ),
      ],
    );
  }
}

String _displayedPhone(UserProfile profile, AuthRepository authRepository) {
  final List<String> candidates = <String>[
    if (profile.phoneNumber != null) profile.phoneNumber!,
    if (authRepository.currentUser.phoneNumber != null)
      authRepository.currentUser.phoneNumber!,
  ];
  for (final String item in candidates) {
    final String trimmed = item.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return '';
}

String _profileDisplayName(UserProfile profile) {
  final String displayName = profile.displayName.trim();
  return displayName.isEmpty ? '未设置昵称' : displayName;
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return '暂无记录';
  }
  final DateTime local = value.toLocal();
  final String minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}/${local.month}/${local.day} ${local.hour}:$minute';
}

String _locationSummary(Dorm dorm) {
  final DormLocationAnchor? anchor = dorm.locationAnchor;
  if (anchor == null) {
    return '暂未配置自动回宿判断。点击下方按钮记录当前宿舍位置。';
  }
  final DateTime recordedAt = anchor.recordedAt.toLocal();
  return '已记录宿舍坐标，判定半径 ${anchor.radiusMeters.toStringAsFixed(0)}m。'
      ' 上次记录于 ${recordedAt.month}/${recordedAt.day} '
      '${recordedAt.hour.toString().padLeft(2, '0')}:'
      '${recordedAt.minute.toString().padLeft(2, '0')}。';
}

String _presenceLabel(DormPresenceStatus status) {
  return switch (status) {
    DormPresenceStatus.returned => '已返宿',
    DormPresenceStatus.away => '未返宿',
    DormPresenceStatus.unknown => '状态待确认',
  };
}

String _statusLabel(DormMemberStatus status) {
  return switch (status) {
    DormMemberStatus.sleeping => '睡眠中',
    DormMemberStatus.quiet => '安静模式',
    DormMemberStatus.away => '暂离',
    DormMemberStatus.active => '在线',
  };
}
