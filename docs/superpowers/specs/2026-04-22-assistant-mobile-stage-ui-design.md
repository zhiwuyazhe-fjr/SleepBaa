# Assistant Mobile Stage UI Design

**Date:** 2026-04-22

## Source of Truth

The assistant mobile UI must follow `D:/sleep_dorm_app/glacier/pen_file/pencil-ai-2.pen` exactly.

The active target frames are:

- `wXHXp` = `V5 Tool Status`
- `64cTM` = `V6 Empty Dark`
- `jwRyJ` = `V7 User Waiting`
- `vr8iN` = `V9 Pull Hint`
- `Irs6q` = `V10 History Expanded`

No extra avatar block, back button, edit button, title subtitle stack, or custom chrome may be introduced unless it exists in the Pencil file.

## Screen Contract

### Main page

The assistant main page is a stage, not a transcript.

It contains only:

- top header: left `add`, centered `小眠`, right `history`
- center stage: one visual state at a time
- bottom composer: translucent rounded container

The main page states are:

1. `V6 Empty Dark`
2. `V7 User Waiting`
3. `V9 Pull Hint`

### History page

The history page follows `V10 History Expanded`.

It uses the same shell and composer as the main page, but the center body becomes a vertical archive flow.

## Message Rules

### Main page

- Default page: show only the empty copy from `V6`
- Waiting page: show only the latest user line from `V7`
- Reply page: show only the latest assistant reply from `V9`
- The reply block has no border and no bubble card
- Tool calls are plain inline icon rows under the current assistant reply

### History page

- Older assistant messages are plain text
- Older user messages are full-width rounded cards
- Current assistant reply is the large 20pt text block at the bottom
- Tool calls in history are bullet text, not boxed rows

## Visual Rules

- Phone-first responsive layout only
- Use container-based layout, not absolute positioning
- Use theme-derived colors from the existing Dart theme/color system
- Keep the dark black background and bottom green glow from Pencil
- Visible message/composer surfaces use `20` corner radius
- Assistant message text on the stage uses the Pencil sizing:
  - empty title: 34
  - waiting user text: 14
  - current assistant reply: 20
  - history assistant text: 13
  - user card text: 14
  - tool status text: 11

## Behavior Rules

- Default route still opens the empty dark page
- The seeded assistant welcome message must not break the empty default stage
- After the first user message is sent, the main page shows only the latest live stage
- History is a separate route reached from the top-right history icon
- Starting a new conversation from `add` resets the visible stage
- Busy state keeps the duplicate-send guard

## Motion and Haptics

- Motion must stay subtle and must not change the Pencil layout
- The empty headline and the current assistant reply may use a gentle vertical floating motion
- The floating motion is low-amplitude and slow-cycle only; no bounce, zoom, shimmer, or parallax layers
- Haptics are single-shot feedback, not continuous vibration
- When a new assistant reply first appears, trigger one light haptic
- If that reply also renders tool status rows, a second lighter confirmation tap may follow shortly after
- Do not vibrate continuously during the floating motion

## Existing Function Handling

If existing assistant capabilities are not shown in Pencil, keep the underlying logic if needed but do not surface extra UI.

Current examples:

- thread creation still exists, but thread management UI is not rendered
- capture-mode plumbing still exists, but the surface remains the same Pencil shell
- tool receipts are rendered from existing event data instead of adding new backend schema

## Test Policy

- Focused assistant UI checks live in `D:/sleep_dorm_app/test/glacier_test.dart`
- Broad app regression coverage remains in `D:/sleep_dorm_app/test/widget_test.dart`
- Any future assistant visual change must be checked against the Pencil frames above before widening scope
