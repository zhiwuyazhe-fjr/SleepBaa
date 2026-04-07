# 助手模块接口

## 前端入口

- `AssistantFacade.sendPrompt(prompt)`
- `AssistantFacade.currentThread`
- `AssistantFacade.currentMessages`

## Flutter 调用链

- page -> `AssistantFacade`
- facade -> `AssistantRepository`
- facade -> `AssistantReplyGateway`
- gateway -> `POST /api/assistant/reply`

## CloudBase 路由

### `POST /api/assistant/reply`

请求：

```json
{
  "threadId": "thread-user-123",
  "prompt": "今晚宿舍有点吵怎么办"
}
```

返回：

```json
{
  "reply": "先用耳塞和低刺激音频兜底。",
  "runId": "run-123",
  "intent": "noise_issue",
  "provider": "deterministic-fallback",
  "model": "rules-v1",
  "recommendedActions": [],
  "updatedSurfaces": ["assistant_context", "home_pre_sleep"]
}
```

## 涉及集合

- `assistant_threads`
- `assistant_messages`
- `user_state`
- `card_snapshots`
- `assistant_runs`

## 后端职责

- 确保线程存在
- 写 user message
- 组装 assistant context
- 分类意图
- 调用 AI provider
- 必要时刷新今晚计划
- 写 assistant message
- 记录 `assistant_runs`

## 是否依赖真实 AI

- 否，fallback 可以直接跑通
- 是，接入真实 AI 时只改 `provider_factory.ts`
