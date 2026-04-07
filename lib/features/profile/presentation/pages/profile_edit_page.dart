import 'package:flutter/material.dart';
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
  TextEditingController? _nameController;
  TextEditingController? _taglineController;
  TextEditingController? _roleController;
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
    _roleController?.dispose();
    _nameController = TextEditingController(text: profile.displayName);
    _taglineController = TextEditingController(text: profile.tagline);
    _roleController = TextEditingController(text: profile.role);
  }

  @override
  void dispose() {
    _nameController?.dispose();
    _taglineController?.dispose();
    _roleController?.dispose();
    super.dispose();
  }

  Future<void> _save(AppServices services) async {
    setState(() => _isSaving = true);
    try {
      await services.profileFacade.saveProfile(
        displayName: _nameController!.text.trim(),
        tagline: _taglineController!.text.trim(),
        role: _roleController!.text.trim(),
        settings: services.profileFacade.currentSettings,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$error')),
        );
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
        _roleController == null) {
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
                  TextField(
                    controller: _roleController,
                    decoration: const InputDecoration(labelText: '角色'),
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
