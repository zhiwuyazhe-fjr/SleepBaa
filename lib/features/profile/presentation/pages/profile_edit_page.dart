import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_page_insets.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/core/utils/avatar_picker.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_detail_page_header.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';
import 'package:sleep_dorm_app/core/widgets/user_avatar.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  static const List<String> _presetRoles = <String>['早起的鸟儿有虫吃', '晚起的虫儿不会被鸟吃'];

  TextEditingController? _nameController;
  TextEditingController? _taglineController;
  TextEditingController? _customRoleController;
  String? _selectedRole;
  String? _boundUid;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final UserProfile profile = context.appServices.profileFacade.currentUser;
    if (_boundUid == profile.uid && _nameController != null) {
      return;
    }
    _boundUid = profile.uid;
    _nameController?.dispose();
    _taglineController?.dispose();
    _customRoleController?.dispose();
    _nameController = TextEditingController(text: profile.displayName);
    _taglineController = TextEditingController(text: profile.tagline);
    if (_presetRoles.contains(profile.role)) {
      _selectedRole = profile.role;
      _customRoleController = TextEditingController();
    } else {
      _selectedRole = null;
      _customRoleController = TextEditingController(text: profile.role);
    }
  }

  @override
  void dispose() {
    _nameController?.dispose();
    _taglineController?.dispose();
    _customRoleController?.dispose();
    super.dispose();
  }

  String _resolvedRole() {
    final String? selectedRole = _selectedRole?.trim();
    if (selectedRole != null && selectedRole.isNotEmpty) {
      return selectedRole;
    }
    return _customRoleController!.text.trim();
  }

  Future<void> _save(AppServices services) async {
    final String resolvedRole = _resolvedRole();
    if (resolvedRole.isEmpty) {
      await notifyPassiveToast(context, message: '请先选择角色');
      return;
    }
    setState(() => _isSaving = true);
    try {
      await services.profileFacade.saveProfile(
        displayName: _nameController!.text.trim(),
        tagline: _taglineController!.text.trim(),
        role: resolvedRole,
        settings: services.profileFacade.currentSettings,
      );
      if (!mounted) {
        return;
      }
      await notifyPassiveToast(context, message: '个人资料已保存。');
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      await notifyPassiveToast(context, message: '保存失败：$error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    final UserProfile profile = services.profileFacade.currentUser;
    if (_nameController == null ||
        _taglineController == null ||
        _customRoleController == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    return Scaffold(
      appBar: AppDetailPageAppBar(
        title: '编辑个人资料',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SafeArea(
        child: ListView(
          padding: AppPageInsets.page(bottom: AppSpacing.lg),
          children: <Widget>[
            AppCard(
              color: context.nightMoodPalette.primaryHighlight,
              padding: const EdgeInsets.all(AppSpacing.sm),
              borderRadius: AppRadius.compactCard,
              child: Row(
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
                          '调整昵称、签名和角色，让账号页展示更完整。',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '头像也可以直接点按更新。',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: context.appColors.textSecondary,
                                height: 1.3,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.sm),
              borderRadius: AppRadius.compactCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _EditSectionHeader(
                    title: '基础信息',
                    subtitle: '这些内容会直接影响你的账号展示。',
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _LabeledEditor(
                    label: '昵称',
                    hintText: '输入你希望展示的昵称',
                    controller: _nameController!,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _LabeledEditor(
                    label: '个性签名',
                    hintText: '写一句代表你当前状态的话',
                    controller: _taglineController!,
                    minLines: 3,
                    maxLines: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.sm),
              borderRadius: AppRadius.compactCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _EditSectionHeader(
                    title: '角色设定',
                    subtitle: '先选常用角色，也可以写一个更贴近你状态的描述。',
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: _presetRoles
                        .map((String role) {
                          final bool selected = _selectedRole == role;
                          return _RoleOptionButton(
                            label: role,
                            selected: selected,
                            onTap: () {
                              setState(() {
                                _selectedRole = selected ? null : role;
                                if (!selected) {
                                  _customRoleController!.clear();
                                }
                              });
                            },
                          );
                        })
                        .toList(growable: false),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _LabeledEditor(
                    label: '自定义角色',
                    hintText: '输入一个更贴近你状态的角色描述',
                    controller: _customRoleController!,
                    onChanged: (String value) {
                      if (value.trim().isEmpty || _selectedRole == null) {
                        return;
                      }
                      setState(() => _selectedRole = null);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: _isSaving ? '保存中...' : '保存',
              icon: Icons.save_rounded,
              size: PrimaryButtonSize.compact,
              onPressed: _isSaving ? null : () => _save(services),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditSectionHeader extends StatelessWidget {
  const _EditSectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: appColors.textSecondary,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _LabeledEditor extends StatelessWidget {
  const _LabeledEditor({
    required this.label,
    required this.hintText,
    required this.controller,
    this.minLines = 1,
    this.maxLines = 1,
    this.onChanged,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: appColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xxs),
        TextField(
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: appColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            border: OutlineInputBorder(
              borderRadius: AppRadius.control,
              borderSide: BorderSide(color: appColors.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.control,
              borderSide: BorderSide(color: appColors.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.control,
              borderSide: BorderSide(color: context.nightMoodPalette.primary),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoleOptionButton extends StatelessWidget {
  const _RoleOptionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    final AppSemanticColors appColors = context.appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: AppRadius.control,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minWidth: 120),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: selected
                ? palette.welcomeAccentColor.withAlpha(70)
                : appColors.surfaceMuted,
            borderRadius: AppRadius.compactCard,
            border: Border.all(
              color: selected
                  ? palette.welcomeAccentColor
                  : appColors.borderSubtle,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 18,
                color: selected
                    ? appColors.textOnAccent
                    : appColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: selected
                        ? appColors.textOnAccent
                        : appColors.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
