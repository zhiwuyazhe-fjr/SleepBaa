# AI 编排说明

## 总体原则

- AI 助手是后端统一编排器，不只是一个聊天框。
- 业务层只依赖统一领域结构，不直接依赖某家模型厂商的返回格式。
- 所有模型输出都必须先转换为固定契约，再写入数据库和前端快照。
- 远端失败时允许 fallback，但不能再伪装成“联网成功”。

## 统一 Provider 契约

当前后端统一通过 `AIProvider` 输出以下业务结构：

- `StructuredAssistantReply`
- `TonightPlan`
- `DreamAnalysis`
- `MorningReviewResult`

每次调用都会返回 `AIProviderResult<T>`：

- `value`
- `providerName`
- `modelName`
- `sourceMode`
- `errorMessage`

其中：

- `sourceMode=remoteSuccess` 表示远端模型真正成功。
- `sourceMode=fallbackSuccess` 表示远端失败，结果来自 deterministic fallback。

## Provider Mode

`AI_PROVIDER_MODE` 是唯一入口，不再允许通过 `AI_PROVIDER_BASE_URL` 隐式抢占模式。

当前支持：

- `xai_responses`
- `cloudbase_ai`
- `deterministic`

默认部署参数：

- `AI_PROVIDER_MODE=cloudbase_ai`
- `AI_PROVIDER_BASE_URL=`
- `AI_PROVIDER_MODEL=hunyuan-2.0-instruct-20251111`
- `AI_PROVIDER_API_KEY=`
- `AI_PROVIDER_TIMEOUT_MS=60000`

## 多供应商扩展方式

后续新增供应商时，遵循下面的边界：

1. 在 `functions/src/providers/` 新增一个 adapter。
2. adapter 只负责请求拼装、响应提取、JSON 解析和错误归一。
3. 在 `provider_factory.ts` 增加一个显式 `mode` 分支。
4. 不修改 `assistant_orchestrator.ts`。
5. 不修改 Flutter 助手页面和 facade。

也就是说：

- 换模型：改部署参数。
- 换同一家供应商的路由地址：改部署参数。
- 换新供应商：加 adapter + 改部署参数。

## 四条 AI 主链路

### 1. `prepareTonightPlan`

触发时机：

- 保存夜间心情
- 手动刷新卡片
- 首次需要生成今晚建议时

流程：

1. 构建 assistant context。
2. 调用 provider 生成 `TonightPlan`。
3. 更新 `user_state.tonightPlan`。
4. 刷新 `home_pre_sleep` 和 `assistant_context` 快照。
5. 写入 `assistant_runs`。

### 2. `assistantReply`

触发时机：

- 用户在助手页发送 prompt

流程：

1. 先写入 user message。
2. 构建完整 assistant context。
3. `classifyIntent(prompt)`。
4. 调用 provider 生成 `StructuredAssistantReply`。
5. 必要时继续生成 `TonightPlan`。
6. 更新 `user_state`。
7. 刷新相关 surface。
8. 写入 `assistant_runs`。
9. 写入 assistant message。

### 3. `onSleepSessionWrite`

用于驱动：

- `sleep_mode`
- `morning_feedback`
- `profile_report`
- `assistant_context`

### 4. `onDreamEntryWrite`

用于驱动：

- 梦境分析写回 dream entry
- `profile_report`
- `assistant_context`

## Assistant Run 语义

`assistant_runs` 现在同时保留两层语义：

- `success`
- `fallback`
- `error`

以及主语义字段：

- `sourceMode=remoteSuccess`
- `sourceMode=fallbackSuccess`
- `sourceMode=error`

建议前端和运维排查时优先看：

- `provider`
- `model`
- `sourceMode`
- `status`
- `error`
- `createdAt`

## 前后端联动约定

### CloudBase 客户端兜底

- CloudBase 正式链路不再在 Flutter 端执行 stub fallback。
- `/api/assistant/reply` 如果返回 `fallbackSuccess`，说明后端远端调用失败，但 deterministic fallback 已成功。
- `/api/assistant/reply` 如果返回 `error`，说明客户端没有拿到有效服务端结果，本次需要提示重试。

### 消息去重

前端先生成：

- `clientUserMessageId`
- `clientAssistantMessageId`

后端写库时直接复用，保证：

- 本地乐观消息
- 远端落库消息
- 快照回流消息

最终都指向同一条记录。

### 时间显示

Flutter 反序列化层统一把：

- ISO UTC 时间
- Firestore `_seconds/_nanoseconds`

转换为本地时区，避免中国时区看到 UTC 聊天时间。

## 手机号首登

CloudBase 环境下不再匿名自动登录。

当前规则：

- 没有有效 session：进入手机号验证码登录页。
- 有 refresh token：尝试恢复 session。
- 恢复失败：清理旧 session，并要求重新手机号登录。

旧接口：

- `/api/auth/recover-phone-account`
- `/api/auth/link-phone`

现在只保留为 `legacy-disabled`，不再承担正常业务路径。
