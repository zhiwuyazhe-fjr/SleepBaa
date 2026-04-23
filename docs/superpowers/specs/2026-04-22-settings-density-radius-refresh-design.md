# Settings Density And Radius Refresh Design

**Date:** 2026-04-22

## Goal

Reduce the visual bloat in the current settings and account surfaces, reuse the existing shared component system more consistently, and align buttons, cards, and passive notifications to one tighter radius and density language.

## Scope

- Refine the current profile/settings/account flow only
- Prioritize the shared component layer plus the touched settings/account/profile pages
- Keep the new account information architecture already agreed in place
- Do not start a full app-wide typography or radius migration in this pass

## Confirmed Information Architecture

### Settings hub

- Keep the settings page as the hub
- Keep `AppMenuGroupCard` in use
- Remove the standalone `账号设置` section title
- Keep the entry card that routes into `账号管理`
- Remove the top profile summary card from the settings landing page entirely

### Account management

Add a dedicated `账号管理` page that contains:

- `个人资料`
- `重置密码`
- `登录管理`
- `寝室管理`

### Profile editing

- `编辑资料` remains a separate page
- `重置密码` must not reuse the old auth shell or inherit a back stack that returns to the login flow unexpectedly
- The top profile card in `账号管理` should also be removed so the page starts directly with grouped account actions

## Core Design Decisions

### 1. Remove overly decorative section framing

- Delete the `资料摘要` block from the settings landing page
- Remove the standalone `账号设置` heading entirely
- Avoid standalone section headings like `切换心情` when the explanation can live inside the card itself
- Similar explanatory copy should be folded into card content, like the existing `目标睡眠时长` treatment

### 2. Tighten density across the whole surface

Use a more compact layout standard for this round:

- Main page/card padding should usually land around `12`
- Section gaps should usually stay in the `8 / 12 / 16` range
- Avoid oversized vertical spacers between related controls
- `睡眠偏好` should be visibly denser than the current implementation
- Apply the same compact-density rule to every touched settings child page, not just the settings landing page
- Nickname / phone / tagline spacing in profile-related pages should be reduced as much as readability allows

### 3. Remove thin separators between child items

- Do not use thin divider lines between settings/account child rows in the touched pages
- Prefer grouped list rhythm and compact padding instead of standalone mini-cards
- Separate items with spacing, grouped rows, or row rhythm instead of hairlines

### 4. Split corner-radius rules by component role

For this pass, do not force one radius onto every component.

Apply this to:

- normal cards and grouped setting containers: `20`
- shared primary / secondary buttons: `16`
- passive toast / passive notification shape: `16`

Do not force this onto shapes that are intentionally non-rectangular:

- toggles
- chip-like options when their current silhouette still works
- avatars
- fully circular affordances

### 5. Reuse existing shared buttons instead of default-looking controls

- Buttons in these settings/account surfaces should use the reusable button component rather than ad-hoc default button styling
- Current button sizing is too large and should be reduced to match the more compact placeholder-page scale
- The default shared button should move away from the oversized pill treatment
- Preferred shape is rounded rectangle with radius `16`, not a large stadium pill
- Tappable shared buttons and grouped menu rows should provide light haptic feedback
- Use the reset-password page bottom CTA as the dimensional reference for the shared primary button
- Promote the settings-page bottom action into the reusable secondary button style
- Replace placeholder-page bottom CTA styling with that shared secondary button style

Recommended button density targets:

- main CTA height around `56`
- secondary / inline action height around `44`

### 6. Filled primary color source

Filled primary actions in this refactor should use the emphasis-card semantics:

- background: `welcomeAccentColor`
- foreground: `welcomeTextOnAccent`

## Typography Decision For This Round

- The app already has a shared text token layer
- There is not yet a fully locked brand font-family system in practice
- Font-family standardization is out of scope for this round unless a concrete issue appears during testing

## Shared Component Changes Expected

### `PrimaryButton`

- Default to a compact rounded-rectangle button
- Replace the oversized vertical padding and pill radius
- Preserve filled / soft / ghost variants
- Make the component suitable for both page CTA and smaller inline actions
- Add shared haptic feedback on press
- Shared primary radius should be `16`
- Shared secondary style should come from the compact settings-page action treatment

### Placeholder page CTA

- Replace the local CTA styling with the shared secondary button component
- Use the same horizontal page inset rule as profile / home / dorm

### Passive toast

- Passive toast should use the same rounded-corner language
- Move to shared `16` radius and align left/right inset with the app page-padding token

### Shared settings-item component

- Sleep preferences and account-management entry lists should converge on one reusable compact row component
- Icon-bearing rows should vertically center the icon within the whole row
- Icon size should visually align with the profile-bottom list treatment
- Row subtitles / explanation sentences should be removed for `切换心情`, `睡眠偏好`, `账号管理`, and account-management child items

### Shared page inset token

- The touched settings/account/profile/notification/placeholder pages should share the same horizontal screen inset token as the profile page
- Avoid hard-coded per-page left/right values for these surfaces
- Notification center and placeholder pages should be pulled back onto that same inset rule

## Page-Specific Expectations

### Settings page

- Remove the top user information card completely
- Remove `资料摘要`
- Remove the standalone `账号设置` title
- Keep the account-management entry but let the card carry the meaning
- Remove the left icon from the `账号管理` entry on the settings hub
- Use the profile-bottom list title scale for `切换心情` and `睡眠偏好`
- Remove explanatory subtitle copy from those grouped settings blocks
- Compress the `切换心情` block further so its left/right breathing room is visibly smaller than the previous pass
- Shrink the selected mood ring and reduce the visual weight of its outline
- Rebuild `睡眠偏好` as a grouped settings list in the same style direction as the profile page `设置 / 常见问题` group, not as stacked inner cards
- Make switch controls visually flatter / shorter
- Reduce the weight of sleep-preference child labels so they read lighter than section headings
- Reduce horizontal padding around text, controls, and buttons so the page feels compact instead of airy

### Account pages

- Keep the new account-management hierarchy
- Keep `AppMenuGroupCard` in the overall solution, but converge account-management entry rows onto the same reusable compact settings-row component used by `睡眠偏好`
- Remove the top profile card from `账号管理`
- Remove thin dividers from profile/login/member detail layouts in the touched pages
- Tighten nickname / phone / summary spacing in `个人资料`
- Keep the overall visual rhythm lighter and more compact than the first implementation pass
- Remove explanation subtitles from account-management child rows

### Reset password page

- Match the visual system and density of the login / auth flow instead of using generic settings-form cards
- Reuse the auth-page spacing language, input rhythm, and action styling as closely as practical
- Preserve account-settings navigation behavior:
  - back from the first reset step returns to the previous account page
  - back from deeper reset steps returns to the prior reset step instead of leaving the flow immediately
- When the keyboard is visible, back should dismiss the keyboard first instead of leaving the reset flow immediately

## Testing Notes

Update `test/glacier_test.dart` to cover the approved direction where practical, including:

- no standalone `账号设置` section title on the settings hub
- no `资料摘要` block on the settings hub
- no settings landing-page top profile summary card
- account management still exposes the four agreed entry points
- shared button styling still resolves filled colors from `welcomeAccentColor` and `welcomeTextOnAccent`

## Packaging Note

For local packaging during this line of work, continue using the local bat-equivalent Flutter build flow:

```bash
flutter build apk --dart-define-from-file=D:\sleep_dorm_app\.cloudbase.local.json --no-tree-shake-icons
```

## 2026-04-23 Follow-Up Refinements

### Settings page

- Rename `切换心情` to `切换心情主题`
- Remove the decorative glow treatment around the mood choices on the settings page
- Shrink the selected mood ring and reduce the top / bottom empty space around each mood circle
- Keep the settings landing page compact and preserve the shared bottom `退出登录` action
- In `睡眠偏好`, keep the bed icon visually centered by reserving a stable leading slot and letting the slider begin slightly to the right
- Do not override typography, padding, leading width, or row height for the non-slider sleep-preference rows
- `睡前提醒时间 / 睡前提醒 / 晨间反馈提醒 / 宿舍动态提醒 / 智能建议` must stay on the shared `AppSettingsItem` baseline used by account-management child entries

### Account management child pages

- In `个人资料`, keep the summary card only for avatar / name / phone / edit action
- Move `个性签名 / 角色 / 寝室` into a separate grouped settings-style card
- In `登录管理`, keep the status summary card only for the high-level account state
- Move `登录方式 / 手机验证 / 最近绑定` into a separate grouped settings-style card
- Reuse the shared account sign-out action button instead of a page-local logout implementation

### Dorm management

- Remove the `查看宿舍空间` shortcut from `寝室管理`
- Move `编辑宿舍名称` into the same grouped entry section as `邀请舍友` and `查看宿舍规则`
- Keep the overall compact density of the `寝室管理` page because that layout direction was explicitly approved
- Leave the location-status card focused on status plus the `重新记录位置` action

### Invite roommate page

- Compress page padding and card spacing to match the compact settings/account density standard
- Tighten text-field and content spacing so the page no longer feels oversized
- Rework `刷新邀请码 / 复制邀请码` into compact shared-button actions with a cleaner horizontal wrap layout
- Apply the same compact shared-button sizing to `创建宿舍 / 加入宿舍 / 返回选择`
