# 助手接口

## 前端入口

- `AssistantFacade.sendPrompt(prompt)`
- `AssistantFacade.currentThread`
- `AssistantFacade.currentMessages`
- `AssistantFacade.updateAssistantProfileName(name)`

## Flutter 调用链

- 页面 -> `AssistantFacade`
- facade -> `AssistantRepository`
- facade -> `AssistantReplyGateway`
- gateway -> `POST /api/assistant/reply`

## `POST /api/assistant/reply`

请求体：

```json
{
  "threadId": "thread-user-123",
  "prompt": "今晚宿舍有点吵怎么办？",
  "clientUserMessageId": "assistant-msg-user-1",
  "clientAssistantMessageId": "assistant-msg-assistant-1"
}
```

说明：

- `clientUserMessageId` 由前端先生成，并作为乐观消息 ID。
- `clientAssistantMessageId` 由前端先生成，并作为 pending assistant message ID。
- 后端会直接复用这两个 ID 落库，避免本地 pending 消息和快照正式消息重复。

响应体：

```json
{
  "reply": "先把噪声压下来，再收束今晚节奏。",
  "runId": "run-123",
  "intent": "noise_issue",
  "provider": "xai_responses",
  "model": "grok-4-1-fast-reasoning",
  "sourceMode": "remoteSuccess",
  "errorMessage": null,
  "assistantMessageId": "assistant-msg-assistant-1",
  "recommendedActions": [],
  "updatedSurfaces": ["assistant_context", "home_pre_sleep"]
}
```

字段说明：

- `sourceMode`
  - `remoteSuccess`：远端模型成功返回。
  - `fallbackSuccess`：远端失败，已回退到 deterministic fallback。
  - `error`：这是 CloudBase Flutter gateway 的本地映射，表示本次没有拿到有效服务端结果。
- `errorMessage`
  - 远端失败时保留真实错误，前端可用于展示“回退回复”或错误提示。
- `assistantMessageId`
  - 当前 assistant 回复实际落库的消息 ID，正常情况下等于请求里的 `clientAssistantMessageId`。

## 相关集合

- `assistant_profiles`
- `assistant_threads`
- `assistant_messages`
- `assistant_thread_summaries`
- `assistant_memory_items`
- `assistant_runs`
- `user_state`
- `card_snapshots`

## 后端职责

- 保证线程存在。
- 先写 user message。
- 构建完整 assistant context。
- 调用统一 provider 接口。
- 根据回复结果决定是否刷新今晚计划。
- 写入 `assistant_runs`，兼容保留 `status`，同时把 `sourceMode` 作为主语义持久化。
- 写入 assistant message，并把 `sourceMode / provider / model / errorMessage` 一起持久化。
- 更新 `assistant_context`，必要时同步刷新 `home_pre_sleep`。

## CloudBase 前端约定

- CloudBase 正式链路不再做客户端 stub fallback。
- 如果 `/api/assistant/reply` 请求失败，页面会显示 `error`，由用户手动重试。
- 只有后端 deterministic fallback 才会返回 `fallbackSuccess`。

## 其它接口

### `POST /api/assistant/profile`

用于修改 AI 助手昵称与人设配置补丁。

### `POST /api/assistant/threads`

创建新线程。

### `POST /api/assistant/threads/:id`

重命名线程。

### `POST /api/assistant/threads/:id/delete`

删除线程。
