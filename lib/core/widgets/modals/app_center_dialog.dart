import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/widgets/modals/app_modal_spec.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';

Future<T?> showAppCenterDialog<T>(
  BuildContext context, {
  required AppCenterDialogSpec<T> spec,
}) {
  if (spec is AppRichChoiceDialogSpec<T>) {
    final AppRichChoiceDialogSpec<T> dialogSpec = spec;
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: dialogSpec.barrierDismissible,
      barrierLabel: dialogSpec.barrierLabel ?? 'app-rich-choice-dialog',
      barrierColor: dialogSpec.barrierColor,
      transitionDuration: dialogSpec.transitionDuration,
      routeSettings: dialogSpec.routeSettings,
      pageBuilder:
          (
            BuildContext dialogContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return Material(
              color: Colors.transparent,
              child: Stack(
                children: <Widget>[
                  if (dialogSpec.blurBackdrop)
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  Center(child: AppRichChoiceDialog<T>(dialogSpec: dialogSpec)),
                ],
              ),
            );
          },
      transitionBuilder:
          dialogSpec.transitionBuilder ??
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
                child: child,
              ),
            );
          },
    );
  }

  if (spec is AppRichCenterDialogSpec<T>) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: spec.barrierDismissible,
      barrierLabel: spec.barrierLabel ?? 'app-rich-center-dialog',
      barrierColor: spec.barrierColor,
      transitionDuration: spec.transitionDuration,
      routeSettings: spec.routeSettings,
      pageBuilder:
          (
            BuildContext dialogContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return Material(
              color: Colors.transparent,
              child: Stack(
                children: <Widget>[
                  if (spec.blurBackdrop)
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  Center(child: spec.builder(dialogContext)),
                ],
              ),
            );
          },
      transitionBuilder:
          spec.transitionBuilder ??
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
                child: child,
              ),
            );
          },
    );
  }

  return showDialog<T>(
    context: context,
    barrierDismissible: spec.barrierDismissible,
    barrierColor: spec.barrierColor,
    useRootNavigator: spec.useRootNavigator,
    routeSettings: spec.routeSettings,
    builder: (BuildContext dialogContext) {
      if (spec is AppConfirmationDialogSpec) {
        final AppConfirmationDialogSpec dialogSpec =
            spec as AppConfirmationDialogSpec;
        return AppCenterDialogScaffold(
          key: const ValueKey<String>('app-center-dialog-standard'),
          icon: dialogSpec.icon,
          title: dialogSpec.title,
          body: dialogSpec.body,
          actions: <Widget>[
            AppModalAction(
              label: dialogSpec.cancelLabel,
              variant: PrimaryButtonVariant.ghost,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            AppModalAction(
              label: dialogSpec.confirmLabel,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      }
      if (spec is AppInfoDialogSpec) {
        final AppInfoDialogSpec dialogSpec = spec as AppInfoDialogSpec;
        return AppCenterDialogScaffold(
          key: const ValueKey<String>('app-center-dialog-info'),
          icon: dialogSpec.icon,
          title: dialogSpec.title,
          body: dialogSpec.body,
          actions: <Widget>[
            AppModalAction(
              label: dialogSpec.confirmLabel,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      }
      if (spec is AppDestructiveDialogSpec) {
        final AppDestructiveDialogSpec dialogSpec =
            spec as AppDestructiveDialogSpec;
        return AppCenterDialogScaffold(
          key: const ValueKey<String>('app-center-dialog-destructive'),
          icon: dialogSpec.icon,
          title: dialogSpec.title,
          body: dialogSpec.body,
          actions: <Widget>[
            AppModalAction(
              label: dialogSpec.cancelLabel,
              variant: PrimaryButtonVariant.ghost,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            AppModalAction(
              label: dialogSpec.confirmLabel,
              variant: PrimaryButtonVariant.ghost,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      }
      if (spec is AppFormDialogSpec<T>) {
        return spec.builder(dialogContext);
      }
      throw StateError('Unsupported center dialog spec: ${spec.runtimeType}');
    },
  );
}

class AppCenterDialogScaffold extends StatelessWidget {
  const AppCenterDialogScaffold({
    super.key,
    required this.title,
    required this.actions,
    this.icon,
    this.body,
    this.content,
    this.backgroundColor,
    this.border,
    this.boxShadow = AppColors.cardShadow,
    this.maxWidth = 320,
    this.padding = const EdgeInsets.fromLTRB(24, 24, 24, 20),
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.titleColor,
    this.bodyColor,
    this.textAlign = TextAlign.center,
    this.showDivider = true,
  });

  final AppDialogIconSpec? icon;
  final String title;
  final String? body;
  final Widget? content;
  final List<Widget> actions;
  final Color? backgroundColor;
  final BoxBorder? border;
  final List<BoxShadow> boxShadow;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final CrossAxisAlignment crossAxisAlignment;
  final Color? titleColor;
  final Color? bodyColor;
  final TextAlign textAlign;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor ?? appColors.surface,
            borderRadius: AppRadius.card,
            border: border,
            boxShadow: boxShadow,
          ),
          child: Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: crossAxisAlignment,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  _DialogIcon(spec: icon!),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Text(
                  title,
                  style: _titleStyle(
                    context,
                    color: titleColor ?? appColors.textPrimary,
                  ),
                  textAlign: textAlign,
                ),
                if (body != null && body!.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    body!,
                    style: _bodyStyle(
                      context,
                      color: bodyColor ?? appColors.textSecondary,
                    ),
                    textAlign: textAlign,
                  ),
                ],
                if (content != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  content!,
                ],
                if (actions.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  if (showDivider)
                    Divider(
                      color: appColors.borderSubtle,
                      height: 1,
                      thickness: 1,
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  _DialogActions(actions: actions),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppFormDialogScaffold extends StatelessWidget {
  const AppFormDialogScaffold({
    super.key,
    required this.title,
    required this.actions,
    this.icon,
    this.body,
    this.content,
    this.maxWidth = 320,
  });

  final String title;
  final String? body;
  final AppDialogIconSpec? icon;
  final Widget? content;
  final List<Widget> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return AppCenterDialogScaffold(
      key: const ValueKey<String>('app-center-dialog-form'),
      icon: icon,
      title: title,
      body: body,
      content: content,
      actions: actions,
      maxWidth: maxWidth,
    );
  }
}

class AppRichCenterDialogFrame extends StatelessWidget {
  const AppRichCenterDialogFrame({
    super.key,
    required this.child,
    this.surfaceKey = const ValueKey<String>('app-center-dialog-rich'),
    this.maxWidth = 440,
    this.margin = const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.backgroundColor,
    this.borderColor = AppColors.darkBorder,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.md)),
    this.boxShadow = AppColors.floatingShadow,
  });

  final Widget child;
  final Key surfaceKey;
  final double maxWidth;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color borderColor;
  final BorderRadiusGeometry borderRadius;
  final List<BoxShadow> boxShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: surfaceKey,
      constraints: BoxConstraints(maxWidth: maxWidth),
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.darkSurface,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor),
        boxShadow: boxShadow,
      ),
      child: child,
    );
  }
}

class AppRichChoiceDialog<T> extends StatelessWidget {
  const AppRichChoiceDialog({super.key, required this.dialogSpec});

  final AppRichChoiceDialogSpec<T> dialogSpec;

  @override
  Widget build(BuildContext context) {
    final double availableWidth =
        MediaQuery.sizeOf(context).width - (AppSpacing.xl * 2);
    final bool useStackedActions =
        availableWidth < dialogSpec.stackActionsBelowWidth;

    return AppRichCenterDialogFrame(
      surfaceKey: const ValueKey<String>('app-center-dialog-rich-choice'),
      maxWidth: dialogSpec.maxWidth,
      backgroundColor: dialogSpec.backgroundColor,
      borderColor: dialogSpec.borderColor ?? AppColors.darkBorder,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            dialogSpec.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: dialogSpec.titleColor ?? AppColors.onDark,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            dialogSpec.body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: dialogSpec.bodyColor ?? AppColors.onDark.withAlpha(180),
              height: 1.55,
            ),
          ),
          if (dialogSpec.note != null &&
              dialogSpec.note!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              dialogSpec.note!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: dialogSpec.noteColor ?? AppColors.onDark.withAlpha(140),
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _RichChoiceActions<T>(
            actions: dialogSpec.actions,
            useStackedActions: useStackedActions,
          ),
        ],
      ),
    );
  }
}

class _RichChoiceActions<T> extends StatelessWidget {
  const _RichChoiceActions({
    required this.actions,
    required this.useStackedActions,
  });

  final List<AppRichChoiceDialogAction<T>> actions;
  final bool useStackedActions;

  @override
  Widget build(BuildContext context) {
    if (actions.length == 1) {
      return _RichChoiceActionButton<T>(action: actions.single);
    }
    if (actions.length == 3 && useStackedActions) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: _RichChoiceActionButton<T>(action: actions[0])),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _RichChoiceActionButton<T>(action: actions[1])),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _RichChoiceActionButton<T>(action: actions[2]),
        ],
      );
    }
    return Row(
      children: <Widget>[
        for (int index = 0; index < actions.length; index += 1) ...<Widget>[
          Expanded(child: _RichChoiceActionButton<T>(action: actions[index])),
          if (index < actions.length - 1) const SizedBox(width: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _RichChoiceActionButton<T> extends StatelessWidget {
  const _RichChoiceActionButton({required this.action});

  final AppRichChoiceDialogAction<T> action;

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      label: action.label,
      size: PrimaryButtonSize.compact,
      variant: action.variant,
      foregroundColor: action.foregroundColor,
      backgroundColor: action.backgroundColor,
      borderColor: action.borderColor,
      onPressed: () => Navigator.of(context).pop(action.result),
    );
  }
}

class _DialogIcon extends StatelessWidget {
  const _DialogIcon({required this.spec});

  final AppDialogIconSpec spec;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return Container(
      width: spec.containerSize,
      height: spec.containerSize,
      decoration: BoxDecoration(
        color: spec.backgroundColor ?? appColors.accentSoft,
        shape: BoxShape.circle,
      ),
      child: Icon(
        spec.icon,
        size: spec.iconSize,
        color: spec.foregroundColor ?? appColors.accentDeep,
      ),
    );
  }
}

class _DialogActions extends StatelessWidget {
  const _DialogActions({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.length == 1) {
      return actions.single;
    }
    return Row(
      children: <Widget>[
        for (int index = 0; index < actions.length; index += 1) ...<Widget>[
          Expanded(child: actions[index]),
          if (index < actions.length - 1) const SizedBox(width: AppSpacing.md),
        ],
      ],
    );
  }
}

TextStyle? _titleStyle(BuildContext context, {required Color color}) {
  return Theme.of(context).textTheme.titleLarge?.copyWith(
    fontFamily: 'Manrope',
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: color,
  );
}

TextStyle? _bodyStyle(BuildContext context, {required Color color}) {
  return Theme.of(context).textTheme.bodyMedium?.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: color,
    height: 1.45,
  );
}
