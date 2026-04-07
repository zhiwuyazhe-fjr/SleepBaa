# Assistant Context Engine

## Objective

The context engine decides what the AI sees before generating a reply. Its job is to keep prompts small, relevant, and durable across chat sessions.

## Inputs

The engine reads from:

- `users`
- `user_settings`
- `user_state`
- `sleep_sessions`
- `dream_entries`
- `dorms`
- `dorm_members`
- `assistant_messages`
- `assistant_thread_summaries`
- `assistant_memory_items`

## Composition Strategy

### 1. Stable profile context

Includes:
- display name
- tagline
- role
- linked phone state
- avatar metadata when available
- reminder and sleep preference settings

### 2. Situational dorm and sleep context

Includes:
- current dorm
- dorm members
- recent sleep sessions
- recent dream entries

This lets the assistant answer questions like "why am I restless tonight" using actual recent app state.

### 3. Active thread recency

Recent thread messages remain highest priority. V1 keeps a bounded window of raw messages to preserve local continuity without blowing up prompt size.

### 4. Rolling thread summary

When older conversation falls out of the raw window, the summary keeps the thread coherent. It acts like a compaction-safe synopsis of the thread's state.

### 5. Long-term memory retrieval

Relevant durable facts are appended last so they can influence replies without overwhelming the prompt.

Typical kinds:
- `preference`
- `profile`
- `goal`
- `dorm_context`
- `sleep_pattern`

## Retrieval Policy

V1 retrieval is simple and deterministic:

1. Load the most recent long-term memory items for the user.
2. Prefer higher-salience and more recently used items.
3. Keep the injection bounded.

This intentionally stops short of a full embedding pipeline. The document design leaves room for a future vector/BM25 hybrid retriever similar to the vector search concepts described by OpenClaw.

OpenClaw reference:
- https://openclawlab.com/en/docs/concepts/memory/

## Failure Behavior

If long-term memory or summary retrieval fails:

- the assistant still replies using recent messages and app state
- the reply pipeline must not hard-fail because of memory lookup

## Future Extensions

Planned-compatible directions:

- semantic retrieval over `assistant_memory_items`
- compaction-triggered memory flush
- background consolidation jobs
- per-memory confidence and decay rules
