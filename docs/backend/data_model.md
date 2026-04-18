# CloudBase 数据模型

## 顶层集合

| 集合 | 主键 | 主要写入方 | 主要读取方 | 用途 |
| --- | --- | --- | --- | --- |
| `users` | `_id = uid` | `app-api` | Flutter bootstrap | 用户基础档案 |
| `user_settings` | `_id = uid` | `app-api` | Flutter bootstrap | 睡眠偏好与提醒设置 |
| `user_state` | `_id = uid` | AI orchestrator | Flutter bootstrap | AI 全局状态 |
| `card_snapshots` | `_id = ${uid}:${surfaceId}` | AI orchestrator | Flutter bootstrap | 聚合读模型 |
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

### `sleep_sessions/{sessionId}`

```json
{
  "_id": "session-123",
  "id": "session-123",
  "uid": "user-123",
  "startedAt": "2026-04-06T23:00:00.000Z",
  "endedAt": "2026-04-07T07:00:00.000Z",
  "sleepDayKey": "2026-04-07",
  "status": "awaitingFeedback",
  "sleepModeActive": false,
  "dormId": "dorm-user123",
  "recommendations": [],
  "selectedRecommendationIds": [],
  "segments": [
    {
      "startedAt": "2026-04-06T23:00:00.000Z",
      "endedAt": "2026-04-07T07:00:00.000Z"
    }
  ],
  "trackedDurationMinutes": 480,
  "awakenings": [],
  "feedback": [],
  "summary": null,
  "updatedAt": "2026-04-07T07:00:00.000Z"
}
```

说明：

- `sleepGoalMet` 不存回 `sleep_sessions` 文档。
- `sleepGoalMet` 在 `bootstrap` 和 `AssistantContext.recentSessions` 读取出口派生，规则基于当前 `user_settings.sleepGoalHours`。
- 只有已结束且时长稳定的 `awaitingFeedback` / `completed` 记录参与派生；`active` / `paused` / `drafted` 返回 `null`。

### `card_snapshots/{uid:surfaceId}`

固定 `surfaceId`：

- `home_pre_sleep`
- `sleep_mode`
- `morning_feedback`
- `profile_report`
- `assistant_context`

## 读模型补充

- `bootstrap.data.sleepSessions[]`：原始会话字段 + 派生 `sleepGoalMet`
- `AssistantContext.recentSessions[]`：摘要字段 + 派生 `sleepGoalMet`
- `profile_report`：仍按既有汇总逻辑生成，不承担日历达标判定主入口
