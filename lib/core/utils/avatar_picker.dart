import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';

const int _maxAvatarUploadBytes = 3 * 1024 * 1024;

Future<void> pickAndSaveAvatar(BuildContext context) async {
  final profileFacade = context.appServices.profileFacade;
  final ImagePicker picker = ImagePicker();
  final XFile? image = await picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 72,
    maxWidth: 960,
  );
  if (image == null) {
    return;
  }

  try {
    final Uint8List bytes = await image.readAsBytes();
    if (bytes.length > _maxAvatarUploadBytes) {
      if (!context.mounted) {
        return;
      }
      await notifyPassiveToast(
        context,
        message:
            '\u5934\u50cf\u6587\u4ef6\u8fc7\u5927\uff0c\u8bf7\u6362\u4e00\u5f20\u66f4\u5c0f\u7684\u56fe\u7247',
      );
      return;
    }
    await profileFacade.updateAvatar(
      avatarPath: image.path,
      avatarBytes: bytes,
    );
    if (!context.mounted) {
      return;
    }
    await notifyPassiveToast(
      context,
      message: '\u5934\u50cf\u5df2\u66f4\u65b0',
    );
  } catch (_) {
    if (!context.mounted) {
      return;
    }
    await notifyPassiveToast(
      context,
      message: '\u5934\u50cf\u4fdd\u5b58\u5931\u8d25\uff0c\u8bf7\u91cd\u8bd5',
    );
  }
}
