import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择角色')));
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
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    if (_nameController == null ||
        _taglineController == null ||
        _customRoleController == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    return Scaffold(
      appBar: AppBar(title: const Text('编辑个人资料')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: <Widget>[
            AppCard(
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: '昵称'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _taglineController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: '个性签名'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '角色',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
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
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _customRoleController,
                    decoration: const InputDecoration(
                      labelText: 'Others……',
                      hintText: '输入自定义角色',
                    ),
                    onChanged: (String value) {
                      if (value.trim().isEmpty || _selectedRole == null) {
                        return;
                      }
                      setState(() {
                        _selectedRole = null;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: _isSaving ? '保存中...' : '保存',
              icon: Icons.save_rounded,
              onPressed: _isSaving ? null : () => _save(services),
            ),
          ],
        ),
      ),
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
    final Color primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minWidth: 140),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: selected ? primary.withAlpha(18) : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? primary : AppColors.divider,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 18,
                color: selected ? primary : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: selected ? primary : AppColors.textPrimary,
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
