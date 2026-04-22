import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/features/assistant/presentation/controllers/assistant_conversation_controller.dart';
import 'package:sleep_dorm_app/features/assistant/presentation/widgets/assistant_surface.dart';

class AssistantHistoryPage extends StatefulWidget {
  const AssistantHistoryPage({super.key});

  @override
  State<AssistantHistoryPage> createState() => _AssistantHistoryPageState();
}

class _AssistantHistoryPageState extends State<AssistantHistoryPage> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

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

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit(AppServices services) async {
    final String prompt = _inputController.text.trim();
    if (prompt.isEmpty) {
      _focusNode.requestFocus();
      return;
    }

    final AssistantConversationSubmitResult result = await services
        .assistantConversationController
        .submitPrompt(prompt);

    switch (result) {
      case AssistantConversationSubmitResult.sent:
        if (mounted) {
          setState(_inputController.clear);
        }
        _focusNode.unfocus();
        break;
      case AssistantConversationSubmitResult.busy:
        if (!mounted) {
          return;
        }
        await notifyPassiveToast(context, message: '上一条还在处理中，请稍后再发');
        break;
      case AssistantConversationSubmitResult.missingActiveSession:
      case AssistantConversationSubmitResult.empty:
        break;
    }
  }

  Future<void> _startNewConversation(AppServices services) async {
    await services.assistantFacade.createThread(title: '新对话');
    if (!mounted) {
      return;
    }
    setState(_inputController.clear);
    context.go(AppRoutes.assistant);
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
        final AssistantConversationController controller =
            services.assistantConversationController;
        final AssistantConversationSlice slice =
            AssistantConversationSlice.fromMessages(controller.currentMessages);
        final List<AssistantMessage> historyMessages = controller
            .currentMessages
            .where(
              (AssistantMessage message) =>
                  message.role != AssistantMessageRole.system,
            )
            .toList(growable: false);
        final bool isBusy = controller.isBusy;

        return AssistantShellScaffold(
          onTapAdd: () => _startNewConversation(services),
          onTapHistory: () => context.go(AppRoutes.assistant),
          bodyBuilder:
              (
                BuildContext context,
                AssistantSurfaceMetrics metrics,
                AssistantSurfacePalette palette,
              ) {
                return _AssistantHistoryStage(
                  metrics: metrics,
                  palette: palette,
                  messages: historyMessages,
                  hasVisibleConversation: slice.hasVisibleConversation,
                  controller: controller,
                );
              },
          composerBuilder:
              (
                BuildContext context,
                AssistantSurfaceMetrics metrics,
                AssistantSurfacePalette palette,
              ) {
                return AssistantComposer(
                  controller: _inputController,
                  focusNode: _focusNode,
                  metrics: metrics,
                  palette: palette,
                  hintText: isBusy ? '小眠正在整理你的心绪...' : '和小眠说说现在的心情...',
                  isBusy: isBusy,
                  onSubmit: () => _handleSubmit(services),
                );
              },
        );
      },
    );
  }
}

class _AssistantHistoryStage extends StatelessWidget {
  const _AssistantHistoryStage({
    required this.metrics,
    required this.palette,
    required this.messages,
    required this.hasVisibleConversation,
    required this.controller,
  });

  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;
  final List<AssistantMessage> messages;
  final bool hasVisibleConversation;
  final AssistantConversationController controller;

  @override
  Widget build(BuildContext context) {
    if (!hasVisibleConversation) {
      return const SizedBox.expand();
    }

    AssistantMessage? latestAssistant;
    for (final AssistantMessage message in messages.reversed) {
      if (message.role == AssistantMessageRole.assistant) {
        latestAssistant = message;
        break;
      }
    }
    final int latestAssistantIndex = latestAssistant == null
        ? -1
        : messages.lastIndexOf(latestAssistant);
    final List<AssistantMessage> earlierMessages = latestAssistantIndex <= 0
        ? messages
              .take(latestAssistantIndex == -1 ? messages.length : 0)
              .toList(growable: false)
        : messages.sublist(0, latestAssistantIndex);
    final bool showEarlierLabel = earlierMessages.any(
      (AssistantMessage message) =>
          message.role == AssistantMessageRole.assistant,
    );
    final bool showCurrentLabel =
        latestAssistant != null && earlierMessages.isNotEmpty;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                key: const ValueKey<String>('assistant-history-flow'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (showEarlierLabel) ...<Widget>[
                    Text(
                      '更早的对话',
                      key: const ValueKey<String>('assistant-history-earlier'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: palette.mutedText,
                        fontSize: metrics.unit(11),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: metrics.unit(12)),
                  ],
                  ...earlierMessages.asMap().entries.expand<Widget>((
                    MapEntry<int, AssistantMessage> entry,
                  ) {
                    final AssistantMessage message = entry.value;
                    if (message.role == AssistantMessageRole.user) {
                      return <Widget>[
                        AssistantUserCard(
                          text: message.content.trim(),
                          metrics: metrics,
                          palette: palette,
                        ),
                        SizedBox(height: metrics.unit(16)),
                      ];
                    }

                    final List<AssistantToolStatus> statuses =
                        assistantToolStatusesFromSurfaceIds(
                          controller.updatedSurfacesForMessage(message.id),
                        );
                    return <Widget>[
                      Text(
                        message.content.trim(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: palette.bodyText,
                          fontSize: metrics.unit(13),
                          fontWeight: FontWeight.w500,
                          height: 1.58,
                        ),
                      ),
                      if (statuses.isNotEmpty) ...<Widget>[
                        SizedBox(height: metrics.unit(8)),
                        AssistantBulletStatusList(
                          statuses: statuses,
                          metrics: metrics,
                          palette: palette,
                        ),
                      ],
                      SizedBox(height: metrics.unit(16)),
                    ];
                  }),
                  if (showCurrentLabel) ...<Widget>[
                    Text(
                      '刚刚',
                      key: const ValueKey<String>('assistant-history-current'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: palette.mutedText,
                        fontSize: metrics.unit(11),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: metrics.unit(12)),
                  ],
                  if (latestAssistant != null) ...<Widget>[
                    Text(
                      latestAssistant.content.trim(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: palette.headlineText,
                        fontSize: metrics.unit(20),
                        fontWeight: FontWeight.w500,
                        height: 1.62,
                      ),
                    ),
                    SizedBox(height: metrics.unit(12)),
                    AssistantBulletStatusList(
                      statuses: assistantToolStatusesFromSurfaceIds(
                        controller.updatedSurfacesForMessage(
                          latestAssistant.id,
                        ),
                      ),
                      metrics: metrics,
                      palette: palette,
                    ),
                  ] else
                    ...messages
                        .where(
                          (AssistantMessage message) =>
                              message.role == AssistantMessageRole.user,
                        )
                        .map(
                          (AssistantMessage message) => Padding(
                            padding: EdgeInsets.only(bottom: metrics.unit(16)),
                            child: AssistantUserCard(
                              text: message.content.trim(),
                              metrics: metrics,
                              palette: palette,
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
