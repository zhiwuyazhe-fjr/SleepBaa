# Assistant API

## Owner

- Extended content teammate

## Facade

- `AssistantFacade.currentThread`
- `AssistantFacade.threads`
- `AssistantFacade.currentMessages`
- `AssistantFacade.sendPrompt(prompt)`

## Cloud data

- `assistant_threads/{threadId}`
- `assistant_threads/{threadId}/messages/{messageId}`

## Callable contract

- Function name: `assistantReply`
- Request:
  - `threadId`
  - `prompt`
  - `dorm.id`
  - `dorm.noiseDb`
  - `dorm.quietLabel`
  - `dorm.memberCount`
- Response:
  - `reply`

## Integration notes

- The app already uses a callable adapter with local fallback
- Pages should never talk to `FirebaseFunctions` directly
