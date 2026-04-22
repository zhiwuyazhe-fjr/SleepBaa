import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
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
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('编辑快捷功能')),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                key: const ValueKey<String>('home-quick-actions-editor-scroll'),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
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
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _availableActions
                        .map((HomeQuickActionDefinition action) {
                          final bool canAdd =
                              _selectedIds.length <
                              kHomeQuickActionSelectionCount;
                          return _AvailableQuickActionTile(
                            action: action,
                            enabled: canAdd,
                            onTap: () => _addAction(action),
                          );
                        })
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              decoration: const BoxDecoration(
                color: AppColors.background,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (!_hasExactSelection) ...<Widget>[
                    Text(
                      '请选择 4 个快捷功能',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.warning,
                      ),
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
    return Row(
      children: <Widget>[
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        Text(
          detail,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
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
    final Color iconColor = context.nightMoodPalette.primaryDeep;
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      borderRadius: AppRadius.surfacePrimary,
      boxShadow: const <BoxShadow>[],
      border: Border.all(color: AppColors.divider),
      child: Row(
        children: <Widget>[
          ReorderableDragStartListener(
            key: ValueKey<String>('home-quick-action-drag-${action.id}'),
            index: index,
            child: const Icon(
              Icons.drag_handle_rounded,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _QuickActionIcon(icon: action.icon, color: iconColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            key: ValueKey<String>('home-quick-action-remove-${action.id}'),
            tooltip: '移除${action.label}',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
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
    final Color iconColor = enabled
        ? context.nightMoodPalette.primaryDeep
        : AppColors.textHint;
    return SizedBox(
      width: 156,
      child: AppCard(
        key: ValueKey<String>('home-quick-action-add-${action.id}'),
        padding: const EdgeInsets.all(AppSpacing.md),
        borderRadius: AppRadius.surfacePrimary,
        boxShadow: const <BoxShadow>[],
        border: Border.all(color: AppColors.divider),
        color: enabled ? AppColors.surface : AppColors.surfaceMuted,
        onTap: enabled ? onTap : null,
        child: Row(
          children: <Widget>[
            _QuickActionIcon(icon: action.icon, color: iconColor),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: enabled ? AppColors.textPrimary : AppColors.textHint,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.add_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionIcon extends StatelessWidget {
  const _QuickActionIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.iconContainer,
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 20),
    );
  }
}
