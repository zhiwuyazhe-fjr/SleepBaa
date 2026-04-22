import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class AssistantHistoryPage extends StatelessWidget {
  const AssistantHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    final NightMoodPalette palette = context.nightMoodPalette;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: const Text('对话记录'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.onDark,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color.lerp(
                AppColors.darkBackground,
                palette.heroGradientStart,
                0.48,
              )!,
              Color.lerp(
                AppColors.darkBackground,
                palette.heroGradientMid,
                0.32,
              )!,
              AppColors.darkBackground,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: ListenableBuilder(
            listenable: services.assistantFacade,
            builder: (BuildContext context, Widget? child) {
              final List<AssistantThread> threads =
                  services.assistantFacade.threads;
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: () async {
                      await services.assistantFacade.createThread(title: '新对话');
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.welcomeAccentColor,
                      foregroundColor: palette.welcomeTextOnAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.surfacePrimary,
                      ),
                    ),
                    icon: const Icon(Icons.add_comment_rounded),
                    label: const Text('新建对话'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (threads.isEmpty)
                    _HistoryEmptyState(palette: palette)
                  else
                    ...threads.map(
                      (AssistantThread thread) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _ThreadCard(
                          thread: thread,
                          palette: palette,
                          onTap: () async {
                            await services.assistantFacade.setCurrentThread(
                              thread.id,
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          onRename: () => _showRenameDialog(
                            context: context,
                            services: services,
                            thread: thread,
                          ),
                          onDelete: () =>
                              services.assistantFacade.deleteThread(thread.id),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({required this.palette});

  final NightMoodPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Color.lerp(
          AppColors.darkSurface,
          palette.welcomeSurfaceColor,
          0.56,
        ),
        borderRadius: AppRadius.cardLarge,
        border: Border.all(color: palette.primarySoft.withAlpha(42)),
      ),
      child: Text(
        '还没有历史会话，先开始聊一聊吧。',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.onDark.withAlpha(196),
          height: 1.6,
        ),
      ),
    );
  }
}

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({
    required this.thread,
    required this.palette,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final AssistantThread thread;
  final NightMoodPalette palette;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.card,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Color.lerp(
              AppColors.darkSurface,
              palette.welcomeSurfaceColor,
              0.5,
            ),
            borderRadius: AppRadius.card,
            border: Border.all(color: palette.primarySoft.withAlpha(38)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      thread.title,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: AppColors.onDark),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '最近更新 ${_formatDate(thread.updatedAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onDark.withAlpha(144),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: Color.lerp(
                  AppColors.darkSurface,
                  palette.welcomeSurfaceColor,
                  0.5,
                ),
                iconColor: AppColors.onDark,
                onSelected: (String value) {
                  if (value == 'rename') {
                    onRename();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (BuildContext context) =>
                    const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'rename',
                        child: Text('重命名'),
                      ),
                      PopupMenuItem<String>(value: 'delete', child: Text('删除')),
                    ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showRenameDialog({
  required BuildContext context,
  required AppServices services,
  required AssistantThread thread,
}) async {
  final TextEditingController controller = TextEditingController(
    text: thread.title,
  );
  final String? value = await showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('重命名会话'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入新的会话标题'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      );
    },
  );
  if (value == null || value.isEmpty) {
    return;
  }
  await services.assistantFacade.renameThread(
    threadId: thread.id,
    title: value,
  );
}

String _formatDate(DateTime value) {
  return '${value.month}月${value.day}日 ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
