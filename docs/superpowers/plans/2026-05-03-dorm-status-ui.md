# Dorm Status UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the Flutter dorm surfaces into alignment with the approved Pencil design: dorm status records, roommate detail activity records, dorm home status snippets, and dorm settings.

**Architecture:** Use the Pencil `Dorm Status Grouped List` as the visual source of truth for record cards. Extract one dorm-scoped reusable status record tile so `DormStatusPage`, `DormPage`, and `DormMemberDetailPage` share the same card rhythm without forcing the home page to be a 1:1 copy of the status page.

**Tech Stack:** Flutter, Dart, `go_router`, existing `AppColors`, `NightMoodPalette`, `AppCard`, `AppSettingsGroup`, widget tests in `test/widget_test.dart`.

---

## Scope Lock

Pencil anchors:

- `9Djal` / `Dorm Status Grouped List`: source-of-truth record list style.
- `5vqgx`: approved unread/status card style. Do not redesign it.
- `p3FrY`: status filter tab row; use rounded rectangle pills and the approved library color.
- `qq3NH`: private/member status pill; must be reproduced closely.
- `WOvJt`: dorm home page; only small changes to status record snippets, because the real Flutter page does not match the Pencil layout exactly.
- `kzwPH` / `Dorm Member Detail`: member detail activity list should match the status record family closely.

Implementation scope:

- Two color fixes: `p3FrY`-equivalent filter selected state and `qq3NH`-equivalent member/private status pill.
- New or refined roommate detail page behavior/visuals.
- Dorm settings page visual refinement.
- Dorm status records page redesign.
- Dorm home page status snippets only; no broad home page redesign.

Out of scope:

- No unrelated Pencil work.
- No changes to dorm rules, invite flow, badges, AI assistant, auth, or backend sync.
- No new color values outside `AppColors` / `NightMoodPalette`.

---

## File Structure

- Modify: `lib/app/theme/app_colors.dart`
  - Verify `AppColors.primary` is already the approved new primary. If it is not, change only this token after matching the approved color board.
- Modify: `lib/features/dorm/presentation/support/dorm_event_records.dart`
  - Remove hardcoded event colors that create old/dark accents. Return semantic display kinds or palette/library colors.
- Create: `lib/features/dorm/presentation/widgets/dorm_status_record_tile.dart`
  - Shared record card used by status page, dorm home snippets, and member detail activity.
- Modify: `lib/features/dorm/presentation/pages/dorm_status_page.dart`
  - Rebuild list structure to match `Dorm Status Grouped List`: overview card, rounded filter row, grouped records, current roommate section if still needed.
- Modify: `lib/features/dorm/presentation/pages/dorm_page.dart`
  - Replace `_DormEventTile` internals with the shared record tile; keep home layout and spacing mostly intact.
- Modify: `lib/features/dorm/presentation/pages/dorm_member_detail_page.dart`
  - Match the `qq3NH` status pill and use shared record tiles for recent activity.
- Modify: `lib/features/profile/presentation/pages/profile_account_pages.dart`
  - Refine `DormManagementPage` to the agreed dorm settings style while keeping existing actions.
- Modify: `test/widget_test.dart`
  - Add focused widget assertions for route presence, card/tabs keys, and no regression in navigation.

---

### Task 1: Lock Approved Color Tokens

**Files:**
- Modify: `lib/app/theme/app_colors.dart`
- Read: `lib/app/theme/night_mood_theme.dart`

- [ ] **Step 1: Verify the current primary and CTA tokens**

Read `AppColors.primary`, `AppColors.primarySoft`, `AppColors.primaryHighlight`, and `NightMoodPalette.welcomeAccentColor`.

Expected source-of-truth mapping:

```dart
// Strong text remains black/gray.
AppColors.textStrong
AppColors.textPrimary
AppColors.textSecondary
AppColors.textSubtle

// Young CTA family used by p3FrY and qq3NH equivalents.
AppColors.primary
AppColors.primarySoft
AppColors.primaryHighlight
```

- [ ] **Step 2: If `AppColors.primary` is still the old dark primary, update only that token**

Use the approved library primary value. Do not add a new token unless the color board has already named one.

```dart
static const Color primary = Color(0xFF8EDDF2);
```

If the repository already has the approved new primary, leave this file untouched.

- [ ] **Step 3: Run static analysis for theme changes**

Run:

```powershell
flutter analyze
```

Expected: no new analyzer errors from theme files.

---

### Task 2: Create Shared Dorm Status Record Tile

**Files:**
- Create: `lib/features/dorm/presentation/widgets/dorm_status_record_tile.dart`
- Modify later: `dorm_status_page.dart`, `dorm_page.dart`, `dorm_member_detail_page.dart`

- [ ] **Step 1: Add the reusable tile**

Create this widget with explicit variants for unread/active and read/normal cards.

```dart
import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';

enum DormStatusRecordTone { active, normal }

class DormStatusRecordTile extends StatelessWidget {
  const DormStatusRecordTile({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.timeLabel,
    this.tone = DormStatusRecordTone.normal,
    this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String timeLabel;
  final DormStatusRecordTone tone;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    final bool active = tone == DormStatusRecordTone.active;
    final double iconSize = compact ? 34 : 36;
    return AppCard(
      onTap: onTap,
      color: active ? AppColors.legacyCardSurface : AppColors.surface,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      borderRadius: AppRadius.control,
      boxShadow: const <BoxShadow>[],
      child: Row(
        children: <Widget>[
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: active ? palette.primaryHighlight : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: active ? palette.primary : AppColors.calmBlue,
              size: compact ? 18 : 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSubtle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            timeLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: active ? palette.primary : AppColors.textSecondary,
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run format**

Run:

```powershell
dart format lib/features/dorm/presentation/widgets/dorm_status_record_tile.dart
```

Expected: file formatted without errors.

---

### Task 3: Update Dorm Status Page

**Files:**
- Modify: `lib/features/dorm/presentation/pages/dorm_status_page.dart`

- [ ] **Step 1: Import the shared tile**

```dart
import 'package:sleep_dorm_app/features/dorm/presentation/widgets/dorm_status_record_tile.dart';
```

- [ ] **Step 2: Update the filter row to match `p3FrY`**

Use rounded rectangle pills. Selected state uses the approved primary/CTA library color and black text, not dark teal.

```dart
selectedColor: palette.welcomeAccentColor,
backgroundColor: AppColors.surfaceMuted,
labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
  color: selected ? AppColors.textStrong : AppColors.textSecondary,
  fontWeight: FontWeight.w800,
),
shape: RoundedRectangleBorder(borderRadius: AppRadius.pill),
```

- [ ] **Step 3: Replace `_StatusEventCard` with the shared tile**

Active tone should be used for the first filtered records that correspond to `Dorm Status Grouped List` unread/important cards.

```dart
DormStatusRecordTile(
  icon: event.icon,
  title: event.title,
  detail: event.detail,
  timeLabel: event.timeLabel,
  tone: _activeRecordTitles.contains(event.title)
      ? DormStatusRecordTone.active
      : DormStatusRecordTone.normal,
)
```

Define:

```dart
bool _isActiveDormRecord(DormEventRecord event) {
  return event.title.contains('入睡') ||
      event.title.contains('噪') ||
      event.title.contains('公约') ||
      event.title.contains('提醒');
}
```

- [ ] **Step 4: Keep the roommate status section**

Do not remove `当前室友状态`. Only make sure its status pill does not use hard dark fills.

```dart
color: palette.welcomeAccentColor,
```

Text:

```dart
color: AppColors.textStrong,
```

- [ ] **Step 5: Add keys for tests**

Add stable keys:

```dart
static const ValueKey<String> filterRowKey =
    ValueKey<String>('dorm-status-filter-row');
static const ValueKey<String> activeRecordKey =
    ValueKey<String>('dorm-status-active-record');
```

Use `activeRecordKey` on the first active record tile.

---

### Task 4: Update Dorm Home Status Snippets

**Files:**
- Modify: `lib/features/dorm/presentation/pages/dorm_page.dart`

- [ ] **Step 1: Import shared tile**

```dart
import 'package:sleep_dorm_app/features/dorm/presentation/widgets/dorm_status_record_tile.dart';
```

- [ ] **Step 2: Replace `_DormEventTile` body with shared tile**

Keep the existing home layout and section header. Use `compact: true` so the home page does not try to copy the full status page.

```dart
return DormStatusRecordTile(
  icon: event.icon,
  title: event.title,
  detail: event.detail,
  timeLabel: event.timeLabel,
  tone: _isDormHomeActiveRecord(event)
      ? DormStatusRecordTone.active
      : DormStatusRecordTone.normal,
  compact: true,
  onTap: onTap,
);
```

Add helper near `_DormEventTile`:

```dart
bool _isDormHomeActiveRecord(DormEventRecord event) {
  return event.title.contains('入睡') ||
      event.title.contains('噪') ||
      event.title.contains('公约');
}
```

- [ ] **Step 3: Keep home changes small**

Do not change `_DormHeroCard`, roommate strip layout, or hub grid in this task.

---

### Task 5: Update Dorm Member Detail

**Files:**
- Modify: `lib/features/dorm/presentation/pages/dorm_member_detail_page.dart`

- [ ] **Step 1: Import shared tile**

```dart
import 'package:sleep_dorm_app/features/dorm/presentation/widgets/dorm_status_record_tile.dart';
```

- [ ] **Step 2: Reproduce `qq3NH` status pill**

In `_DormMemberProfileHero`, replace the deep filled pill with a light CTA pill and black text/dot.

```dart
Container(
  padding: const EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.xs,
  ),
  decoration: BoxDecoration(
    color: context.nightMoodPalette.welcomeAccentColor,
    borderRadius: AppRadius.pill,
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.textStrong,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: AppSpacing.xs),
      Text(
        dormPresenceSleepLabel(member, showPresence: showPresence),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.textStrong,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  ),
)
```

- [ ] **Step 3: Replace `_DormMemberActivityTile` with shared tile**

```dart
return DormStatusRecordTile(
  icon: event.icon,
  title: event.title,
  detail: event.detail,
  timeLabel: event.timeLabel,
  tone: index == 0 ? DormStatusRecordTone.active : DormStatusRecordTone.normal,
);
```

If the list mapping currently lacks `index`, change it to `asMap().entries.map(...)`.

- [ ] **Step 4: Add test key for private status**

```dart
static const ValueKey<String> privateStatusPillKey =
    ValueKey<String>('dorm-member-private-status-pill');
```

Use it on the status pill container.

---

### Task 6: Update Dorm Settings Page

**Files:**
- Modify: `lib/features/profile/presentation/pages/profile_account_pages.dart`

- [ ] **Step 1: Keep existing route and actions**

Do not change:

```dart
AppRoutes.profileAccountDorm
DormManagementPage
_renameDorm
_recordDormAnchor
_leaveDorm
```

- [ ] **Step 2: Apply the same color rule to dorm settings icons**

Replace dark icon colors in `DormManagementPage` with light card/icon language where the row owns the visual surface. Keep `AppSettingsGroup` structure.

```dart
iconColor: palette.primary,
```

Do not introduce hardcoded color values.

- [ ] **Step 3: If dorm settings has a hero/info card, use library colors**

Use:

```dart
color: AppColors.surface,
borderRadius: AppRadius.compactCard,
```

For soft emphasis:

```dart
color: palette.primaryHighlight,
```

Text on soft emphasis:

```dart
color: AppColors.textStrong,
```

---

### Task 7: Update Dorm Event Color Source

**Files:**
- Modify: `lib/features/dorm/presentation/support/dorm_event_records.dart`

- [ ] **Step 1: Remove hardcoded non-library event colors**

Replace:

```dart
const Color(0xFFF1A936)
const Color(0xFF63D4ED)
const Color(0xFF5B8CFF)
```

With library/palette colors:

```dart
Color _colorForDormEvent(DormEvent event, NightMoodPalette palette) {
  return switch (event.type) {
    DormEventType.memberStatus => palette.primary,
    DormEventType.ruleUpdate => palette.primary,
    DormEventType.notification => palette.primary,
    DormEventType.invite => AppColors.calmBlue,
    DormEventType.system => AppColors.textSecondary,
  };
}
```

- [ ] **Step 2: Re-run pages to confirm no hardcoded accent leaks**

Search:

```powershell
Select-String -LiteralPath 'lib\features\dorm\presentation\support\dorm_event_records.dart' -Pattern 'Color\\(0x'
```

Expected: no hardcoded event accent colors remain except allowed `AppColors` or palette usage.

---

### Task 8: Tests

**Files:**
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Add status page filter/tile test**

Add assertions to the existing dorm status route test:

```dart
expect(find.byKey(DormStatusPage.filterRowKey), findsOneWidget);
expect(find.byKey(DormStatusPage.activeRecordKey), findsWidgets);
```

- [ ] **Step 2: Add member detail status pill test**

Pump member detail route:

```dart
await _pumpApp(
  tester,
  initialLocation: AppRoutes.dormMemberLocation('u2'),
  clock: _dayClock,
);
```

Assert:

```dart
expect(find.byType(DormMemberDetailPage), findsOneWidget);
expect(find.byKey(DormMemberDetailPage.privateStatusPillKey), findsOneWidget);
```

- [ ] **Step 3: Add dorm management route smoke test if missing**

```dart
await _pumpApp(
  tester,
  initialLocation: AppRoutes.profileAccountDorm,
  clock: _dayClock,
);
expect(find.byType(DormManagementPage), findsOneWidget);
expect(find.text('寝室管理'), findsWidgets);
```

- [ ] **Step 4: Run focused tests**

Run:

```powershell
flutter test test/widget_test.dart --name dorm
```

Expected: dorm-related widget tests pass.

- [ ] **Step 5: Run analyzer**

Run:

```powershell
flutter analyze
```

Expected: no new analyzer errors.

---

### Task 9: Final Visual Check

**Files:**
- No file changes required.

- [ ] **Step 1: Launch the app on the existing dev target**

Run the app with the repository's usual Flutter command.

- [ ] **Step 2: Inspect these routes**

Open:

```text
/dorm
/dorm/status
/dorm/member?uid=<existing roommate uid>
/profile/settings/account/dorm
```

- [ ] **Step 3: Compare against Pencil**

Check:

- `DormStatusPage`: matches `Dorm Status Grouped List` family.
- `DormPage`: only status snippets changed; home layout is not overhauled.
- `DormMemberDetailPage`: private status pill matches `qq3NH` closely.
- `DormManagementPage`: settings style uses library colors and no dark accent blocks.

---

## Execution Notes

Start with Tasks 1-3 because they establish the shared component and status page. Then do Tasks 4-6 as consumers. Task 7 should happen before final visual review so event colors do not reintroduce old hardcoded accents.

Plan self-review:

- Scope matches the latest user request: small implementation, not a broad redesign.
- No Pencil-only node IDs are treated as code IDs; they are visual anchors.
- No new color values are introduced.
- Home page is intentionally not 1:1 with the Pencil draft.
- Member/private status pill is called out as a close reproduction requirement.
