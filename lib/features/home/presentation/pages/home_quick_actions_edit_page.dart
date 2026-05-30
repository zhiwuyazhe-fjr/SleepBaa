import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/theme/app_page_insets.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/app_typography.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/interaction/app_haptics.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_detail_page_header.dart';
import 'package:sleep_dorm_app/core/widgets/app_settings_group.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';
import 'package:sleep_dorm_app/features/home/presentation/widgets/home_quick_actions.dart';

class HomeQuickActionsEditPage extends StatefulWidget {
  const HomeQuickActionsEditPage({super.key});

  @override
  State<HomeQuickActionsEditPage> createState() =>
      _HomeQuickActionsEditPageState();
}

class _HomeQuickActionsEditPageState extends State<HomeQuickActionsEditPage> {
  bool _didInit = false;
  bool _isSaving = false;
  List<String> _selectedIds = <String>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) {
      return;
    }
    _selectedIds = normalizeHomeQuickActionIds(
      context.appServices.settingsRepository.currentSettings.homeQuickActionIds,
    );
    _didInit = true;
  }

  bool get _hasExactSelection =>
      _selectedIds.length == kHomeQuickActionSelectionCount;

  List<HomeQuickActionDefinition> get _selectedActions =>
      _selectedIds.map(homeQuickActionDefinitionFor).toList(growable: false);

  List<HomeQuickActionDefinition> get _availableActions =>
      kHomeQuickActionCatalog
          .where((HomeQuickActionDefinition action) {
            return !_selectedIds.contains(action.id);
          })
          .toList(growable: false);

  void _addAction(HomeQuickActionDefinition action) {
    if (_selectedIds.length >= kHomeQuickActionSelectionCount) {
      return;
    }
    setState(() => _selectedIds = <String>[..._selectedIds, action.id]);
  }

  void _removeAction(HomeQuickActionDefinition action) {
    setState(() {
      _selectedIds = _selectedIds
          .where((String id) => id != action.id)
          .toList(growable: false);
    });
  }

  void _reorderSelectedActions(int oldIndex, int newIndex) {
    setState(() {
      final List<String> next = List<String>.from(_selectedIds);
      final String moved = next.removeAt(oldIndex);
      final int targetIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
      next.insert(targetIndex, moved);
      _selectedIds = next;
    });
  }

  Future<void> _save() async {
    if (!_hasExactSelection || _isSaving) {
      return;
    }
    setState(() => _isSaving = true);
    final services = context.appServices;
    await services.settingsRepository.saveSettings(
      services.settingsRepository.currentSettings.copyWith(
        homeQuickActionIds: _selectedIds,
      ),
    );
    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppDetailPageAppBar(title: '编辑快捷功能', onBack: () => context.pop()),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              key: const ValueKey<String>('home-quick-actions-editor-scroll'),
              padding: AppPageInsets.page(bottom: AppSpacing.xl),
              children: <Widget>[
                _EditorSectionHeader(
                  title: '已选择',
                  detail:
                      '${_selectedIds.length}/$kHomeQuickActionSelectionCount',
                ),
                const SizedBox(height: AppSpacing.md),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: _selectedActions.length,
                  onReorder: _reorderSelectedActions,
                  itemBuilder: (BuildContext context, int index) {
                    final HomeQuickActionDefinition action =
                        _selectedActions[index];
                    return Padding(
                      key: ValueKey<String>(
                        'home-quick-action-selected-${action.id}',
                      ),
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _SelectedQuickActionTile(
                        action: action,
                        index: index,
                        onRemove: () => _removeAction(action),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                _EditorSectionHeader(
                  title: '可添加',
                  detail: _hasExactSelection ? '已满' : '继续选择',
                ),
                const SizedBox(height: AppSpacing.md),
                Column(
                  children: _availableActions
                      .map((HomeQuickActionDefinition action) {
                        final bool canAdd =
                            _selectedIds.length <
                            kHomeQuickActionSelectionCount;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _AvailableQuickActionTile(
                            action: action,
                            enabled: canAdd,
                            onTap: () => _addAction(action),
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppPageInsets.horizontal,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: appColors.pageBackground,
              border: Border(top: BorderSide(color: appColors.borderSubtle)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (!_hasExactSelection) ...<Widget>[
                  Text(
                    '请选择 4 个快捷功能',
                    textAlign: TextAlign.center,
                    style: AppTypography.meta(
                      textTheme,
                    ).copyWith(color: appColors.accentDeep),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                PrimaryButton(
                  label: _isSaving ? '保存中...' : '保存快捷功能',
                  onPressed: _hasExactSelection && !_isSaving ? _save : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorSectionHeader extends StatelessWidget {
  const _EditorSectionHeader({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        Text(title, style: AppTypography.sectionTitle(textTheme)),
        const Spacer(),
        Text(
          detail,
          style: AppTypography.meta(
            textTheme,
            ).copyWith(color: context.appColors.textSecondary),
        ),
      ],
    );
  }
}

class _SelectedQuickActionTile extends StatelessWidget {
  const _SelectedQuickActionTile({
    required this.action,
    required this.index,
    required this.onRemove,
  });

  final HomeQuickActionDefinition action;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final Color iconColor = appColors.accentDeep;
    return _QuickActionStripTile(
      action: action,
      enabled: true,
      iconColor: iconColor,
      titleColor: appColors.textPrimary,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ReorderableDragStartListener(
            key: ValueKey<String>('home-quick-action-drag-${action.id}'),
            index: index,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Icon(
                Icons.drag_handle_rounded,
                color: appColors.textSecondary,
                size: AppSpacing.lg,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          _StripActionButton(
            key: ValueKey<String>('home-quick-action-remove-${action.id}'),
            tooltip: '移除${action.label}',
            icon: Icons.close_rounded,
            onTap: onRemove,
          ),
        ],
      ),
    );
  }
}

class _AvailableQuickActionTile extends StatelessWidget {
  const _AvailableQuickActionTile({
    required this.action,
    required this.enabled,
    required this.onTap,
  });

  final HomeQuickActionDefinition action;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final Color disabledColor = appColors.textSecondary.withAlpha(120);
    final Color iconColor = enabled ? appColors.accentDeep : disabledColor;
    return _QuickActionStripTile(
      key: ValueKey<String>('home-quick-action-add-${action.id}'),
      action: action,
      enabled: enabled,
      iconColor: iconColor,
      titleColor: enabled ? appColors.textPrimary : disabledColor,
      onTap: enabled ? onTap : null,
      trailing: Icon(
        Icons.add_rounded,
        size: AppSpacing.lg,
        color: enabled ? appColors.textSecondary : disabledColor,
      ),
    );
  }
}

class _QuickActionStripTile extends StatelessWidget {
  const _QuickActionStripTile({
    super.key,
    required this.action,
    required this.enabled,
    required this.iconColor,
    required this.titleColor,
    required this.trailing,
    this.onTap,
  });

  final HomeQuickActionDefinition action;
  final bool enabled;
  final Color iconColor;
  final Color titleColor;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: EdgeInsets.zero,
      borderRadius: AppRadius.compactCard,
      boxShadow: const <BoxShadow>[],
      border: Border.all(color: appColors.borderSubtle),
      color: enabled ? appColors.surface : appColors.surfaceMuted,
      onTap: onTap,
      child: AppSettingsItem(
        title: action.label,
        icon: action.icon,
        iconColor: iconColor,
        leadingWidth: AppSpacing.xxl,
        titleStyle: AppTypography.cardTitle(
          textTheme,
        ).copyWith(color: titleColor, fontWeight: FontWeight.w600),
        trailing: trailing,
      ),
    );
  }
}

class _StripActionButton extends StatelessWidget {
  const _StripActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.control,
          onTap: AppHaptics.tapHandler(onTap),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Icon(
              icon,
              color: context.appColors.textPrimary,
              size: AppSpacing.lg,
            ),
          ),
        ),
      ),
    );
  }
}
