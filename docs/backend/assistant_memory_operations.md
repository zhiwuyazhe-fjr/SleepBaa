# Assistant Memory Operations

## Runtime Flow

### On user message

1. Ensure the thread exists.
2. Persist the user message.
3. Build full assistant context.
4. Generate the reply.
5. Persist the assistant message.
6. Update thread summary.
7. Extract and upsert long-term memory items.

## Summary Update Rules

Thread summaries should:

- preserve the latest topic
- mention recent user intent
- mention the assistant's current working direction
- remain compact enough for prompt injection

V1 uses a deterministic rolling summary assembled from recent messages plus the latest exchange.

## Long-Term Memory Extraction Rules

We only persist durable signals, not every chat turn.

Examples that should be written:

- "我通常一点以后才睡"
- "我不喜欢太刺激的建议"
- "我在宿舍里最怕室友深夜打游戏"
- "我希望这周把作息拉回到 12 点前"

Examples that should not be written:

- one-off small talk
- transient acknowledgements
- generic assistant phrasing

## Upsert Policy

Memory items are upserted by stable semantic slot rather than appended blindly. This prevents repeated mentions of the same preference from creating endless duplicates.

Current slots:

- `preference`
- `profile`
- `goal`
- `dorm_context`
- `sleep_pattern`

## Recall Policy

When building a reply:

1. load the active thread summary
2. load recent durable memory items
3. inject only the bounded, highest-value subset

## Operational Guardrails

- Memory writes must be idempotent.
- Reply generation must not block forever on memory persistence.
- If memory write fails, the assistant reply still succeeds and the failure is logged for later repair.

## V1 Boundaries

This release intentionally excludes:

- background dreaming
- autonomous consolidation workers
- file-backed Markdown memory
- embedding-based recall

Those are future-compatible extensions, not prerequisites for shipping persistent assistant memory now.
