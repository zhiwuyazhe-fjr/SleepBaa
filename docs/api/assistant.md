# 助手接口说明

这份文档描述当前 App 里 AI 助手相关接口的实际语义。

## 1. 前端入口

- `AssistantFacade.sendPrompt(prompt)`
- `AssistantReplyGateway.streamReply(...)`
- `AssistantReplyGateway.streamCapture(...)`

聊天页主路径是流式接口，不再依赖“先等完整 JSON 再整体展示”。

## 2. 普通聊天接口

### `POST /api/assistant/reply`

非流式兼容接口。

请求体示例：

```json
{
  "threadId": "thread-user-123",
  "prompt": "今晚宿舍有点吵怎么办？",
  "clientUserMessageId": "assistant-msg-user-1",
  "clientAssistantMessageId": "assistant-msg-assistant-1"
}
```

返回成功时：

```json
{
  "reply": "先把最直接的干扰压下来，再慢慢把节奏收回来。",
  "runId": "run-123",
  "intent": "noise_issue",
  "provider": "xai_responses",
  "model": "grok-4-1-fast-reasoning",
  "sourceMode": "remoteSuccess",
  "errorMessage": null,
  "updatedSurfaces": ["assistant_context"]
}
```

现在的关键语义：

- 普通聊天远端失败时，不再自动返回 fallback reply
- 失败会直接返回错误响应

### `POST /api/assistant/reply/stream`

普通聊天主接口。

事件顺序通常是：

- `ack`
- `message_delta`
- `message_completed`
- `surface_patch`
- `memory_synced`
- `done`

远端失败时：

- 不再发 fallback 正文
- 直接发 `error`

## 3. 梦记 / 事记接口

### `POST /api/assistant/capture`

非流式兼容接口。

### `POST /api/assistant/capture/stream`

梦记和事记主接口。

事件顺序通常是：

- `ack`
- `message_delta`
- `message_completed`
- `surface_patch`
- `capture_record`
- `memory_synced`
- `done`

capture 链路不是普通聊天正文链路，因此仍允许结构化 fallback 保底。

## 4. `sourceMode` 语义

- `remoteSuccess`
  - 远端模型成功完成

- `fallbackSuccess`
  - 当前主要保留给：
    - deterministic provider 模式
    - 非聊天正文的 fallback 场景
  - 普通聊天在远端失败时不再自动产出这个状态

- `error`
  - 本轮没有拿到有效服务端结果

## 5. 当前后端职责

后端会负责：

- 确保线程存在
- 先写 user message
- 构建 `reply_lite` 或 `insight_full` 上下文
- 调用统一 provider
- 必要时提炼影响因素、行动建议、长期记忆
- 写入 `assistant_runs`
- 更新 `user_state`
- 更新 `card_snapshots`
- 更新 `assistant_thread_summaries`

## 6. 当前前端职责

前端会负责：

- 先本地插入用户消息
- 先本地插入 pending assistant 气泡
- 监听 `message_delta` 实时改写助手气泡
- 在 `message_completed` 后结束 loading
- 在 `surface_patch` 后局部更新快照仓库

## 7. 现在和以前最大的不同

现在已经不再有“聊天失败时自动给一条本地回退正文”的语义。

也就是说：

- 成功就显示真实回复
- 失败就明确错误并允许重试

这样可以避免出现“正文像正常回答，但底部又挂着远端 abort”的混乱体验。
