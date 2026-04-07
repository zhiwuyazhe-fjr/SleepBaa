# 睡眠模块接口

## 前端入口

- `SleepFacade.enterSleepMode()`
- `SleepFacade.exitSleepMode()`
- `SleepFacade.addNightAwakening(...)`
- `SleepFacade.submitMorningFeedback(...)`

## Flutter 调用链

- facade -> `SleepExperienceController`
- controller -> `SleepSessionRepository`
- repository -> `POST /api/sleep/enter`
- repository -> `POST /api/sleep/exit`
- repository -> `POST /api/feedback/morning`

## CloudBase 路由

### `POST /api/sleep/enter`

请求：

```json
{
  "dormId": "dorm-user123",
  "recommendationSnapshot": [],
  "selectedRecommendationIds": []
}
```

返回：

```json
{
  "sessionId": "session-123",
  "status": "active",
  "updatedSurfaces": ["sleep_mode"]
}
```

### `POST /api/sleep/exit`

请求：

```json
{
  "sessionId": "session-123",
  "status": "awaitingFeedback",
  "endedAt": "2026-04-06T23:00:00.000Z",
  "awakenings": []
}
```

### `POST /api/feedback/morning`

请求：

```json
{
  "sessionId": "session-123",
  "summary": {
    "sleepQuality": 72,
    "restedLevel": 68,
    "totalSleepHours": 6.9,
    "awakeningsCount": 1,
    "note": "Noise after 1am"
  },
  "feedback": []
}
```

## 涉及集合

- `sleep_sessions`
- `user_state`
- `card_snapshots`
- `notifications`

## 触发器

- `on-sleep-session-write`

## 当前实现重点

- 进入睡眠前会先 `ensureAuthenticated()`
- BFF 落库后统一复用 `handleSleepSessionChange`
- `completed` 分支会更新 `feedbackLoop` 和 `profile_report`
