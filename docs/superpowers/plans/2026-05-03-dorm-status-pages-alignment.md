# Dorm Status Pages Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the Flutter dorm surfaces with `glacier/pen_file/pencil-dorm_page.pen`: home "查看全部" opens a new current-roommate-status page, the dorm status record page matches the grouped message design, record taps change read state, and "寝室设置" routes to the existing dorm management page.

**Architecture:** Keep the dorm feature in its existing AppScope/GoRouter structure. Add one focused page for "当前室友状态", refine the existing dorm status record page around read/unread groups, and reuse `AppMessageRecordCard` instead of introducing another card language. All new layout must be responsive: widths come from `LayoutBuilder`, `FractionallySizedBox`, `ConstrainedBox`, `Expanded`, and design tokens, not arbitrary absolute page widths.

**Tech Stack:** Flutter, GoRouter, AppScope services, `ListenableBuilder`, existing theme tokens in `AppColors`, `AppSpacing`, and `AppRadius`.

---

## Design References

- Pencil file: `glacier/pen_file/pencil-dorm_page.pen`
- Home frame: `WOvJt` / `Dorm Page - Final`
- Status record frame: `nPfYe` / `Dorm Status Page`
- Current roommate status frame: `Bhx0r` / `Current Roommate Status Page`
- Member detail frame: `kzwPH` / `Dorm Member Detail`

## File Structure

- Modify `lib/app/routes.dart`
  - Add `AppRoutes.dormCurrentStatus = '/dorm/current_status'`
  - Register route for `DormCurrentStatusPage`
  - Keep `AppRoutes.profileAccountDorm` as the target for dorm settings

- Create `lib/features/dorm/presentation/pages/dorm_current_status_page.dart`
  - New standalone page shown after tapping home "当前室友状态 / 查看全部"
  - Reads `DormRepository`, `AuthRepository`, and `DormLiveStatusController`
  - Renders the `Bhx0r` layout: header, overview, filter pills, roommate status list

- Modify `lib/features/dorm/presentation/pages/dorm_page.dart`
  - Change "舍友动态" to "当前室友状态"
  - Add route action for "查看全部" -> `AppRoutes.dormCurrentStatus`
  - Add hero "寝室设置" pill -> `AppRoutes.profileAccountDorm`
  - Keep "寝室状态记录 / 查看更多" -> `AppRoutes.dormStatus`

- Modify `lib/features/dorm/presentation/pages/dorm_status_page.dart`
  - Replace current all/sleep/noise/reminder filters with read-state tabs: `待处理`, `今天`, `更早`
  - Add unread overview card
  - Remove the embedded "当前室友状态" member section from the bottom
  - Make record cards tappable; tapping unread records marks them read and moves them into the read group

- Modify `lib/features/dorm/presentation/support/dorm_event_records.dart`
  - Give `DormEventRecord` stable IDs, timestamps, read state, and optional `notificationId`
  - Preserve existing title/detail/icon/action route behavior

- Modify `lib/core/widgets/app_message_record_card.dart`
  - Keep as the shared message/status card
  - Add small affordances needed by status rows only if necessary, without changing existing visual defaults

- Modify `test/widget_test.dart`
  - Add route/interaction tests for the new page, settings route, grouped record page, and read-state tap behavior

---

### Task 1: Route And Home Entry Wiring

**Files:**
- Modify: `lib/app/routes.dart`
- Modify: `lib/features/dorm/presentation/pages/dorm_page.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Write route tests first**

Add these tests near the existing dorm tests in `test/widget_test.dart`:

```dart
testWidgets('dorm current status more action opens the dedicated page', (
  WidgetTester tester,
) async {
  await _pumpApp(tester, initialLocation: AppRoutes.dorm, clock: _dayClock);

  await tester.scrollUntilVisible(
    find.byKey(DormPage.currentStatusMoreKey),
    240,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();

  tester
      .widget<TextButton>(find.byKey(DormPage.currentStatusMoreKey))
      .onPressed!
      .call();
  await tester.pumpAndSettle();

  expect(find.byType(DormCurrentStatusPage), findsOneWidget);
  expect(find.text('当前室友状态'), findsWidgets);
  expect(find.text('按室友查看'), findsOneWidget);
});

testWidgets('dorm hero settings opens existing dorm management page', (
  WidgetTester tester,
) async {
  await _pumpApp(tester, initialLocation: AppRoutes.dorm, clock: _dayClock);

  await tester.tap(find.byKey(DormPage.heroSettingsKey));
  await tester.pumpAndSettle();

  expect(find.byType(DormManagementPage), findsOneWidget);
  expect(find.text('寝室管理'), findsWidgets);
});
```

- [ ] **Step 2: Run the new tests and confirm they fail**

Run:

```bash
flutter test test/widget_test.dart --name "dorm current status more action|dorm hero settings"
```

Expected: FAIL because `DormCurrentStatusPage`, `DormPage.currentStatusMoreKey`, and `DormPage.heroSettingsKey` do not exist yet.

- [ ] **Step 3: Add route constants and route registration**

In `lib/app/routes.dart`, add the import:

```dart
import 'package:sleep_dorm_app/features/dorm/presentation/pages/dorm_current_status_page.dart';
```

Add the route constant near the other dorm routes:

```dart
static const String dormCurrentStatus = '/dorm/current_status';
```

Register the route near `AppRoutes.dormStatus`:

```dart
GoRoute(
  path: AppRoutes.dormCurrentStatus,
  builder: (BuildContext context, GoRouterState state) =>
      const DormCurrentStatusPage(),
),
```

- [ ] **Step 4: Add the home keys and route targets**

In `DormPage`, add keys:

```dart
static const ValueKey<String> currentStatusMoreKey = ValueKey<String>(
  'dorm-current-status-more',
);
static const ValueKey<String> heroSettingsKey = ValueKey<String>(
  'dorm-hero-settings',
);
```

In `_DormPencilScaffold`, change the roommate section header:

```dart
_DormPencilSectionHeader(
  title: '当前室友状态',
  actionLabel: '查看全部',
  actionKey: DormPage.currentStatusMoreKey,
  onAction: () => context.push(AppRoutes.dormCurrentStatus),
),
```

Update `_DormHeroCard` to accept an `onSettingsTap` callback:

```dart
const _DormHeroCard({
  super.key,
  required this.palette,
  required this.onlineLabel,
  required this.quietScore,
  required this.onSettingsTap,
});

final VoidCallback onSettingsTap;
```

Pass it from `_DormPencilScaffold`:

```dart
_DormHeroCard(
  key: DormPage.heroCardKey,
  palette: palette,
  onlineLabel: dormOnlineCountLabel(dorm.members, now: liveNow),
  quietScore: quietStars,
  onSettingsTap: () => context.push(AppRoutes.profileAccountDorm),
),
```

Render the setting pill in the hero top row, using existing tokens:

```dart
Row(
  children: <Widget>[
    Expanded(
      child: Text(
        '宿舍脉搏',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textStrong,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    TextButton.icon(
      key: DormPage.heroSettingsKey,
      onPressed: onSettingsTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textStrong,
        backgroundColor: AppColors.surface,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.pill),
      ),
      icon: const Icon(Icons.settings_rounded, size: AppSpacing.sm),
      label: const Text('寝室设置'),
    ),
  ],
),
```

- [ ] **Step 5: Run route tests**

Run:

```bash
flutter test test/widget_test.dart --name "dorm current status more action|dorm hero settings"
```

Expected: PASS after Task 2 creates the new page. If this task is run before Task 2, route compilation still fails until the page file exists.

---

### Task 2: Dedicated Current Roommate Status Page

**Files:**
- Create: `lib/features/dorm/presentation/pages/dorm_current_status_page.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Create the new page skeleton**

Create `lib/features/dorm/presentation/pages/dorm_current_status_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_message_record_card.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/support/dorm_member_status_presenter.dart';

enum _CurrentDormStatusFilter { all, quiet, pending }

class DormCurrentStatusPage extends StatefulWidget {
  const DormCurrentStatusPage({super.key});

  static const ValueKey<String> listKey = ValueKey<String>(
    'dorm-current-status-list',
  );

  @override
  State<DormCurrentStatusPage> createState() => _DormCurrentStatusPageState();
}

class _DormCurrentStatusPageState extends State<DormCurrentStatusPage> {
  _CurrentDormStatusFilter _filter = _CurrentDormStatusFilter.all;

  @override
  Widget build(BuildContext context) {
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
            final UserProfile currentUser = services.authRepository.currentUser;
            final List<DormMember> members = _filteredMembers(dorm);

            return LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double widthFactor = _pageWidthFactor(
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
                              _CurrentStatusHeader(
                                onBack: () => context.pop(),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              _CurrentStatusOverview(dorm: dorm),
                              const SizedBox(height: AppSpacing.xs),
                              _CurrentStatusTabs(
                                value: _filter,
                                onChanged: (value) {
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
                              const SizedBox(height: AppSpacing.xs),
                              Column(
                                key: DormCurrentStatusPage.listKey,
                                children: members
                                    .map(
                                      (DormMember member) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: AppSpacing.xs,
                                        ),
                                        child: _CurrentRoommateStatusCard(
                                          member: member,
                                          currentUser: currentUser,
                                          showPresence: shouldShowDormPresence(
                                            dorm,
                                            member,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
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
  }

  List<DormMember> _filteredMembers(Dorm dorm) {
    return switch (_filter) {
      _CurrentDormStatusFilter.all => dorm.members,
      _CurrentDormStatusFilter.quiet => dorm.members
          .where(
            (DormMember member) =>
                member.status == DormMemberStatus.quiet ||
                member.status == DormMemberStatus.sleeping,
          )
          .toList(growable: false),
      _CurrentDormStatusFilter.pending => dorm.members
          .where(
            (DormMember member) =>
                member.presenceStatus == DormPresenceStatus.unknown ||
                !member.appOnline,
          )
          .toList(growable: false),
    };
  }
}
```

- [ ] **Step 2: Add the header, overview, tabs, and card widgets**

In the same file, add:

```dart
class _CurrentStatusHeader extends StatelessWidget {
  const _CurrentStatusHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
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
          '当前室友状态',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CurrentStatusOverview extends StatelessWidget {
  const _CurrentStatusOverview({required this.dorm});

  final Dorm dorm;

  @override
  Widget build(BuildContext context) {
    final int activeCount = dorm.members
        .where((DormMember member) => member.appOnline)
        .length;
    final int sleepCount = dorm.members
        .where((DormMember member) => member.sleepModeActive)
        .length;
    return AppMessageRecordCard(
      icon: Icons.people_alt_rounded,
      title: '今晚 ${dorm.members.length} 位室友有状态',
      detail: '$activeCount 位在线 · $sleepCount 位睡眠中',
      highlighted: false,
      iconBackgroundColor: AppColors.primaryHighlight,
      iconColor: AppColors.textStrong,
    );
  }
}

class _CurrentStatusTabs extends StatelessWidget {
  const _CurrentStatusTabs({required this.value, required this.onChanged});

  final _CurrentDormStatusFilter value;
  final ValueChanged<_CurrentDormStatusFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _CurrentDormStatusFilter.values.map((filter) {
          final bool selected = filter == value;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: ChoiceChip(
              selected: selected,
              showCheckmark: false,
              label: Text(_filterLabel(filter)),
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surfaceMuted,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.pill),
              labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected
                        ? AppColors.textStrong
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
              onSelected: (_) => onChanged(filter),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  String _filterLabel(_CurrentDormStatusFilter filter) {
    return switch (filter) {
      _CurrentDormStatusFilter.all => '全部',
      _CurrentDormStatusFilter.quiet => '安静中',
      _CurrentDormStatusFilter.pending => '待确认',
    };
  }
}

class _CurrentRoommateStatusCard extends StatelessWidget {
  const _CurrentRoommateStatusCard({
    required this.member,
    required this.currentUser,
    required this.showPresence,
  });

  final DormMember member;
  final UserProfile currentUser;
  final bool showPresence;

  @override
  Widget build(BuildContext context) {
    final String label = dormPresenceSleepLabel(
      member,
      showPresence: showPresence,
    );
    return AppMessageRecordCard(
      icon: _iconForMember(member),
      title: '${member.name} · $label',
      detail: member.note,
      highlighted:
          member.status == DormMemberStatus.sleeping ||
          member.status == DormMemberStatus.quiet,
      iconBackgroundColor: member.appOnline
          ? AppColors.primaryHighlight
          : AppColors.surfaceMuted,
      iconColor: AppColors.textStrong,
      trailing: _CurrentStatusPill(label: label, active: member.appOnline),
    );
  }

  IconData _iconForMember(DormMember member) {
    return switch (member.status) {
      DormMemberStatus.sleeping => Icons.bedtime_rounded,
      DormMemberStatus.quiet => Icons.menu_book_rounded,
      DormMemberStatus.away => Icons.location_on_outlined,
      DormMemberStatus.active => Icons.auto_awesome_rounded,
    };
  }
}

class _CurrentStatusPill extends StatelessWidget {
  const _CurrentStatusPill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.surfaceMuted,
        borderRadius: AppRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: AppSpacing.xs,
            height: AppSpacing.xs,
            decoration: BoxDecoration(
              color: active ? AppColors.textStrong : AppColors.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: active ? AppColors.textStrong : AppColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

double _pageWidthFactor(double maxWidth) {
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
```

- [ ] **Step 3: Run the new-page tests**

Run:

```bash
flutter test test/widget_test.dart --name "dorm current status more action"
```

Expected: PASS.

---

### Task 3: Record Data Model For Read/Unread Behavior

**Files:**
- Modify: `lib/features/dorm/presentation/support/dorm_event_records.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Extend `DormEventRecord`**

Change `DormEventRecord` to include stable read-state fields:

```dart
class DormEventRecord {
  const DormEventRecord({
    required this.id,
    required this.title,
    required this.detail,
    required this.color,
    required this.timeLabel,
    required this.icon,
    required this.createdAt,
    required this.isRead,
    this.actionRoute,
    this.notificationId,
  });

  final String id;
  final String title;
  final String detail;
  final Color color;
  final String timeLabel;
  final IconData icon;
  final DateTime createdAt;
  final bool isRead;
  final String? actionRoute;
  final String? notificationId;
}
```

- [ ] **Step 2: Populate read-state fields**

For dorm events, set:

```dart
DormEventRecord(
  id: 'event-${event.id}',
  title: event.title,
  detail: event.detail,
  color: _colorForDormEvent(event, palette),
  timeLabel: _relativeTimeLabel(event.createdAt, effectiveNow),
  icon: _iconForDormEvent(event),
  createdAt: event.createdAt,
  isRead: false,
)
```

For dorm notifications, set:

```dart
DormEventRecord(
  id: 'notification-${dormNotification.id}',
  title: dormNotification.title,
  detail: dormNotification.body,
  color: palette.primary,
  timeLabel: _relativeTimeLabel(dormNotification.createdAt, effectiveNow),
  icon: Icons.notifications_active_rounded,
  createdAt: dormNotification.createdAt,
  isRead: dormNotification.isRead,
  notificationId: dormNotification.id,
  actionRoute: dormNotification.route,
)
```

For the rule record, set:

```dart
DormEventRecord(
  id: 'rule-${dorm.rules.first.id}',
  title: '今晚默认执行寝室公约',
  detail: dorm.rules.first.title,
  color: palette.primary,
  timeLabel: '规则',
  icon: Icons.rule_rounded,
  createdAt: dorm.rules.first.updatedAt ?? effectiveNow,
  isRead: false,
  actionRoute: AppRoutes.dormRules,
)
```

If `DormRule` does not expose `updatedAt`, use `effectiveNow` and do not add a model field.

- [ ] **Step 3: Keep existing callers compiling**

Update all `DormEventRecord(...)` construction sites in this file only. Do not change repository models.

- [ ] **Step 4: Run dorm tests**

Run:

```bash
flutter test test/widget_test.dart --name dorm
```

Expected: compile after Task 4 updates status-page usage. If run before Task 4, compile may fail because consumers still expect the old shape.

---

### Task 4: Dorm Status Record Page Matches Pencil And Reacts To Taps

**Files:**
- Modify: `lib/features/dorm/presentation/pages/dorm_status_page.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Write interaction tests**

Add tests near the existing `dorm event actions route to dorm status records page` test:

```dart
testWidgets('dorm status page uses read-state tabs and grouped records', (
  WidgetTester tester,
) async {
  await _pumpApp(tester, initialLocation: AppRoutes.dormStatus, clock: _dayClock);

  expect(find.text('待处理'), findsWidgets);
  expect(find.text('今天'), findsWidgets);
  expect(find.text('更早'), findsWidgets);
  expect(find.text('当前室友状态'), findsNothing);
  expect(find.byKey(DormStatusPage.unreadOverviewKey), findsOneWidget);
});

testWidgets('tapping unread dorm status record marks it as read', (
  WidgetTester tester,
) async {
  await _pumpApp(tester, initialLocation: AppRoutes.dormStatus, clock: _dayClock);

  expect(find.byKey(DormStatusPage.activeRecordKey), findsWidgets);
  final Finder unreadRecord = find.byKey(DormStatusPage.activeRecordKey).first;
  await tester.tap(unreadRecord);
  await tester.pumpAndSettle();

  expect(find.textContaining('待处理'), findsWidgets);
  expect(find.byKey(DormStatusPage.activeRecordKey), findsWidgets);
  expect(find.byKey(DormStatusPage.readRecordKey), findsWidgets);
});
```

- [ ] **Step 2: Replace filter enum and add keys**

In `DormStatusPage`, replace `_DormStatusFilter`:

```dart
enum _DormStatusReadFilter { unread, today, earlier }
```

Add keys:

```dart
static const ValueKey<String> unreadOverviewKey = ValueKey<String>(
  'dorm-status-unread-overview',
);
static const ValueKey<String> readRecordKey = ValueKey<String>(
  'dorm-status-read-record',
);
```

In state, replace `_filter`:

```dart
_DormStatusReadFilter _filter = _DormStatusReadFilter.unread;
final Set<String> _locallyReadRecordIds = <String>{};
```

- [ ] **Step 3: Build resolved records**

Inside `build`, after `buildDormEventRecords(...)`, resolve read state:

```dart
final List<DormEventRecord> allRecords = buildDormEventRecords(
  dorm: dorm,
  notifications: services.notificationRepository.notifications,
  palette: palette,
  now: services.dormLiveStatusController.currentTime,
).map((DormEventRecord record) {
  if (_locallyReadRecordIds.contains(record.id)) {
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
  return record;
}).toList(growable: false);
```

- [ ] **Step 4: Add grouping helpers**

Add helpers in `DormStatusPage`:

```dart
List<DormEventRecord> _recordsForFilter(
  List<DormEventRecord> records,
  DateTime now,
) {
  return switch (_filter) {
    _DormStatusReadFilter.unread =>
      records.where((DormEventRecord record) => !record.isRead).toList(),
    _DormStatusReadFilter.today => records
        .where(
          (DormEventRecord record) =>
              record.isRead && _isSameDay(record.createdAt, now),
        )
        .toList(),
    _DormStatusReadFilter.earlier => records
        .where(
          (DormEventRecord record) =>
              record.isRead && !_isSameDay(record.createdAt, now),
        )
        .toList(),
  };
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
```

- [ ] **Step 5: Replace the page body**

The visual order should be:

1. `_DormStatusHeader`
2. `_DormStatusOverview`
3. `_DormStatusReadTabs`
4. `_DormStatusGroupedList`

Use this structure inside the existing responsive `LayoutBuilder`:

```dart
final DateTime now = services.dormLiveStatusController.currentTime;
final List<DormEventRecord> visibleRecords = _recordsForFilter(
  allRecords,
  now,
);
final int unreadCount = allRecords
    .where((DormEventRecord record) => !record.isRead)
    .length;

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
              _DormStatusHeader(onBack: () => Navigator.of(context).maybePop()),
              const SizedBox(height: AppSpacing.sm),
              _DormStatusOverview(unreadCount: unreadCount),
              const SizedBox(height: AppSpacing.xs),
              _DormStatusReadTabs(
                key: DormStatusPage.filterRowKey,
                value: _filter,
                onChanged: (value) => setState(() => _filter = value),
              ),
              const SizedBox(height: AppSpacing.xs),
              _DormStatusGroupedList(
                label: _sectionLabel(_filter),
                records: visibleRecords,
                onTap: (record) => _handleRecordTap(
                  context,
                  services,
                  record,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
```

- [ ] **Step 6: Add overview, tabs, list widgets**

Use existing `AppMessageRecordCard` and theme tokens:

```dart
class _DormStatusOverview extends StatelessWidget {
  const _DormStatusOverview({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return AppMessageRecordCard(
      key: DormStatusPage.unreadOverviewKey,
      icon: Icons.notifications_active_rounded,
      title: unreadCount > 0 ? '有 $unreadCount 条待处理状态' : '状态都已处理',
      detail: unreadCount > 0 ? '点击卡片后会标记为已读' : '今天的寝室状态已经看完',
      highlighted: false,
      iconBackgroundColor: AppColors.primaryHighlight,
      iconColor: AppColors.textStrong,
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _DormStatusReadFilter.values.map((filter) {
          final bool selected = filter == value;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: ChoiceChip(
              selected: selected,
              showCheckmark: false,
              label: Text(_tabLabel(filter)),
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surfaceMuted,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.pill),
              labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected
                        ? AppColors.textStrong
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
              onSelected: (_) => onChanged(filter),
            ),
          );
        }).toList(growable: false),
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
```

List rendering:

```dart
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
    if (records.isEmpty) {
      return Text(
        '这一组暂时没有状态',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
      );
    }
    return Column(
      key: DormStatusPage.timelineKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ...records.map((record) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: AppMessageRecordCard(
              key: record.isRead
                  ? DormStatusPage.readRecordKey
                  : DormStatusPage.activeRecordKey,
              icon: record.icon,
              title: record.title,
              detail: record.detail,
              timeLabel: record.timeLabel,
              highlighted: !record.isRead,
              onTap: () => onTap(record),
              iconBackgroundColor: !record.isRead
                  ? AppColors.primaryHighlight
                  : AppColors.surfaceMuted,
              iconColor: AppColors.textStrong,
            ),
          );
        }),
      ],
    );
  }
}
```

- [ ] **Step 7: Add the tap handler**

In `_DormStatusPageState`, add:

```dart
Future<void> _handleRecordTap(
  BuildContext context,
  AppServices services,
  DormEventRecord record,
) async {
  if (!record.isRead) {
    setState(() => _locallyReadRecordIds.add(record.id));
    final String? notificationId = record.notificationId;
    if (notificationId != null) {
      await services.notificationRepository.markRead(notificationId);
    }
  }
  final String? route = record.actionRoute;
  if (route != null && context.mounted) {
    context.push(route);
  }
}

String _sectionLabel(_DormStatusReadFilter filter) {
  return switch (filter) {
    _DormStatusReadFilter.unread => '待处理',
    _DormStatusReadFilter.today => '今天',
    _DormStatusReadFilter.earlier => '更早',
  };
}
```

If navigation makes the read-state change hard to see in tests, only navigate for explicit trailing action routes and keep normal card taps on the current page.

- [ ] **Step 8: Run status-page tests**

Run:

```bash
flutter test test/widget_test.dart --name "dorm status page|tapping unread dorm status record|dorm event actions"
```

Expected: PASS. The status page shows `待处理/今天/更早`, does not show the member-status section, and tapping unread cards changes at least one card into the read visual state.

---

### Task 5: Shared Message Card Polish Without New Colors

**Files:**
- Modify: `lib/core/widgets/app_message_record_card.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Keep the current default visual contract**

Do not change constructor defaults that existing pages rely on:

```dart
color: highlighted ? AppColors.legacyCardSurface : AppColors.surface,
borderRadius: borderRadius ?? AppRadius.compactCard,
boxShadow: const <BoxShadow>[],
```

- [ ] **Step 2: Add only responsive overflow hardening**

Keep title and detail constrained and prevent trailing overflow:

```dart
Flexible(
  child: trailingWidget,
)
```

Only use this if status pills overflow on narrow screens. Otherwise leave the widget unchanged.

- [ ] **Step 3: Run the dorm tests**

Run:

```bash
flutter test test/widget_test.dart --name dorm
```

Expected: PASS. No new colors are introduced; card colors remain `AppColors.primary`, `AppColors.primaryHighlight`, `AppColors.legacyCardSurface`, `AppColors.surface`, `AppColors.surfaceMuted`, and text colors from `AppColors`.

---

### Task 6: Responsive Layout And No Arbitrary Absolute Pixels Audit

**Files:**
- Modify: `lib/features/dorm/presentation/pages/dorm_page.dart`
- Modify: `lib/features/dorm/presentation/pages/dorm_status_page.dart`
- Modify: `lib/features/dorm/presentation/pages/dorm_current_status_page.dart`
- Modify: `lib/features/dorm/presentation/pages/dorm_member_detail_page.dart` only if a regression appears
- Test: `test/widget_test.dart`

- [ ] **Step 1: Audit new code for raw dimensions**

Run:

```bash
Select-String -Path 'lib\features\dorm\presentation\pages\dorm_*.dart','lib\core\widgets\app_message_record_card.dart' -Pattern 'width: [0-9]|height: [0-9]|EdgeInsets\.(all|only|symmetric)\([0-9]|Color\(0x'
```

Expected: new code uses `AppSpacing`, `AppRadius`, `AppColors`, `Expanded`, `Flexible`, `FractionallySizedBox`, and `ConstrainedBox`. Any remaining fixed icon/avatar sizes must be existing component API requirements or token-derived constants, not arbitrary page layout widths.

- [ ] **Step 2: Add mobile and tablet smoke coverage**

Add or extend a dorm layout test:

```dart
testWidgets('dorm status pages stay usable on mobile and tablet widths', (
  WidgetTester tester,
) async {
  for (final Size size in <Size>[
    const Size(390, 844),
    const Size(820, 1180),
  ]) {
    await tester.binding.setSurfaceSize(size);
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.dormStatus,
      clock: _dayClock,
    );
    expect(find.byType(DormStatusPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  }
  addTearDown(() => tester.binding.setSurfaceSize(null));
});
```

- [ ] **Step 3: Run focused verification**

Run:

```bash
flutter test test/widget_test.dart --name dorm
flutter analyze
```

Expected: PASS for all dorm tests and no analyzer errors.

---

## Self-Review

- Spec coverage:
  - New "当前室友状态" page after home "查看全部": covered by Task 1 and Task 2.
  - Status record page closer to Pencil `nPfYe`: covered by Task 4.
  - Status record card click/read-unread reaction: covered by Task 3 and Task 4.
  - Dorm settings routes to existing page: covered by Task 1.
  - No new colors and no arbitrary absolute page layout pixels: covered by Task 5 and Task 6.

- Placeholder scan:
  - No TBD/TODO placeholders remain.
  - Every task has exact files and concrete commands.

- Type consistency:
  - `DormCurrentStatusPage` is introduced before route tests are expected to pass.
  - `DormEventRecord` field names are used consistently in status-page code.
  - Route constants are consistently named `AppRoutes.dormCurrentStatus`.

