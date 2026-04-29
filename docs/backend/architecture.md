# Backend Architecture

最后核验日期：2026-04-29。本文以 `functions/src/**` 与 Flutter 端 `lib/core/**` 的当前代码为准。

## 分层总览

```text
Flutter UI
  -> AppScope / Facade / Controller / Repository interface
  -> CloudBase*Repository or InMemory*Repository
  -> CloudBaseAppApiClient
  -> CloudBase HTTP Function: app-api
  -> Repository + Orchestrator + AI Provider + CloudBase collections
```

当前后端的核心入口是 `functions/src/http/app_api.ts`。Flutter 端不会直接访问集合，而是通过 `lib/core/backend/cloudbase_app_api_client.dart` 调用 `app-api`，再由 `lib/core/data/cloudbase_repositories.dart` 把 JSON payload 转成领域模型。

## 运行模式

运行模式由 `lib/core/backend/app_environment.dart` 读取 `--dart-define` 决定：

| `APP_BACKEND` | 说明 |
| --- | --- |
| 未设置或 `in_memory` | 使用 `InMemory*Repository`，适合 UI 快速开发与本地调试。 |
| `emulator` / `staging` / `production` | 使用 CloudBase 认证、快照和 `app-api`。 |

CloudBase 模式需要配置 `CLOUDBASE_ENV_ID`、`CLOUDBASE_AUTH_BASE_URL`、`CLOUDBASE_APP_API_BASE_URL`、`CLOUDBASE_PUBLISHABLE_KEY` 等字段。Android 联调脚本会从 `.cloudbase.local.json` 注入这些值。

## HTTP Function

`app-api` 是当前移动端统一后端接口：

- 健康检查：`GET /health`
- 启动快照：`POST /api/app/bootstrap`
- 用户、设置、头像、夜间情绪、通知、睡眠、梦记、宿舍、音频目录、干扰因素、助手、卡片刷新等写接口
- 助手流式响应：`POST /api/assistant/reply/stream` 与 `POST /api/assistant/capture/stream`

鉴权在所有业务路由前通过 `resolveAuthenticatedUser` 统一解析。CloudBase 模式下使用 `Authorization: Bearer <accessToken>`；本地调试环境允许 `x-debug-uid` 或 `LOCAL_DEBUG_UID` 兜底。

## 后端模块

| 模块 | 主要文件 | 职责 |
| --- | --- | --- |
| HTTP API | `functions/src/http/app_api.ts` | 路由、参数归一化、错误响应、SSE 输出。 |
| Repository | `functions/src/repositories/firestore_repositories.ts` | CloudBase 集合读写、bootstrap payload、卡片快照、宿舍与助手持久化。 |
| 共享类型 | `functions/src/shared/types.ts` | 运行时 payload、SSE event、卡片 surface、助手类型。 |
| 助手编排 | `functions/src/services/assistant_orchestrator.ts` | 睡前计划、助手回复、梦记/事记整理、卡片刷新。 |
| Provider | `functions/src/providers/provider_factory.ts` | `deterministic`、`cloudbase_ai`、`xai_responses` provider 选择。 |
| 触发器 | `functions/src/triggers/**` | 睡眠记录、梦记记录变更后的自动派生。 |

## 关键业务链路

### 启动快照

Flutter 启动后，`CloudBaseAuthRepository.ensureAuthenticated()` 确保有有效会话，`CloudBaseAppApiClient.bootstrap()` 请求 `/api/app/bootstrap`。返回 payload 会刷新用户、设置、宿舍、睡眠、梦记、通知、助手线程、卡片快照和 `userState`。

### 睡眠模式

`/api/sleep/enter` 写入或恢复 `sleep_sessions`，同步宿舍成员 `sleepModeActive`，并触发 `handleSleepSessionChange` 派生 `sleep_mode` 卡片。`/api/sleep/pause` 与 `/api/sleep/exit` 会关闭睡眠模式，并根据是否已提交反馈把会话推进到 `paused`、`awaitingFeedback` 或 `completed`。

### 晨间反馈

`/api/feedback/morning` 将会话写成 `completed`，保存 summary 与 feedback，触发 `morning_feedback`、`profile_report`、`assistant_context` 更新。

### 助手回复

普通回复走 `reply_lite` 优先路径，先完成可见回复，再通过后台 postprocess 更新洞察和卡片。梦记/事记整理走 capture 路径，会同时返回保存后的 `SleepCaptureRecord`、记忆同步数量和 surface patch。

### 宿舍协作

宿舍接口由 `CloudBaseDormRepository` 统一调用，包含创建、邀请、成员状态、心跳、位置锚点、环境、规则提案、提醒和离开宿舍。成员在线状态与睡眠状态分离：心跳只更新 app 在线字段，睡眠模式由 sleep 接口或成员状态接口维护。

## 错误形态

普通业务错误返回 HTTP 400：

```json
{
  "code": "APP_API_ERROR",
  "message": "..."
}
```

助手流式接口用 SSE `error` event 传输错误。并发同一线程时会返回 `THREAD_TURN_BUSY`；provider 超时会返回 `ASSISTANT_REPLY_TIMEOUT`。

## 维护要求

- 新增或删除接口时，同步更新 [api-reference.md](api-reference.md)。
- 改集合字段、bootstrap payload、surface id 时，同步更新 [data-model.md](data-model.md)。
- 改助手 provider、SSE event、turn lease 或记忆写入时，同步更新 [assistant-runtime.md](assistant-runtime.md)。
- 改部署脚本或 `.cloudbase.local.example.json` 时，同步更新 [cloudbase-operations.md](cloudbase-operations.md)。
