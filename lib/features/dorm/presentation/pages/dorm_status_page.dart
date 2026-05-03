import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/support/dorm_event_records.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/support/dorm_live_status_scope.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/support/dorm_member_status_presenter.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/widgets/dorm_member_avatar.dart';

enum _DormStatusFilter { all, sleep, noise, reminder }

class DormStatusPage extends StatefulWidget {
  const DormStatusPage({super.key});

  static const ValueKey<String> timelineKey = ValueKey<String>(
    'dorm-status-timeline',
  );

  @override
  State<DormStatusPage> createState() => _DormStatusPageState();
}

class _DormStatusPageState extends State<DormStatusPage> {
  _DormStatusFilter _filter = _DormStatusFilter.all;

  @override
  Widget build(BuildContext context) {
    return DormLiveStatusScope(
      pageId: 'dorm-status-page',
      builder: (BuildContext context) {
        final AppServices services = context.appServices;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: ListenableBuilder(
              listenable: Listenable.merge(<Listenable>[
                services.authRepository,
                services.dormRepository,
                services.notificationRepository,
                services.dormLiveStatusController,
              ]),
              builder: (BuildContext context, Widget? child) {
                final NightMoodPalette palette = context.nightMoodPalette;
                final Dorm dorm = services.dormRepository.currentDorm;
                final UserProfile currentUser =
                    services.authRepository.currentUser;
                final List<DormEventRecord> events = _filterEvents(
                  buildDormEventRecords(
                    dorm: dorm,
                    notifications:
                        services.notificationRepository.notifications,
                    palette: palette,
                    now: services.dormLiveStatusController.currentTime,
                  ),
                );

                return LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double widthFactor = _statusWidthFactor(
                      constraints.maxWidth,
                    );
                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 112),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: FractionallySizedBox(
                          widthFactor: widthFactor,
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
                                  _DormStatusHeader(
                                    onBack: () =>
                                        Navigator.of(context).maybePop(),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  _DormStatusFilters(
                                    palette: palette,
                                    value: _filter,
                                    onChanged: (_DormStatusFilter value) {
                                      setState(() => _filter = value);
                                    },
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    '今天',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Column(
                                    key: DormStatusPage.timelineKey,
                                    children: events
                                        .map(
                                          (DormEventRecord event) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: AppSpacing.xs,
                                            ),
                                            child: _StatusEventCard(
                                              event: event,
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                  ),
                                  const SizedBox(height: AppSpacing.xl),
                                  Text(
                                    '当前室友状态',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  ...dorm.members.map(
                                    (DormMember member) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: AppSpacing.xs,
                                      ),
                                      child: _DormStatusMemberTile(
                                        member: member,
                                        currentUser: currentUser,
                                        showPresence: shouldShowDormPresence(
                                          dorm,
                                          member,
                                        ),
                                      ),
                                    ),
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

  List<DormEventRecord> _filterEvents(List<DormEventRecord> events) {
    return switch (_filter) {
      _DormStatusFilter.all => events,
      _DormStatusFilter.sleep =>
        events
            .where(
              (DormEventRecord event) =>
                  event.title.contains('入睡') ||
                  event.title.contains('起床') ||
                  event.detail.contains('睡眠'),
            )
            .toList(growable: false),
      _DormStatusFilter.noise =>
        events
            .where(
              (DormEventRecord event) =>
                  event.title.contains('噪') || event.detail.contains('声音'),
            )
            .toList(growable: false),
      _DormStatusFilter.reminder =>
        events
            .where(
              (DormEventRecord event) =>
                  event.title.contains('提醒') ||
                  event.detail.contains('提醒') ||
                  event.title.contains('规则'),
            )
            .toList(growable: false),
    };
  }
}

class _DormStatusHeader extends StatelessWidget {
  const _DormStatusHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AppRadius.button,
            onTap: onBack,
            child: const SizedBox.square(
              dimension: 40,
              child: Icon(Icons.chevron_left_rounded),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '寝室状态记录',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _DormStatusFilters extends StatelessWidget {
  const _DormStatusFilters({
    required this.palette,
    required this.value,
    required this.onChanged,
  });

  final NightMoodPalette palette;
  final _DormStatusFilter value;
  final ValueChanged<_DormStatusFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _DormStatusFilter.values
            .map((_DormStatusFilter filter) {
              final bool selected = filter == value;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: ChoiceChip(
                  selected: selected,
                  showCheckmark: false,
                  label: Text(_filterLabel(filter)),
                  selectedColor: palette.welcomeAccentColor,
                  backgroundColor: AppColors.surfaceMuted,
                  side: BorderSide.none,
                  labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected
                        ? palette.primaryDeep
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                  onSelected: (_) => onChanged(filter),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  String _filterLabel(_DormStatusFilter filter) {
    return switch (filter) {
      _DormStatusFilter.all => '全部',
      _DormStatusFilter.sleep => '睡眠',
      _DormStatusFilter.noise => '噪声',
      _DormStatusFilter.reminder => '提醒',
    };
  }
}

class _StatusEventCard extends StatelessWidget {
  const _StatusEventCard({required this.event});

  final DormEventRecord event;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      borderRadius: AppRadius.card,
      boxShadow: const <BoxShadow>[],
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: event.color.withAlpha(20),
              borderRadius: AppRadius.iconContainer,
            ),
            alignment: Alignment.center,
            child: Icon(event.icon, color: event.color, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  event.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            event.timeLabel,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _DormStatusMemberTile extends StatelessWidget {
  const _DormStatusMemberTile({
    required this.member,
    required this.currentUser,
    required this.showPresence,
  });

  final DormMember member;
  final UserProfile currentUser;
  final bool showPresence;

  @override
  Widget build(BuildContext context) {
    final bool isCurrentUser = member.uid == currentUser.uid;
    final Color accentColor = dormPresenceSleepColor(
      member,
      showPresence: showPresence,
    );
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      borderRadius: AppRadius.card,
      boxShadow: const <BoxShadow>[],
      child: Row(
        children: <Widget>[
          DormMemberAvatar(
            key: ValueKey<String>('dorm-status-avatar-${member.uid}'),
            size: 44,
            accentColor: accentColor,
            avatarBytes: isCurrentUser ? currentUser.avatarBytes : null,
            avatarUrl: isCurrentUser
                ? currentUser.avatarUrl ?? member.avatarUrl
                : member.avatarUrl,
            fallbackSeed:
                isCurrentUser &&
                    currentUser.avatarFallbackSeed?.trim().isNotEmpty == true
                ? currentUser.avatarFallbackSeed!
                : member.name,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  member.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  member.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: accentColor.withAlpha(18),
              borderRadius: AppRadius.pill,
            ),
            child: Text(
              dormPresenceSleepLabel(member, showPresence: showPresence),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: accentColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

double _statusWidthFactor(double maxWidth) {
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
