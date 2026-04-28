import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/core/widgets/modals/app_bottom_sheet.dart';
import 'package:sleep_dorm_app/core/widgets/modals/app_center_dialog.dart';
import 'package:sleep_dorm_app/core/widgets/modals/app_modal_spec.dart';

export 'package:sleep_dorm_app/core/widgets/modals/app_bottom_sheet.dart';
export 'package:sleep_dorm_app/core/widgets/modals/app_center_dialog.dart';
export 'package:sleep_dorm_app/core/widgets/modals/app_modal_spec.dart';

Future<T?> showAppModal<T>(
  BuildContext context, {
  required AppModalSpec<T> spec,
}) {
  if (spec is AppCenterDialogSpec<T>) {
    return showAppCenterDialog<T>(context, spec: spec);
  }
  if (spec is AppBottomSheetSpec<T>) {
    return showAppBottomSheet<T>(context, spec: spec);
  }
  throw StateError('Unsupported app modal spec: ${spec.runtimeType}');
}
