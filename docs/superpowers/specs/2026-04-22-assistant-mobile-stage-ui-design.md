# Assistant Mobile Stage UI Design

**Date:** 2026-04-22

## Goal

Implement the assistant mobile client as a quiet, dark, companion-first surface where the current page emphasizes one live reply instead of a full chat transcript.

## Scope

- Target `D:/sleep_dorm_app/lib/features/assistant/presentation/pages/assistant_page.dart`
- Keep the controller / facade / repository separation from the conversation refactor
- Keep the history route lightweight, but align it visually with the new dark assistant surface
- Do not redesign repository storage or backend contracts for tool receipts in this pass

## Approved UI Direction

### 1. Current conversation page is a stage, not a transcript

The main page should show:

- a small top hint for history access
- a compact header with identity and controls
- one centered conversation stage
- a bottom composer anchored for phone usage

The current page should no longer render the whole message list as stacked bubbles.

### 2. The stage keeps only the latest conversation focus

The stage prioritizes:

- the latest user message as a single full-width card
- the latest assistant reply as the main content block
- lightweight inline status lines below the reply

The assistant reply should not look like the old bordered bubble. The content should feel more open and fill the stage width.

### 3. History stays separate from the main mood

The main page should preserve the emotional atmosphere by hiding the long transcript.

History access is still available, but the current page should not visually collapse back into a list.

## Responsive Rules

- Layout must be phone-first
- Major width decisions should be container-driven and proportional, not fixed-width chat bubbles
- Avoid hardcoded positional layout values for the conversation stage
- Internal spacing should come from the app spacing tokens
- Keep controls within adaptive containers instead of absolute offsets

## Theme Rules

- Colors must be derived from the theme system and `NightMoodPalette`
- The dark assistant surface should be built from palette-derived dark blends, not raw one-off hex colors
- Reply accents, borders, glow, and send CTA should stay theme-reactive
- Tool/status text should stay subtle and gray-toned

## Message and Status Treatment

### User message

- Show as a full-width card in the stage
- Keep a background surface for the user message
- Match the assistant stage width

### Assistant reply

- Do not render as the old outlined bubble
- Use a wider content block with minimal chrome
- Increase perceived readability with larger body text and calmer spacing

### Tool/status rows

- Show as inline icon + text rows
- No full-width status boxes
- Use different icons for different status meanings
- In this pass, derive status from existing message / capture state instead of introducing a new persistence model

## Composer Behavior

- Keep the composer fixed at the bottom
- Show a busy placeholder when the thread is generating
- Preserve the existing send guard: no duplicate send while the thread is busy
- Starting a new conversation should reset the local composer state

## History Page

- Keep the current route structure
- Update the visuals to the same dark theme language
- Keep thread management actions intact

## Testing

- Existing broad regressions remain in `test/widget_test.dart`
- New page-specific UI regressions should be added to `test/glacier_test.dart`
- `glacier_test.dart` is the preferred file for future Glacier-managed focused UI checks to avoid growing the monolithic widget suite unnecessarily

## Non-Goals

- No gesture-driven waterfall history implementation in this pass
- No backend schema for persistent tool receipts yet
- No redesign of unrelated home / dorm / profile surfaces
