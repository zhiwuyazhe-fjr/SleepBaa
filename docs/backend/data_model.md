# CloudBase 数据模型

## 顶层集合

| 集合名 | 主键规则 | 主要写入方 | 主要读取方 | 用途 |
| --- | --- | --- | --- | --- |
| `users` | `_id = uid` | `app-api` | Flutter bootstrap | 用户基础档案 |
| `user_settings` | `_id = uid` | `app-api` | Flutter bootstrap | 睡眠偏好、night mood |
| `user_state` | `_id = uid` | AI orchestrator | Flutter bootstrap | AI 全局状态 |
| `card_snapshots` | `_id = ${uid}:${surfaceId}` | AI orchestrator | Flutter bootstrap | 前端聚合读模型 |
| `assistant_runs` | `_id = ${uid}:${runId}` | AI orchestrator | 调试 / 审计 | AI 运行日志 |
| `sleep_sessions` | `_id = sessionId` | `app-api` | Flutter bootstrap | 睡眠主记录 |
| `dream_entries` | `_id = entryId` | `app-api` | Flutter bootstrap | 梦境原始记录 |
| `assistant_threads` | `_id = threadId` | `app-api` | Flutter bootstrap | 对话线程 |
| `assistant_messages` | `_id = ${threadId}:${messageId}` | `app-api` | Flutter bootstrap | 对话消息 |
| `notifications` | `_id = ${uid}:${notificationId}` | orchestrator / BFF | Flutter bootstrap | 通知与提醒 |
| `dorms` | `_id = dormId` | `app-api` | Flutter bootstrap | 宿舍主档案 |
| `dorm_members` | `_id = ${dormId}:${uid}` | `app-api` | Flutter bootstrap | 宿舍成员状态 |
| `dorm_events` | `_id = eventId` | `app-api` / orchestrator | Flutter bootstrap | 宿舍事件流 |
| `dorm_invites` | `_id = inviteId` | `app-api` | `app-api` | 邀请码 |

## 核心文档结构

### `users/{uid}`

```json
{
  "_id": "user-123",
  "uid": "user-123",
  "displayName": "Sleeper A1B2C3",
  "tagline": "AI sleep routine learner",
  "role": "Student",
  "dormId": "dorm-user123",
  "avatarUrl": null,
  "phoneNumber": null,
  "updatedAt": "2026-04-06T12:00:00.000Z"
}
```

### `user_settings/{uid}`

```json
{
  "_id": "user-123",
  "sleepGoalHours": 7.5,
  "bedtimeReminderEnabled": true,
  "morningReminderEnabled": true,
  "dormAlertsEnabled": true,
  "bedtimeReminder": { "hour": 23, "minute": 10 },
  "preferredTrackTitle": "Deep Ocean Waves",
  "smartSuggestionsEnabled": true,
  "selectedNightMood": "calm",
  "updatedAt": "2026-04-06T12:00:00.000Z"
}
```

### `user_state/{uid}`

```json
{
  "_id": "user-123",
  "currentPhase": "home_pre_sleep",
  "activeSessionId": null,
  "latestThreadId": "thread-user-123",
  "latestNightMood": "calm",
  "profileSummary": {
    "sleepPatternSummary": "Recent nights average 6.8 hours...",
    "highRiskFactors": ["Dorm noise", "Late routine drift"],
    "effectiveActions": ["Play wind-down audio", "Prepare earplugs"],
    "dreamTrendSummary": "Recent dream notes suggest a reflective tone.",
    "emotionTrendSummary": "Current mood is calm.",
    "lastUpdatedAt": "2026-04-06T12:00:00.000Z"
  },
  "tonightPlan": {
    "dateKey": "2026-04-06",
    "coachSummary": "Focus on noise first...",
    "riskLevel": "medium",
    "topFactors": [],
    "recommendedActions": [],
    "generatedAt": "2026-04-06T12:00:00.000Z",
    "sourceRunId": "run-xxx"
  },
  "feedbackLoop": null,
  "updatedAt": "2026-04-06T12:00:00.000Z"
}
```

### `card_snapshots/{uid:surfaceId}`

固定 surface：

- `home_pre_sleep`
- `sleep_mode`
- `morning_feedback`
- `profile_report`
- `assistant_context`

文档结构：

```json
{
  "_id": "user-123:home_pre_sleep",
  "uid": "user-123",
  "surfaceId": "home_pre_sleep",
  "version": "v-1712400000000",
  "generatedAt": "2026-04-06T12:00:00.000Z",
  "headline": "今晚计划",
  "cards": [],
  "sourceRefs": ["user_state", "sleep_sessions"]
}
```

### `sleep_sessions/{sessionId}`

```json
{
  "_id": "session-123",
  "id": "session-123",
  "uid": "user-123",
  "startedAt": "2026-04-06T15:20:00.000Z",
  "endedAt": null,
  "status": "active",
  "sleepModeActive": true,
  "dormId": "dorm-user123",
  "recommendations": [],
  "selectedRecommendationIds": [],
  "awakenings": [],
  "feedback": [],
  "summary": null,
  "updatedAt": "2026-04-06T15:20:00.000Z"
}
```

### `dream_entries/{entryId}`

```json
{
  "_id": "dream-123",
  "id": "dream-123",
  "userId": "user-123",
  "title": "走不完的走廊",
  "body": "我一直找不到教室门，越走越着急……",
  "tags": ["考试", "走廊"],
  "emotionLabel": "不安",
  "sessionId": "session-123",
  "createdAt": "2026-04-07T00:10:00.000Z",
  "ai": {
    "summary": "这条梦境更像是在投射紧张情绪。",
    "dominantEmotion": "不安",
    "suggestedFocus": "routine",
    "sourceRefs": ["dream_entries.body"],
    "updatedAt": "2026-04-07T00:10:10.000Z"
  }
}
```

### `assistant_threads/{threadId}` 与 `assistant_messages/{threadId:messageId}`

线程：

```json
{
  "_id": "thread-user-123",
  "id": "thread-user-123",
  "userId": "user-123",
  "title": "今晚睡前聊聊",
  "createdAt": "2026-04-06T12:00:00.000Z",
  "updatedAt": "2026-04-06T12:30:00.000Z"
}
```

消息：

```json
{
  "_id": "thread-user-123:msg-1",
  "id": "msg-1",
  "threadId": "thread-user-123",
  "role": "assistant",
  "content": "先从一个低刺激的小动作开始。",
  "status": "complete",
  "createdAt": "2026-04-06T12:30:00.000Z"
}
```

### `dorms / dorm_members / dorm_events / dorm_invites`

宿舍主档：

```json
{
  "_id": "dorm-user123",
  "id": "dorm-user123",
  "name": "Dorm R123",
  "overview": "Shared dorm with AI-assisted quiet-hour coordination.",
  "noiseDb": 32,
  "lightLabel": "Dim",
  "quietLabel": "Stable",
  "rulesSettings": {}
}
```

成员：

```json
{
  "_id": "dorm-user123:user-123",
  "dormId": "dorm-user123",
  "uid": "user-123",
  "name": "Sleeper A1B2C3",
  "status": "quiet",
  "sleepModeActive": false,
  "lastActiveAt": "2026-04-06T12:00:00.000Z",
  "note": "Ready for tonight's routine."
}
```

邀请：

```json
{
  "_id": "invite-123",
  "id": "invite-123",
  "dormId": "dorm-user123",
  "code": "DORM-AB12CD",
  "createdByUid": "user-123",
  "createdAt": "2026-04-06T12:00:00.000Z",
  "expiresAt": "2026-04-09T12:00:00.000Z",
  "status": "pending"
}
```

## 读写规则

### 客户端只读聚合结果

客户端最终依赖：

- `/api/app/bootstrap`
- `user_state`
- `card_snapshots`
- 聚合后的 `sleep_sessions`、`dream_entries`、`assistant_threads`

### 客户端不应直接写业务集合

目标规则是：

- 业务集合默认 `ADMINWRITE`
- Flutter 客户端只通过 `app-api` 写业务数据
- 后续如果单独开放某些用户自写集合，再额外列白名单

## 与前端模型的映射重点

### `recommendedActions[] -> NightRecommendation`

固定字段：

- `id`
- `title`
- `subtitle`
- `type`
- `priority`
- `reason`
- `route`
- `trackId`
- `tags`

### `card_snapshots -> Insights / Home 卡片`

- `home_pre_sleep`
  - 今晚建议、干扰因子、陪伴文案
- `sleep_mode`
  - 睡眠中状态卡片
- `morning_feedback`
  - 晨间反馈入口与摘要
- `profile_report`
  - 画像报告、周趋势、梦境趋势
- `assistant_context`
  - AI 对话旁路上下文
