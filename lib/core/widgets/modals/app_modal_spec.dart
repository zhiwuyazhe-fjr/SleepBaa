import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';

sealed class AppModalSpec<T> {
  const AppModalSpec();
}

sealed class AppCenterDialogSpec<T> extends AppModalSpec<T> {
  const AppCenterDialogSpec({
    this.barrierDismissible = true,
    this.barrierColor = const Color(0x80000000),
    this.useRootNavigator = false,
    this.barrierLabel,
    this.routeSettings,
  });

  final bool barrierDismissible;
  final Color barrierColor;
  final bool useRootNavigator;
  final String? barrierLabel;
  final RouteSettings? routeSettings;
}

sealed class AppBottomSheetSpec<T> extends AppModalSpec<T> {
  const AppBottomSheetSpec({
    this.useSafeArea = false,
    this.useRootNavigator = false,
    this.isScrollControlled = false,
    this.isDismissible = true,
    this.enableDrag = true,
    this.showDragHandle = false,
    this.backgroundColor,
    this.shape,
    this.constraints,
    this.routeSettings,
  });

  final bool useSafeArea;
  final bool useRootNavigator;
  final bool isScrollControlled;
  final bool isDismissible;
  final bool enableDrag;
  final bool showDragHandle;
  final Color? backgroundColor;
  final ShapeBorder? shape;
  final BoxConstraints? constraints;
  final RouteSettings? routeSettings;
}

class AppDialogIconSpec {
  const AppDialogIconSpec({
    required this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.containerSize = 56,
    this.iconSize = 28,
  });

  final IconData icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double containerSize;
  final double iconSize;
}

class AppConfirmationDialogSpec extends AppCenterDialogSpec<bool> {
  const AppConfirmationDialogSpec({
    required this.title,
    required this.body,
    this.icon = const AppDialogIconSpec(
      icon: Icons.check_circle_outline_rounded,
    ),
    this.cancelLabel = '取消',
    this.confirmLabel = '确认',
    super.barrierDismissible = true,
    super.barrierColor,
    super.useRootNavigator,
    super.barrierLabel,
    super.routeSettings,
  });

  final String title;
  final String body;
  final AppDialogIconSpec icon;
  final String cancelLabel;
  final String confirmLabel;
}

class AppInfoDialogSpec extends AppCenterDialogSpec<void> {
  const AppInfoDialogSpec({
    required this.title,
    required this.body,
    this.icon = const AppDialogIconSpec(icon: Icons.info_outline_rounded),
    this.confirmLabel = '知道了',
    super.barrierDismissible = true,
    super.barrierColor,
    super.useRootNavigator,
    super.barrierLabel,
    super.routeSettings,
  });

  final String title;
  final String body;
  final AppDialogIconSpec icon;
  final String confirmLabel;
}

class AppDestructiveDialogSpec extends AppCenterDialogSpec<bool> {
  const AppDestructiveDialogSpec({
    required this.title,
    required this.body,
    this.icon = const AppDialogIconSpec(icon: Icons.delete_outline_rounded),
    this.cancelLabel = '取消',
    this.confirmLabel = '确认',
    super.barrierDismissible = true,
    super.barrierColor,
    super.useRootNavigator,
    super.barrierLabel,
    super.routeSettings,
  });

  final String title;
  final String body;
  final AppDialogIconSpec icon;
  final String cancelLabel;
  final String confirmLabel;
}

class AppFormDialogSpec<T> extends AppCenterDialogSpec<T> {
  const AppFormDialogSpec({
    required this.builder,
    super.barrierDismissible = true,
    super.barrierColor,
    super.useRootNavigator,
    super.barrierLabel,
    super.routeSettings,
  });

  final WidgetBuilder builder;
}

class AppRichCenterDialogSpec<T> extends AppCenterDialogSpec<T> {
  const AppRichCenterDialogSpec({
    required this.builder,
    this.transitionDuration = const Duration(milliseconds: 220),
    this.transitionBuilder,
    this.blurBackdrop = false,
    super.barrierDismissible = true,
    super.barrierColor,
    super.useRootNavigator,
    super.barrierLabel,
    super.routeSettings,
  });

  final WidgetBuilder builder;
  final Duration transitionDuration;
  final RouteTransitionsBuilder? transitionBuilder;
  final bool blurBackdrop;
}

class AppRichChoiceDialogAction<T> {
  const AppRichChoiceDialogAction({
    required this.label,
    required this.result,
    this.variant = PrimaryButtonVariant.ghost,
    this.foregroundColor,
    this.backgroundColor,
    this.borderColor,
  });

  final String label;
  final T result;
  final PrimaryButtonVariant variant;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final Color? borderColor;
}

class AppRichChoiceDialogSpec<T> extends AppCenterDialogSpec<T> {
  const AppRichChoiceDialogSpec({
    required this.title,
    required this.body,
    required this.actions,
    this.note,
    this.maxWidth = 440,
    this.stackActionsBelowWidth = 420,
    this.backgroundColor,
    this.borderColor,
    this.titleColor,
    this.bodyColor,
    this.noteColor,
    this.blurBackdrop = true,
    this.transitionDuration = const Duration(milliseconds: 220),
    this.transitionBuilder,
    super.barrierDismissible = true,
    super.barrierColor = const Color(0x46000000),
    super.useRootNavigator = false,
    super.barrierLabel,
    super.routeSettings,
  });

  final String title;
  final String body;
  final String? note;
  final List<AppRichChoiceDialogAction<T>> actions;
  final double maxWidth;
  final double stackActionsBelowWidth;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? titleColor;
  final Color? bodyColor;
  final Color? noteColor;
  final bool blurBackdrop;
  final Duration transitionDuration;
  final RouteTransitionsBuilder? transitionBuilder;
}

class AppSelectionOption<T> {
  const AppSelectionOption({
    required this.value,
    required this.label,
    this.description,
    this.key,
  });

  final T value;
  final String label;
  final String? description;
  final Key? key;
}

class AppSelectionSheetSpec<T> extends AppBottomSheetSpec<T> {
  const AppSelectionSheetSpec({
    required this.title,
    this.description,
    required this.options,
    this.selectedValue,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 24),
    super.useSafeArea = false,
    super.useRootNavigator = false,
    super.isScrollControlled = false,
    super.isDismissible = true,
    super.enableDrag = true,
    super.showDragHandle = false,
    super.backgroundColor,
    super.shape,
    super.constraints,
    super.routeSettings,
  });

  final String title;
  final String? description;
  final List<AppSelectionOption<T>> options;
  final T? selectedValue;
  final EdgeInsetsGeometry padding;
}

class AppEditorSheetSpec<T> extends AppBottomSheetSpec<T> {
  const AppEditorSheetSpec({
    required this.builder,
    super.useSafeArea = false,
    super.useRootNavigator = false,
    super.isScrollControlled = false,
    super.isDismissible = true,
    super.enableDrag = true,
    super.showDragHandle = false,
    super.backgroundColor,
    super.shape,
    super.constraints,
    super.routeSettings,
  });

  final WidgetBuilder builder;
}

class AppDetailSheetSpec<T> extends AppBottomSheetSpec<T> {
  const AppDetailSheetSpec({
    required this.builder,
    super.useSafeArea = false,
    super.useRootNavigator = false,
    super.isScrollControlled = false,
    super.isDismissible = true,
    super.enableDrag = true,
    super.showDragHandle = false,
    super.backgroundColor,
    super.shape,
    super.constraints,
    super.routeSettings,
  });

  final WidgetBuilder builder;
}

class AppRichDetailSheetSpec<T> extends AppBottomSheetSpec<T> {
  const AppRichDetailSheetSpec({
    required this.builder,
    super.useSafeArea = true,
    super.useRootNavigator = true,
    super.isScrollControlled = true,
    super.isDismissible = true,
    super.enableDrag = true,
    super.showDragHandle = false,
    super.backgroundColor = Colors.transparent,
    super.shape,
    super.constraints,
    super.routeSettings,
  });

  final WidgetBuilder builder;
}

class AppActionSheetSpec<T> extends AppBottomSheetSpec<T> {
  const AppActionSheetSpec({
    required this.builder,
    super.useSafeArea = false,
    super.useRootNavigator = false,
    super.isScrollControlled = false,
    super.isDismissible = true,
    super.enableDrag = true,
    super.showDragHandle = false,
    super.backgroundColor,
    super.shape,
    super.constraints,
    super.routeSettings,
  });

  final WidgetBuilder builder;
}

class AppRichActionSheetSpec<T> extends AppBottomSheetSpec<T> {
  const AppRichActionSheetSpec({
    required this.builder,
    super.useSafeArea = true,
    super.useRootNavigator = true,
    super.isScrollControlled = true,
    super.isDismissible = true,
    super.enableDrag = true,
    super.showDragHandle = false,
    super.backgroundColor = Colors.transparent,
    super.shape,
    super.constraints,
    super.routeSettings,
  });

  final WidgetBuilder builder;
}

class AppModalAction extends StatelessWidget {
  const AppModalAction({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = PrimaryButtonVariant.filled,
    this.foregroundColor,
    this.backgroundColor,
    this.borderColor,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final PrimaryButtonVariant variant;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      label: label,
      size: PrimaryButtonSize.compact,
      variant: variant,
      foregroundColor: foregroundColor,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      isLoading: isLoading,
      onPressed: onPressed,
    );
  }
}
