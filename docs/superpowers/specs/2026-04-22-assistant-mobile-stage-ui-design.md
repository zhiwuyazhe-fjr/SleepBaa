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
- The pull hint stays hidden by default and appears only after the first downward pull gesture
- The composer stays single-line and compact on phone screens
- The right edge of the composer contains two actions: `mic` then `send`
- The input container must stay tighter than the current implementation: reduce icon spacing, edge padding, and overall height

### History page

- The current thread archive is opened from the stage by a two-step downward pull
- First pull only reveals the hint and arms archive expansion for `5s`
- Second downward pull inside that `5s` window expands the archive
- If the user waits longer than `5s`, the hint disappears and the two-step sequence resets
- After the archive is open, when the list is at the bottom, an upward pull collapses back to the centered stage
- Older assistant messages are plain text
- Older user messages are full-width rounded cards
- Current assistant reply is the large 20pt text block at the bottom
- Tool calls in history are bullet text, not boxed rows
- The top-right header history action is reserved for saved conversation threads, not for the inline archive
- The thread history page must not show a second `add` action in the top-right corner

## Visual Rules

- Phone-first responsive layout only
- Use container-based layout, not absolute positioning
- Use theme-derived colors from the existing Dart theme/color system
- Keep the dark black background and bottom green glow from Pencil
- Visible message/composer surfaces use `20` corner radius
- Keep the shell visually compact on tall phones; do not scale spacing upward past the Pencil baseline
- Reduce extra top padding above the `小眠` header row
- Increase the bottom glow brightness slightly and expand its spread using theme-derived accent colors only
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
- The inline archive is revealed only by the two-step downward pull interaction on the reply stage
- The top-right history icon opens saved conversation threads
- Starting a new conversation from `add` resets the visible stage
- Starting a new conversation from `add` must respond immediately without a multi-second visible pause
- Busy state keeps the duplicate-send guard
- All visible action buttons need immediate touch feedback
- The thread history route should not rely on Android predictive back preview

## Motion and Haptics

- Motion must stay subtle and must not change the Pencil layout
- The empty eyebrow, headline, and body copy float together as one slow group
- The current assistant reply may use a gentle vertical floating motion
- The reply floating motion must support three user-selectable levels in Settings: `low`, `medium`, `high`
- The default floating level is `medium`
- The Settings page is the only control surface for this motion level selector
- The floating motion is low-amplitude and slow-cycle only; no bounce, zoom, shimmer, or parallax layers
- Stage switching must feel sequential:
  - the outgoing text floats upward and fades out first
  - then the incoming text floats upward into place
  - the full transition should be slower and calmer than the current implementation
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
