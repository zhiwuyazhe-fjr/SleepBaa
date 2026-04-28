import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/core/widgets/modals/app_modal.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';

Future<void> confirmAndSignOutAccount(
  BuildContext context,
  AppServices services,
) async {
  final bool? confirmed = await showAppModal<bool>(
    context,
    spec: const AppDestructiveDialogSpec(
      title: '退出登录',
      body: '退出后将清除当前登录状态，需要重新完成登录。',
      icon: AppDialogIconSpec(icon: Icons.logout_rounded),
      cancelLabel: '取消',
      confirmLabel: '确认退出',
    ),
  );
  if (confirmed != true) {
    return;
  }
  await services.profileFacade.signOut();
  if (!context.mounted) {
    return;
  }
  context.go(AppRoutes.authPhone);
  await notifyPassiveToast(context, message: '已退出登录。');
}

class AccountSignOutButton extends StatelessWidget {
  const AccountSignOutButton({
    super.key,
    required this.services,
    this.label = '退出当前账号',
  });

  final AppServices services;
  final String label;

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      label: label,
      icon: Icons.logout_rounded,
      variant: PrimaryButtonVariant.ghost,
      size: PrimaryButtonSize.compact,
      onPressed: () => confirmAndSignOutAccount(context, services),
    );
  }
}
