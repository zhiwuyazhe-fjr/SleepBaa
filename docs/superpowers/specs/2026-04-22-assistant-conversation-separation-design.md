# Assistant Conversation Separation Design

**Date:** 2026-04-22

## Goal

Separate the assistant conversation page into clearer UI, orchestration, and data boundaries so the upcoming V-series UI implementation can focus on animation and presentation instead of repository and stream plumbing.

## Scope

- Refactor only the current assistant conversation flow in `D:/sleep_dorm_app/lib/features/assistant/presentation/pages/assistant_page.dart`
- Keep existing repository and gateway contracts unless a small additive API is clearly justified
- Keep thread history management inside the existing assistant feature
- Do not redesign unrelated pages or backend behavior in this refactor

## Current Problems

### 1. `AssistantPage` owns orchestration that is not presentation logic

The page currently performs:

- thread bootstrap
- turn locking
- user message insertion
- assistant placeholder creation
- stream consumption
- assistant message updates
- capture record persistence
- error mapping

This is visible in `_handleSubmit`, `_sendReplyStream`, `_sendCaptureStream`, `_upsertAssistantReply`, and `_setAssistantError`.

### 2. The page reads multiple low-level services directly

`AssistantPage` directly coordinates:

- `assistantRepository`
- `assistantReplyGateway`
- `sleepCaptureRepository`
- `sleepSessionRepository`
- `dormRepository`

That makes UI iteration risky because layout changes are entangled with workflow logic.

### 3. The current boundary is inconsistent across assistant surfaces

`AssistantHistoryPage` mostly uses `assistantFacade`, but still directly calls `assistantRepository.setCurrentThread(...)`. The feature does not yet have a single conversation-facing boundary for page code.

## Design Decision

Introduce a dedicated conversation orchestration layer for the active assistant page and narrow page responsibilities to rendering and local UI interaction.

## Target Boundary

### UI layer

`AssistantPage` and `AssistantHistoryPage` should only do:

- collect user input
- trigger high-level actions
- subscribe to listenable state
- render messages, tool receipts, loading, and error states
- run local animation and scroll behavior

### Conversation orchestration layer

Add a dedicated controller for the current conversation page.

Recommended file:

- `D:/sleep_dorm_app/lib/features/assistant/presentation/controllers/assistant_conversation_controller.dart`

Responsibilities:

- select or ensure the active thread for the page
- expose the current thread turn state
- send a normal prompt
- send a capture prompt
- manage turn lifecycle
- consume stream events from `AssistantReplyGateway`
- upsert assistant/user messages through `AssistantRepository`
- persist capture records when needed
- normalize error handling
- expose lightweight derived state for the UI

### Feature facade layer

Keep `AssistantFacade` focused on feature-wide actions and shared state:

- current thread
- thread list
- assistant profile
- create, rename, delete, select thread
- update assistant profile name

Do not move page-local animation state into the facade.

### Data/backend layer

Keep these boundaries intact:

- `AssistantRepository`: thread/message persistence and turn state storage
- `SleepCaptureRepository`: capture persistence
- `AssistantReplyGateway`: normal reply and capture streaming

## Controller API

The controller should be a `ChangeNotifier` so it matches repo conventions and works with `ListenableBuilder`.

### Inputs

- `bootstrap()`
- `submitPrompt(String prompt)`
- `submitCapturePrompt({required String prompt, required SleepCaptureType captureType})`
- `retryLatestPrompt()`
- `setCurrentThread(String threadId)`

### Exposed state

- `AssistantThread? currentThread`
- `List<AssistantMessage> currentMessages`
- `AssistantThreadTurnState? turnState`
- `bool isBusy`
- `bool isCaptureModeAllowed`
- `String? latestUserPrompt`
- `String? latestErrorCode`

### Optional additive UI model

For the next UI pass, tool receipts should not be inferred from raw message text. The controller may expose a lightweight derived list such as:

- `List<AssistantToolReceipt> currentToolReceipts`

This refactor does not need to fully redesign the data model for receipts yet, but the controller should become the single place where that mapping is introduced later.

## File Responsibilities

### Modify

- `D:/sleep_dorm_app/lib/features/assistant/presentation/pages/assistant_page.dart`
  - remove direct reply/capture orchestration
  - bind page to the new controller
- `D:/sleep_dorm_app/lib/features/assistant/presentation/pages/assistant_history_page.dart`
  - stop directly calling repository methods from the page
- `D:/sleep_dorm_app/lib/core/facades/app_facades.dart`
  - if needed, add a small thread-selection helper so pages stay off repositories
- `D:/sleep_dorm_app/lib/core/app_scope.dart`
  - construct and expose the new conversation controller

### Create

- `D:/sleep_dorm_app/lib/features/assistant/presentation/controllers/assistant_conversation_controller.dart`
  - own active-page conversation workflow

### Test

- `D:/sleep_dorm_app/test/widget_test.dart`
  - add focused tests around assistant-page behavior if there is already assistant coverage here
- `D:/sleep_dorm_app/test/features/assistant/assistant_conversation_controller_test.dart`
  - preferred new focused controller test file if test layout supports it

## Data Flow After Refactor

1. `AssistantPage` collects a prompt and calls controller submit.
2. The controller ensures/selects the thread.
3. The controller starts the turn in `AssistantRepository`.
4. The controller inserts the user message and placeholder assistant message.
5. The controller consumes `AssistantReplyGateway` events.
6. The controller updates repository-backed messages and turn state.
7. The page rebuilds from controller state and handles visuals only.

## Error Handling

The controller remains the single place for:

- thread-busy toasts or returned busy state
- timeout mapping
- assistant fallback/error content selection
- capture fallback persistence

The page should not map backend exceptions into user-facing copy.

## Testing Strategy

### Controller tests

Add tests for:

- submit prompt writes user message and placeholder assistant message
- stream delta updates existing assistant message
- completion marks final assistant message complete
- error maps to assistant error message
- busy turn rejects duplicate submit
- capture submit persists a record when remote does not

### Widget tests

Add at least one widget-level regression that proves:

- `AssistantPage` no longer needs to coordinate repositories directly to render assistant state

## Non-Goals

- No backend API redesign
- No assistant history visual redesign in this refactor
- No persistence schema redesign for future tool-receipt UI
- No broad migration of all facades/controllers in the app

## Recommended Implementation Order

1. Add controller tests that describe current desired workflow behavior.
2. Implement `AssistantConversationController`.
3. Rewire `AppScope`.
4. Trim `AssistantPage`.
5. Trim `AssistantHistoryPage`.
6. Run focused analyze and tests.
