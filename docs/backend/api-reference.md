# App API Reference

最后核验日期：2026-04-29。接口清单来自 `functions/src/http/app_api.ts`，请求语义抽查自 `functions/test/*.test.ts` 与 Flutter 端 `CloudBase*Repository` 调用。

## 通用约定

业务路由都挂在 CloudBase HTTP Function `app-api` 下。CloudBase 模式请求头由 `lib/core/backend/cloudbase_app_api_client.dart` 自动添加：

| Header | 说明 |
| --- | --- |
| `Authorization: Bearer <accessToken>` | CloudBase access token。401 时客户端会尝试 refresh token 后重试一次。 |
| `x-device-id` | 本机设备 id，用于调试和后端诊断。 |
| `x-debug-uid` | 仅本地调试兜底使用；正式环境不要依赖。 |

普通 JSON 错误：

```json
{
  "code": "APP_API_ERROR",
  "message": "错误信息"
}
```

## 健康检查

| Method | Path | 说明 |
| --- | --- | --- |
| `GET` | `/health` | 返回函数运行状态、时间戳和环境变量探测结果。 |

## App Bootstrap

| Method | Path | 请求重点 | 响应重点 |
| --- | --- | --- | --- |
| `POST` | `/api/app/bootstrap` | 无必填 body。 | `AppBootstrapPayload`：用户、设置、宿舍、睡眠、梦记、事记、通知、助手线程、卡片快照、`userState`。 |
| `POST` | `/api/app/bootstrap-diagnose` | 无必填 body。 | bootstrap 诊断结果，用于定位 CloudBase 集合或权限问题。 |

## Profile, Settings, Notification

| Method | Path | 请求重点 | 响应重点 |
| --- | --- | --- | --- |
| `POST` | `/api/profile/save` | `{ profile?: object, settings?: object }`，任一为空时跳过对应保存。 | `{ profile?, settings? }`。 |
| `POST` | `/api/profile/avatar` | 头像 payload，由 `CloudBaseAuthRepository.updateAvatar` 生成。 | 更新后的用户或头像信息，并同步宿舍成员头像字段。 |
| `POST` | `/api/profile/night-mood` | `{ selectedNightMood?: string, source?: string }`。 | 保存夜间情绪后触发 `prepareTonightPlanCallable`，返回睡前计划相关 payload。 |
| `POST` | `/api/assistant/profile` | 助手配置对象。 | 保存后的 `AssistantProfile`。 |
| `POST` | `/api/notifications/read` | `{ notificationId: string, readAt?: string }`。 | `{ ok: true, notificationId }`。 |

## Sleep, Feedback, Dream, Capture

| Method | Path | 请求重点 | 响应重点 |
| --- | --- | --- | --- |
| `POST` | `/api/sleep/enter` | 可传 `sessionId` 或 session 字段；无会话时创建。 | `{ sessionId, status, updatedSurfaces: ["sleep_mode"] }`。 |
| `POST` | `/api/sleep/pause` | `{ sessionId }` 或 `{ session: { id } }`。 | 状态变为 `paused`；若已有 summary，则变为 `completed`。 |
| `POST` | `/api/sleep/exit` | `{ sessionId }` 或 `{ session: { id } }`，可传 `status: "completed"`。 | 状态变为 `awaitingFeedback`、`completed` 或保留已完成反馈后的状态。 |
| `POST` | `/api/feedback/morning` | `{ sessionId?, session?, summary?, feedback?, endedAt? }`。 | 将会话写为 `completed`，更新 `morning_feedback`、`profile_report`、`assistant_context`。 |
| `POST` | `/api/dream/save` | `{ entry: DreamEntry }`。 | `{ entryId, analysis, updatedSurfaces }`，并触发梦记 AI 分析。 |
| `POST` | `/api/sleep-capture/save` | `{ record: SleepCaptureRecord }`，`type` 会规范为 `dream` 或 `memo`。 | `{ record, updatedSurfaces: ["assistant_context"] }`。 |
| `POST` | `/api/sleep-capture/banner/show` | `{ sessionId: string }`。 | 写入 `userState.sleepCapture.pendingMemoBanner`，返回 banner payload。 |
| `POST` | `/api/sleep-capture/banner/clear` | 无必填 body。 | `{ ok: true, updatedSurfaces: ["home_pre_sleep"] }`。 |
| `POST` | `/api/interference/tonight` | 干扰因素 payload。 | 保存当晚干扰因素并返回后端持久化结果。 |
| `POST` | `/api/cards/refresh` | `{ surfaces?: SurfaceId[] }`。 | 按 surface 刷新卡片快照。 |

## Dorm

| Method | Path | 请求重点 | 响应重点 |
| --- | --- | --- | --- |
| `POST` | `/api/dorm/create` | 宿舍创建 payload。 | 创建宿舍并把当前用户写入成员表。 |
| `POST` | `/api/dorm/invite/create` | `{ expiresInHours?: number }`，默认 72。 | 创建邀请码。 |
| `POST` | `/api/dorm/invite/accept` | `{ inviteCode: string }`。 | 加入宿舍并写入成员快照。 |
| `POST` | `/api/dorm/rename` | `{ name: string }`。 | 更新宿舍名称。 |
| `POST` | `/api/dorm/member/status` | 成员状态 payload。 | 更新当前用户宿舍状态。 |
| `POST` | `/api/dorm/member-status` | 同上。 | 兼容旧路径，当前仍保留。 |
| `POST` | `/api/dorm/member/heartbeat` | 在线心跳 payload。 | 仅更新 app 在线字段，不覆盖睡眠模式。 |
| `POST` | `/api/dorm/location-anchor` | 位置锚点 payload。 | 保存宿舍位置锚点。 |
| `POST` | `/api/dorm/environment` | 环境 payload，如噪声、光照等。 | 保存宿舍环境快照。 |
| `POST` | `/api/dorm/rules` | `{ rulesSettings }` 或直接传规则设置对象。 | 保存规则或规则提案。 |
| `POST` | `/api/dorm/rules/approve` | `{ proposalId: string }`。 | 批准待确认规则。 |
| `POST` | `/api/dorm/rules/reject` | `{ proposalId: string, reason?: string }`。 | 拒绝待确认规则。 |
| `POST` | `/api/dorm/reminders/gentle` | `{ targetUid: string, anonymous?: boolean, message?: string }`。 | 发送温和提醒。 |
| `POST` | `/api/dorm/leave` | 无必填 body。 | 当前用户离开宿舍。 |

## Media

| Method | Path | 请求重点 | 响应重点 |
| --- | --- | --- | --- |
| `POST` | `/api/media/audio-catalog` | 无必填 body。 | 返回可播放音频目录。CloudBase 实现会优先读 storage 目录。 |

## Assistant Threads

| Method | Path | 请求重点 | 响应重点 |
| --- | --- | --- | --- |
| `POST` | `/api/assistant/threads` | `{ title?: string }`。 | 创建助手线程。 |
| `POST` | `/api/assistant/threads/:id` | `{ title: string }`。 | 重命名线程。 |
| `POST` | `/api/assistant/threads/:id/delete` | 无必填 body。 | `{ ok: true }`，删除线程。 |

## Assistant Reply

| Method | Path | 请求重点 | 响应重点 |
| --- | --- | --- | --- |
| `POST` | `/api/assistant/reply` | `{ threadId?, prompt, title?, clientUserMessageId?, clientAssistantMessageId? }`。 | 一次性返回 `reply`、`runId`、`intent`、`provider`、`model`、`sourceMode`、`assistantMessageId`。 |
| `POST` | `/api/assistant/reply/stream` | 同 `/api/assistant/reply`。 | SSE：`ack`、多个 `message_delta`、`message_completed`、`done`；失败时 `error`。 |
| `POST` | `/api/assistant/capture` | `{ threadId?, prompt, sessionId, captureType, title?, clientUserMessageId?, clientAssistantMessageId? }`。 | 一次性返回整理回复、保存记录、surface patch、记忆同步信息。 |
| `POST` | `/api/assistant/capture/stream` | 同 `/api/assistant/capture`。 | SSE：`ack`、`message_delta`、`message_completed`、`surface_patch`、`capture_record`、`memory_synced`、`done`；失败时 `error`。 |

### SSE Event

| Event | 说明 |
| --- | --- |
| `ack` | 服务端已接收请求，包含 `threadId` 和 `assistantMessageId`。capture 还包含 `captureType`、`sessionId`。 |
| `message_delta` | 增量文本片段，字段为 `delta`。 |
| `message_completed` | 完整回复与 provider 元数据。 |
| `surface_patch` | capture 完成后返回需要局部合并的 surface patch。 |
| `capture_record` | capture 完成后返回已保存的梦记或事记记录。 |
| `memory_synced` | capture 完成后返回记忆同步数量。 |
| `done` | 流结束。普通回复可能带 `backgroundSyncPending` 和 `reconcileAfterMs`。 |
| `error` | 流式错误。常见 `code`：`THREAD_TURN_BUSY`、`ASSISTANT_REPLY_TIMEOUT`。 |

## Legacy Disabled

| Method | Path | 当前行为 |
| --- | --- | --- |
| `POST` | `/api/auth/recover-phone-account` | HTTP 410，`code: "LEGACY_DISABLED"`。 |
| `POST` | `/api/auth/link-phone` | HTTP 410，`code: "LEGACY_DISABLED"`。 |

## 路由核验命令

```powershell
rg -n "app\.(get|post)" functions/src/http/app_api.ts
```
