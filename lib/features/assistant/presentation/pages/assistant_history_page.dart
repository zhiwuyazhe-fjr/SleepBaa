import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';

class AssistantHistoryPage extends StatelessWidget {
  const AssistantHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return Scaffold(
      appBar: AppBar(title: const Text('历史会话')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: services.assistantFacade,
          builder: (BuildContext context, Widget? child) {
            final List<AssistantThread> threads =
                services.assistantFacade.threads;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: <Widget>[
                PrimaryButton(
                  label: '新建对话',
                  icon: Icons.add_comment_rounded,
                  onPressed: () async {
                    await services.assistantFacade.createThread(title: '新对话');
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                if (threads.isEmpty)
                  AppCard(
                    child: Text(
                      '还没有历史会话，先开始聊一聊吧。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                else
                  ...threads.map(
                    (AssistantThread thread) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: AppCard(
                        onTap: () async {
                          await services.assistantFacade.setCurrentThread(
                            thread.id,
                          );
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
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
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    '最近更新 ${_formatDate(thread.updatedAt)}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (String value) async {
                                if (value == 'rename') {
                                  await _showRenameDialog(
                                    context: context,
                                    services: services,
                                    thread: thread,
                                  );
                                } else if (value == 'delete') {
                                  await services.assistantFacade.deleteThread(
                                    thread.id,
                                  );
                                }
                              },
                              itemBuilder: (BuildContext context) =>
                                  const <PopupMenuEntry<String>>[
                                    PopupMenuItem<String>(
                                      value: 'rename',
                                      child: Text('重命名'),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Text('删除'),
                                    ),
                                  ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
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
