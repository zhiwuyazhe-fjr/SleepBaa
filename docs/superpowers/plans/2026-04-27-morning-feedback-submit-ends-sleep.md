# Morning Feedback Submit-Ends-Sleep Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the post-sleep "晨间反馈" card open a live feedback form without ending sleep mode, and only end the session when the user submits feedback or explicitly chooses "结束睡眠模式".

**Architecture:** Keep the existing route and session model. Split behavior by session state: `active` sessions use a live feedback mode in `MorningFeedbackPage`, while `awaitingFeedback` sessions keep the existing historical backfill behavior. Move the "finish then submit" branch into `SleepExperienceController` so the page does not orchestrate repository-level session closing on its own.

**Tech Stack:** Flutter, GoRouter, ChangeNotifier repositories/controllers, flutter_test widget tests

---

### Task 1: Lock the new behavior with failing tests

**Files:**
- Modify: `D:/sleep_dorm_app/test/widget_test.dart`
- Modify: `D:/sleep_dorm_app/test/features/feedback/presentation/pages/morning_feedback_page_test.dart`
- Modify: `D:/sleep_dorm_app/test/core/state/sleep_experience_controller_test.dart`

- [ ] **Step 1: Rewrite the post-sleep card widget test to expect a live session instead of an already-finished session**

Add assertions that the route still opens `MorningFeedbackPage`, but `allowReturnToSleep == false`, the live session stays `active`, and `sleepModeActive == true`.

- [ ] **Step 2: Add widget tests for live-mode return behavior**

Cover both the explicit in-page "返回" button path and system back path:
- opening from `HomePostSleepPage`
- showing discard confirmation text instead of "返回睡眠模式？"
- returning directly to `HomePostSleepPage`
- never showing the return-to-sleep loading UI

- [ ] **Step 3: Add a controller test for submitting feedback from an active session**

Write a failing test proving that calling the controller submit API with an `active` session:
- closes that session
- marks it `completed`
- clears `sleepModeActive`
- cancels the foreground sleep notification

- [ ] **Step 4: Run the focused test targets and verify RED**

Run:
`flutter test test/widget_test.dart --plain-name "post-sleep morning feedback card"`
`flutter test test/widget_test.dart --plain-name "morning feedback return"`
`flutter test test/core/state/sleep_experience_controller_test.dart --plain-name "active session"`
`flutter test test/features/feedback/presentation/pages/morning_feedback_page_test.dart`

Expected: failures that show the current implementation still ends sleep too early and still uses the resume path.

### Task 2: Implement live feedback mode and submit-time session ending

**Files:**
- Modify: `D:/sleep_dorm_app/lib/features/home/presentation/pages/home_post_sleep_page.dart`
- Modify: `D:/sleep_dorm_app/lib/features/feedback/presentation/pages/morning_feedback_page.dart`
- Modify: `D:/sleep_dorm_app/lib/core/state/sleep_experience_controller.dart`

- [ ] **Step 1: Change the post-sleep card entry to push the feedback route directly**

Keep the explicit "结束睡眠模式" dialog flow unchanged. Only the support card should stop calling `finishSleepMode()` up front.

- [ ] **Step 2: Teach `MorningFeedbackPage` to distinguish live vs historical feedback sessions**

Add a small internal mode split:
- live mode when the explicit `sessionId` resolves to an `active` session with `sleepModeActive == true`
- historical mode when the session is `awaitingFeedback`

Preserve the existing generic route behavior for routes without `sessionId`.

- [ ] **Step 3: Replace live-mode return handling**

For live mode:
- show a discard confirmation
- pop/go back to `HomePostSleepPage`
- do not call `resumeSleepModeFromFeedbackReturn()`

Keep the old resume flow only for legacy `resumeToSleep=1` compatibility.

- [ ] **Step 4: Update the submit button behavior**

Use live-mode label `提交反馈并结束本次睡眠`, historical label `提交反馈`, and compute the summary with a fresh clock read at tap time.

- [ ] **Step 5: Extend `SleepExperienceController.submitMorningFeedback` to close active sessions first**

If the input session is live:
- cancel the sleep notification
- finish the active session in the repository
- submit feedback against the closed session
- skip the pending-feedback reminder side effects used by `finishSleepMode()`

Historical sessions should keep the current path unchanged.

- [ ] **Step 6: Run the same focused tests and verify GREEN**

Run the same commands from Task 1.
Expected: the rewritten tests now pass.

### Task 3: Regression cleanup and broader verification

**Files:**
- Modify: `D:/sleep_dorm_app/test/widget_test.dart`
- Modify: `D:/sleep_dorm_app/test/features/feedback/presentation/pages/morning_feedback_page_test.dart`
- Modify: `D:/sleep_dorm_app/test/core/state/sleep_experience_controller_test.dart`

- [ ] **Step 1: Update any now-stale expectations that assume the card entry uses `resumeToSleep`**

Keep historical backfill expectations intact, but remove live-entry assumptions that the session is already `awaitingFeedback`.

- [ ] **Step 2: Run the full targeted regression set**

Run:
`flutter test test/features/feedback/presentation/pages/morning_feedback_page_test.dart`
`flutter test test/core/state/sleep_experience_controller_test.dart`
`flutter test test/widget_test.dart --plain-name "morning feedback"`
`flutter test test/widget_test.dart --plain-name "post-sleep"`

Expected: all targeted feedback/post-sleep tests pass.

- [ ] **Step 3: Run analyzer if the targeted tests are green**

Run:
`flutter analyze`

Expected: exit 0 with no new analyzer errors attributable to this change.
