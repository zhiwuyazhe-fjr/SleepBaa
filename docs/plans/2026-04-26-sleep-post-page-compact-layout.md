# Sleep Post Page Compact Layout Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Update `HomePostSleepPage` to match the approved compact design language, prevent narrow-screen overflow risks, and route system back gestures through the sleep-exit confirmation dialog.

**Architecture:** Keep the existing page structure and business flow, but tighten spacing, radius, and typography to existing app tokens. Move the sleep-page hero and tool grid to responsive layouts so the same widget tree adapts across narrow widths. Reuse the existing exit dialog logic for both the explicit button and system back handling.

**Tech Stack:** Flutter, Dart, GoRouter, widget tests, existing `AppSpacing` / `AppRadius` / `PrimaryButton` tokens

---

### Task 1: Lock the navigation regression with tests

**Files:**
- Modify: `test/widget_test.dart`
- Modify: `lib/features/home/presentation/pages/home_post_sleep_page.dart`

**Step 1: Write the failing test**

Add widget coverage that enters sleep mode, triggers a system back pop from `HomePostSleepPage`, and asserts the confirmation dialog appears instead of leaving the page.

**Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart --plain-name "system back from post-sleep page opens exit dialog"`

Expected: FAIL because the page currently pops immediately and no dialog is shown.

**Step 3: Write minimal implementation**

Wrap the sleep page in `PopScope`, intercept the back attempt, and call the same dialog flow already used by the “结束睡眠模式” button.

**Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart --plain-name "system back from post-sleep page opens exit dialog"`

Expected: PASS

### Task 2: Lock the compact layout against overflow

**Files:**
- Modify: `test/widget_test.dart`
- Modify: `lib/features/home/presentation/pages/home_post_sleep_page.dart`
- Modify: `lib/features/home/presentation/widgets/home_widgets.dart`

**Step 1: Write the failing test**

Add a narrow-width widget test that pumps `HomePostSleepPage` with a small logical width and asserts `tester.takeException()` stays `null` after settling.

**Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart --plain-name "post-sleep page stays overflow-free on narrow width"`

Expected: FAIL if fixed sizing or dialog/button layout still overflows.

**Step 3: Write minimal implementation**

Use token-aligned spacing/radius updates, responsive hero sizing, responsive tool-card layout, and a wrapping/stacking exit dialog action layout that fits narrow widths.

**Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart --plain-name "post-sleep page stays overflow-free on narrow width"`

Expected: PASS

### Task 3: Apply the approved compact visual language

**Files:**
- Modify: `lib/features/home/presentation/pages/home_post_sleep_page.dart`
- Modify: `lib/features/home/presentation/widgets/home_widgets.dart`

**Step 1: Refactor page layout to token-based density**

Replace ad-hoc spacing/radius values with existing `AppSpacing` and `AppRadius` tokens. Keep the current content order.

**Step 2: Make the moon hero responsive**

Use `LayoutBuilder` to scale the moon block from available width instead of fixed `264x264` sizing.

**Step 3: Tighten secondary components**

Adjust `SessionAudioCard` and `SupportToolCard` typography, padding, and wrapping so they match the approved compact design while staying readable.

**Step 4: Verify manually with tests**

Run the focused widget tests plus a broader home-page regression slice.

### Task 4: Final verification

**Files:**
- No additional code changes expected

**Step 1: Run focused tests**

Run:
- `flutter test test/widget_test.dart --plain-name "system back from post-sleep page opens exit dialog"`
- `flutter test test/widget_test.dart --plain-name "post-sleep page stays overflow-free on narrow width"`
- `flutter test test/widget_test.dart --plain-name "finishing sleep mode from post-sleep page goes to morning feedback"`

**Step 2: Run static analysis**

Run: `flutter analyze`

Expected: no new issues introduced by the layout and navigation changes.

Plan complete and saved to `docs/plans/2026-04-26-sleep-post-page-compact-layout.md`.
