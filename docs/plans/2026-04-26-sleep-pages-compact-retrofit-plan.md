# Sleep Pages Compact Retrofit Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Apply the new global compact page retrofit standard to the remaining sleep-related pages, starting with morning feedback, cant-sleep support, and night-awakening logging.

**Architecture:** Use the new `glacier/visual-specs/app-compact-page-retrofit-spec.md` as the retrofit source of truth. Refactor one page at a time with TDD, preferring shared `core/widgets/**` components and token-based responsive layouts over page-local fixed-size panels.

**Tech Stack:** Flutter, Dart, GoRouter, widget tests, existing `AppSpacing` / `AppRadius` / `AppColors` / `NightMoodPalette` tokens

---

### Task 1: Lock morning feedback back-navigation behavior

**Files:**
- Modify: `test/widget_test.dart`
- Modify: `lib/features/feedback/presentation/pages/morning_feedback_page.dart`

**Step 1: Write the failing test**

Add a widget test that enters `MorningFeedbackPage` with `allowReturnToSleep = true`, triggers a system back pop, and asserts a confirmation dialog appears instead of exiting.

**Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart --plain-name "morning feedback system back opens return-to-sleep confirmation"`

Expected: FAIL because the page currently has no `PopScope`.

**Step 3: Write minimal implementation**

Add `PopScope` and reuse the same return-to-sleep confirmation flow for system back, app-bar back, and explicit return button.

**Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart --plain-name "morning feedback system back opens return-to-sleep confirmation"`

Expected: PASS

### Task 2: Compact-retrofit the morning feedback page

**Files:**
- Modify: `test/widget_test.dart`
- Modify: `lib/features/feedback/presentation/pages/morning_feedback_page.dart`

**Step 1: Write the failing test**

Add a narrow-width widget test for `MorningFeedbackPage` that asserts no overflow exceptions and verifies compact layout controls still render.

**Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart --plain-name "morning feedback stays overflow-free on narrow width"`

Expected: FAIL if current cards, sliders, or feedback controls overflow.

**Step 3: Write minimal implementation**

Refactor page spacing, card density, section rhythm, and option presentation to the compact retrofit standard. If recommendation feedback options are better represented by a drawer/sheet, implement the smallest reusable version that fits the page.

**Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart --plain-name "morning feedback stays overflow-free on narrow width"`

Expected: PASS

### Task 3: Compact-retrofit the cant-sleep page

**Files:**
- Modify: `test/widget_test.dart`
- Modify: `lib/features/sleep/presentation/pages/cant_sleep_page.dart`
- Optional modify/create: `lib/core/widgets/...` if a new reusable compact sleep component is justified

**Step 1: Write the failing test**

Add a narrow-width widget test and a structure assertion for the cause-selection area.

**Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart --plain-name "cant sleep page stays compact on narrow width"`

Expected: FAIL if the current heavy panel layout or cause selector is not compact/responsive enough.

**Step 3: Write minimal implementation**

Refactor the page to compact grouped sections, reuse shared card/button language, and replace the current cause presentation with the approved lighter interaction model.

**Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart --plain-name "cant sleep page stays compact on narrow width"`

Expected: PASS

### Task 4: Compact-retrofit the night-awakening log page

**Files:**
- Modify: `test/widget_test.dart`
- Modify: `lib/features/logs/presentation/pages/night_awakening_log_page.dart`
- Optional modify/create: `lib/core/widgets/...` if shared compact form structures emerge

**Step 1: Write the failing test**

Add a narrow-width widget test and a save-flow regression test if needed.

**Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart --plain-name "night awakening page stays compact on narrow width"`

Expected: FAIL if the current panels or text fields overflow or remain visually too loose.

**Step 3: Write minimal implementation**

Refactor time selection, trigger selection, and note entry into one compact form rhythm aligned with the new retrofit spec.

**Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart --plain-name "night awakening page stays compact on narrow width"`

Expected: PASS

### Task 5: Final verification and commit

**Files:**
- Modify: touched implementation and test files

**Step 1: Run targeted regressions**

Run the focused widget tests added above plus existing sleep-flow regressions in `test/widget_test.dart`.

**Step 2: Run static analysis**

Run: `flutter analyze`

Expected: no new issues.

**Step 3: Commit**

Run:
`git add docs/plans/2026-04-26-app-compact-page-retrofit-design.md docs/plans/2026-04-26-sleep-pages-compact-retrofit-plan.md glacier/README.md glacier/visual-specs/README.md glacier/visual-specs/app-compact-page-retrofit-spec.md lib/... test/widget_test.dart`

Create a non-amended commit after verification passes.
