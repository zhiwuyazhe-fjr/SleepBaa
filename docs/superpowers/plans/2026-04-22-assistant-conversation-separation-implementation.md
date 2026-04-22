# Assistant Conversation Separation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move assistant conversation orchestration out of `AssistantPage` into a dedicated controller while preserving current assistant behavior.

**Architecture:** Add a `ChangeNotifier` controller for active assistant conversation workflow, wire it through `AppScope`, and make assistant pages consume high-level state/actions instead of coordinating repositories and gateway streams directly. Keep repository and gateway contracts stable and use additive facade helpers only where that removes direct repository access from UI code.

**Tech Stack:** Flutter, Dart, `ChangeNotifier`, existing `AppScope` service injection, widget tests, focused unit tests

---

### Task 1: Replace stale docs and lock the implementation boundary

**Files:**
- Create: `D:/sleep_dorm_app/docs/superpowers/specs/2026-04-22-assistant-conversation-separation-design.md`
- Create: `D:/sleep_dorm_app/docs/superpowers/plans/2026-04-22-assistant-conversation-separation-implementation.md`

- [ ] **Step 1: Save the approved design spec for the current refactor scope**

Rule:

```text
The spec must describe code-layer separation for the assistant conversation page, not the earlier Pencil-only visual state flow.
```

- [ ] **Step 2: Save this implementation plan next to the spec**

Rule:

```text
The plan must stay scoped to assistant-page orchestration extraction and must not expand into unrelated UI redesign work.
```

### Task 2: Write the failing controller tests first

**Files:**
- Create: `D:/sleep_dorm_app/test/features/assistant/assistant_conversation_controller_test.dart`
- Read only: `D:/sleep_dorm_app/lib/core/data/in_memory_repositories.dart`
- Read only: `D:/sleep_dorm_app/lib/core/backend/assistant_reply_gateway.dart`
- Read only: `D:/sleep_dorm_app/lib/core/models/app_models.dart`

- [ ] **Step 1: Write a test for normal prompt submission**

```dart
test('submitPrompt adds user message and completes assistant reply', () async {
  final InMemoryAssistantRepository assistantRepository =
      InMemoryAssistantRepository(userId: 'user-1');
  final InMemorySleepCaptureRepository sleepCaptureRepository =
      InMemorySleepCaptureRepository();
  final InMemoryDormRepository dormRepository =
      InMemoryDormRepository(currentUserId: 'user-1');
  final AssistantConversationController controller =
      AssistantConversationController(
        assistantRepository: assistantRepository,
        sleepCaptureRepository: sleepCaptureRepository,
        sleepSessionRepository: InMemorySleepSessionRepository(
          initialUid: 'user-1',
        ),
        dormRepository: dormRepository,
        assistantReplyGateway: const StubAssistantReplyGateway(),
      );

  await controller.bootstrap();
  await controller.submitPrompt('I cannot sleep tonight');

  final List<AssistantMessage> messages = controller.currentMessages;
  expect(messages.last.role, AssistantMessageRole.assistant);
  expect(messages.last.status, AssistantMessageStatus.complete);
  expect(controller.turnState?.status, AssistantThreadTurnStatus.idle);
});
```

- [ ] **Step 2: Run the new controller test and verify red**

Run: `flutter test test/features/assistant/assistant_conversation_controller_test.dart`

Expected:

```text
FAIL because AssistantConversationController does not exist yet
```

- [ ] **Step 3: Add a second failing test for busy-turn rejection**

```dart
test('submitPrompt returns busy result when a turn is already streaming', () async {
  final InMemoryAssistantRepository assistantRepository =
      InMemoryAssistantRepository(userId: 'user-1');
  final AssistantThread thread = await assistantRepository.ensureThread(
    title: 'Tonight',
  );
  await assistantRepository.tryStartThreadTurn(
    threadId: thread.id,
    turnId: 'turn-1',
  );

  final AssistantConversationController controller =
      AssistantConversationController(
        assistantRepository: assistantRepository,
        sleepCaptureRepository: InMemorySleepCaptureRepository(),
        sleepSessionRepository: InMemorySleepSessionRepository(
          initialUid: 'user-1',
        ),
        dormRepository: InMemoryDormRepository(currentUserId: 'user-1'),
        assistantReplyGateway: const StubAssistantReplyGateway(),
      );

  await controller.bootstrap();
  final AssistantConversationSubmitResult result =
      await controller.submitPrompt('hello');

  expect(result, AssistantConversationSubmitResult.busy);
});
```

- [ ] **Step 4: Run the controller test file again and verify red for the expected reason**

Run: `flutter test test/features/assistant/assistant_conversation_controller_test.dart`

Expected:

```text
FAIL with missing controller/result types, not with unrelated setup errors
```

### Task 3: Implement the minimal conversation controller

**Files:**
- Create: `D:/sleep_dorm_app/lib/features/assistant/presentation/controllers/assistant_conversation_controller.dart`
- Modify: `D:/sleep_dorm_app/lib/core/facades/app_facades.dart`

- [ ] **Step 1: Add the controller and a minimal submit result enum**

```dart
enum AssistantConversationSubmitResult { sent, busy, missingActiveSession }

class AssistantConversationController extends ChangeNotifier {
  AssistantConversationController({
    required AssistantRepository assistantRepository,
    required SleepCaptureRepository sleepCaptureRepository,
    required SleepSessionRepository sleepSessionRepository,
    required DormRepository dormRepository,
    required AssistantReplyGateway assistantReplyGateway,
  }) : _assistantRepository = assistantRepository,
       _sleepCaptureRepository = sleepCaptureRepository,
       _sleepSessionRepository = sleepSessionRepository,
       _dormRepository = dormRepository,
       _assistantReplyGateway = assistantReplyGateway {
    _assistantRepository.addListener(_relayState);
  }

  final AssistantRepository _assistantRepository;
  final SleepCaptureRepository _sleepCaptureRepository;
  final SleepSessionRepository _sleepSessionRepository;
  final DormRepository _dormRepository;
  final AssistantReplyGateway _assistantReplyGateway;

  AssistantThread? get currentThread => _assistantRepository.currentThread;
  List<AssistantMessage> get currentMessages {
    final AssistantThread? thread = currentThread;
    if (thread == null) {
      return const <AssistantMessage>[];
    }
    return _assistantRepository.messagesForThread(thread.id);
  }
}
```

- [ ] **Step 2: Add `bootstrap()` and basic thread-selection helpers**

```dart
Future<void> bootstrap() async {
  await _assistantRepository.selectMostRecentThread();
}

Future<void> setCurrentThread(String threadId) async {
  await _assistantRepository.setCurrentThread(threadId);
}
```

- [ ] **Step 3: Move normal prompt orchestration from `AssistantPage` into the controller**

Implementation rule:

```text
Port the existing page behavior for ensure thread, tryStartThreadTurn, placeholder assistant message, stream consumption, finalization, and error mapping with minimal behavioral change.
```

- [ ] **Step 4: Add capture submission support**

Implementation rule:

```text
Port the existing capture workflow including active-session validation and local capture persistence fallback when the remote result did not persist a record.
```

- [ ] **Step 5: Add a small facade helper for thread selection if the page still needs a public feature boundary**

```dart
Future<void> setCurrentThread(String threadId) {
  return _assistantRepository.setCurrentThread(threadId);
}
```

- [ ] **Step 6: Run controller tests and verify green**

Run: `flutter test test/features/assistant/assistant_conversation_controller_test.dart`

Expected:

```text
PASS
```

### Task 4: Rewire `AppScope` and make assistant pages consume the new boundary

**Files:**
- Modify: `D:/sleep_dorm_app/lib/core/app_scope.dart`
- Modify: `D:/sleep_dorm_app/lib/features/assistant/presentation/pages/assistant_page.dart`
- Modify: `D:/sleep_dorm_app/lib/features/assistant/presentation/pages/assistant_history_page.dart`

- [ ] **Step 1: Add the controller to `AppScope` and `AppServices`**

```dart
late final AssistantConversationController _assistantConversationController;
```

```dart
_assistantConversationController = AssistantConversationController(
  assistantRepository: _assistantRepository,
  sleepCaptureRepository: _sleepCaptureRepository,
  sleepSessionRepository: _sleepSessionRepository,
  dormRepository: _dormRepository,
  assistantReplyGateway: _assistantReplyGateway,
);
```

```dart
required this.assistantConversationController,
final AssistantConversationController assistantConversationController;
```

- [ ] **Step 2: Remove direct repository/gateway orchestration from `AssistantPage`**

Implementation rule:

```text
Delete the page-local submit/orchestration helpers after their behavior is represented in the controller. The page may still keep local text, focus, scroll, and animation state.
```

- [ ] **Step 3: Bind `AssistantPage` rebuilds to both facade and controller state where needed**

Implementation rule:

```text
The page should read profile/thread-list data from AssistantFacade and current conversation state from AssistantConversationController.
```

- [ ] **Step 4: Remove the direct repository call from `AssistantHistoryPage`**

Implementation rule:

```text
Replace assistantRepository.setCurrentThread(...) with assistantFacade.setCurrentThread(...) or controller.setCurrentThread(...), whichever boundary is added in Task 3.
```

- [ ] **Step 5: Run widget or focused tests to verify green**

Run: `flutter test test/widget_test.dart --plain-name assistant`

Expected:

```text
PASS, or no matching tests if the suite has no assistant-named cases yet
```

### Task 5: Add a focused widget regression if assistant coverage is missing

**Files:**
- Modify: `D:/sleep_dorm_app/test/widget_test.dart`

- [ ] **Step 1: Add a widget test that pumps `AssistantPage` through `SleepDormApp` or the local helper**

```dart
testWidgets('assistant page renders seeded assistant reply from controller-backed state', (
  WidgetTester tester,
) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await tester.pumpWidget(_pumpApp(initialLocation: AppRoutes.assistant));
  await tester.pumpAndSettle();

  expect(find.text('今晚睡前聊聊'), findsOneWidget);
  expect(find.textContaining('呼吸练习'), findsOneWidget);
});
```

- [ ] **Step 2: Run the targeted widget test and verify red if the helper or expectation is wrong**

Run: `flutter test test/widget_test.dart --plain-name "assistant page renders seeded assistant reply"`

Expected:

```text
FAIL for a concrete expectation mismatch before implementation adjustments
```

- [ ] **Step 3: Adjust the minimal page wiring until the widget test passes**

Implementation rule:

```text
Do not add new UI behavior here. Only finish the wiring needed for the controller-backed page to render the seeded repository state.
```

- [ ] **Step 4: Re-run the targeted widget test and verify green**

Run: `flutter test test/widget_test.dart --plain-name "assistant page renders seeded assistant reply"`

Expected:

```text
PASS
```

### Task 6: Verify the refactor and report remaining risks

**Files:**
- Modify if needed: `D:/sleep_dorm_app/docs/superpowers/specs/2026-04-22-assistant-conversation-separation-design.md`

- [ ] **Step 1: Run focused static analysis**

Run: `flutter analyze lib/core/app_scope.dart lib/core/facades/app_facades.dart lib/features/assistant/presentation/pages/assistant_page.dart lib/features/assistant/presentation/pages/assistant_history_page.dart lib/features/assistant/presentation/controllers/assistant_conversation_controller.dart test/features/assistant/assistant_conversation_controller_test.dart test/widget_test.dart`

Expected:

```text
No issues found!
```

- [ ] **Step 2: Run the focused assistant tests**

Run: `flutter test test/features/assistant/assistant_conversation_controller_test.dart`

Expected:

```text
PASS
```

- [ ] **Step 3: Run the selected widget regression**

Run: `flutter test test/widget_test.dart --plain-name assistant`

Expected:

```text
PASS, or explicitly note if no assistant-specific cases exist yet
```

- [ ] **Step 4: Record residual risks**

Check:

```text
- the page still holds animation/scroll timing logic by design
- future tool-receipt UI still needs an explicit derived model
- the controller remains feature-specific and is not a generic app-wide pattern
```
