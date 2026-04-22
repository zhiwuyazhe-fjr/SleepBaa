import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/features/assistant/presentation/widgets/assistant_surface.dart';

class AssistantHistoryPage extends StatefulWidget {
  const AssistantHistoryPage({super.key});

  @override
  State<AssistantHistoryPage> createState() => _AssistantHistoryPageState();
}

class _AssistantHistoryPageState extends State<AssistantHistoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      await context.appServices.assistantConversationController.bootstrap();
    });
  }

  Future<void> _selectThread(String threadId) async {
    await context.appServices.assistantConversationController.setCurrentThread(
      threadId,
    );
    if (!mounted) {
      return;
    }
    context.pop();
  }

  Future<void> _createThread() async {
    await context.appServices.assistantFacade.createThread(title: '新对话');
    if (!mounted) {
      return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        services.assistantFacade,
        services.assistantConversationController,
      ]),
      builder: (BuildContext context, Widget? child) {
        final List<AssistantThread> threads = services.assistantFacade.threads;
        final String? currentThreadId =
            services.assistantFacade.currentThread?.id;
        return Scaffold(
          backgroundColor: AppColors.darkBackground,
          body: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final AssistantSurfaceMetrics metrics =
                  AssistantSurfaceMetrics.fromWidth(constraints.maxWidth);
              final AssistantSurfacePalette palette =
                  AssistantSurfacePalette.fromMood(context.nightMoodPalette);
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  const DecoratedBox(
                    decoration: BoxDecoration(color: AppColors.darkBackground),
                  ),
                  IgnorePointer(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: 0.36,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: <Color>[
                                palette.bottomGlowStart,
                                palette.bottomGlowMid,
                                Colors.transparent,
                              ],
                              stops: const <double>[0, 0.42, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        metrics.unit(20),
                        metrics.unit(18),
                        metrics.unit(20),
                        metrics.unit(12),
                      ),
                      child: Column(
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              _AssistantThreadHistoryIconButton(
                                key: const ValueKey<String>(
                                  'assistant-thread-history-close',
                                ),
                                size: metrics.unit(40),
                                onPressed: () => context.pop(),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: metrics.unit(22),
                                  color: palette.headerIcon,
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    '历史对话',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: palette.titleText,
                                          fontSize: metrics.unit(20),
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ),
                              _AssistantThreadHistoryIconButton(
                                key: const ValueKey<String>(
                                  'assistant-thread-history-add',
                                ),
                                size: metrics.unit(40),
                                onPressed: _createThread,
                                child: Icon(
                                  Icons.add_rounded,
                                  size: metrics.unit(22),
                                  color: palette.headerIcon,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: metrics.unit(20)),
                          Expanded(
                            child: threads.isEmpty
                                ? Center(
                                    child: Text(
                                      '还没有保存的对话',
                                      key: const ValueKey<String>(
                                        'assistant-thread-history-empty',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: palette.secondaryText,
                                            fontSize: metrics.unit(14),
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  )
                                : ListView.separated(
                                    key: const ValueKey<String>(
                                      'assistant-thread-history-list',
                                    ),
                                    itemCount: threads.length,
                                    separatorBuilder:
                                        (BuildContext context, int index) =>
                                            SizedBox(height: metrics.unit(12)),
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                          final AssistantThread thread =
                                              threads[index];
                                          final bool isCurrent =
                                              thread.id == currentThreadId;
                                          final List<AssistantMessage> messages =
                                              services.assistantFacade
                                                  .messagesForThread(thread.id);
                                          return _AssistantThreadTile(
                                            key: ValueKey<String>(
                                              'assistant-thread-item-${thread.id}',
                                            ),
                                            metrics: metrics,
                                            palette: palette,
                                            thread: thread,
                                            preview: _threadPreview(messages),
                                            isCurrent: isCurrent,
                                            onTap: () => _selectThread(thread.id),
                                          );
                                        },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _AssistantThreadHistoryIconButton extends StatelessWidget {
  const _AssistantThreadHistoryIconButton({
    super.key,
    required this.size,
    required this.onPressed,
    required this.child,
  });

  final double size;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      onPressed: () {
        HapticFeedback.selectionClick();
        onPressed();
      },
      icon: child,
    );
  }
}

class _AssistantThreadTile extends StatelessWidget {
  const _AssistantThreadTile({
    super.key,
    required this.metrics,
    required this.palette,
    required this.thread,
    required this.preview,
    required this.isCurrent,
    required this.onTap,
  });

  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;
  final AssistantThread thread;
  final String preview;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(metrics.unit(20)),
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.all(metrics.unit(16)),
          decoration: BoxDecoration(
            color: isCurrent ? palette.userCardFill : palette.composerFill,
            borderRadius: BorderRadius.circular(metrics.unit(20)),
            border: Border.all(
              color: isCurrent
                  ? palette.composerBorder
                  : palette.userCardBorder,
              width: metrics.unit(isCurrent ? 1.5 : 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      thread.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: palette.headlineText,
                        fontSize: metrics.unit(15),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: metrics.unit(12)),
                  Text(
                    _threadTimeLabel(thread.updatedAt),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: palette.mutedText,
                      fontSize: metrics.unit(11),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SizedBox(height: metrics.unit(8)),
              Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.secondaryText,
                  fontSize: metrics.unit(13),
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _threadPreview(List<AssistantMessage> messages) {
  for (final AssistantMessage message in messages.reversed) {
    if (message.role == AssistantMessageRole.system) {
      continue;
    }
    final String content = message.content.trim();
    if (content.isNotEmpty) {
      return content;
    }
  }
  return '还没有新的内容';
}

String _threadTimeLabel(DateTime updatedAt) {
  final int hour = updatedAt.hour;
  final int minute = updatedAt.minute;
  final String minuteLabel = minute.toString().padLeft(2, '0');
  return '$hour:$minuteLabel';
}
