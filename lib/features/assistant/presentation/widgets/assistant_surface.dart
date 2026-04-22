import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class AssistantSurfaceMetrics {
  const AssistantSurfaceMetrics._({required this.scale});

  factory AssistantSurfaceMetrics.fromWidth(double width) {
    final double nextScale = (width / 390).clamp(0.92, 1.08);
    return AssistantSurfaceMetrics._(scale: nextScale);
  }

  final double scale;

  double unit(double designUnit) => designUnit * scale;
}

class AssistantToolStatus {
  const AssistantToolStatus({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class AssistantConversationSlice {
  const AssistantConversationSlice({
    required this.visibleMessages,
    required this.latestUser,
    required this.latestAssistant,
  });

  factory AssistantConversationSlice.fromMessages(
    List<AssistantMessage> messages,
  ) {
    final List<AssistantMessage> filtered = messages
        .where(
          (AssistantMessage message) =>
              message.role != AssistantMessageRole.system,
        )
        .toList(growable: false);
    final int firstUserIndex = filtered.indexWhere(
      (AssistantMessage message) => message.role == AssistantMessageRole.user,
    );
    final List<AssistantMessage> visibleMessages = firstUserIndex == -1
        ? const <AssistantMessage>[]
        : List<AssistantMessage>.unmodifiable(filtered.sublist(firstUserIndex));

    AssistantMessage? latestUser;
    AssistantMessage? latestAssistant;
    for (final AssistantMessage message in visibleMessages.reversed) {
      if (latestUser == null && message.role == AssistantMessageRole.user) {
        latestUser = message;
      }
      if (latestAssistant == null &&
          message.role == AssistantMessageRole.assistant) {
        latestAssistant = message;
      }
      if (latestUser != null && latestAssistant != null) {
        break;
      }
    }

    return AssistantConversationSlice(
      visibleMessages: visibleMessages,
      latestUser: latestUser,
      latestAssistant: latestAssistant,
    );
  }

  final List<AssistantMessage> visibleMessages;
  final AssistantMessage? latestUser;
  final AssistantMessage? latestAssistant;

  bool get hasVisibleConversation => visibleMessages.isNotEmpty;
}

class AssistantSurfacePalette {
  const AssistantSurfacePalette({
    required this.headerIcon,
    required this.titleText,
    required this.headlineText,
    required this.bodyText,
    required this.secondaryText,
    required this.mutedText,
    required this.statusText,
    required this.composerFill,
    required this.composerBorder,
    required this.composerShadow,
    required this.composerText,
    required this.composerHint,
    required this.userCardFill,
    required this.userCardBorder,
    required this.userText,
    required this.bottomGlowStart,
    required this.bottomGlowMid,
  });

  factory AssistantSurfacePalette.fromMood(NightMoodPalette mood) {
    final Color accent = mood.welcomeAccentColor;
    final Color surface = mood.welcomeSurfaceColor;
    final Color midGlow = Color.lerp(
      mood.heroGradientMid,
      AppColors.darkBackground,
      0.18,
    )!;
    final Color textBlend = Color.lerp(AppColors.onDark, surface, 0.42)!;

    return AssistantSurfacePalette(
      headerIcon: _alpha(AppColors.onDark, 0.90),
      titleText: _alpha(AppColors.onDark, 0.95),
      headlineText: _alpha(AppColors.onDark, 0.98),
      bodyText: _alpha(textBlend, 0.92),
      secondaryText: _alpha(textBlend, 0.82),
      mutedText: _alpha(textBlend, 0.66),
      statusText: _alpha(textBlend, 0.74),
      composerFill: _alpha(Colors.white, 0.04),
      composerBorder: _alpha(accent, 0.40),
      composerShadow: _alpha(accent, 0.17),
      composerText: _alpha(AppColors.onDark, 0.92),
      composerHint: _alpha(AppColors.onDark, 0.78),
      userCardFill: _alpha(surface, 0.91),
      userCardBorder: _alpha(accent, 0.22),
      userText: _alpha(Color.lerp(AppColors.onDark, surface, 0.18)!, 0.93),
      bottomGlowStart: _alpha(accent, 0.15),
      bottomGlowMid: _alpha(midGlow, 0.82),
    );
  }

  final Color headerIcon;
  final Color titleText;
  final Color headlineText;
  final Color bodyText;
  final Color secondaryText;
  final Color mutedText;
  final Color statusText;
  final Color composerFill;
  final Color composerBorder;
  final Color composerShadow;
  final Color composerText;
  final Color composerHint;
  final Color userCardFill;
  final Color userCardBorder;
  final Color userText;
  final Color bottomGlowStart;
  final Color bottomGlowMid;
}

class AssistantShellScaffold extends StatelessWidget {
  const AssistantShellScaffold({
    super.key,
    required this.bodyBuilder,
    required this.composerBuilder,
    required this.onTapAdd,
    required this.onTapHistory,
  });

  final Widget Function(
    BuildContext context,
    AssistantSurfaceMetrics metrics,
    AssistantSurfacePalette palette,
  )
  bodyBuilder;
  final Widget Function(
    BuildContext context,
    AssistantSurfaceMetrics metrics,
    AssistantSurfacePalette palette,
  )
  composerBuilder;
  final VoidCallback? onTapAdd;
  final VoidCallback? onTapHistory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.darkBackground,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final AssistantSurfaceMetrics metrics =
              AssistantSurfaceMetrics.fromWidth(constraints.maxWidth);
          final AssistantSurfacePalette palette =
              AssistantSurfacePalette.fromMood(context.nightMoodPalette);
          final double keyboardInset = MediaQuery.of(context).viewInsets.bottom;

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
                    heightFactor: 0.42,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          stops: const <double>[0, 0.36, 1],
                          colors: <Color>[
                            palette.bottomGlowStart,
                            palette.bottomGlowMid,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.fromLTRB(
                    metrics.unit(20),
                    metrics.unit(24),
                    metrics.unit(20),
                    metrics.unit(20) + keyboardInset,
                  ),
                  child: Column(
                    children: <Widget>[
                      AssistantHeader(
                        metrics: metrics,
                        palette: palette,
                        onTapAdd: onTapAdd,
                        onTapHistory: onTapHistory,
                      ),
                      SizedBox(height: metrics.unit(28)),
                      Expanded(child: bodyBuilder(context, metrics, palette)),
                      SizedBox(height: metrics.unit(28)),
                      composerBuilder(context, metrics, palette),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AssistantHeader extends StatelessWidget {
  const AssistantHeader({
    super.key,
    required this.metrics,
    required this.palette,
    required this.onTapAdd,
    required this.onTapHistory,
  });

  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;
  final VoidCallback? onTapAdd;
  final VoidCallback? onTapHistory;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _AssistantHeaderIcon(
          key: const ValueKey<String>('assistant-header-add'),
          icon: Icons.add,
          size: metrics.unit(22),
          color: palette.headerIcon,
          onTap: onTapAdd,
        ),
        Expanded(
          child: Center(
            child: Text(
              '小眠',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: palette.titleText,
                fontSize: metrics.unit(20),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        _AssistantHeaderIcon(
          key: const ValueKey<String>('assistant-header-history'),
          icon: Icons.history,
          size: metrics.unit(22),
          color: palette.headerIcon,
          onTap: onTapHistory,
        ),
      ],
    );
  }
}

class AssistantComposer extends StatelessWidget {
  const AssistantComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.metrics,
    required this.palette,
    required this.hintText,
    required this.isBusy,
    required this.onSubmit,
    this.onTapAdd,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;
  final String hintText;
  final bool isBusy;
  final VoidCallback onSubmit;
  final VoidCallback? onTapAdd;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(metrics.unit(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: metrics.unit(16),
          sigmaY: metrics.unit(16),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.composerFill,
            border: Border.all(
              color: palette.composerBorder,
              width: metrics.unit(1.5),
            ),
            borderRadius: BorderRadius.circular(metrics.unit(20)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: palette.composerShadow,
                blurRadius: metrics.unit(16),
                offset: Offset(0, metrics.unit(6)),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(metrics.unit(24)),
            child: ListenableBuilder(
              listenable: controller,
              builder: (BuildContext context, Widget? child) {
                final bool canSubmit =
                    !isBusy && controller.text.trim().isNotEmpty;
                return Row(
                  children: <Widget>[
                    _AssistantHeaderIcon(
                      icon: Icons.add,
                      size: metrics.unit(22),
                      color: palette.headerIcon,
                      onTap: onTapAdd,
                    ),
                    SizedBox(width: metrics.unit(16)),
                    Expanded(
                      child: TextField(
                        key: const ValueKey<String>('assistant-composer-field'),
                        controller: controller,
                        focusNode: focusNode,
                        textInputAction: TextInputAction.send,
                        minLines: 1,
                        maxLines: 4,
                        cursorColor: palette.composerText,
                        keyboardAppearance: Brightness.dark,
                        onSubmitted: (_) => onSubmit(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: palette.composerText,
                          fontSize: metrics.unit(16),
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                        ),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: hintText,
                          hintStyle: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: palette.composerHint,
                                fontSize: metrics.unit(isBusy ? 15 : 16),
                                fontWeight: FontWeight.w500,
                                height: 1.45,
                              ),
                        ),
                      ),
                    ),
                    SizedBox(width: metrics.unit(16)),
                    _AssistantHeaderIcon(
                      key: const ValueKey<String>('assistant-composer-submit'),
                      icon: isBusy ? Icons.autorenew_rounded : Icons.mic,
                      size: metrics.unit(24),
                      color: palette.headerIcon,
                      onTap: canSubmit ? onSubmit : null,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class AssistantPullHint extends StatelessWidget {
  const AssistantPullHint({
    super.key,
    required this.metrics,
    required this.palette,
    required this.text,
  });

  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      key: const ValueKey<String>('assistant-history-hint'),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: palette.mutedText,
        fontSize: metrics.unit(12),
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class AssistantInlineStatusList extends StatelessWidget {
  const AssistantInlineStatusList({
    super.key,
    required this.statuses,
    required this.metrics,
    required this.palette,
  });

  final List<AssistantToolStatus> statuses;
  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;

  @override
  Widget build(BuildContext context) {
    if (statuses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      key: const ValueKey<String>('assistant-current-status-list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List<Widget>.generate(statuses.length, (int index) {
        final AssistantToolStatus status = statuses[index];
        return Padding(
          padding: EdgeInsets.only(
            bottom: index == statuses.length - 1 ? 0 : metrics.unit(8),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: metrics.unit(2)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  status.icon,
                  size: metrics.unit(14),
                  color: palette.mutedText,
                ),
                SizedBox(width: metrics.unit(10)),
                Flexible(
                  child: Text(
                    status.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: palette.statusText,
                      fontSize: metrics.unit(11),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class AssistantBulletStatusList extends StatelessWidget {
  const AssistantBulletStatusList({
    super.key,
    required this.statuses,
    required this.metrics,
    required this.palette,
  });

  final List<AssistantToolStatus> statuses;
  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;

  @override
  Widget build(BuildContext context) {
    if (statuses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: statuses
          .map((AssistantToolStatus status) {
            return Padding(
              padding: EdgeInsets.only(bottom: metrics.unit(8)),
              child: Text(
                '· ${status.label}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.statusText,
                  fontSize: metrics.unit(11),
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class AssistantUserCard extends StatelessWidget {
  const AssistantUserCard({
    super.key,
    required this.text,
    required this.metrics,
    required this.palette,
  });

  final String text;
  final AssistantSurfaceMetrics metrics;
  final AssistantSurfacePalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(metrics.unit(16)),
      decoration: BoxDecoration(
        color: palette.userCardFill,
        borderRadius: BorderRadius.circular(metrics.unit(20)),
        border: Border.all(
          color: palette.userCardBorder,
          width: metrics.unit(1),
        ),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: palette.userText,
          fontSize: metrics.unit(14),
          fontWeight: FontWeight.w500,
          height: 1.56,
        ),
      ),
    );
  }
}

List<AssistantToolStatus> assistantToolStatusesFromSurfaceIds(
  Iterable<String> surfaceIds,
) {
  final List<AssistantToolStatus> statuses = <AssistantToolStatus>[];
  final Set<String> seenLabels = <String>{};
  for (final String surfaceId in surfaceIds) {
    final AssistantToolStatus? status = _toolStatusForSurfaceId(surfaceId);
    if (status == null || !seenLabels.add(status.label)) {
      continue;
    }
    statuses.add(status);
  }
  return List<AssistantToolStatus>.unmodifiable(statuses);
}

AssistantToolStatus? _toolStatusForSurfaceId(String surfaceId) {
  final String normalized = surfaceId.trim().toLowerCase();
  switch (normalized) {
    case 'alarm':
    case 'sleep_alarm':
    case 'bedtime_alarm':
      return const AssistantToolStatus(icon: Icons.alarm, label: '闹钟已设定 23:00');
    case 'dorm_quiet':
    case 'dorm':
    case 'dorm_status':
    case 'dorm_rules':
      return const AssistantToolStatus(
        icon: Icons.volume_off,
        label: '寝室静音模式已同步',
      );
    case 'bedtime_reminder':
    case 'notification':
    case 'notifications':
      return const AssistantToolStatus(
        icon: Icons.notifications_active,
        label: '晚安提醒已开启',
      );
    case 'sleep_mode':
      return const AssistantToolStatus(icon: Icons.bedtime, label: '睡眠模式已预热');
    case 'assistant_context':
      return const AssistantToolStatus(
        icon: Icons.auto_awesome,
        label: '对话记忆已同步',
      );
    case 'home_pre_sleep':
      return const AssistantToolStatus(icon: Icons.hotel, label: '睡前卡片已刷新');
    case 'profile_report':
      return const AssistantToolStatus(icon: Icons.insights, label: '画像摘要已更新');
    default:
      return null;
  }
}

class _AssistantHeaderIcon extends StatelessWidget {
  const _AssistantHeaderIcon({
    super.key,
    required this.icon,
    required this.size,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tight(Size.square(size)),
      splashRadius: size,
      onPressed: onTap,
      icon: Icon(icon, size: size, color: color),
    );
  }
}

Color _alpha(Color color, double opacity) {
  return color.withAlpha((opacity * 255).round().clamp(0, 255));
}
