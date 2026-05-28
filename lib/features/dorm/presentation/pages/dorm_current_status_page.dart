import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/app_typography.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/interaction/app_haptics.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_detail_page_header.dart';
import 'package:sleep_dorm_app/core/widgets/app_message_record_card.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/support/dorm_live_status_scope.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/support/dorm_member_status_presenter.dart';

enum _CurrentStatusFilter { all, quiet, pending }

class DormCurrentStatusPage extends StatefulWidget {
  const DormCurrentStatusPage({super.key});

  static const ValueKey<String> listKey = ValueKey<String>(
    'dorm-current-status-list',
  );

  @override
  State<DormCurrentStatusPage> createState() => _DormCurrentStatusPageState();
}

class _DormCurrentStatusPageState extends State<DormCurrentStatusPage> {
  _CurrentStatusFilter _filter = _CurrentStatusFilter.all;

  @override
  Widget build(BuildContext context) {
    return DormLiveStatusScope(
      pageId: 'dorm-current-status-page',
      builder: (BuildContext context) {
        final AppServices services = context.appServices;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: ListenableBuilder(
              listenable: Listenable.merge(<Listenable>[
                services.authRepository,
                services.dormRepository,
                services.dormLiveStatusController,
              ]),
              builder: (BuildContext context, Widget? child) {
                final Dorm dorm = services.dormRepository.currentDorm;
                final DateTime now =
                    services.dormLiveStatusController.currentTime;
                final List<DormMember> members = _filteredMembers(dorm.members);
                return LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: FractionallySizedBox(
                          widthFactor: _currentStatusWidthFactor(
                            constraints.maxWidth,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.xl,
                                AppSpacing.xs,
                                AppSpacing.xl,
                                0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  _CurrentStatusHeader(
                                    onBack: () =>
                                        Navigator.of(context).maybePop(),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  _CurrentStatusOverviewCard(
                                    dorm: dorm,
                                    now: now,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  _CurrentStatusFilters(
                                    value: _filter,
                                    onChanged: (_CurrentStatusFilter value) {
                                      setState(() => _filter = value);
                                    },
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    '按室友查看',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  _CurrentStatusList(
                                    dorm: dorm,
                                    members: members,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  List<DormMember> _filteredMembers(List<DormMember> members) {
    return switch (_filter) {
      _CurrentStatusFilter.all => members,
      _CurrentStatusFilter.quiet =>
        members
            .where(
              (DormMember member) => member.status != DormMemberStatus.active,
            )
            .toList(growable: false),
      _CurrentStatusFilter.pending =>
        members
            .where(
              (DormMember member) => member.status == DormMemberStatus.active,
            )
            .toList(growable: false),
    };
  }
}

class _CurrentStatusHeader extends StatelessWidget {
  const _CurrentStatusHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return AppDetailPageHeader(title: '当前室友状态', onBack: onBack);
  }
}

class _CurrentStatusOverviewCard extends StatelessWidget {
  const _CurrentStatusOverviewCard({required this.dorm, required this.now});

  final Dorm dorm;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final int onlineCount = dormAppOnlineMemberCount(dorm.members, now: now);
    final int quietCount = dorm.members
        .where((DormMember member) => member.status != DormMemberStatus.active)
        .length;
    final int pendingCount = dorm.members.length - quietCount;
    return AppMessageRecordCard(
      icon: Icons.people_alt_rounded,
      title: '今晚 ${dorm.members.length} 位室友有状态',
      detail: '$onlineCount 位在线 · $quietCount 位安静中 · $pendingCount 位待确认',
      highlighted: false,
      iconBackgroundColor: appColors.accentSoft,
      iconColor: appColors.accentDeep,
    );
  }
}

class _CurrentStatusFilters extends StatelessWidget {
  const _CurrentStatusFilters({required this.value, required this.onChanged});

  final _CurrentStatusFilter value;
  final ValueChanged<_CurrentStatusFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _CurrentStatusFilter.values
            .map((_CurrentStatusFilter filter) {
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: _FeedbackFilterPill(
                  key: ValueKey<String>(_filterKey(filter)),
                  label: _filterLabel(filter),
                  selected: value == filter,
                  appColors: appColors,
                  textTheme: textTheme,
                  onTap: () => onChanged(filter),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  String _filterLabel(_CurrentStatusFilter filter) {
    return switch (filter) {
      _CurrentStatusFilter.all => '全部',
      _CurrentStatusFilter.quiet => '安静中',
      _CurrentStatusFilter.pending => '待确认',
    };
  }

  String _filterKey(_CurrentStatusFilter filter) {
    final String suffix = switch (filter) {
      _CurrentStatusFilter.all => 'all',
      _CurrentStatusFilter.quiet => 'quiet',
      _CurrentStatusFilter.pending => 'pending',
    };
    return 'dorm-current-status-filter-$suffix';
  }
}

class _FeedbackFilterPill extends StatefulWidget {
  const _FeedbackFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.appColors,
    required this.textTheme,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final AppSemanticColors appColors;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  State<_FeedbackFilterPill> createState() => _FeedbackFilterPillState();
}

class _FeedbackFilterPillState extends State<_FeedbackFilterPill> {
  bool _pressed = false;
  bool _longPressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() {
      _pressed = value;
    });
  }

  void _setLongPressed(bool value) {
    if (_longPressed == value) {
      return;
    }
    setState(() {
      _longPressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = widget.appColors;
    final double scale = _longPressed
        ? 1.025
        : _pressed
        ? 0.98
        : 1;
    final Color backgroundColor = widget.selected
        ? appColors.accent
        : appColors.surfaceMuted;
    final Color foregroundColor = widget.selected
        ? appColors.textOnAccent
        : appColors.textSecondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: AppHaptics.selectionHandler(widget.onTap),
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onLongPressStart: (_) {
        _setPressed(false);
        _setLongPressed(true);
      },
      onLongPressEnd: (_) => _setLongPressed(false),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: AppRadius.pill,
            boxShadow: _longPressed
                ? <BoxShadow>[
                    BoxShadow(
                      color: appColors.accent.withAlpha(
                        widget.selected ? 52 : 30,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.meta(
              widget.textTheme,
            ).copyWith(color: foregroundColor, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _CurrentStatusList extends StatelessWidget {
  const _CurrentStatusList({required this.dorm, required this.members});

  final Dorm dorm;
  final List<DormMember> members;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const _CurrentStatusEmpty();
    }
    return Column(
      key: DormCurrentStatusPage.listKey,
      children: members
          .map((DormMember member) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _CurrentStatusMemberCard(
                member: member,
                showPresence: shouldShowDormPresence(dorm, member),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _CurrentStatusMemberCard extends StatelessWidget {
  const _CurrentStatusMemberCard({
    required this.member,
    required this.showPresence,
  });

  final DormMember member;
  final bool showPresence;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final String presenceLabel = dormPresenceSleepLabel(
      member,
      showPresence: showPresence,
    );
    final String activityLabel = dormActivityLabel(member);
    final bool needsConfirmation = member.status == DormMemberStatus.active;
    return AppMessageRecordCard(
      icon: needsConfirmation
          ? Icons.notifications_active_rounded
          : Icons.nightlight_round,
      title: member.name,
      detail: '${member.note} · $presenceLabel',
      highlighted: needsConfirmation,
      iconBackgroundColor: needsConfirmation
          ? appColors.accentSoft
          : appColors.surfaceMuted,
      iconColor: appColors.accentDeep,
      trailing: _StatusPill(
        label: needsConfirmation ? '待确认' : activityLabel,
        emphasized: needsConfirmation,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.emphasized});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: emphasized ? appColors.accent : appColors.surfaceMuted,
        borderRadius: AppRadius.pill,
      ),
      child: Text(
        label,
        style: AppTypography.chip(textTheme).copyWith(
          color: emphasized ? appColors.textOnAccent : appColors.textSecondary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CurrentStatusEmpty extends StatelessWidget {
  const _CurrentStatusEmpty();

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return AppMessageRecordCard(
      icon: Icons.people_alt_outlined,
      title: '暂无符合条件的室友状态',
      detail: '切换其他筛选看看室友的当前状态',
      iconBackgroundColor: appColors.surfaceMuted,
      iconColor: appColors.accentDeep,
    );
  }
}

double _currentStatusWidthFactor(double maxWidth) {
  if (maxWidth >= 1200) {
    return 0.38;
  }
  if (maxWidth >= 900) {
    return 0.48;
  }
  if (maxWidth >= 700) {
    return 0.68;
  }
  return 1;
}
