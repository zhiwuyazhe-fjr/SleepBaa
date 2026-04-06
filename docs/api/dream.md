# Dream API

## Owner

- Extended content teammate

## Facade

- `DreamFacade.entries`
- `DreamFacade.latestEntry`
- `DreamFacade.saveDraft({userId, title, body, tags, emotionLabel, sessionId})`
- `DreamFacade.deleteEntry(entryId)`

## Cloud data

- `dream_entries/{entryId}`

## Local-only state

- Draft text before save

## Integration notes

- Dream detail pages should receive a `DreamEntry` via router `extra` when available
- Dream entries are user-owned documents, not dorm-owned documents
