import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/app_typography.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_message_record_card.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/support/dorm_event_records.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/support/dorm_live_status_scope.dart';

enum _DormStatusReadFilter { unread, today, earlier }

class DormStatusPage extends StatefulWidget {
  const DormStatusPage({super.key});

  static const ValueKey<String> timelineKey = ValueKey<String>(
    'dorm-status-timeline',
  );
  static const ValueKey<String> filterRowKey = ValueKey<String>(
    'dorm-status-filter-row',
  );
  static const ValueKey<String> activeRecordKey = ValueKey<String>(
    'dorm-status-active-record',
  );
  static const ValueKey<String> readRecordKey = ValueKey<String>(
    'dorm-status-read-record',
  );
  static const ValueKey<String> unreadOverviewKey = ValueKey<String>(
    'dorm-status-unread-overview',
  );

  @override
  State<DormStatusPage> createState() => _DormStatusPageState();
}

class _DormStatusPageState extends State<DormStatusPage> {
  _DormStatusReadFilter _filter = _DormStatusReadFilter.unread;

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
                services.dormRepository,
                services.notificationRepository,
                services.dormLiveStatusController,
              ]),
              builder: (BuildContext context, Widget? child) {
                final NightMoodPalette palette = context.nightMoodPalette;
                final Dorm dorm = services.dormRepository.currentDorm;
                final DateTime now =
                    services.dormLiveStatusController.currentTime;
                final List<DormEventRecord> records =
                    buildDormEventRecords(
                          dorm: dorm,
                          notifications:
                              services.notificationRepository.notifications,
                          palette: palette,
                          now: now,
                          fullHistory: true,
                        )
                        .map(
                          (DormEventRecord record) =>
                              _resolveReadState(services, record),
                        )
                        .toList(growable: false);
                final List<DormEventRecord> visibleRecords = _recordsForFilter(
                  records,
                  now,
                );
                final int unreadCount = records
                    .where((DormEventRecord record) => !record.isRead)
                    .length;

                return LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double widthFactor = _statusWidthFactor(
                      constraints.maxWidth,
                    );
                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
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
                                  _DormStatusOverview(unreadCount: unreadCount),
                                  const SizedBox(height: AppSpacing.xs),
                                  _DormStatusReadTabs(
                                    key: DormStatusPage.filterRowKey,
                                    value: _filter,
                                    onChanged: (_DormStatusReadFilter value) {
                                      setState(() => _filter = value);
                                    },
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  _DormStatusGroupedList(
                                    label: _sectionLabel(_filter),
                                    records: visibleRecords,
                                    onTap: (DormEventRecord record) =>
                                        _handleRecordTap(services, record),
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

  DormEventRecord _resolveReadState(
    AppServices services,
    DormEventRecord record,
  ) {
    if (record.isRead ||
        !services.dormRepository.isDormStatusRecordRead(record.id)) {
      return record;
    }
    return DormEventRecord(
      id: record.id,
      title: record.title,
      detail: record.detail,
      color: record.color,
      timeLabel: record.timeLabel,
      icon: record.icon,
      createdAt: record.createdAt,
      isRead: true,
      actionRoute: record.actionRoute,
      notificationId: record.notificationId,
    );
  }

  List<DormEventRecord> _recordsForFilter(
    List<DormEventRecord> records,
    DateTime now,
  ) {
    return switch (_filter) {
      _DormStatusReadFilter.unread =>
        records
            .where((DormEventRecord record) => !record.isRead)
            .toList(growable: false),
      _DormStatusReadFilter.today =>
        records
            .where(
              (DormEventRecord record) =>
                  record.isRead && _isSameDay(record.createdAt, now),
            )
            .toList(growable: false),
      _DormStatusReadFilter.earlier =>
        records
            .where(
              (DormEventRecord record) =>
                  record.isRead && !_isSameDay(record.createdAt, now),
            )
            .toList(growable: false),
    };
  }

  Future<void> _handleRecordTap(
    AppServices services,
    DormEventRecord record,
  ) async {
    if (record.isRead) {
      return;
    }
    await services.dormRepository.markDormStatusRecordRead(record.id);
    final String? notificationId = record.notificationId;
    if (notificationId != null) {
      await services.notificationRepository.markRead(notificationId);
    }
  }

  String _sectionLabel(_DormStatusReadFilter filter) {
    return switch (filter) {
      _DormStatusReadFilter.unread => '待处理',
      _DormStatusReadFilter.today => '今天',
      _DormStatusReadFilter.earlier => '更早',
    };
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DormStatusHeader extends StatelessWidget {
  const _DormStatusHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.chevron_left_rounded),
          color: AppColors.textPrimary,
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '寝室状态记录',
          style: AppTypography.sectionTitle(
            textTheme,
          ).copyWith(color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

class _DormStatusOverview extends StatelessWidget {
  const _DormStatusOverview({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return AppMessageRecordCard(
      key: DormStatusPage.unreadOverviewKey,
      icon: Icons.notifications_active_rounded,
      title: unreadCount > 0 ? '有 $unreadCount 条待处理状态' : '状态都已处理',
      detail: unreadCount > 0 ? '点击状态卡片后会标记为已读' : '今天的寝室状态已经看完',
      highlighted: false,
      iconBackgroundColor: appColors.accentSoft,
      iconColor: appColors.accentDeep,
    );
  }
}

class _DormStatusReadTabs extends StatelessWidget {
  const _DormStatusReadTabs({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final _DormStatusReadFilter value;
  final ValueChanged<_DormStatusReadFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _DormStatusReadFilter.values
            .map((_DormStatusReadFilter filter) {
              final bool selected = filter == value;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: ChoiceChip(
                  selected: selected,
                  showCheckmark: false,
                  label: Text(_tabLabel(filter)),
                  color: _dormStatusChipColor(appColors),
                  selectedColor: appColors.accent,
                  backgroundColor: appColors.surfaceMuted,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.pill),
                  labelStyle: AppTypography.meta(textTheme).copyWith(
                    color: selected
                        ? appColors.textOnAccent
                        : appColors.textSecondary,
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

  String _tabLabel(_DormStatusReadFilter filter) {
    return switch (filter) {
      _DormStatusReadFilter.unread => '待处理',
      _DormStatusReadFilter.today => '今天',
      _DormStatusReadFilter.earlier => '更早',
    };
  }
}

WidgetStateProperty<Color?> _dormStatusChipColor(AppSemanticColors appColors) {
  return WidgetStateProperty.resolveWith((Set<WidgetState> states) {
    if (states.contains(WidgetState.selected)) {
      return appColors.accent;
    }
    return appColors.surfaceMuted;
  });
}

class _DormStatusGroupedList extends StatelessWidget {
  const _DormStatusGroupedList({
    required this.label,
    required this.records,
    required this.onTap,
  });

  final String label;
  final List<DormEventRecord> records;
  final ValueChanged<DormEventRecord> onTap;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    if (records.isEmpty) {
      return Text(
        '这一组暂时没有状态',
        style: AppTypography.body(
          Theme.of(context).textTheme,
        ).copyWith(color: appColors.textSecondary),
      );
    }
    final int firstUnreadIndex = records.indexWhere(
      (DormEventRecord record) => !record.isRead,
    );
    final int firstReadIndex = records.indexWhere(
      (DormEventRecord record) => record.isRead,
    );
    return Column(
      key: DormStatusPage.timelineKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: AppTypography.meta(Theme.of(context).textTheme).copyWith(
            color: appColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ...records.asMap().entries.map((MapEntry<int, DormEventRecord> entry) {
          final DormEventRecord record = entry.value;
          final Key? key = _recordKey(
            record: record,
            index: entry.key,
            firstUnreadIndex: firstUnreadIndex,
            firstReadIndex: firstReadIndex,
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: AppMessageRecordCard(
              key: key,
              icon: record.icon,
              title: record.title,
              detail: record.detail,
              timeLabel: record.timeLabel,
              highlighted: !record.isRead,
              onTap: () => onTap(record),
              iconBackgroundColor: !record.isRead
                  ? appColors.accentSoft
                  : appColors.surfaceMuted,
              iconColor: appColors.accentDeep,
            ),
          );
        }),
      ],
    );
  }

  Key? _recordKey({
    required DormEventRecord record,
    required int index,
    required int firstUnreadIndex,
    required int firstReadIndex,
  }) {
    if (!record.isRead && index == firstUnreadIndex) {
      return DormStatusPage.activeRecordKey;
    }
    if (record.isRead && index == firstReadIndex) {
      return DormStatusPage.readRecordKey;
    }
    return null;
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
