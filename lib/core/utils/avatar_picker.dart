import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';

Future<void> pickAndSaveAvatar(BuildContext context) async {
  final authRepository = context.appServices.authRepository;
  final ImagePicker picker = ImagePicker();
  final XFile? image = await picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 86,
    maxWidth: 1440,
  );
  if (image == null) {
    return;
  }

  try {
    final Uint8List bytes = await image.readAsBytes();
    await authRepository.updateAvatar(
      avatarPath: image.path,
      avatarBytes: bytes,
    );
    if (!context.mounted) {
      return;
    }
    await notifyPassiveToast(context, message: '头像已更新');
  } catch (_) {
    if (!context.mounted) {
      return;
    }
    await notifyPassiveToast(context, message: '头像读取失败，请重试');
  }
}
