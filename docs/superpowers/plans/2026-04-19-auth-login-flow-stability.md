# Auth Login Flow Stability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stabilize the phone auth route during CloudBase auth refreshes and restore the reset-password flow to a separate password-only page after successful SMS verification.

**Architecture:** Keep the existing router and auth repository contracts intact. Fix the refresh bug at the app shell by preventing post-bootstrap auth loading from replacing the routed subtree, then restore the phone auth page's internal reset-password stepper so verified users move to a dedicated password page.

**Tech Stack:** Flutter, GoRouter, widget tests, AppScope services, CloudBase auth repository

---

### Task 1: Lock the expected auth behavior with widget tests

**Files:**
- Modify: `test/widget_test.dart`
- Verify: `flutter test test/widget_test.dart --plain-name "cloudbase auth gate keeps phone auth input stable during re-authentication"`
- Verify: `flutter test test/widget_test.dart --plain-name "phone auth reset verification opens a password-only page"`
- Verify: `flutter test test/widget_test.dart --plain-name "phone auth back leaves reset password page before returning to login"`

- [ ] **Step 1: Write the failing test for auth gate stability**

Add a widget test that:
- boots the app with a CloudBase environment
- waits for the phone auth page
- enters a phone number
- triggers `authRepository.ensureAuthenticated()` without awaiting completion first
- verifies the login input remains mounted and retains its text after the auth cycle settles

- [ ] **Step 2: Run the auth gate test to verify it fails**

Run: `flutter test test/widget_test.dart --plain-name "cloudbase auth gate keeps phone auth input stable during re-authentication"`

Expected: FAIL because the current auth gate swaps the routed subtree with `_AuthLoadingPage`, dropping local input state.

- [ ] **Step 3: Write the failing tests for the reset-password stepper**

Adjust the reset-password widget tests so they require:
- successful verification to open a separate `resetPassword` internal page
- the password page to hide phone/code/send-code widgets
- back navigation to leave the password page before returning to login

- [ ] **Step 4: Run the reset-password tests to verify they fail**

Run: `flutter test test/widget_test.dart --plain-name "phone auth reset verification opens a password-only page"`

Run: `flutter test test/widget_test.dart --plain-name "phone auth back leaves reset password page before returning to login"`

Expected: FAIL because the current implementation still keeps verification UI in the same merged page.

### Task 2: Fix auth gate subtree replacement

**Files:**
- Modify: `lib/app/app.dart`
- Verify: `flutter test test/widget_test.dart --plain-name "cloudbase auth gate keeps phone auth input stable during re-authentication"`

- [ ] **Step 1: Update `_CloudBaseAuthGate` to only block on initial bootstrap**

Change the gate so it returns `_AuthLoadingPage` only while `hasCompletedInitialAuthBootstrap` is false. After bootstrap completion, always return the routed child and let router redirects handle auth route selection.

- [ ] **Step 2: Re-run the auth gate test**

Run: `flutter test test/widget_test.dart --plain-name "cloudbase auth gate keeps phone auth input stable during re-authentication"`

Expected: PASS

### Task 3: Restore a separate reset-password page inside `PhoneAuthPage`

**Files:**
- Modify: `lib/features/auth/presentation/pages/phone_auth_page.dart`
- Verify: `flutter test test/widget_test.dart --plain-name "phone auth reset verification opens a password-only page"`
- Verify: `flutter test test/widget_test.dart --plain-name "phone auth back leaves reset password page before returning to login"`

- [ ] **Step 1: Restore the `resetPassword` auth view and page builder**

Reintroduce the `_AuthView.resetPassword` branch and dedicated `_buildResetPasswordPage()` method so the verified reset flow lives on its own internal page again.

- [ ] **Step 2: Move verification success into the password page**

Keep `_verifyResetCode()` calling `verifyPhoneCode()`, store `PhoneVerificationProof`, and then switch to `resetPassword`.

- [ ] **Step 3: Clear verification proof when leaving the password page**

When returning from `resetPassword`, clear the saved proof and password draft, then navigate back to `forgotPassword`.

- [ ] **Step 4: Re-run the reset-password tests**

Run: `flutter test test/widget_test.dart --plain-name "phone auth reset verification opens a password-only page"`

Run: `flutter test test/widget_test.dart --plain-name "phone auth back leaves reset password page before returning to login"`

Expected: PASS

### Task 4: Full verification for the login page changes

**Files:**
- Verify: `flutter analyze`
- Verify: `flutter test test/widget_test.dart --plain-name "cloudbase auth gate"`
- Verify: `flutter test test/widget_test.dart --plain-name "phone auth"`

- [ ] **Step 1: Run static analysis**

Run: `flutter analyze`

Expected: exit code 0

- [ ] **Step 2: Run login-page-related widget tests**

Run: `flutter test test/widget_test.dart --plain-name "cloudbase auth gate"`

Run: `flutter test test/widget_test.dart --plain-name "phone auth"`

Expected: all targeted auth-related widget tests pass.
