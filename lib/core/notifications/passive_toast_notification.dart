import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/notifications/unified_notification.dart';
import 'package:sleep_dorm_app/core/widgets/passive_toast.dart';

const String passiveToastContextMetadataKey = 'passiveToastContext';
const String passiveToastKeyMetadataKey = 'passiveToastKey';

Future<void> notifyPassiveToast(
  BuildContext context, {
  required String message,
  Duration duration = const Duration(seconds: 2),
  Key? toastKey,
}) {
  return context.appServices.notificationApi.notify(
    UnifiedNotificationRequest(
      kind: NotificationDeliveryKind.inApp,
      channel: InAppNotificationChannelType.passiveToast.name,
      payload: UnifiedNotificationPayload(
        message: message,
        metadata: <String, Object?>{
          passiveToastContextMetadataKey: context,
          passiveToastKeyMetadataKey: toastKey,
        },
      ),
      duration: duration,
    ),
  );
}

final class PassiveToastNotificationChannel
    extends InAppNotificationChannelProtocol {
  PassiveToastNotificationChannel({PassiveToastController? controller})
    : _controller = controller ?? PassiveToastController();

  final PassiveToastController _controller;

  @override
  String get channel => InAppNotificationChannelType.passiveToast.name;

  @override
  Future<void> deliver(UnifiedNotificationRequest request) async {
    final BuildContext? context =
        request.payload.metadata[passiveToastContextMetadataKey]
            as BuildContext?;
    if (context == null || !context.mounted) {
      return;
    }
    final Key? toastKey =
        request.payload.metadata[passiveToastKeyMetadataKey] as Key?;
    await _controller.show(
      context,
      message: request.payload.message,
      duration: request.duration,
      toastKey: toastKey,
    );
  }

  void dispose() {
    _controller.dispose();
  }
}
