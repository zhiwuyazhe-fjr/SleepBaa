import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/interaction/app_haptics.dart';
import 'package:sleep_dorm_app/core/widgets/modals/app_modal_spec.dart';

Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required AppBottomSheetSpec<T> spec,
}) {
  final bool usesSharedSheetSurface = spec is AppSelectionSheetSpec<T>;
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: spec.useSafeArea,
    useRootNavigator: spec.useRootNavigator,
    isScrollControlled: spec.isScrollControlled,
    isDismissible: spec.isDismissible,
    enableDrag: spec.enableDrag,
    showDragHandle: usesSharedSheetSurface ? false : spec.showDragHandle,
    backgroundColor: usesSharedSheetSurface
        ? Colors.transparent
        : spec.backgroundColor,
    shape: spec.shape,
    constraints: spec.constraints,
    routeSettings: spec.routeSettings,
    builder: (BuildContext sheetContext) {
      if (spec is AppRichDetailSheetSpec<T>) {
        return spec.builder(sheetContext);
      }
      if (spec is AppRichActionSheetSpec<T>) {
        return spec.builder(sheetContext);
      }
      if (spec is AppSelectionSheetSpec<T>) {
        return AppBottomSheetScaffold(
          key: const ValueKey<String>('app-bottom-sheet-selection'),
          padding: spec.padding,
          title: spec.title,
          description: spec.description,
          showHandle: spec.showDragHandle,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final AppSelectionOption<T> option in spec.options)
                ListTile(
                  key: option.key,
                  contentPadding: EdgeInsets.zero,
                  title: Text(option.label),
                  subtitle: option.description == null
                      ? null
                      : Text(option.description!),
                  trailing: option.value == spec.selectedValue
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: AppHaptics.selectionHandler(
                    () => Navigator.of(sheetContext).pop(option.value),
                  ),
                ),
            ],
          ),
        );
      }
      if (spec is AppEditorSheetSpec<T>) {
        return spec.builder(sheetContext);
      }
      if (spec is AppDetailSheetSpec<T>) {
        return spec.builder(sheetContext);
      }
      if (spec is AppActionSheetSpec<T>) {
        return spec.builder(sheetContext);
      }
      throw StateError('Unsupported bottom sheet spec: ${spec.runtimeType}');
    },
  );
}

class AppBottomSheetScaffold extends StatelessWidget {
  const AppBottomSheetScaffold({
    super.key,
    required this.child,
    this.title,
    this.description,
    this.header,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 24),
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.includeBottomViewInsets = false,
    this.showHandle = false,
  });

  final String? title;
  final String? description;
  final Widget? header;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final CrossAxisAlignment crossAxisAlignment;
  final bool includeBottomViewInsets;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors appColors = context.appColors;
    final EdgeInsets resolvedPadding = padding.resolve(
      Directionality.of(context),
    );
    final double bottomInset = includeBottomViewInsets
        ? MediaQuery.viewInsetsOf(context).bottom
        : 0;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: appColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: appColors.borderSubtle),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: resolvedPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: crossAxisAlignment,
                children: <Widget>[
                  if (showHandle) ...<Widget>[
                    _AppSheetHandle(color: appColors.borderSubtle),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (header != null) ...<Widget>[
                    header!,
                    const SizedBox(height: AppSpacing.md),
                  ] else if (title != null) ...<Widget>[
                    Text(title!, style: theme.textTheme.titleLarge),
                    if (description != null &&
                        description!.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: appColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                  ],
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppBottomSheetCard extends StatelessWidget {
  const AppBottomSheetCard({
    super.key,
    required this.child,
    this.backgroundColor,
  });

  final Widget child;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor ?? appColors.surfaceRaised,
        borderRadius: AppRadius.card,
        border: Border.all(color: appColors.borderSubtle),
      ),
      child: child,
    );
  }
}

class AppRichDetailSheetScaffold extends StatelessWidget {
  const AppRichDetailSheetScaffold({
    super.key,
    required this.child,
    this.surfaceKey = const ValueKey<String>('app-bottom-sheet-rich-detail'),
    this.backgroundColor,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(28)),
    this.showHandle = true,
    this.includeBottomSafeInset = true,
  });

  final Widget child;
  final Key surfaceKey;
  final Color? backgroundColor;
  final BorderRadiusGeometry borderRadius;
  final bool showHandle;
  final bool includeBottomSafeInset;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final double viewInsetBottom = MediaQuery.viewInsetsOf(context).bottom;
    final double bottomSafeInset = MediaQuery.viewPaddingOf(context).bottom;
    final double bottomGestureInset = MediaQuery.systemGestureInsetsOf(
      context,
    ).bottom;
    final double resolvedBottomInset = includeBottomSafeInset
        ? (bottomSafeInset > bottomGestureInset
              ? bottomSafeInset
              : bottomGestureInset)
        : 0;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsetBottom),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double handleWidth = constraints.maxWidth * 0.12;
          final double handleHeight = handleWidth * 0.1;

          return Container(
            key: surfaceKey,
            width: double.infinity,
            decoration: BoxDecoration(
              color: backgroundColor ?? appColors.surface,
              borderRadius: borderRadius,
              border: Border.all(color: appColors.borderSubtle),
            ),
            child: SafeArea(
              top: false,
              minimum: EdgeInsets.only(bottom: resolvedBottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (showHandle)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Center(
                        child: _AppSheetHandle(
                          color: appColors.borderSubtle,
                          width: handleWidth,
                          height: handleHeight,
                        ),
                      ),
                    ),
                  child,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AppSheetHandle extends StatelessWidget {
  const _AppSheetHandle({
    required this.color,
    this.width = 44,
    this.height = 4,
  });

  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(height),
        ),
      ),
    );
  }
}

class AppRichActionSheetScaffold extends StatelessWidget {
  const AppRichActionSheetScaffold({
    super.key,
    required this.title,
    required this.child,
    required this.footer,
    this.description,
    this.surfaceKey = const ValueKey<String>('app-bottom-sheet-rich-action'),
    this.maxHeight,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.lg,
      AppSpacing.xl,
      AppSpacing.lg,
    ),
    this.header,
  });

  final String title;
  final String? description;
  final Widget? header;
  final Widget child;
  final Widget footer;
  final Key surfaceKey;
  final double? maxHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return AppRichDetailSheetScaffold(
      surfaceKey: surfaceKey,
      child: Padding(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight ?? double.infinity),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (description != null &&
                    description!.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    description!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: appColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
                if (header != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  header!,
                ],
                const SizedBox(height: AppSpacing.md),
                child,
                const SizedBox(height: AppSpacing.md),
                footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
