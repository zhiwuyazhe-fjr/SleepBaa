# Assistant Memory Architecture

## Goal

The assistant memory system upgrades chat from stateless request/response into a durable, user-scoped context engine. The v1 design follows the same product idea highlighted in OpenClaw's memory docs: durable memory must be written to storage, not left in transient prompt context alone.

OpenClaw references:
- https://openclawlab.com/en/docs/concepts/memory/

## Design Principles

1. Source of truth is persisted storage.
   In OpenClaw, Markdown files are the source of truth. In this app, the equivalent source of truth is CloudBase collections plus thread/message history.

2. Separate short-term thread context from long-term user memory.
   Current-thread recency and rolling summaries solve immediate coherence.
   Long-term memory items solve durable recall across threads and devices.

3. Retrieval happens before generation.
   The assistant only "remembers" what is written into `assistant_thread_summaries` and `assistant_memory_items`, then injected back into the reply context.

4. Memory writes happen inline after successful assistant replies.
   V1 does not depend on background dreaming or consolidation jobs.

## Data Model

### `assistant_thread_summaries`

One document per thread.

Fields:
- `threadId`
- `summary`
- `keywords`
- `updatedAt`

Purpose:
- Compress long threads into a rolling synopsis.
- Give the model continuity when older raw messages are no longer injected.

### `assistant_memory_items`

User-scoped durable memory records.

Fields:
- `id`
- `userId`
- `kind`
- `content`
- `sourceThreadId`
- `salience`
- `lastUsedAt`
- `sourceRefs`
- `createdAt`
- `updatedAt`

Purpose:
- Store durable preferences, self-description, dorm context, sleep patterns, goals.
- Allow cross-thread recall.

### `account_migrations`

Tracks anonymous-to-phone recovery merges.

Purpose:
- Guarantee idempotent migration.
- Prevent duplicate data transfer during retries, device changes, or reconnects.

## Context Assembly Order

The backend builds assistant context in this order:

1. System rules and product behavior
2. User profile and settings
3. Dorm and sleep context
4. Recent raw messages from the active thread
5. Rolling thread summary
6. Retrieved long-term memory items

This keeps the freshest conversation close to the model while still letting stable memory influence replies.

## Write Path

After each successful assistant reply:

1. Persist the assistant run and user state updates.
2. Recompute a rolling thread summary.
3. Extract durable memory candidates from the latest user turn.
4. Upsert those memory items into the long-term store.

## Why This Mirrors OpenClaw

OpenClaw emphasizes three ideas that directly shaped this implementation:

1. Durable memory must be explicitly written.
2. Memory storage and memory retrieval are separate concerns.
3. Retrieval should survive compaction and session turnover.

This app adapts those ideas from file-backed Markdown memory into app-domain persistence backed by CloudBase.
