# Assistant Runtime

最后核验日期：2026-04-29。本文以 `assistant_orchestrator`、`provider_factory`、`app_api` 与 Flutter `assistant_reply_gateway` 的当前实现为准。

## 调用链

```text
AssistantPage / AssistantConversationController
  -> AssistantReplyGateway
  -> CloudBaseAppApiClient
  -> /api/assistant/reply(/stream) or /api/assistant/capture(/stream)
  -> assistant_orchestrator
  -> AIProvider
  -> assistant_runs / assistant_messages / card_snapshots / memory
```

Flutter 端优先使用流式接口；本地 in-memory 模式有本地 gateway 兜底，CloudBase 模式通过 SSE 解析事件并更新对话 UI。

## Reply 与 Capture 的区别

| 路径 | 主要用途 | 持久化与派生 |
| --- | --- | --- |
| `reply` | 普通助手聊天、睡前建议、环境问答。 | 立即保存 user/assistant message；可见回复完成后后台 postprocess 更新洞察、记忆和卡片。 |
| `capture` | 把睡前输入整理成梦记或事记。 | 保存 message，同时生成 `SleepCaptureRecord`、同步记忆并返回 surface patch。 |

## 普通回复流

`POST /api/assistant/reply/stream` 的成功事件顺序：

1. `ack`
2. `message_delta`，可能出现多次
3. `message_completed`
4. `done`

`done` 可能携带：

```json
{
  "backgroundSyncPending": true,
  "reconcileAfterMs": 1500
}
```

这表示用户可见回复已经完成，但后端仍可能异步刷新卡片和记忆。Flutter `AssistantReplyGateway` 会按 backoff 做 reconcile。

## Capture 流

`POST /api/assistant/capture/stream` 的成功事件顺序：

1. `ack`
2. `message_delta`
3. `message_completed`
4. `surface_patch`
5. `capture_record`
6. `memory_synced`
7. `done`

capture 必须传 `sessionId` 和 `captureType`。`captureType` 目前规范为 `dream` 或 `memo`。

## Turn Lease

流式助手请求会以 `clientAssistantMessageId` 作为 `turnId` 尝试锁定当前线程：

- 未获得 lease：返回 SSE `error`，`code: "THREAD_TURN_BUSY"`。
- 回复过程中定时续租。
- 完成或失败后释放 lease。

这保证同一线程不会同时写入多个流式回复。前端遇到 `THREAD_TURN_BUSY` 应提示用户等待当前回复完成。

## Context 策略

普通聊天先走轻量上下文：

- 低信号或问候型 prompt 使用 `reply_lite`，避免昂贵洞察路径。
- 需要时再在后台补 richer insight。
- capture 直接产出结构化记录和 memory patch。

后台卡片刷新会写入 `card_snapshots` 和 `user_state`，由下一次 bootstrap 或 reconcile 进入前端。

## Provider 模式

`functions/src/providers/provider_factory.ts` 根据 `AI_PROVIDER_MODE` 选择 provider：

| Mode | 说明 |
| --- | --- |
| `deterministic` | 规则/测试 provider，默认模型名 `rules-v1`。 |
| `cloudbase_ai` | CloudBase OpenAI-compatible gateway。默认模型 `hunyuan-2.0-instruct-20251111`。 |
| `xai_responses` | xAI Responses API。默认 base URL `https://api.x.ai/v1/responses`，默认模型 `grok-4-1-fast-reasoning`。 |

常用环境变量：

| 变量 | 说明 |
| --- | --- |
| `AI_PROVIDER_MODE` | provider 模式。部署脚本默认写入 `cloudbase_ai`。 |
| `AI_PROVIDER_MODEL` | 通用模型。 |
| `AI_PROVIDER_MODEL_REPLY` | 普通聊天回复模型覆盖。 |
| `AI_PROVIDER_MODEL_STRUCTURED` | 结构化任务模型覆盖。 |
| `AI_PROVIDER_TIMEOUT_MS` | 通用超时。 |
| `AI_PROVIDER_TIMEOUT_MS_REPLY` | 回复超时覆盖。 |
| `AI_PROVIDER_TIMEOUT_MS_STRUCTURED` | 结构化任务超时覆盖。 |
| `AI_PROVIDER_GROUP` | CloudBase 自定义 provider group。 |
| `AI_PROVIDER_API_KEY` | 自定义 group 所需 API key。 |
| `AI_PROVIDER_BASE_URL` | 自定义 provider base URL。 |

当 `cloudbase_ai` 缺少必要 CloudBase 环境时，会退回 deterministic provider；自定义 group 缺少 API key 时会明确报错。

## Assistant Collections

| Collection | 用途 |
| --- | --- |
| `assistant_profiles` | 助手昵称、人格配置。 |
| `assistant_thread_summaries` | 线程标题、当前 turn lease、最近消息。 |
| `assistant_messages` | 消息内容与 provider 元数据。 |
| `assistant_runs` | 每次 AI 调用、run id、sourceMode、错误。 |
| `assistant_memory_items` | capture 和洞察提取出的长期记忆。 |
| `card_snapshots` | 助手相关 surface 物化结果。 |

## 前端接入点

- 页面：`lib/features/assistant/presentation/pages/assistant_page.dart`
- 控制器：`lib/features/assistant/presentation/controllers/assistant_conversation_controller.dart`
- Gateway：`lib/core/backend/assistant_reply_gateway.dart`
- Repository：`lib/core/data/repositories.dart` 中的 `AssistantRepository`
- Facade：`lib/core/facades/app_facades.dart` 中的 `AssistantFacade`

## 排查顺序

1. 先确认 CloudBase access token 是否有效，客户端 401 会自动 refresh 一次。
2. 检查是否同线程重复发送导致 `THREAD_TURN_BUSY`。
3. 检查 provider 环境变量和 `provider_factory.test.ts` 覆盖的模式。
4. 检查 `assistant_runs` 中的 `sourceMode`、`provider`、`model`、`errorMessage`。
5. 检查前端是否在 `done.backgroundSyncPending` 后完成 reconcile。
